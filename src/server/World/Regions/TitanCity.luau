--!strict
--[[
	TitanCity — Region 7 (x 3400..12000, z -3200..8200)

	Titan-sized and up (600–1500+ studs tall). A golden city built at titan
	scale by the ancient Titans: streets 1200 wide, towers 1500–5000 tall.
	Downtown's skyscrapers, visible behind the Titan Wall, now look small.

	Landmarks: the Titan Gate, Colossus Plaza (giant statue), the Titan Forge,
	Sky Harbor (floating platforms), the Core Spire (7000 tall, ringed with
	ledges) and the Archive Vault (a door built for something small).

	Final art: monumental architecture, glowing runes, banners, light shafts.
]]

local Kit = require(script.Parent.Parent.Kit)

local TitanCity = {}

local ZONE = "TitanCity"

local GOLD = Color3.fromRGB(230, 195, 120)
local STONE = Kit.Colors.TitanStone

local function deco(part: Part)
	part.CanCollide = false
	part.CanQuery = false
end

-- A titan-scale tower: podium, main shaft with gold corner pilasters and
-- glowing window strips, a set-back upper tier, a crown and a beacon. The
-- climbable ledges spiral up the +X face whichever tier they're on.
local function megaTower(
	parent: Instance,
	name: string,
	base: Vector3,
	footprint: number,
	height: number,
	color: Color3
)
	local model = Kit.model(parent, name, true)
	local lowerH = math.floor(height * 0.62)
	local upperW = footprint * 0.72
	Kit.block(
		model,
		"Podium",
		base + Vector3.new(0, 60, 0),
		Vector3.new(footprint + 160, 120, footprint + 160),
		GOLD:Lerp(STONE, 0.3),
		Enum.Material.Marble
	)
	Kit.tower(model, "Body", base, Vector2.new(footprint, footprint), lowerH, color, Enum.Material.Sandstone)
	Kit.tower(
		model,
		"Upper",
		base + Vector3.new(0, lowerH, 0),
		Vector2.new(upperW, upperW),
		height - lowerH,
		color:Lerp(GOLD, 0.15),
		Enum.Material.Sandstone
	)
	-- Setback cornice where the tiers meet.
	Kit.block(
		model,
		"Cornice",
		base + Vector3.new(0, lowerH + 15, 0),
		Vector3.new(footprint + 40, 30, footprint + 40),
		GOLD,
		Enum.Material.Marble
	)
	local half = footprint / 2
	for _, c in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		for _, part in
			Kit.tower(
				model,
				"Pilaster",
				base + Vector3.new(c.X * half, 120, c.Y * half),
				Vector2.new(50, 50),
				lowerH - 120,
				GOLD,
				Enum.Material.Marble
			)
		do
			deco(part)
		end
	end
	-- Window strips: two per face, glowing warm.
	local stripH = math.min(lowerH - 360, 2000)
	local glow = Color3.fromRGB(255, 214, 140)
	for _, face in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local side = Vector3.new(face.Z, 0, face.X)
		for _, k in { -0.22, 0.22 } do
			local strip = Kit.block(
				model,
				"WindowStrip",
				base + face * (half + 2) + side * (footprint * k) + Vector3.new(0, 200 + stripH / 2, 0),
				Vector3.new(if face.X ~= 0 then 4 else 40, stripH, if face.X ~= 0 then 40 else 4),
				glow,
				Enum.Material.Neon
			)
			strip.Transparency = 0.25
			deco(strip)
		end
	end
	for y = 450, height - 300, 500 do
		local w = if y < lowerH then footprint else upperW
		Kit.block(
			model,
			"Ledge",
			base + Vector3.new(w / 2 + 60, y, 0),
			Vector3.new(120, 30, w * 0.6),
			GOLD,
			Enum.Material.Marble
		)
		deco(
			Kit.block(
				model,
				"Rune",
				base + Vector3.new(0, y + 120, w / 2 + 2),
				Vector3.new(w * 0.4, 60, 4),
				Color3.fromRGB(255, 220, 120),
				Enum.Material.Neon
			)
		)
	end
	Kit.block(
		model,
		"Crown",
		base + Vector3.new(0, height + 20, 0),
		Vector3.new(upperW + 60, 40, upperW + 60),
		GOLD,
		Enum.Material.Marble
	)
	Kit.pillar(model, "Mast", base + Vector3.new(0, height + 40, 0), 260, 24, GOLD, Enum.Material.Metal)
	deco(
		Kit.ball(
			model,
			"Beacon",
			base + Vector3.new(0, height + 310, 0),
			60,
			Color3.fromRGB(255, 236, 170),
			Enum.Material.Neon
		)
	)
