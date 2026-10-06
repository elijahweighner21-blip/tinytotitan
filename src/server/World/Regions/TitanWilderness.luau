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

local TitanWilderness = {}

local ZONE = "TitanWilderness"

-- Stepped mountain: stacked slabs shrinking upward (each step < a jump).
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
	local steps = math.max(1, math.floor(height / stepHeight))
	for i = 0, steps - 1 do
		local t = i / steps
		local r = radius * (1 - t * 0.85)
		local y = i * stepHeight
		local tone = if snow and t > 0.75 then Kit.Colors.Snow else color:Lerp(Color3.fromRGB(90, 85, 80), t * 0.4)
		Kit.part(model, {
			Name = "Step",
			Size = Vector3.new(math.min(r * 2, 2048), stepHeight, math.min(r * 2, 2048)),
			CFrame = CFrame.new(base + Vector3.new(0, y + stepHeight / 2, 0)) * CFrame.Angles(0, i * 0.35, 0),
			Color = tone,
			Material = if snow and t > 0.75 then Enum.Material.Snow else Enum.Material.Rock,
		})
	end
	return base + Vector3.new(0, steps * stepHeight, 0)
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
	local water = Kit.block(
		m,
		"Waterfall",
		falls + Vector3.new(810, 1500, 0),
		Vector3.new(30, 3000, 400),
		Color3.fromRGB(120, 200, 255),
		Enum.Material.Neon
	)
	water.Transparency = 0.35
	water.CanCollide = false
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

	Kit.spawnPad(m, ZONE, Vector3.new(-3400, 0, 1100), 200)
	Kit.fastTravel(m, ZONE, Vector3.new(-3600, 0, 600), 200)
	Kit.npc(m, "Elder", Vector3.new(-3900, 0, 1100), Vector3.new(1, 0, 0))
	Kit.station(m, "Upgrades", "Elder's Anvil", Vector3.new(-3800, 0, 1700), 200, Color3.fromRGB(120, 255, 140))
	Kit.orbLine(m, ZONE, Vector3.new(-3600, 10, 1100), Vector3.new(-9000, 10, 3500), 16)
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(-13800, 10, 8000))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(-3000, 10, -5800))
	Kit.enemySpawner(m, "StoneGolem", valley + Vector3.new(0, 10, -1500), 3, 2000)
	Kit.enemySpawner(m, "TitanGuardian", ruins + Vector3.new(0, 10, -2000), 3, 2000)
	Kit.enemySpawner(m, "StoneGolem", Vector3.new(-10000, 10, 0), 3, 2000)
end

return TitanWilderness
