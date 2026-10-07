--!strict
--[[
	FloorWorld — Region 1 (the living-room floor, x 0..320, z 0..320)

	The player starts ~1 stud tall. Everything here is built to make that feel
	enormous: carpet fibers taller than you, crumbs like boulders, coin stacks
	forming canyons, cables like fallen tree trunks, and a sneaker on the
	horizon that is the first big goal ("Reach the top of the shoe").

	Route for a microscopic player (jump ≈ 1.7 studs, so every step ≤ 1.3):
	  spawn → orb trail → rug edge (1.2) → Crumb Mountain → fiber forest
	  → coin canyon → shoe (sole 0.8, toe ramp, laces, tongue, collar 4.4)

	Final art: carpet/hardwood textures, modelled sneaker with laces, crumb
	meshes, coin meshes with embossing, a fabric couch.
]]

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)

local FloorWorld = {}

local ZONE = "FloorWorld"

local function rug(m: Instance)
	local C = Kit.Colors
	Kit.box(m, "Rug", Vector3.new(60, 0, 60), Vector3.new(170, 1.2, 190), C.Rug, Enum.Material.Fabric)
	-- Fringe along the rug's short edges: rows of little threads.
	for i = 0, 33 do
		local x = 62 + i * 5
		Kit.box(
			m,
			"Fringe",
			Vector3.new(x, 0, 56),
			Vector3.new(0.5, 0.4, 4),
			Color3.fromRGB(230, 210, 180),
			Enum.Material.Fabric
		)
		Kit.box(
			m,
			"Fringe",
			Vector3.new(x, 0, 250),
			Vector3.new(0.5, 0.4, 4),
			Color3.fromRGB(230, 210, 180),
			Enum.Material.Fabric
		)
	end
	Kit.discovery(m, "RugEdge", Vector3.new(145, 3, 62), Vector3.new(170, 6, 10))
end

local function fiberForest(m: Instance)
	-- Shag fibers on the rug: a forest at microscopic scale.
	local rng = Random.new(101)
	for gx = 0, 11 do
		for gz = 0, 10 do
			if rng:NextNumber() < 0.75 then
				local h = rng:NextNumber(1.6, 3.2)
				local x = 152 + gx * 4 + rng:NextNumber(-1, 1)
				local z = 202 + gz * 4 + rng:NextNumber(-1, 1)
				local tint = Color3.fromRGB(150 + rng:NextInteger(-20, 20), 70 + rng:NextInteger(-15, 15), 60)
				local fiber = Kit.part(m, {
					Name = "Fiber",
					Size = Vector3.new(0.35, h, 0.35),
					CFrame = CFrame.new(x, 1.2 + h / 2, z)
						* CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)),
					Color = tint,
					Material = Enum.Material.Fabric,
				})
				fiber.CastShadow = false
			end
		end
	end
	Kit.orbLine(m, ZONE, Vector3.new(154, 1.2, 204), Vector3.new(196, 1.2, 244), 8)
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(175, 1.2, 225))
end

