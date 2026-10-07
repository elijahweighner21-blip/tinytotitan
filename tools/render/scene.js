// three.js approximation of the Roblox scene exported by export.luau.
import * as THREE from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { ShaderPass } from "three/addons/postprocessing/ShaderPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";

const world = await (await fetch("/world.json")).json();
const W = innerWidth;
const H = innerHeight;
const renderer = new THREE.WebGLRenderer({ antialias: true, logarithmicDepthBuffer: true, preserveDrawingBuffer: true });
renderer.setSize(W, H);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();

// Roblox material → PBR approximation. `grain` adds a subtle procedural
// pattern so large surfaces don't read as flat colour (Roblox materials are
// textured).
const MATERIALS = {
	Plastic: { r: 0.55, m: 0, grain: 0.02 },
	SmoothPlastic: { r: 0.35, m: 0, grain: 0 },
	Neon: { r: 1, m: 0, emissive: 2.2 },
	Glass: { r: 0.05, m: 0.1, glass: true },
	ForceField: { r: 1, m: 0, emissive: 1.2, glass: true },
	Metal: { r: 0.35, m: 0.8, grain: 0.04 },
	DiamondPlate: { r: 0.3, m: 0.85, grain: 0.1 },
	CorrodedMetal: { r: 0.7, m: 0.6, grain: 0.15 },
	Foil: { r: 0.2, m: 0.9, grain: 0.08 },
	Wood: { r: 0.7, m: 0, grain: 0.12, stripes: true },
	WoodPlanks: { r: 0.7, m: 0, grain: 0.14, planks: true },
	Fabric: { r: 0.95, m: 0, grain: 0.1 },
	Grass: { r: 0.95, m: 0, grain: 0.18 },
	LeafyGrass: { r: 0.95, m: 0, grain: 0.2 },
	Concrete: { r: 0.9, m: 0, grain: 0.1 },
	Pavement: { r: 0.9, m: 0, grain: 0.1 },
	Asphalt: { r: 0.9, m: 0, grain: 0.12 },
	Brick: { r: 0.85, m: 0, grain: 0.12, bricks: true },
	Cobblestone: { r: 0.85, m: 0, grain: 0.18 },
	Marble: { r: 0.25, m: 0, grain: 0.05 },
	Granite: { r: 0.6, m: 0, grain: 0.15 },
	Slate: { r: 0.8, m: 0, grain: 0.14 },
	Rock: { r: 0.9, m: 0, grain: 0.2 },
	Basalt: { r: 0.9, m: 0, grain: 0.2 },
	Limestone: { r: 0.85, m: 0, grain: 0.12 },
	Sandstone: { r: 0.85, m: 0, grain: 0.14 },
	Sand: { r: 0.95, m: 0, grain: 0.15 },
	Ground: { r: 0.95, m: 0, grain: 0.2 },
	Mud: { r: 0.8, m: 0, grain: 0.2 },
	Snow: { r: 0.8, m: 0, grain: 0.05 },
	Ice: { r: 0.15, m: 0.1, grain: 0.04 },
	Rubber: { r: 0.9, m: 0, grain: 0.03 },
	Cardboard: { r: 0.9, m: 0, grain: 0.1 },
	Carpet: { r: 1, m: 0, grain: 0.2 },
	Plaster: { r: 0.9, m: 0, grain: 0.06 },
	CeramicTiles: { r: 0.3, m: 0, grain: 0.05, bricks: true },
};