end

function TitanCity.build(root: Instance)
	local m = Kit.folder(root, "TitanCity")
	Kit.ground(m, "Paving", 3460, -3200, 12000, 8200, 0, 10, STONE, Enum.Material.Sandstone)

	-- Titan Gate (the gap in the Titan Wall at z 2300..2900).
	local gate = Kit.model(m, "TitanGate", true)
	for _, z in { 2200, 3000 } do
		Kit.tower(gate, "GatePylon", Vector3.new(3500, 0, z), Vector2.new(260, 200), 1400, GOLD, Enum.Material.Marble)
	end
	Kit.block(
		gate,
		"GateLintel",
		Vector3.new(3500, 1450, 2600),
		Vector3.new(260, 100, 1000),
		GOLD,
		Enum.Material.Marble
	)
	Kit.discovery(m, "TitanGate", Vector3.new(3800, 500, 2600), Vector3.new(600, 1000, 800))

	-- Colossus Plaza.
	local plazaCenter = Vector3.new(7700, 0, 2500)
	Kit.pillar(m, "Plaza", plazaCenter, 4, 3000, Color3.fromRGB(240, 220, 170), Enum.Material.Marble)
	local statue = Kit.model(m, "ColossusStatue", true)
	Kit.tower(
		statue,
		"Plinth",
		plazaCenter + Vector3.new(0, 4, 0),
		Vector2.new(600, 600),
		400,
		GOLD,
		Enum.Material.Marble
	)
	Kit.tower(
		statue,
		"Legs",
		plazaCenter + Vector3.new(0, 404, 0),
		Vector2.new(360, 200),
		1200,
		STONE,
		Enum.Material.Sandstone
	)
	Kit.tower(
		statue,
		"Torso",
		plazaCenter + Vector3.new(0, 1604, 0),
		Vector2.new(520, 300),
		1000,
		STONE,
		Enum.Material.Sandstone
	)
	Kit.ball(statue, "Head", plazaCenter + Vector3.new(0, 2800, 0), 380, STONE, Enum.Material.Sandstone)
	Kit.block(
		statue,
		"Arm",
		plazaCenter + Vector3.new(420, 2300, 0),
		Vector3.new(160, 900, 160),
		STONE,
		Enum.Material.Sandstone
	)
	Kit.discovery(m, "ColossusPlaza", plazaCenter + Vector3.new(0, 500, 0), Vector3.new(3000, 1000, 3000))
	Kit.orbRing(m, ZONE, plazaCenter + Vector3.new(0, 4, 0), 1200, 16)
	Kit.collectible(m, "GoldenOrb", ZONE, plazaCenter + Vector3.new(0, 404, 0))

	-- Core Spire: ledges spiral to the top (rise 450 per ledge < a Titan jump).
	local spireBase = Vector3.new(10500, 0, 500)
	local spire = Kit.model(m, "CoreSpire", true)
	Kit.tower(
		spire,
		"Spire",
		spireBase,
		Vector2.new(700, 700),
		7000,
		Color3.fromRGB(200, 170, 110),
		Enum.Material.Marble
	)
	for i = 1, 15 do
		local a = i * 1.3
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		Kit.block(
			spire,
			"SpiralLedge",
			spireBase + dir * 520 + Vector3.new(0, i * 450, 0),
			Vector3.new(420, 40, 420),
			GOLD,
			Enum.Material.Marble
		)
	end
	local core = Kit.ball(
		spire,
		"Core",
		spireBase + Vector3.new(0, 7300, 0),
		500,
		Color3.fromRGB(255, 220, 100),
		Enum.Material.Neon
	)
	core.CanCollide = false
	Kit.light(core, Color3.fromRGB(255, 220, 120), 60, 3)
	Kit.discovery(m, "CoreSpire", spireBase + Vector3.new(0, 7150, 0), Vector3.new(900, 400, 900))
	Kit.collectible(m, "TitanShard", ZONE, spireBase + Vector3.new(0, 7040, 0))

	-- Sky Harbor: floating stepping platforms.
	local harbor = Kit.model(m, "SkyHarbor", true)
	local hb = Vector3.new(6000, 0, -1800)
	for i = 0, 9 do
		local a = i * 0.9
		local p = hb + Vector3.new(math.cos(a) * 900, 300 + i * 350, math.sin(a) * 900)
		Kit.block(
			harbor,
			"FloatingDock",
			p,
			Vector3.new(600, 60, 600),
			Color3.fromRGB(180, 200, 230),
			Enum.Material.Marble
		)
	end
	local top = hb + Vector3.new(0, 3800, 0)
	Kit.block(harbor, "Harbor", top, Vector3.new(1400, 80, 1400), Color3.fromRGB(200, 215, 240), Enum.Material.Marble)
	Kit.discovery(m, "SkyHarbor", top + Vector3.new(0, 300, 0), Vector3.new(1400, 500, 1400))
	Kit.collectible(m, "Relic", ZONE, top + Vector3.new(400, 40, 400))
	Kit.orbLine(m, ZONE, hb + Vector3.new(900, 330, 0), top + Vector3.new(0, 40, 0), 10)

	-- Titan Forge.
	local forge = Kit.model(m, "TitanForge", true)
	local fc = Vector3.new(9500, 0, 6500)
	Kit.tower(forge, "ForgeHall", fc, Vector2.new(1600, 1200), 900, Color3.fromRGB(140, 90, 60), Enum.Material.Basalt)
	for i = 0, 3 do
		local pool = Kit.block(
			forge,
			"MoltenPool",
			fc + Vector3.new(-600 + i * 400, 905, -700),
			Vector3.new(300, 10, 200),
			Color3.fromRGB(255, 110, 30),
			Enum.Material.Neon
		)
		Kit.light(pool, Color3.fromRGB(255, 120, 40), 60, 2)
	end
	Kit.discovery(m, "TitanForge", fc + Vector3.new(0, 1000, 0), Vector3.new(1700, 400, 1500))
	Kit.collectible(m, "MemoryFragment", ZONE, fc + Vector3.new(500, 905, 300))
	for i = 0, 4 do
		Kit.interactable(
			m,
			"TitanPillar",
			CFrame.new(fc + Vector3.new(-900, 400, -500 + i * 250)),
			Vector3.new(160, 800, 160),
			GOLD,
			Enum.Material.Marble,
			nil
		)
	end

	-- Archive Vault: a door only 170 tall (Large-sized or smaller).
	local vault = Kit.model(m, "ArchiveVault", true)
	local vc = Vector3.new(5200, 0, 6800)
	Kit.wall(
		vault,
		"VaultWall",
		"X",
		vc.Z - 500,
		vc.X - 500,
		vc.X + 500,
		0,
		1200,
		80,
		{ { vc.X - 60, vc.X + 60, 170 } },
		STONE,
		Enum.Material.Sandstone
	)
	Kit.wall(
		vault,
		"VaultWall",
		"X",
		vc.Z + 500,
		vc.X - 500,
		vc.X + 500,
		0,
		1200,
		80,
		nil,
		STONE,
		Enum.Material.Sandstone
	)
	Kit.wall(
		vault,
		"VaultWall",
		"Z",
		vc.X - 500,
		vc.Z - 500,
		vc.Z + 500,
		0,
		1200,
		80,
		nil,
		STONE,
		Enum.Material.Sandstone
	)
	Kit.wall(
		vault,
		"VaultWall",
		"Z",
		vc.X + 500,
		vc.Z - 500,
		vc.Z + 500,
		0,
		1200,
		80,
		nil,
		STONE,
		Enum.Material.Sandstone
	)
	Kit.block(vault, "VaultRoof", vc + Vector3.new(0, 1240, 0), Vector3.new(1080, 80, 1080), GOLD, Enum.Material.Marble)
	for i = 0, 5 do
		Kit.block(
			vault,
			"Shelf",
			vc + Vector3.new(-300 + i * 120, 150, 200),
			Vector3.new(60, 300, 400),
			Color3.fromRGB(140, 100, 60),
			Enum.Material.Wood
		)
	end
	Kit.discovery(m, "ArchiveVault", vc + Vector3.new(0, 200, 0), Vector3.new(900, 400, 900))
	Kit.collectible(m, "SecretStar", ZONE, vc + Vector3.new(0, 0, 300))

	-- City blocks of mega towers, keeping landmarks and streets clear.
	local rng = Random.new(1501)
	local reserved: { { any } } = {
		{ plazaCenter, 1800 },
		{ spireBase, 1400 },
		{ hb, 1600 },
		{ fc, 1300 },
		{ vc, 900 },
		{ Vector3.new(4200, 0, 2500), 900 }, -- spawn
		{ Vector3.new(6200, 0, 6000), 700 }, -- gauntlet pad
		{ Vector3.new(9800, 0, -1500), 700 }, -- long jump pad
	}
	for x = 4400, 11400, 1700 do
		for z = -2600, 7600, 1700 do
			local p = Vector3.new(x, 0, z)
			local blocked = false
			for _, r in reserved do
				local center: Vector3, radius: number = r[1], r[2]
				if (p - center).Magnitude < radius then
					blocked = true
					break
				end
			end
			if not blocked then
				megaTower(
					m,
					"MegaTower",
					p,
					rng:NextNumber(500, 900),
					rng:NextNumber(1500, 4500),
					STONE:Lerp(GOLD, rng:NextNumber(0, 0.5))
				)
			end
		end
	end

	Kit.spawnPad(m, ZONE, Vector3.new(4200, 0, 2500), 120)
	Kit.fastTravel(m, ZONE, Vector3.new(4300, 0, 2000), 120)
	Kit.npc(m, "Archivist", Vector3.new(6400, 0, 2500), Vector3.new(-1, 0, 0))
	Kit.npc(m, "Broker", Vector3.new(6400, 0, 3300), Vector3.new(-1, 0, 0))
	Kit.station(m, "Ascension", "Ascension Altar", Vector3.new(6600, 0, 1800), 120, Color3.fromRGB(255, 255, 220))
	Kit.station(m, "Shop", "Titan Exchange", Vector3.new(6600, 0, 3300), 120, Color3.fromRGB(255, 200, 80))
	Kit.station(m, "Upgrades", "Titan Forge Bench", Vector3.new(4500, 0, 2900), 120, Color3.fromRGB(120, 255, 140))
	Kit.station(m, "SkillTree", "Titan Shrine", Vector3.new(4500, 0, 2100), 120, Color3.fromRGB(190, 140, 255))
	Kit.orbLine(m, ZONE, Vector3.new(4900, 10, 2500), Vector3.new(6300, 10, 2500), 10)
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(11800, 10, 8000))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(11800, 10, -3000))
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(3700, 1460, 2600))
	Kit.enemySpawner(m, "TitanDefender", plazaCenter + Vector3.new(0, 4, 1700), 3, 1500)
	Kit.enemySpawner(m, "Warden", Vector3.new(8500, 1500, -1000), 3, 2000)
	Kit.enemySpawner(m, "TitanDefender", fc + Vector3.new(-1500, 0, 0), 3, 1200)
end

return TitanCity