local function crumbMountain(m: Instance)
	-- Stacked crumbs climbing to ~7 studs with steps ≤ 1.2.
	local rng = Random.new(202)
	local center = Vector3.new(100, 1.2, 130)
	local tones = { Color3.fromRGB(215, 170, 100), Color3.fromRGB(190, 140, 80), Color3.fromRGB(230, 195, 130) }
	for layer = 0, 5 do
		local radius = 12 - layer * 2
		local count = 8 - layer
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + layer * 0.6
			local size = rng:NextNumber(1.6, 3)
			local pos = center + Vector3.new(math.cos(a) * radius, layer * 1.1 + size * 0.4, math.sin(a) * radius)
			Kit.part(m, {
				Name = "Crumb",
				Size = Vector3.new(size, size * 0.8, size * 1.1),
				CFrame = CFrame.new(pos)
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
				Color = tones[rng:NextInteger(1, #tones)],
				Material = Enum.Material.Sand,
			})
		end
	end
	local summit = Kit.block(
		m,
		"CrumbSummit",
		center + Vector3.new(0, 6.6, 0),
		Vector3.new(4, 1.2, 4),
		Color3.fromRGB(235, 200, 140),
		Enum.Material.Sand
	)
	local _ = summit
	Kit.discovery(m, "CrumbMountain", center + Vector3.new(0, 9, 0), Vector3.new(8, 5, 8))
	Kit.orbRing(m, ZONE, center + Vector3.new(0, 7.2, 0), 1.2, 4)
	Kit.collectible(m, "GoldenOrb", ZONE, center + Vector3.new(0, 7.2, 0))
	-- Breakable crumbs around the base.
	for i = 1, 6 do
		local a = i * 1.05
		Kit.interactable(
			m,
			"CrumbChunk",
			CFrame.new(center + Vector3.new(math.cos(a) * 17, 0.8, math.sin(a) * 17)),
			Vector3.new(1.6, 1.6, 1.6),
			Color3.fromRGB(220, 175, 105),
			Enum.Material.Sand
		)
	end
end

local function coinCanyon(m: Instance)
	local C = Kit.Colors
	local rng = Random.new(303)
	-- Two walls of coin stacks with a winding path between them.
	for i = 0, 9 do
		for side = -1, 1, 2 do
			local x = 165 + i * 4
			local z = 292 + side * (5 + math.sin(i * 0.8) * 1.5)
			local stack = rng:NextInteger(18, 60)
			local h = stack * 0.08
			Kit.pillar(
				m,
				"CoinStack",
				Vector3.new(x, 0, z),
				h,
				2.6,
				if rng:NextNumber() < 0.5 then C.Gold else C.Steel,
				Enum.Material.Metal
			)
		end
	end
	-- Stepping stack in the middle to climb onto the canyon rim.
	for i = 1, 4 do
		Kit.pillar(m, "CoinStep", Vector3.new(160 - i * 2.6, 0, 292), i * 0.9, 2.4, C.Gold, Enum.Material.Metal)
	end
	Kit.discovery(m, "CoinCanyon", Vector3.new(185, 3, 292), Vector3.new(40, 6, 8))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(170, 0, 292))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(196, 0, 292))
	Kit.orbLine(m, ZONE, Vector3.new(166, 0, 292), Vector3.new(198, 0, 292), 6)
end

local function shoe(m: Instance)
	local shoeModel = Kit.model(m, "Sneaker", true)
	local white = Color3.fromRGB(240, 240, 240)
	local blue = Color3.fromRGB(60, 110, 200)
	local base = Vector3.new(112, 0, 288)
	-- Sole 0.8, toe ramp up to 2.5, lace plateau, tongue 3.6, collar 4.4.
	Kit.box(shoeModel, "Sole", base, Vector3.new(14, 0.8, 6), white, Enum.Material.Rubber)
	Kit.wedge(
		shoeModel,
		"ToeRamp",
		CFrame.new(base + Vector3.new(2.5, 0.8 + 0.85, 3)) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(5, 1.7, 5),
		blue,
		Enum.Material.Fabric
	)
	Kit.box(shoeModel, "Laces", base + Vector3.new(5, 0.8, 0.5), Vector3.new(4, 1.7, 5), blue, Enum.Material.Fabric)
	for i = 0, 3 do
		Kit.box(
			shoeModel,
			"Lace",
			base + Vector3.new(5.2 + i, 2.5, 0.6),
			Vector3.new(0.3, 0.25, 4.8),
			white,
			Enum.Material.Fabric
		)
	end
	Kit.box(
		shoeModel,
		"Tongue",
		base + Vector3.new(9, 0.8, 0.8),
		Vector3.new(2.5, 2.8, 4.4),
		blue,
		Enum.Material.Fabric
	)
	Kit.box(shoeModel, "Collar", base + Vector3.new(11.5, 0.8, 0), Vector3.new(2.5, 3.6, 6), blue, Enum.Material.Fabric)
	Kit.box(shoeModel, "Heel", base + Vector3.new(13, 0.8, 0.5), Vector3.new(1, 2.6, 5), white, Enum.Material.Rubber)
	Kit.discovery(shoeModel, "ShoeSummit", base + Vector3.new(12.7, 6, 3), Vector3.new(3.5, 3, 6))
	Kit.collectible(shoeModel, "TitanShard", ZONE, base + Vector3.new(12.7, 4.4, 3))
	Kit.orbLine(shoeModel, ZONE, base + Vector3.new(1, 0.8, 3), base + Vector3.new(10, 3.6, 3), 5)
	-- A dropped shoelace on the floor leads the eye from spawn to the shoe.
	for i = 0, 10 do
		Kit.box(
			m,
			"LooseLace",
			Vector3.new(60 + i * 5, 0, 286 + math.sin(i) * 2),
			Vector3.new(5, 0.35, 0.6),
			white,
			Enum.Material.Fabric
		)
	end