// World-space procedural grain (triplanar-ish), injected into the standard
// material so every surface gets a little texture at any scale.
function grainify(material, amount, kind) {
	if (!amount) return material;
	material.onBeforeCompile = (shader) => {
		shader.uniforms.grainAmount = { value: amount };
		shader.uniforms.grainKind = { value: kind };
		shader.vertexShader = shader.vertexShader
			.replace("#include <common>", "#include <common>\nvarying vec3 vWorldPos; varying vec3 vWorldNormal;")
			.replace(
				"#include <worldpos_vertex>",
				"#include <worldpos_vertex>\nvWorldPos = (modelMatrix * vec4(transformed,1.0)).xyz; vWorldNormal = normalize(mat3(modelMatrix) * objectNormal);",
			);
		shader.fragmentShader = shader.fragmentShader
			.replace(
				"#include <common>",
				`#include <common>
varying vec3 vWorldPos; varying vec3 vWorldNormal; uniform float grainAmount; uniform float grainKind;
float h3(vec3 p){ return fract(sin(dot(p, vec3(12.9898,78.233,37.719)))*43758.5453); }
float vnoise(vec3 p){ vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(h3(i),h3(i+vec3(1,0,0)),f.x),mix(h3(i+vec3(0,1,0)),h3(i+vec3(1,1,0)),f.x),f.y),
            mix(mix(h3(i+vec3(0,0,1)),h3(i+vec3(1,0,1)),f.x),mix(h3(i+vec3(0,1,1)),h3(i+vec3(1,1,1)),f.x),f.y),f.z); }`,
			)
			.replace(
				"#include <color_fragment>",
				`#include <color_fragment>
{ vec3 p = vWorldPos; float n = vnoise(p*0.9)*0.6 + vnoise(p*3.7)*0.4;
  if (grainKind > 0.5 && grainKind < 1.5) { n = 0.5 + 0.5*sin((p.x+p.z)*1.7 + vnoise(p*0.6)*4.0); }
  if (grainKind > 1.5 && grainKind < 2.5) { n = step(0.06, fract(p.x*0.25)) * (0.7 + 0.3*vnoise(p*0.7)); }
  if (grainKind > 2.5) { vec2 q = vec2(p.x + p.z, p.y); q.x += step(0.5, fract(q.y*0.5))*1.0;
     n = step(0.08, fract(q.x*0.5)) * step(0.1, fract(q.y*1.0)); }
  diffuseColor.rgb *= 1.0 - grainAmount + grainAmount * 2.0 * n * 0.5 + grainAmount*0.5; }`,
			);
	};
	material.customProgramCacheKey = () => `grain-${amount}-${kind}`;
	return material;
}

const materialCache = new Map();
function materialFor(part) {
	const key = `${part.mt}|${part.k.join(",")}|${part.t.toFixed(2)}`;
	let mat = materialCache.get(key);
	if (mat) return mat;
	const def = MATERIALS[part.mt] ?? MATERIALS.Plastic;
	const color = new THREE.Color(`rgb(${part.k[0]},${part.k[1]},${part.k[2]})`);
	const kind = def.stripes ? 1 : def.planks ? 2 : def.bricks ? 3 : 0;
	if (def.emissive) {
		mat = new THREE.MeshStandardMaterial({ color: color.clone().multiplyScalar(0.3), emissive: color, emissiveIntensity: def.emissive });
	} else {
		mat = grainify(new THREE.MeshStandardMaterial({ color, roughness: def.r, metalness: def.m, envMapIntensity: 1 }), def.grain, kind);
	}
	const alpha = 1 - part.t;
	if (def.glass || part.t > 0.01) {
		mat.transparent = true;
		mat.opacity = def.glass ? Math.min(alpha, 0.55) : alpha;
		mat.depthWrite = alpha > 0.6;
	}
	materialCache.set(key, mat);
	return mat;
}

const unitBox = new THREE.BoxGeometry(1, 1, 1);
const unitBall = new THREE.SphereGeometry(0.5, 28, 18);
const unitCyl = new THREE.CylinderGeometry(0.5, 0.5, 1, 28).rotateZ(Math.PI / 2); // Roblox cylinders run along X
const unitWedge = (() => {
	// High edge at +Z, slope facing -Z/up (Roblox WedgePart).
	const s = new THREE.Shape();
	s.moveTo(-0.5, -0.5);
	s.lineTo(0.5, -0.5);
	s.lineTo(0.5, 0.5);
	s.lineTo(-0.5, -0.5);
	const g = new THREE.ExtrudeGeometry(s, { depth: 1, bevelEnabled: false });
	g.translate(0, 0, -0.5);
	g.rotateY(-Math.PI / 2); // shape X → world Z
	return g;
})();
const GEOMETRY = {
	Block: unitBox,
	Ball: unitBall,
	Cylinder: unitCyl,
	Wedge: unitWedge,
	CornerWedge: unitWedge,
	TerrainCylinder: new THREE.CylinderGeometry(0.5, 0.5, 1, 40), // terrain cylinders run along Y
};

