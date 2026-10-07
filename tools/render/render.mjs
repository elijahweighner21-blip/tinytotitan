// Renders screenshots of the generated world from player-camera positions,
// so environment and lighting changes can be judged visually outside Studio.
//
//   node tools/render/render.mjs [--fresh] [--only Zone1,Zone2] [--shots file.json]
//
// Needs three.js in .tools/render (npm install three) and Playwright's
// Chromium. This is an approximation of Roblox's renderer (no material
// textures, approximate atmosphere), good for composition, palette, scale
// and lighting mood; not a pixel-exact preview.
import fs from "node:fs";
import path from "node:path";
import http from "node:http";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

// Playwright is installed globally in this environment (or locally).
function loadPlaywright() {
	const require = createRequire(import.meta.url);
	try {
		return require("playwright");
	} catch {
		const globalRoot = execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
		return require(path.join(globalRoot, "playwright"));
	}
}
const { chromium } = loadPlaywright();

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const outDir = path.join(root, "build", "render");
fs.mkdirSync(outDir, { recursive: true });
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const opt = (name) => {
	const i = args.indexOf(name);
	return i >= 0 ? args[i + 1] : undefined;
};

const worldFile = path.join(outDir, "world.json");
if (flag("--fresh") || !fs.existsSync(worldFile)) {
	const rawFile = path.join(outDir, "export.txt");
	const fd = fs.openSync(rawFile, "w");
	execFileSync("node", [path.join(root, "tools/test/runner.mjs"), "--play", "tools/render/export.luau"], { cwd: root, stdio: ["ignore", fd, "inherit"] });
	fs.closeSync(fd);
	const out = fs.readFileSync(rawFile, "utf8");
	const chunks = out.split("\n").filter((l) => l.startsWith("@@WORLD@@"));
	if (chunks.length === 0) {
		console.error(out.slice(-4000));
		process.exit(1);
	}
	fs.writeFileSync(worldFile, chunks.map((l) => l.slice("@@WORLD@@".length)).join(""));
}
const world = JSON.parse(fs.readFileSync(worldFile, "utf8"));

// Default shots: for each zone, the player at its recommended size looking
// four ways from the spawn, plus an overview.
function defaultShots() {
	const shots = [];
	const only = opt("--only")?.split(",");
	for (const zone of Object.values(world.zones)) {
		if (only && !only.includes(zone.Id)) continue;
		const tier = zone.Recommended?.[0] ?? zone.RequiredTier ?? 1;
		const scale = world.tiers[tier - 1]?.Scale ?? 1;
		for (const yaw of [0, 90, 180, 270]) {
			shots.push({ name: `${zone.Id}-t${tier}-y${yaw}`, zone: zone.Id, at: zone.Spawn, scale, yaw });
		}
		// Overview from inside the zone's box, high up in one corner.
		const [sx, sy, sz] = zone.Size;
		const floorY = zone.Spawn[1];
		shots.push({
			name: `${zone.Id}-overview`,
			zone: zone.Id,
			camera: [zone.Center[0] + sx * 0.42, floorY + Math.min(sy * 0.45, Math.max(sx, sz) * 0.3), zone.Center[2] + sz * 0.42],
			target: [zone.Center[0] - sx * 0.1, floorY, zone.Center[2] - sz * 0.1],
		});
	}
	return shots;
}
const shots = opt("--shots") ? JSON.parse(fs.readFileSync(opt("--shots"), "utf8")) : defaultShots();

const threeDir = path.join(root, ".tools", "render", "node_modules", "three");
const page = `<!doctype html><html><head><style>html,body{margin:0;background:#000}canvas{display:block}</style>
<script type="importmap">{"imports":{"three":"/three/build/three.module.js","three/addons/":"/three/examples/jsm/"}}</script>
</head><body><script type="module" src="/scene.js"></script></body></html>`;

const server = http.createServer((req, res) => {
	const url = decodeURIComponent(req.url.split("?")[0]);
	let file;
	if (url === "/") {
		res.writeHead(200, { "content-type": "text/html" });
		return res.end(page);
	} else if (url === "/world.json") file = worldFile;
	else if (url === "/scene.js") file = path.join(root, "tools", "render", "scene.js");
	else if (url.startsWith("/three/")) file = path.join(threeDir, url.slice("/three/".length));
	if (!file || !fs.existsSync(file)) {
		res.writeHead(404);
		return res.end();
	}
	res.writeHead(200, { "content-type": file.endsWith(".js") ? "text/javascript" : "application/json" });
	fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const port = server.address().port;

const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const tab = await browser.newPage({ viewport: { width: Number(opt("--width") ?? 960), height: Number(opt("--height") ?? 540) } });
tab.on("console", (m) => {
	if (m.type() === "error") console.error("[page]", m.text());
});
tab.on("pageerror", (e) => console.error("[page]", e.message));
await tab.goto(`http://localhost:${port}/`);
await tab.waitForFunction(() => window.ready === true, null, { timeout: 120000 });
for (const shot of shots) {
	await tab.evaluate((s) => window.renderShot(s), shot);
	const file = path.join(outDir, `${shot.name}.png`);
	await tab.screenshot({ path: file });
	console.log(file);
}
await browser.close();
server.close();