end

local function wireJungle(m: Instance)
	local C = Kit.Colors
	local black = Color3.fromRGB(30, 30, 35)
	-- TV stand (top at 27) with a cable switchback route up its side.
	Kit.box(m, "TVStand", Vector3.new(4, 0, 100), Vector3.new(36, 27, 120), C.DarkWood, Enum.Material.Wood)
	local tv = Kit.box(
		m,
		"TV",
		Vector3.new(12, 27, 110),
		Vector3.new(6, 50, 100),
		Color3.fromRGB(20, 20, 25),
		Enum.Material.Glass
	)
	tv.Reflectance = 0.1
	Kit.box(
		m,
		"PowerStrip",
		Vector3.new(44, 0, 150),
		Vector3.new(14, 2.5, 5),
		Color3.fromRGB(235, 235, 235),
		Enum.Material.SmoothPlastic
	)
	Kit.box(m, "CableClip", Vector3.new(40, 0, 136), Vector3.new(8, 6, 8), black, Enum.Material.SmoothPlastic)
	Kit.ramp(m, "CableRamp", Vector3.new(44, 2.5, 155), Vector3.new(44, 6, 142), 1.6, black, Enum.Material.Rubber)
	Kit.ramp(m, "CableRamp", Vector3.new(44, 6, 138), Vector3.new(44, 14, 112), 1.6, black, Enum.Material.Rubber)
	Kit.box(m, "CableClip", Vector3.new(40, 0, 104), Vector3.new(8, 14, 8), black, Enum.Material.SmoothPlastic)
	Kit.ramp(m, "CableRamp", Vector3.new(44, 14, 112), Vector3.new(44, 21, 136), 1.6, black, Enum.Material.Rubber)
	Kit.box(m, "CableClip", Vector3.new(40, 0, 136), Vector3.new(8, 21, 8), black, Enum.Material.SmoothPlastic)
	Kit.ramp(m, "CableRamp", Vector3.new(41, 21, 140), Vector3.new(38, 27, 160), 1.6, black, Enum.Material.Rubber)
	Kit.discovery(m, "TVStandTop", Vector3.new(26, 30, 185), Vector3.new(26, 6, 60))
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(30, 27, 210))
	Kit.collectible(m, "Relic", ZONE, Vector3.new(30, 27, 120))
	-- Cables snaking across the floor: trunks to climb over.
	local cables = {
		{ Vector3.new(48, 0.4, 158), Vector3.new(70, 0.4, 190) },
		{ Vector3.new(70, 0.4, 190), Vector3.new(60, 0.4, 230) },
		{ Vector3.new(52, 0.4, 170), Vector3.new(90, 0.4, 210) },
		{ Vector3.new(90, 0.4, 210), Vector3.new(80, 0.4, 248) },
	}
	for _, c in cables do
		Kit.rod(m, "Cable", c[1], c[2], 0.8, black, Enum.Material.Rubber)
	end
	Kit.discovery(m, "WireJungle", Vector3.new(70, 3, 205), Vector3.new(40, 6, 50))
	Kit.orbLine(m, ZONE, Vector3.new(50, 0, 165), Vector3.new(85, 0, 240), 7)
	Kit.orbLine(m, ZONE, Vector3.new(44, 6, 140), Vector3.new(44, 14, 114), 4)
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(60, 0, 235))
end