function addPart(part) {
	const geo = GEOMETRY[part.s] ?? unitBox;
	const mesh = new THREE.Mesh(geo, materialFor(part));
	const c = part.c;
	const m = new THREE.Matrix4().set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
	m.multiply(new THREE.Matrix4().makeScale(part.z[0], part.z[1], part.z[2]));
	mesh.matrixAutoUpdate = false;
	mesh.matrix.copy(m);
	const isEmissive = (MATERIALS[part.mt] ?? {}).emissive;
	mesh.castShadow = !isEmissive && part.t < 0.5;
	mesh.receiveShadow = true;
	scene.add(mesh);
}
for (const part of world.parts) addPart(part);

// Terrain fills, drawn as their primitive shapes with Roblox's default
// terrain colours (or the colours the game sets).
const TERRAIN = {
	Grass: [106, 127, 63], LeafyGrass: [115, 132, 74], Rock: [102, 108, 111], Snow: [195, 199, 218], Ground: [102, 92, 59],
	Water: [12, 84, 92], Sand: [143, 126, 95], Mud: [58, 46, 36], Slate: [63, 127, 107], Sandstone: [137, 90, 71],
	Basalt: [30, 30, 37], Glacier: [101, 176, 234], Salt: [198, 189, 181], Limestone: [206, 173, 148], Pavement: [148, 148, 140],
	Asphalt: [115, 123, 107], Ice: [129, 194, 224], CrackedLava: [232, 156, 74], Cobblestone: [132, 123, 90], Concrete: [127, 102, 63],
};
const terrainGeo = { Block: unitBox, Ball: unitBall, Cylinder: new THREE.CylinderGeometry(0.5, 0.5, 1, 40), Wedge: unitWedge };
for (const f of world.terrain ?? []) {
	const col = world.terrainColors?.[f.mt] ?? TERRAIN[f.mt] ?? [120, 120, 120];
	const water = f.mt === "Water";
	addPart({ s: f.k === "Cylinder" ? "TerrainCylinder" : f.k, z: f.z, c: f.c, k: col, t: water ? 0.35 : 0, mt: water ? "Glass" : f.mt === "Snow" ? "Snow" : f.mt === "Grass" ? "Grass" : "Rock" });
}

// Point lights (cheap: only the nearest few are enabled per shot).
const pointLights = world.lights.map((l) => {
	const light = new THREE.PointLight(new THREE.Color(`rgb(${l.k[0]},${l.k[1]},${l.k[2]})`), 0, l.r, 1.6);
	light.position.set(l.p[0], l.p[1], l.p[2]);
	light.userData = l;
	light.visible = false;
	scene.add(light);
	return light;
});

const sun = new THREE.DirectionalLight(0xffffff, 1);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.02;
scene.add(sun, sun.target);
const hemi = new THREE.HemisphereLight(0xffffff, 0x444444, 1);
scene.add(hemi);

// Sky dome: gradient from horizon (atmosphere colour) to zenith.
const skyUniforms = { top: { value: new THREE.Color(0x5a8fd8) }, horizon: { value: new THREE.Color(0xcfe3f5) }, sunDir: { value: new THREE.Vector3() } };
const sky = new THREE.Mesh(
	new THREE.SphereGeometry(1, 32, 16),
	new THREE.ShaderMaterial({
		side: THREE.BackSide,
		depthWrite: false,
		fog: false,
		uniforms: skyUniforms,
		vertexShader: "varying vec3 vDir; void main(){ vDir = normalize(position); vec4 p = projectionMatrix * modelViewMatrix * vec4(position,1.0); gl_Position = p.xyww; }",
		fragmentShader:
			"uniform vec3 top; uniform vec3 horizon; uniform vec3 sunDir; varying vec3 vDir; void main(){ float h = clamp(vDir.y, 0.0, 1.0); vec3 c = mix(horizon, top, pow(h, 0.55)); float s = max(dot(normalize(vDir), sunDir), 0.0); c += vec3(1.0,0.9,0.7) * (pow(s, 600.0)*3.0 + pow(s, 12.0)*0.25); if (vDir.y < 0.0) c = horizon * 0.92; gl_FragColor = vec4(c, 1.0); }",
	}),
);
sky.frustumCulled = false;
sky.renderOrder = -1;
scene.add(sky);

