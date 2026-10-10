// Headless test runner for TINY → TITAN.
//
// Roblox modules use instance-based requires (require(script.Parent.X)), so we
// bundle the source tree into a virtual instance hierarchy and execute the
// specs with the standalone Luau runtime. Only pure-logic modules (configs,
// formulas, data schema, server Logic/ modules) are exercised here; anything
// touching live Roblox services is covered by static type-checking instead.
//
// Usage: node tools/test/runner.mjs [filter]
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const luau = path.join(root, ".tools", "luau");
// `--script <file>` runs a standalone Luau script (e.g. the economy simulator)
// against the same virtual tree instead of the specs.
const playIndex = process.argv.indexOf("--play");
if (playIndex >= 0) {
	runPlay(process.argv[playIndex + 1]);
	process.exit(0);
}
const scriptIndex = process.argv.indexOf("--script");
const scriptFile = scriptIndex >= 0 ? process.argv[scriptIndex + 1] : null;
const filter = scriptFile ? "\u0000" : (process.argv[2] ?? "");

const mounts = [
	["ReplicatedStorage", "Shared", "src/shared"],
	["ServerScriptService", "Server", "src/server"],
	// Client sources are mounted for static (source-scanning) specs only.
	["StarterPlayer", "Client", "src/client"],
];

function collect(dir, virtualPath, out) {
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			collect(full, [...virtualPath, entry.name], out);
		} else if (/\.luau$/.test(entry.name)) {
			let name = entry.name.replace(/(\.server|\.client)?\.luau$/, "");
			const vp = name === "init" ? virtualPath : [...virtualPath, name];
			out.push({ vp, source: fs.readFileSync(full, "utf8"), file: path.relative(root, full) });
		}
	}
}

const modules = [];
for (const [service, name, dir] of mounts) {
	const abs = path.join(root, dir);
	if (fs.existsSync(abs)) collect(abs, [service, name], modules);
}

function longString(s) {
	let level = 5;
	while (s.includes("]" + "=".repeat(level) + "]")) level++;
	const eq = "=".repeat(level);
	return `[${eq}[\n${s}]${eq}]`;
}

const prelude = fs.readFileSync(path.join(root, "tools/test/prelude.luau"), "utf8");
const specsDir = path.join(root, "tests");
const specs = fs
	.readdirSync(specsDir)
	.filter((f) => f.endsWith(".spec.luau") && f.includes(filter))
	.sort();

let bundle = prelude + "\n";
for (const m of modules) {
	bundle += `__register(${JSON.stringify(m.vp)}, ${JSON.stringify(m.file)}, ${longString(m.source)})\n`
		.replace(/^\["/, "{\"");
}
// JSON arrays -> Luau tables
bundle = bundle.replace(/__register\(\[(.*?)\],/g, (_, inner) => `__register({${inner}},`);
for (const spec of specs) {
	const source = fs.readFileSync(path.join(specsDir, spec), "utf8");
	bundle += `__runSpec(${JSON.stringify(spec)}, ${longString(source)})\n`;
}
if (scriptFile) {
	const source = fs.readFileSync(path.resolve(root, scriptFile), "utf8");
	bundle += `__runScript(${longString(source)})\n`;
} else {
	bundle += "__finish()\n";
}

const outFile = path.join(root, "build", "test-bundle.luau");
fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, bundle);
try {
	const output = execFileSync(luau, [outFile], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
	process.stdout.write(output);
} catch (err) {
	process.stdout.write(err.stdout ?? "");
	process.stderr.write(err.stderr ?? "");
	process.exit(1);
}

// Real Roblox class members from the luau-lsp definitions, so the emulator
// can flag property writes that would error in a live game.
function apiTable() {
	const defs = path.join(root, ".tools", "globalTypes.d.luau");
	if (!fs.existsSync(defs)) return "";
	const lines = fs.readFileSync(defs, "utf8").split("\n");
	const classes = [];
	let current = null;
	for (const line of lines) {
		const head = /^declare extern type (\w+)(?: extends (\w+))? with/.exec(line);
		if (head) {
			current = { name: head[1], parent: head[2] ?? "", members: [] };
			classes.push(current);
		} else if (current && /^end/.test(line)) {
			current = null;
		} else if (current) {
			const m = /^\t(?:function )?(\w+)[:(]/.exec(line);
			if (m) current.members.push(m[1]);
		}
	}
	const body = classes.map((c) => `[${JSON.stringify(c.name)}]={${[c.parent, ...c.members].map((x) => JSON.stringify(x)).join(",")}}`).join(",\n");
	return `E.api = {\n${body}\n}\n`;
}

// `--play <scenario>`: boots the real game inside the headless Roblox engine
// emulator (tools/play/*.luau) and runs a scenario script against it.
function runPlay(scenario) {
	const engineDir = path.join(root, "tools", "play");
	const engine = fs
		.readdirSync(engineDir)
		.filter((f) => /^\d\d_.*\.luau$/.test(f))
		.sort()
		.map((f) => `do\n${fs.readFileSync(path.join(engineDir, f), "utf8")}\nend\n`)
		.join("\n");
	const playMounts = [
		[["ReplicatedStorage", "Shared"], "src/shared"],
		[["ServerScriptService", "Server"], "src/server"],
		[["StarterPlayer", "StarterPlayerScripts", "Client"], "src/client"],
	];
	const entries = [];
	for (const [base, dir] of playMounts) {
		const walk = (abs, vp) => {
			for (const entry of fs.readdirSync(abs, { withFileTypes: true })) {
				const full = path.join(abs, entry.name);
				if (entry.isDirectory()) walk(full, [...vp, entry.name]);
				else if (/\.luau$/.test(entry.name)) {
					const kind = entry.name.endsWith(".server.luau") ? "server" : entry.name.endsWith(".client.luau") ? "client" : "module";
					const name = entry.name.replace(/(\.server|\.client)?\.luau$/, "");
					entries.push({ vp: name === "init" ? vp : [...vp, name], kind, file: path.relative(root, full), source: fs.readFileSync(full, "utf8") });
				}
			}
		};
		walk(path.join(root, dir), base);
	}
	entries.sort((a, b) => a.vp.length - b.vp.length);
	let bundle = engine + "\nlocal E = __E\n" + apiTable();
	// PLAY_DEFINES='{"phone":true}' → E.defines in the scenario.
	bundle += `E.defines = E.game:GetService("HttpService"):JSONDecode(${longString(process.env.PLAY_DEFINES ?? "{}")})\n`;
	for (const e of entries) {
		const vp = "{" + e.vp.map((x) => JSON.stringify(x)).join(",") + "}";
		bundle += `E.mount(${vp}, ${JSON.stringify(e.kind)}, ${longString(e.source)}, ${JSON.stringify(e.file)})\n`;
	}
	bundle += `do\n${fs.readFileSync(path.resolve(root, scenario), "utf8")}\nend\n`;
	const outFile = path.join(root, "build", "play-bundle.luau");
	fs.mkdirSync(path.dirname(outFile), { recursive: true });
	fs.writeFileSync(outFile, bundle);
	let output = "";
	let failed = false;
	try {
		output = execFileSync(luau, [outFile], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 1 << 28 });
	} catch (err) {
		output = (err.stdout ?? "") + (err.stderr ?? "");
		failed = true;
	}
	process.stdout.write(output);
	if (failed || output.includes("@@FAIL@@")) process.exit(1);
}
