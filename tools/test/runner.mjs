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
const filter = process.argv[2] ?? "";

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
bundle += "__finish()\n";

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