const camera = new THREE.PerspectiveCamera(70, W / H, 0.05, 2e6);
const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(W, H), 0.6, 0.5, 0.9);
composer.addPass(bloom);
const grade = new ShaderPass({
	uniforms: { tDiffuse: { value: null }, brightness: { value: 0 }, contrast: { value: 0 }, saturation: { value: 0 }, tint: { value: new THREE.Color(1, 1, 1) } },
	vertexShader: "varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }",
	fragmentShader:
		"uniform sampler2D tDiffuse; uniform float brightness; uniform float contrast; uniform float saturation; uniform vec3 tint; varying vec2 vUv; void main(){ vec4 c = texture2D(tDiffuse, vUv); vec3 col = c.rgb * tint + brightness; col = (col - 0.5) * (1.0 + contrast) + 0.5; float l = dot(col, vec3(0.299,0.587,0.114)); col = mix(vec3(l), col, 1.0 + saturation); gl_FragColor = vec4(col, c.a); }",
});
composer.addPass(grade);
composer.addPass(new OutputPass());

const rgb = (a, k = 1) => new THREE.Color(`rgb(${a[0]},${a[1]},${a[2]})`).multiplyScalar(k);

function applyLighting(L) {
	const t = L.ClockTime;
	const theta = ((t - 6) / 12) * Math.PI;
	const dir = new THREE.Vector3(Math.cos(theta), Math.max(Math.sin(theta), -0.2) * 0.9, 0.45).normalize();
	const day = Math.max(0, Math.sin(theta));
	sun.intensity = (0.6 + L.Brightness * 0.9) * Math.min(1, day * 2.5 + 0.05);
	sun.color = new THREE.Color(1, 0.94 + 0.06 * day, 0.82 + 0.18 * day);
	sun.userData.dir = dir;
	skyUniforms.sunDir.value.copy(dir);
	hemi.color = rgb(L.OutdoorAmbient, 1 / 255 * 0 + 1).multiplyScalar(1.1);
	hemi.groundColor = rgb(L.Ambient).multiplyScalar(1.0);
	hemi.intensity = 1.5;
	renderer.toneMappingExposure = Math.pow(2, L.Exposure ?? 0) * 0.95;
	const atm = L.Atmosphere;
	if (atm) {
		const fogColor = rgb(atm.Color).lerp(rgb(L.OutdoorAmbient), 0.25);
		scene.fog = new THREE.FogExp2(fogColor, atm.Density * 0.0011 * (0.6 + 0.4 * Math.min(atm.Haze, 3) / 3));
		skyUniforms.horizon.value = fogColor.clone().lerp(new THREE.Color(1, 1, 1), 0.15);
		skyUniforms.top.value = new THREE.Color(0.25, 0.45, 0.85).lerp(rgb(atm.Color), 0.25 + 0.1 * Math.min(atm.Haze, 3)).multiplyScalar(0.25 + 0.75 * day + 0.1);
	} else {
		scene.fog = null;
	}
	if (L.Bloom && L.Bloom.Enabled !== false) {
		bloom.strength = L.Bloom.Intensity * 0.9;
		bloom.threshold = Math.min(0.98, L.Bloom.Threshold * 0.75);
		bloom.radius = Math.min(1, L.Bloom.Size / 56);
	} else bloom.strength = 0;
	const g = L.Grade;
	if (g && g.Enabled !== false) {
		grade.uniforms.brightness.value = g.Brightness;
		grade.uniforms.contrast.value = g.Contrast;
		grade.uniforms.saturation.value = g.Saturation;
		grade.uniforms.tint.value = rgb(g.Tint);
	}
}