local function couch(m: Instance)
	local fabric = Color3.fromRGB(90, 110, 140)
	local couchModel = Kit.model(m, "Couch", true)
	for _, corner in
		{ Vector3.new(232, 0, 82), Vector3.new(308, 0, 82), Vector3.new(232, 0, 252), Vector3.new(308, 0, 252) }
	do
		Kit.box(couchModel, "Leg", corner, Vector3.new(6, 8, 6), Kit.Colors.DarkWood, Enum.Material.Wood)
	end
	Kit.box(couchModel, "Base", Vector3.new(230, 8, 80), Vector3.new(86, 12, 180), fabric, Enum.Material.Fabric)
	Kit.box(couchModel, "Back", Vector3.new(298, 20, 80), Vector3.new(18, 32, 180), fabric, Enum.Material.Fabric)
	Kit.box(couchModel, "ArmL", Vector3.new(230, 20, 80), Vector3.new(68, 12, 14), fabric, Enum.Material.Fabric)
	Kit.box(couchModel, "ArmR", Vector3.new(230, 20, 246), Vector3.new(68, 12, 14), fabric, Enum.Material.Fabric)
	for i = 0, 2 do
		Kit.box(
			couchModel,
			"Cushion",
			Vector3.new(234, 20, 96 + i * 50),
			Vector3.new(60, 5, 48),
			fabric:Lerp(Color3.new(1, 1, 1), 0.08),
			Enum.Material.Fabric
		)
	end
	-- Under the couch: dust bunnies and lost things (gap is 8 studs tall).
	Kit.discovery(m, "UnderTheCouch", Vector3.new(270, 4, 170), Vector3.new(60, 7, 140))
	local rng = Random.new(404)
	for i = 1, 14 do
		local pos = Vector3.new(rng:NextNumber(240, 305), rng:NextNumber(1, 2.5), rng:NextNumber(95, 245))
		local fluff =
			Kit.ball(m, "DustBunny", pos, rng:NextNumber(1.5, 4), Color3.fromRGB(170, 165, 160), Enum.Material.Fabric)
		fluff.Transparency = 0.15
	end
	Kit.discovery(m, "DustBunnyNest", Vector3.new(302, 3, 240), Vector3.new(14, 6, 16))
	Kit.collectible(m, "SecretStar", ZONE, Vector3.new(304, 0, 244))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(255, 0, 120))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(285, 0, 200))
	Kit.orbLine(m, ZONE, Vector3.new(245, 0, 100), Vector3.new(245, 0, 230), 8)
	for i = 1, 4 do
		Kit.interactable(
			m,
			"DustClump",
			CFrame.new(250 + i * 10, 1, 160 + (i % 2) * 20),
			Vector3.new(2, 2, 2),
			Color3.fromRGB(160, 155, 150),
			Enum.Material.Fabric,
			Enum.PartType.Ball
		)
	end
	-- Cushion summit for larger players climbing via the arm.
	Kit.orbLine(m, ZONE, Vector3.new(240, 25, 100), Vector3.new(240, 25, 230), 6)
end

