--!strict
--[[
	TitanWilderness — Region 8 (x -14000..-2600, z -6000..8200)

	Colossal Titans and beyond (1000–1700+ studs tall). Mountains up to 7000
	tall, a crystal valley, ancient ruins, a sky waterfall, the Colossus
	arena crater and the tomb of the first Titan (entrance only 330 tall).

	From Titan Peak you can see everything — Titan City, downtown, the
	neighbourhood, and the tiny house where it all began.

	Final art: terrain sculpting (the generator below uses parts so it works
	without a terrain asset), snow caps, mist, waterfall particles.
]]

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)

local TitanWilderness = {}

local ZONE = "TitanWilderness"

-- Terraced mountain: each terrace is a cluster of overlapping round lobes
-- (organic silhouette, still a staircase of steps < a jump), rock at the
-- base, slate higher up, snow on top.
local function mountain(
	parent: Instance,
	name: string,
	base: Vector3,
	radius: number,
	height: number,
	stepHeight: number,
	color: Color3,
	snow: boolean
)
	local model = Kit.model(parent, name, true)
	local rng = Random.new(math.floor(base.X + base.Z))
	local steps = math.max(1, math.floor(height / stepHeight))
	for i = 0, steps - 1 do
		local t = i / steps
		local r = radius * (1 - t * 0.85)
		local y = i * stepHeight
		local snowy = snow and t > 0.72
		local tone = if snowy
			then Kit.Colors.Snow
			elseif t > 0.45 then color:Lerp(Color3.fromRGB(150, 145, 150), (t - 0.45) * 1.2)
			else color:Lerp(Color3.fromRGB(96, 104, 84), 0.5 - t)
		local material = if snowy
			then Enum.Material.Snow
			elseif t > 0.45 then Enum.Material.Slate
			else Enum.Material.Rock
		local lobes = if r > 1400 then 5 elseif r > 600 then 3 else 1
		local lobeR = math.min(if lobes == 1 then r else r * 0.62, 1024)
		local spread = if lobes == 1 then 0 else math.max(0, r - lobeR)
		for l = 1, lobes do
			local a = (l / lobes) * math.pi * 2 + i * 0.7
			local offset = Vector3.new(math.cos(a) * spread, 0, math.sin(a) * spread)
			local jitter = rng:NextNumber(0.9, 1.05)
			Kit.part(model, {
				Name = "Step",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(stepHeight, math.min(lobeR * 2 * jitter, 2048), math.min(lobeR * 2 * jitter, 2048)),
				CFrame = CFrame.new(base + offset + Vector3.new(0, y + stepHeight / 2, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = tone,
				Material = material,
			})
		end
	end
	return base + Vector3.new(0, steps * stepHeight, 0)
end

-- Scenery outside the playable area: tall layered peaks that frame the sky.
local function backdropRange(parent: Instance)
	local model = Kit.model(parent, "DistantRange", true)
	local rng = Random.new(808)
	local peaks = {
		{ -17500, -4000 },
		{ -17000, 0 },
		{ -18000, 3500 },
		{ -17200, 7500 },
		{ -12000, 11500 },
		{ -7000, 12000 },
		{ -11000, -9500 },
		{ -5500, -9800 },
	}
	for _, p in peaks do
		local base = Vector3.new(p[1], 0, p[2])
		local h = rng:NextNumber(9000, 14000)
		local r = rng:NextNumber(2600, 3600)
		local layers = 7
		for i = 0, layers - 1 do
			local t = i / layers
			local w = math.min(r * 2 * (1 - t * 0.82), 2048)
			for _, off in { -1, 1 } do
				Kit.part(model, {
					Name = "Peak",
					Size = Vector3.new(w, h / layers, w),
					CFrame = CFrame.new(base + Vector3.new(off * r * 0.35 * (1 - t), (i + 0.5) * h / layers, 0))
						* CFrame.Angles(0, rng:NextNumber(0, 6) + off, 0),
					Color = if t > 0.6
						then Kit.Colors.Snow
						else Color3.fromRGB(120, 126, 150):Lerp(Color3.fromRGB(160, 160, 180), t),
					Material = if t > 0.6 then Enum.Material.Snow else Enum.Material.Rock,
					CanCollide = false,
					CastShadow = false,
				})
			end
		end
	end
end

-- Rolling hills, forests and boulders on the highlands, kept clear of the
-- spawn, the arena and every point of interest.
local function landscape(parent: Instance, avoid: { { any } }, paths: { { Vector3 } })
	local model = Kit.model(parent, "Landscape", true)
	local rng = Random.new(1717)
	local function clear(p: Vector3, r: number): boolean
		local flat = Vector3.new(p.X, 0, p.Z)
		for _, a in avoid do
			if (flat - a[1]).Magnitude < a[2] + r then
				return false
			end
		end
		-- Keep a 500-stud corridor along orb trails.
		for _, seg in paths do
			local a, b = seg[1], seg[2]
			local ab = b - a
			local t = math.clamp((flat - a):Dot(ab) / ab:Dot(ab), 0, 1)
			if (flat - (a + ab * t)).Magnitude < 500 + r then
				return false
			end
		end
		return p.X < -2900 and p.X > -13800 and p.Z > -5800 and p.Z < 8000
	end
	local hills = 0
	for _ = 1, 120 do
		if hills >= 26 then
			break
		end
		local p = Vector3.new(rng:NextNumber(-13800, -3000), 0, rng:NextNumber(-5800, 8000))
		local d = rng:NextNumber(1200, 2048)
		if clear(p, d * 0.5) then
			hills += 1
			Kit.part(model, {
				Name = "Hill",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(d, d, d),
				Position = p - Vector3.new(0, d * rng:NextNumber(0.36, 0.42), 0),
				Color = Color3.fromRGB(rng:NextInteger(98, 120), rng:NextInteger(132, 150), rng:NextInteger(80, 96)),
				Material = Enum.Material.Grass,
			})
		end
	end
	local trees = 0
	for _ = 1, 400 do
		if trees >= 70 then
			break
		end
		-- Trees grow in groves: pick a grove centre, then a few around it.
		local c = Vector3.new(rng:NextNumber(-13600, -3200), 0, rng:NextNumber(-5600, 7800))
		if clear(c, 500) then
			for _ = 1, rng:NextInteger(3, 6) do
				local p = c + Vector3.new(rng:NextNumber(-450, 450), 0, rng:NextNumber(-450, 450))
				if clear(p, 120) then
					trees += 1
					Props.pine(model, p, rng:NextNumber(450, 950), rng:NextInteger(1, 1e6))
				end
			end
		end
	end
	for _ = 1, 60 do
		local p = Vector3.new(rng:NextNumber(-13600, -3200), 0, rng:NextNumber(-5600, 7800))
		if clear(p, 200) then
			Props.boulder(model, p, rng:NextNumber(160, 420), rng:NextInteger(1, 1e6))
		end
	end
end

function TitanWilderness.build(root: Instance)
	local m = Kit.folder(root, "TitanWilderness")
	Kit.ground(m, "Highlands", -14000, -6000, -2700, 8200, 0, 10, Color3.fromRGB(110, 130, 90), Enum.Material.Grass)

	-- Titan Peak.
	local peakTop = mountain(m, "TitanPeak", Vector3.new(-11000, 0, 4000), 2600, 7000, 500, Kit.Colors.Rock, true)
	Kit.discovery(m, "TitanPeak", peakTop + Vector3.new(0, 300, 0), Vector3.new(900, 600, 900))
	Kit.collectible(m, "TitanShard", ZONE, peakTop)
	Kit.collectible(m, "GoldenOrb", ZONE, peakTop + Vector3.new(150, 0, 150))
	local beacon = Kit.pillar(m, "PeakBeacon", peakTop, 600, 60, Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	Kit.light(beacon, Color3.fromRGB(255, 240, 200), 60, 2)
	-- Lesser ridges.
	mountain(m, "Ridge", Vector3.new(-6500, 0, 6500), 1800, 3500, 450, Kit.Colors.Rock, false)
	mountain(m, "Ridge", Vector3.new(-13000, 0, -4500), 1500, 4500, 450, Kit.Colors.Rock, true)
	mountain(m, "Ridge", Vector3.new(-4000, 0, -5000), 1200, 2500, 400, Color3.fromRGB(130, 120, 110), false)

	-- Crystal Valley.
	local rng = Random.new(1601)
	local valley = Vector3.new(-6000, 0, 3000)
	for _ = 1, 26 do
		local p = valley + Vector3.new(rng:NextNumber(-1400, 1400), 0, rng:NextNumber(-1000, 1000))
		local h = rng:NextNumber(400, 1500)
		local crystal = Kit.part(m, {
			Name = "Crystal",
			Size = Vector3.new(h * 0.25, h, h * 0.25),
			CFrame = CFrame.new(p + Vector3.new(0, h * 0.45, 0))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
			Color = Kit.Colors.Crystal:Lerp(Color3.fromRGB(120, 220, 255), rng:NextNumber()),
			Material = Enum.Material.Neon,
		})
		crystal.Transparency = 0.15
	end
	Kit.discovery(m, "CrystalValley", valley + Vector3.new(0, 500, 0), Vector3.new(3000, 1000, 2200))
	Kit.orbRing(m, ZONE, valley + Vector3.new(0, 10, 0), 900, 14)
	Kit.collectible(m, "Relic", ZONE, valley + Vector3.new(300, 10, -200))

	-- Ancient Ruins.
	local ruins = Vector3.new(-8500, 0, 6500)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local h = rng:NextNumber(500, 1600)
		Kit.tower(
			m,
			"RuinPillar",
			ruins + Vector3.new(math.cos(a) * 1200, 10, math.sin(a) * 1200),
			Vector2.new(220, 220),
			h,
			Color3.fromRGB(190, 180, 160),
			Enum.Material.Limestone
		)
	end
	Kit.block(
		m,
		"RuinAltar",
		ruins + Vector3.new(0, 110, 0),
		Vector3.new(600, 200, 600),
		Color3.fromRGB(170, 160, 140),
		Enum.Material.Limestone
	)
	Kit.discovery(m, "AncientRuins", ruins + Vector3.new(0, 600, 0), Vector3.new(2600, 1200, 2600))
	Kit.collectible(m, "MemoryFragment", ZONE, ruins + Vector3.new(0, 210, 0))
	for i = 0, 4 do
		Kit.interactable(
			m,
			"Monolith",
			CFrame.new(ruins + Vector3.new(-600 + i * 300, 410, 1600)),
			Vector3.new(200, 800, 120),
			Color3.fromRGB(80, 80, 95),
			Enum.Material.Basalt,
			nil
		)
	end

	-- Sky Falls: a cliff with a glowing waterfall.
	local falls = Vector3.new(-12500, 0, -500)
	Kit.tower(m, "FallsCliff", falls, Vector2.new(1600, 900), 3000, Color3.fromRGB(110, 105, 100), Enum.Material.Rock)
	-- The falls: a glassy cascade with bright foam bands, a pool and mist.
	local water = Kit.block(
		m,
		"Waterfall",
		falls + Vector3.new(810, 1500, 0),
		Vector3.new(40, 3000, 420),
		Color3.fromRGB(150, 210, 245),
		Enum.Material.Glass
	)
	water.Transparency = 0.25
	water.CanCollide = false
	water.CastShadow = false
	for i = 1, 6 do
		local foam = Kit.block(
			m,
			"Foam",
			falls + Vector3.new(832, i * 480 - 120, rng:NextNumber(-120, 120)),
			Vector3.new(8, 220, rng:NextNumber(120, 260)),
			Color3.fromRGB(235, 248, 255),
			Enum.Material.SmoothPlastic
		)
		foam.Transparency = 0.35
		foam.CanCollide = false
		foam.CastShadow = false
	end
	local pool = Kit.pillar(
		m,
		"Pool",
		falls + Vector3.new(1250, 2, 0),
		12,
		1300,
		Color3.fromRGB(70, 150, 200),
		Enum.Material.Glass
	)
	pool.Transparency = 0.2
	pool.CanCollide = false
	local mist = Kit.block(
		m,
		"Mist",
		falls + Vector3.new(950, 80, 0),
		Vector3.new(300, 40, 500),
		Color3.fromRGB(240, 248, 255),
		Enum.Material.SmoothPlastic
	)
	mist.Transparency = 1
	mist.CanCollide = false
	local spray = Kit.sparkles(mist, Color3.fromRGB(220, 240, 255), 120, 14)
	spray.LightEmission = 0.4
	spray.Transparency = NumberSequence.new(0.5, 1)
	Kit.discovery(m, "SkyFalls", falls + Vector3.new(500, 3100, 0), Vector3.new(1000, 300, 900))
	Kit.collectible(m, "TitanShard", ZONE, falls + Vector3.new(0, 3000, 0))
	-- Ledges up the cliff face.
	for i = 1, 6 do
		Kit.block(
			m,
			"CliffLedge",
			falls + Vector3.new(900, i * 480, -300 + (i % 2) * 600),
			Vector3.new(500, 60, 400),
			Kit.Colors.Rock,
			Enum.Material.Rock
		)
	end

	-- First Titan's tomb inside a mountain flank (entrance 330 tall).
	local tomb = Kit.model(m, "FirstTitanTomb", true)
	local tc = Vector3.new(-12500, 0, 6800)
	Kit.wall(
		tomb,
		"TombWall",
		"Z",
		tc.X + 800,
		tc.Z - 800,
		tc.Z + 800,
		0,
		2000,
		200,
		{ { tc.Z - 120, tc.Z + 120, 330 } },
		Kit.Colors.Rock,
		Enum.Material.Rock
	)
	Kit.wall(
		tomb,
		"TombWall",
		"Z",
		tc.X - 800,
		tc.Z - 800,
		tc.Z + 800,
		0,
		2000,
		200,
		nil,
		Kit.Colors.Rock,
		Enum.Material.Rock
	)
	Kit.wall(
		tomb,
		"TombWall",
		"X",
		tc.Z - 800,
		tc.X - 800,
		tc.X + 800,
		0,
		2000,
		200,
		nil,
		Kit.Colors.Rock,
		Enum.Material.Rock
	)
	Kit.wall(
		tomb,
		"TombWall",
		"X",
		tc.Z + 800,
		tc.X - 800,
		tc.X + 800,
		0,
		2000,
		200,
		nil,
		Kit.Colors.Rock,
		Enum.Material.Rock
	)
	Kit.block(
		tomb,
		"TombRoof",
		tc + Vector3.new(0, 2100, 0),
		Vector3.new(1800, 200, 1800),
		Kit.Colors.Rock,
		Enum.Material.Rock
	)
	Kit.block(
		tomb,
		"Sarcophagus",
		tc + Vector3.new(0, 150, 0),
		Vector3.new(500, 300, 900),
		Color3.fromRGB(200, 170, 110),
		Enum.Material.Marble
	)
	local light =
		Kit.ball(tomb, "TombLight", tc + Vector3.new(0, 900, 0), 120, Color3.fromRGB(200, 160, 255), Enum.Material.Neon)
	light.CanCollide = false
	Kit.light(light, Color3.fromRGB(200, 160, 255), 60, 2)
	Kit.discovery(m, "FirstTitanTomb", tc + Vector3.new(0, 300, 0), Vector3.new(1300, 600, 1300))
	Kit.collectible(m, "SecretStar", ZONE, tc + Vector3.new(0, 300, 300))

	-- Colossus arena crater.
	local arena = Vector3.new(-7000, 0, -2800)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		Kit.block(
			m,
			"CraterRim",
			arena + Vector3.new(math.cos(a) * 3400, 200, math.sin(a) * 3400),
			Vector3.new(1400, 400, 500),
			Kit.Colors.Rock,
			Enum.Material.Rock
		).CFrame = CFrame.new(
			arena + Vector3.new(math.cos(a) * 3400, 200, math.sin(a) * 3400)
		) * CFrame.Angles(0, -a + math.pi / 2, 0)
	end
	Kit.discovery(m, "ColossusArena", arena + Vector3.new(0, 400, 0), Vector3.new(5000, 800, 5000))
	Kit.bossArena(m, "Colossus", arena)

	backdropRange(m)
	landscape(m, {
		{ Vector3.new(-3400, 0, 1100), 1400 }, -- spawn camp
		{ Vector3.new(-11000, 0, 4000), 3000 }, -- Titan Peak
		{ Vector3.new(-6500, 0, 6500), 2100 },
		{ Vector3.new(-13000, 0, -4500), 1800 },
		{ Vector3.new(-4000, 0, -5000), 1500 },
		{ Vector3.new(-6000, 0, 3000), 1900 }, -- crystal valley
		{ Vector3.new(-8500, 0, 6500), 1900 }, -- ruins
		{ Vector3.new(-12500, 0, -500), 1900 }, -- falls
		{ Vector3.new(-12500, 0, 6800), 1300 }, -- tomb
		{ Vector3.new(-7000, 0, -2800), 4300 }, -- Colossus crater
		{ Vector3.new(-10000, 0, 0), 1200 },
		{ Vector3.new(-13800, 0, 8000), 400 }, -- lost coin
		{ Vector3.new(-3000, 0, -5800), 400 }, -- hidden toy
	}, { { Vector3.new(-3600, 0, 1100), Vector3.new(-9000, 0, 3500) } })
	Kit.spawnPad(m, ZONE, Vector3.new(-3400, 0, 1100), 200)
	Kit.fastTravel(m, ZONE, Vector3.new(-3600, 0, 600), 200)
	Kit.npc(m, "Elder", Vector3.new(-3900, 0, 1100), Vector3.new(1, 0, 0))
	Kit.station(m, "Upgrades", "Elder's Anvil", Vector3.new(-3800, 0, 1700), 200, Color3.fromRGB(120, 255, 140))
	Kit.orbLine(m, ZONE, Vector3.new(-4600, 10, 1550), Vector3.new(-9000, 10, 3500), 16)
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(-13800, 10, 8000))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(-3000, 10, -5800))
	Kit.enemySpawner(m, "StoneGolem", valley + Vector3.new(0, 10, -1500), 3, 2000)
	Kit.enemySpawner(m, "TitanGuardian", ruins + Vector3.new(0, 10, -2000), 3, 2000)
	Kit.enemySpawner(m, "StoneGolem", Vector3.new(-10000, 10, 0), 3, 2000)
end

return TitanWilderness