// Stand-in avatar so every shot has a human scale reference.
const avatar = new THREE.Group();
{
	const skin = new THREE.MeshStandardMaterial({ color: 0xf2c49b, roughness: 0.6 });
	const shirt = new THREE.MeshStandardMaterial({ color: 0x2f7fe0, roughness: 0.7 });
	const pants = new THREE.MeshStandardMaterial({ color: 0x29324a, roughness: 0.8 });
	const box = (w, h, d, x, y, mat) => {
		const m = new THREE.Mesh(unitBox, mat);
		m.scale.set(w, h, d);
		m.position.set(x, y, 0);
		m.castShadow = true;
		avatar.add(m);
	};
	box(0.45, 1.9, 0.45, -0.28, 0.95, pants);
	box(0.45, 1.9, 0.45, 0.28, 0.95, pants);
	box(1.15, 1.6, 0.6, 0, 2.7, shirt);
	box(0.4, 1.55, 0.4, -0.8, 2.7, shirt);
	box(0.4, 1.55, 0.4, 0.8, 2.7, shirt);
	box(0.75, 0.75, 0.75, 0, 3.9, skin);
	avatar.children.forEach((c) => (c.userData.base = c.scale.clone()));
}
scene.add(avatar);

window.renderShot = (shot) => {
	const zone = world.zones[shot.zone];
	applyLighting(shot.lighting ?? zone.Lighting);
	let target;
	if (shot.at) {
		const s = shot.scale ?? 1;
		const h = 5 * s;
		const at = new THREE.Vector3(...shot.at);
		avatar.visible = true;
		avatar.position.copy(at);
		avatar.scale.setScalar(h / 4.3);
		avatar.rotation.y = THREE.MathUtils.degToRad(shot.yaw ?? 0) + Math.PI;
		const dist = shot.dist ?? Math.max(4, 11 * Math.pow(s, 0.97));
		const yaw = THREE.MathUtils.degToRad(shot.yaw ?? 0);
		const look = new THREE.Vector3(Math.sin(yaw), 0, -Math.cos(yaw));
		target = at.clone().add(new THREE.Vector3(0, h * 0.75, 0));
		const pitch = THREE.MathUtils.degToRad(shot.pitch ?? 14);
		camera.position.copy(target).addScaledVector(look, -dist * Math.cos(pitch)).add(new THREE.Vector3(0, dist * Math.sin(pitch), 0));
		camera.near = Math.max(0.02, s * 0.05);
	} else {
		avatar.visible = false;
		camera.position.set(...shot.camera);
		target = new THREE.Vector3(...shot.target);
		camera.near = 1;
	}
	camera.fov = shot.fov ?? 70;
	camera.updateProjectionMatrix();
	camera.lookAt(target);
	sky.position.copy(camera.position);
	sky.scale.setScalar(1e5);
	// Shadow frustum around the focus point.
	const span = Math.max(40, camera.position.distanceTo(target) * 6);
	const sc = sun.shadow.camera;
	sc.left = sc.bottom = -span;
	sc.right = sc.top = span;
	sc.near = 1;
	sc.far = span * 8;
	sc.updateProjectionMatrix();
	sun.target.position.copy(target);
	sun.position.copy(target).addScaledVector(sun.userData.dir, span * 3);
	// Nearest point lights only.
	// Lights that can reach the focus area, biggest reach first.
	const reach = (l) => l.position.distanceTo(target) - l.userData.r;
	const sorted = pointLights.filter((l) => reach(l) < 0).sort((a, b) => reach(a) - reach(b));
	pointLights.forEach((l) => (l.visible = false));
	for (const l of sorted.slice(0, 40)) {
		l.visible = true;
		l.intensity = l.userData.b * l.userData.r * l.userData.r * 0.35;
	}
	composer.render();
};
window.ready = true;
