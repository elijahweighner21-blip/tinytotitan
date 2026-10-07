// Renders the game's UI (HUD and every menu) to screenshots by translating
// the exported Roblox GUI tree into HTML/CSS (layouts → flex/grid).
//
//   node tools/render/ui.mjs [--fresh] [--bg build/render/camp-a.png]
//                            [--width 1280 --height 720] [--only hud,Shop]
import fs from "node:fs";
import path from "node:path";
import http from "node:http";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const outDir = path.join(root, "build", "render", "ui");
fs.mkdirSync(outDir, { recursive: true });
const args = process.argv.slice(2);
const opt = (name, d) => {
	const i = args.indexOf(name);
	return i >= 0 ? args[i + 1] : d;
};

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

const uiFile = path.join(outDir, "ui.json");
if (args.includes("--fresh") || !fs.existsSync(uiFile)) {
	const rawFile = path.join(outDir, "export.txt");
	const fd = fs.openSync(rawFile, "w");
	execFileSync("node", [path.join(root, "tools/test/runner.mjs"), "--play", "tools/render/ui-export.luau"], { cwd: root, stdio: ["ignore", fd, "inherit"] });
	fs.closeSync(fd);
	const snaps = {};
	for (const line of fs.readFileSync(rawFile, "utf8").split("\n")) {
		const m = /^@@UI@@([^@]+)@@(.*)$/.exec(line);
		if (m) snaps[m[1]] = (snaps[m[1]] ?? "") + m[2];
	}
	const parsed = Object.fromEntries(Object.entries(snaps).map(([k, v]) => [k, JSON.parse(v)]));
	fs.writeFileSync(uiFile, JSON.stringify(parsed));
}
const ui = JSON.parse(fs.readFileSync(uiFile, "utf8"));
const only = opt("--only")?.split(",");
const bg = path.resolve(root, opt("--bg", "build/render/camp-a.png"));

const page = `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#223 url(/bg.png) center/cover no-repeat;font-family:Inter,sans-serif}
.g{position:absolute;box-sizing:border-box}
</style></head><body><script type="module" src="/page.js"></script></body></html>`;
const server = http.createServer((req, res) => {
	const url = req.url.split("?")[0];
	const files = { "/page.js": path.join(root, "tools/render/ui-page.js"), "/bg.png": bg, "/ui.json": uiFile };
	if (url === "/") {
		res.writeHead(200, { "content-type": "text/html" });
		return res.end(page);
	}
	const file = files[url];
	if (!file || !fs.existsSync(file)) {
		res.writeHead(404);
		return res.end();
	}
	res.writeHead(200, { "content-type": url.endsWith(".js") ? "text/javascript" : url.endsWith(".png") ? "image/png" : "application/json" });
	fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const browser = await chromium.launch();
const tab = await browser.newPage({ viewport: { width: Number(opt("--width", 1280)), height: Number(opt("--height", 720)) } });
tab.on("pageerror", (e) => console.error("[page]", e.message));
await tab.goto(`http://localhost:${server.address().port}/`);
await tab.waitForFunction(() => window.ready === true);
const suffix = opt("--suffix", "");
for (const name of Object.keys(ui)) {
	if (only && !only.includes(name)) continue;
	await tab.evaluate((n) => window.show(n), name);
	const file = path.join(outDir, `${name}${suffix}.png`);
	await tab.screenshot({ path: file });
	console.log(file);
}
await browser.close();
server.close();