local function antHill(m: Instance)
	-- The Queen's colony entrance near the kitchen arch.
	local dirt = Color3.fromRGB(120, 85, 55)
	Kit.part(m, {
		Name = "AntHill",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(18, 9, 18),
		Position = Vector3.new(180, 0, 40),
		Color = dirt,
		Material = Enum.Material.Sand,
	})
	Kit.part(m, {
		Name = "AntHole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 3, 3),
		CFrame = CFrame.new(180, 4.4, 40) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(20, 15, 10),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	Kit.bossArena(m, "Queen", Vector3.new(180, 0, 40))
	Kit.enemySpawner(m, "Ant", Vector3.new(150, 0, 75), 4, 18)
end

local function scatter(m: Instance)
	local rng = Random.new(505)
	-- Ambient floor clutter that sells the scale: hairs, grains, scratches.
	for _ = 1, 40 do
		local pos = Vector3.new(rng:NextNumber(10, 300), 0, rng:NextNumber(10, 310))
		if pos.X > 225 and pos.Z > 75 and pos.Z < 262 then
			continue -- under the couch handled separately
		end
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			Kit.part(m, {
				Name = "Hair",
				Size = Vector3.new(rng:NextNumber(10, 24), 0.12, 0.12),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
				Color = Color3.fromRGB(60, 40, 25),
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			})
		elseif kind == 2 then
			Kit.part(m, {
				Name = "Grain",
				Size = Vector3.new(0.6, 0.5, 0.7),
				Position = pos + Vector3.new(0, 0.25, 0),
				Color = Color3.fromRGB(240, 235, 220),
				Material = Enum.Material.Sand,
			})
		else
			Kit.part(m, {
				Name = "Scratch",
				Size = Vector3.new(rng:NextNumber(6, 14), 0.02, 0.3),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.01, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
				Color = Color3.fromRGB(140, 100, 65),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
	-- Pushable/throwable small objects for later sizes.
	Kit.interactable(
		m,
		"Marble",
		CFrame.new(130, 1.2 + 1, 180),
		Vector3.new(2, 2, 2),
		Color3.fromRGB(80, 160, 255),
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	Kit.interactable(
		m,
		"Marble",
		CFrame.new(205, 1.2 + 1, 120),
		Vector3.new(2, 2, 2),
		Color3.fromRGB(255, 120, 120),
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	Kit.interactable(
		m,
		"BottleCap",
		CFrame.new(90, 0.4, 290),
		Vector3.new(3, 0.8, 3),
		Color3.fromRGB(200, 40, 40),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for i = 0, 5 do
		Kit.interactable(
			m,
			"Domino",
			CFrame.new(215 + i * 4, 2.5, 160),
			Vector3.new(0.8, 5, 2.6),
			Color3.fromRGB(245, 245, 240),
			Enum.Material.SmoothPlastic
		)
	end
end

local INCH = 13.3 / 12

-- The starting camp around the spawn: a tiny person's campsite made of
-- things dropped on the floor — a bottle-cap campfire, a thread spool
-- watchtower, a matchbox table, push-pin posts strung with bead lights.
local function camp(m: Instance)
	local c = Kit.model(m, "TinyCamp")
	-- Bottle-cap campfire with glowing embers.
	local fire = Vector3.new(44, 0, 289)
	Kit.pillar(c, "CapRim", fire, 0.28 * INCH, 1.15 * INCH, Color3.fromRGB(190, 40, 46), Enum.Material.Metal)
	Kit.pillar(
		c,
		"CapInside",
		fire + Vector3.new(0, 0.05, 0),
		0.26 * INCH,
		1.0 * INCH,
		Color3.fromRGB(220, 220, 225),
		Enum.Material.Metal
	)
	local rng = Random.new(77)
	for i = 1, 6 do
		local a = i * 1.05
		local ember = Kit.ball(
			c,
			"Ember",
			fire + Vector3.new(math.cos(a) * 0.22, 0.34, math.sin(a) * 0.22),
			rng:NextNumber(0.14, 0.22),
			Color3.fromRGB(255, rng:NextInteger(110, 170), 60),
			Enum.Material.Neon
		)
		ember.CanCollide = false
	end
	local flame =
		Kit.ball(c, "FireGlow", fire + Vector3.new(0, 0.5, 0), 0.3, Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
	flame.CanCollide = false
	flame.Transparency = 0.3
	Kit.light(flame, Color3.fromRGB(255, 170, 90), 14, 1.2)
	Kit.sparkles(flame, Color3.fromRGB(255, 170, 80), 0.05, 5)
	-- Thread spool watchtower (2 in tall).
	local spool = Vector3.new(52.5, 0, 291)
	Kit.pillar(c, "SpoolFlange", spool, 0.18 * INCH, 1.5 * INCH, Color3.fromRGB(214, 180, 132), Enum.Material.Wood)
	Kit.pillar(c, "Thread", spool, 2 * INCH, 1.15 * INCH, Color3.fromRGB(70, 120, 200), Enum.Material.Fabric)
	Kit.pillar(
		c,
		"SpoolFlange",
		spool + Vector3.new(0, 1.82 * INCH, 0),
		0.18 * INCH,
		1.5 * INCH,
		Color3.fromRGB(214, 180, 132),
		Enum.Material.Wood
	)
	-- Matchbox table with a couple of spilled matches as benches.
	Kit.block(
		c,
		"Matchbox",
		Vector3.new(38.5, 0.35, 291),
		Vector3.new(2.2, 0.7, 1.5),
		Color3.fromRGB(230, 200, 70),
		Enum.Material.Cardboard
	)
	Kit.block(
		c,
		"MatchboxStrip",
		Vector3.new(38.5, 0.35, 290.24),
		Vector3.new(2.0, 0.5, 0.02),
		Color3.fromRGB(120, 70, 50),
		Enum.Material.Sand
	)
	for i, off in { Vector3.new(0, 0, -1.4), Vector3.new(1.6, 0, 0.3) } do
		local match = Kit.part(c, {
			Name = "Match",
			Size = Vector3.new(2.1, 0.12, 0.12),
			CFrame = CFrame.new(Vector3.new(38.5, 0.06, 291) + off) * CFrame.Angles(0, i * 0.8, 0),
			Color = Color3.fromRGB(235, 215, 170),
			Material = Enum.Material.Wood,
		})
		match.CanCollide = true
		Kit.ball(
			c,
			"MatchHead",
			match.CFrame * Vector3.new(1.05, 0, 0),
			0.2,
			Color3.fromRGB(200, 50, 40),
			Enum.Material.Sand
		)
	end
	-- Push-pin posts strung with bead lights around the camp.
	local warm = {
		Color3.fromRGB(255, 210, 120),
		Color3.fromRGB(255, 150, 120),
		Color3.fromRGB(150, 220, 255),
		Color3.fromRGB(180, 255, 160),
	}
	local tops = {
		Props.pushPin(c, Vector3.new(35, 0, 296), Color3.fromRGB(230, 60, 70)),
		Props.pushPin(c, Vector3.new(48, 0, 297.5), Color3.fromRGB(70, 150, 240)),
		Props.pushPin(c, Vector3.new(57, 0, 287), Color3.fromRGB(250, 200, 60)),
		Props.pushPin(c, Vector3.new(33, 0, 285), Color3.fromRGB(110, 210, 120)),
	}
	Props.stringLights(c, tops[1], tops[2], 10, 0.35, warm)
	Props.stringLights(c, tops[2], tops[3], 10, 0.35, warm)
	Props.stringLights(c, tops[4], tops[1], 12, 0.4, warm)
end

-- Room dressing at human scale: what makes the floor read as a real living
-- room from a speck's point of view.
local function livingRoom(m: Instance)
	local d = Kit.model(m, "LivingRoomDecor")
	Props.floorboards(d, 0, 0, 320, 320, 0, 6, Color3.fromRGB(150, 112, 72), 31)
	-- Wall outlet beside the spawn with a phone charger glowing green.
	Props.outlet(d, CFrame.lookAt(Vector3.new(88, 15.5, 320), Vector3.new(88, 15.5, 0)), true)
	-- Paintings.
	Props.painting(d, CFrame.lookAt(Vector3.new(70, 78, 320), Vector3.new(70, 78, 0)), 56, 38, {
		Color3.fromRGB(250, 214, 170),
		Color3.fromRGB(90, 140, 180),
		Color3.fromRGB(240, 120, 80),
		Color3.fromRGB(255, 200, 90),
	}, 11)
	Props.painting(d, CFrame.lookAt(Vector3.new(320, 82, 230), Vector3.new(0, 82, 230)), 64, 42, {
		Color3.fromRGB(200, 225, 240),
		Color3.fromRGB(110, 160, 110),
		Color3.fromRGB(245, 245, 235),
		Color3.fromRGB(80, 110, 160),
	}, 12, Color3.fromRGB(40, 40, 46))
	Props.painting(
		d,
		CFrame.lookAt(Vector3.new(60, 74, 2), Vector3.new(60, 74, 320)),
		44,
		56,
		{ Color3.fromRGB(240, 230, 210), Color3.fromRGB(220, 150, 110), Color3.fromRGB(120, 90, 160) },
		13
	)
	-- A big leafy plant in the window corner and a reading lamp by the couch.
	Props.plant(d, Vector3.new(304, 0, 302), 46, 21)
	Props.floorLamp(d, Vector3.new(304, 0, 22), 66)
end

function FloorWorld.build(root: Instance)
	local m = Kit.folder(root, "FloorWorld")
	rug(m)
	fiberForest(m)
	crumbMountain(m)
	coinCanyon(m)
	shoe(m)
	wireJungle(m)
	couch(m)
	antHill(m)
	scatter(m)
	camp(m)
	livingRoom(m)

	-- Spawn corner: first orbs are in sight of the spawn and lead to the rug.
	Kit.spawnPad(m, ZONE, Vector3.new(46, 0, 282), 0.2)
	Kit.orbLine(m, ZONE, Vector3.new(50, 0, 276), Vector3.new(62, 0, 262), 3)
	Kit.orbLine(m, ZONE, Vector3.new(66, 0, 255), Vector3.new(85, 1.2, 236), 4)
	Kit.orbLine(m, ZONE, Vector3.new(88, 1.2, 225), Vector3.new(100, 1.2, 150), 6)
	Kit.orbLine(m, ZONE, Vector3.new(110, 1.2, 120), Vector3.new(200, 1.2, 80), 8)
	Kit.orbLine(m, ZONE, Vector3.new(30, 0, 30), Vector3.new(120, 0, 30), 6)
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(25, 0, 70))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(140, 1.2, 70))
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(298, -14, 290))
	Kit.discovery(m, "CrackCave", Vector3.new(294, -9, 240), Vector3.new(26, 8, 120))
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(285, -14, 285))
	Kit.collectible(m, "Relic", ZONE, Vector3.new(300, -14, 180))

	Kit.npc(m, "Mote", Vector3.new(62, 0, 272), Vector3.new(-1, 0, 0.3))
	Kit.npc(m, "Merchant", Vector3.new(26, 0, 304), Vector3.new(1, 0, -0.5))
	Kit.station(m, "Shop", "Tiny Merchant", Vector3.new(16, 0, 300), 0.3, Color3.fromRGB(255, 200, 80))
	Kit.station(m, "Upgrades", "Growth Pod", Vector3.new(30, 0, 250), 0.3, Color3.fromRGB(120, 255, 140))
	Kit.fastTravel(m, ZONE, Vector3.new(30, 0, 270), 0.3)

	Kit.enemySpawner(m, "DustMite", Vector3.new(265, 0, 285), 4, 14)
	Kit.enemySpawner(m, "Beetle", Vector3.new(130, 1.2, 165), 2, 12)
	Kit.enemySpawner(m, "DustMite", Vector3.new(60, 0, 40), 3, 14)
end

return FloorWorld
