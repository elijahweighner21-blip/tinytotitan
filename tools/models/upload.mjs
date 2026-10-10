// Uploads the built models (build/models/*.fbx) to Roblox with the Open Cloud
// Assets API and records their ids in src/shared/Config/ModelAssets.luau.
//
//   ROBLOX_API_KEY=... ROBLOX_USER_ID=...  node tools/models/upload.mjs [Name ...]
//   (or ROBLOX_GROUP_ID=... instead of ROBLOX_USER_ID for a group-owned game)
//
// The API key needs the Assets API with read + write. Upload under the same
// user/group that owns the game: InsertService only loads the owner's assets.
// A model that already has an id gets a new version (the id stays the same).
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const modelsDir = path.join(root, "build", "models");
const assetsFile = path.join(root, "src", "shared", "Config", "ModelAssets.luau");
const API = "https://apis.roblox.com/assets/v1";

const key = process.env.ROBLOX_API_KEY;
const userId = process.env.ROBLOX_USER_ID;
const groupId = process.env.ROBLOX_GROUP_ID;
if (!key || !(userId || groupId)) {
	console.error("Set ROBLOX_API_KEY and ROBLOX_USER_ID (or ROBLOX_GROUP_ID). See the header of this file.");
	process.exit(1);
}

function readIds() {
	const ids = {};
	const text = fs.existsSync(assetsFile) ? fs.readFileSync(assetsFile, "utf8") : "";
	for (const m of text.matchAll(/^\t(\w+) = (\d+),$/gm)) ids[m[1]] = Number(m[2]);
	return ids;
}

function writeIds(ids) {
	const lines = Object.keys(ids)
		.sort()
		.map((name) => `\t${name} = ${ids[name]},`);
	fs.writeFileSync(
		assetsFile,
		[
			"--!strict",
			"-- Roblox asset ids of the uploaded 3D models (tools/models), by model name.",
			"-- Written by tools/models/upload.mjs. A model without an id here keeps its",
			"-- generated block body, so this can fill in one model at a time.",
			"",
			lines.length ? "local ModelAssets: { [string]: number } = {" : "local ModelAssets: { [string]: number } = {}",
			...(lines.length ? [...lines, "}"] : []),
			"",
			"return ModelAssets",
			"",
		].join("\n"),
	);
}

async function call(method, url, body) {
	for (let attempt = 0; ; attempt++) {
		const res = await fetch(url, { method, headers: { "x-api-key": key }, body });
		if (res.status === 429 || res.status >= 500) {
			if (attempt >= 4) throw new Error(`${method} ${url}: ${res.status} ${await res.text()}`);
			await new Promise((r) => setTimeout(r, 2000 * 2 ** attempt));
			continue;
		}
		const text = await res.text();
		if (!res.ok) throw new Error(`${method} ${url}: ${res.status} ${text}`);
		return text ? JSON.parse(text) : {};
	}
}

async function waitFor(operation) {
	let op = operation;
	for (let i = 0; !op.done; i++) {
		if (i > 60) throw new Error(`timed out waiting for ${op.path}`);
		await new Promise((r) => setTimeout(r, 2000));
		op = await call("GET", `${API}/${op.path}`);
	}
	if (op.error) throw new Error(JSON.stringify(op.error));
	return op.response;
}

async function upload(name, existingId) {
	const file = path.join(modelsDir, `${name}.fbx`);
	const request = existingId
		? { assetId: existingId }
		: {
				assetType: "Model",
				displayName: `TinyToTitan ${name}`,
				description: `TINY → TITAN creature model: ${name}`,
				creationContext: { creator: groupId ? { groupId: String(groupId) } : { userId: String(userId) } },
			};
	const form = new FormData();
	form.append("request", JSON.stringify(request));
	form.append("fileContent", new Blob([fs.readFileSync(file)], { type: "model/fbx" }), `${name}.fbx`);
	const op = existingId ? await call("PATCH", `${API}/assets/${existingId}`, form) : await call("POST", `${API}/assets`, form);
	const asset = await waitFor(op);
	return Number(asset.assetId ?? existingId);
}

const ids = readIds();
const wanted = process.argv.slice(2);
const names = wanted.length
	? wanted
	: fs
			.readdirSync(modelsDir)
			.filter((f) => f.endsWith(".fbx"))
			.map((f) => f.slice(0, -4));
let failed = 0;
for (const name of names) {
	try {
		const id = await upload(name, ids[name]);
		ids[name] = id;
		writeIds(ids); // after each, so a later failure keeps earlier ids
		console.log(`${name}: uploaded as ${id}`);
	} catch (err) {
		failed++;
		console.error(`${name}: ${err.message}`);
	}
}
process.exit(failed ? 1 : 0);
