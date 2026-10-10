--!strict
--[[
	Neighborhood — Region 5 (x -2600..3400, z -3200..2200)

	Human- to Large-sized (80–150 studs tall). Our own house is just one of
	many now. Streets, houses, a playground, a park with a fountain, a
	construction site with a climbable crane, a water tower, and the storm
	drain (only fits Child-sized or smaller → Shrink Mode).

	Also builds the region border walls whose heights are the natural size
	gates to the next regions:
	  z = 2200  (→ Downtown)        140 tall  (Large jumps 153)
	  x = 3400  (→ Titan City)      500 tall  (Titan jumps 530)
	  x = -2600 (→ Titan Wilderness) 800 tall  (Colossal jumps 845)
	plus a gate barrier in each (client-side passable at the right tier).

	Final art: varied house models, street furniture, trees, parked cars.
]]

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)

local Neighborhood = {}

local ZONE = "Neighborhood"

-- Decorative part: no collision, no queries (raycasts pass through).
local function trim(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?)
	local p = Kit.part(parent, { Name = name, Size = size, CFrame = cf, Color = color, Material = material })
	p.CanCollide = false
	p.CanQuery = false
	return p
end

local function ground(m: Instance)
	local C = Kit.Colors
	-- Ground around the house + backyard rectangle (x -400..720, z -1200..324).
	Kit.ground(m, "Grass", -2600, -3200, 3400, -1200, 0, 6, C.Grass, Enum.Material.Grass)
	Kit.ground(m, "Grass", -2600, 324, 3400, 2200, 0, 6, C.Grass, Enum.Material.Grass)
	Kit.ground(m, "Grass", -2600, -1200, -400, 324, 0, 6, C.Grass, Enum.Material.Grass)
	Kit.ground(m, "Grass", 720, -1200, 3400, 324, 0, 6, C.Grass, Enum.Material.Grass)
	-- Roads sit slightly above the grass (no z-fighting).
	local function road(minX: number, minZ: number, maxX: number, maxZ: number)
		Kit.ground(m, "Road", minX, minZ, maxX, maxZ, 0.6, 0.6, C.Asphalt, Enum.Material.Asphalt)
	end
	road(-2600, 700, 3400, 1020) -- front street
	road(-2600, -1650, 3400, -1350) -- back road
	road(1000, -3200, 1320, 2200) -- east cross street
	road(-1300, -3200, -980, 2200) -- west cross street
	-- Lane markings.
	for x = -2500, 3300, 200 do
		Kit.box(
			m,
			"LaneMark",
			Vector3.new(x, 0.6, 857),
			Vector3.new(100, 0.1, 6),
			Color3.fromRGB(240, 220, 80),
			Enum.Material.SmoothPlastic
		)
		Kit.box(
			m,
			"LaneMark",
			Vector3.new(x, 0.6, -1503),
			Vector3.new(100, 0.1, 6),
			Color3.fromRGB(240, 220, 80),
			Enum.Material.SmoothPlastic
		)
	end
	-- Sidewalk path from the yard gate to the back road.
	Kit.box(m, "Sidewalk", Vector3.new(230, 0, -1350), Vector3.new(70, 1, 150), C.Concrete, Enum.Material.Concrete)
	-- Street lamps along both roads (glowing heads; no light objects, so
	-- they cost nothing). Skips the cross streets and the spawn.
	local function lamp(x: number, z: number)
		local pole = Color3.fromRGB(60, 64, 70)
		Kit.pillar(m, "LampPost", Vector3.new(x, 0, z), 180, 8, pole, Enum.Material.Metal)
		trim(m, "LampArm", CFrame.new(x, 178, z - 22), Vector3.new(6, 6, 50), pole, Enum.Material.Metal)
		trim(
			m,
			"LampHead",
			CFrame.new(x, 172, z - 44),
			Vector3.new(20, 8, 30),
			Color3.fromRGB(255, 236, 190),
			Enum.Material.Neon
		)
	end
	for _, x in { -1975, -400, 325, 2000, 2675 } do
		lamp(x, 1050)
	end
	for _, x in { -2400, -1800, -600, 1600, 2200, 2800 } do
		lamp(x, -1320)
	end
end

-- Street face (-Z): framed windows with sills and shutters on both floors,
-- a porch with steps, trim lines, hedges and a mailbox at the curb.
local function facade(model: Model, center: Vector3, w: number, d: number, h: number, seed: number)
	local rng = Random.new(seed)
	local white = Color3.fromRGB(245, 243, 236)
	local shutter = Color3.fromHSV(rng:NextNumber(), 0.35, 0.45)
	local face = center.Z - d / 2
	trim(
		model,
		"Foundation",
		CFrame.new(center + Vector3.new(0, 7, 0)),
		Vector3.new(w + 6, 14, d + 6),
		Color3.fromRGB(150, 146, 140),
		Enum.Material.Concrete
	)
	trim(model, "Fascia", CFrame.new(center + Vector3.new(0, h, 0)), Vector3.new(w + 8, 10, d + 8), white)
	trim(model, "FloorBand", CFrame.new(center + Vector3.new(0, 140, 0)), Vector3.new(w + 3, 6, d + 3), white)
	for _, spot in { Vector2.new(-180, 210), Vector2.new(180, 210), Vector2.new(-180, 75), Vector2.new(190, 75) } do
		local at = Vector3.new(center.X + spot.X, spot.Y, face)
		local lit = rng:NextNumber() < 0.45
		trim(model, "WindowFrame", CFrame.new(at - Vector3.new(0, 0, 1)), Vector3.new(92, 82, 2), white)
		local glass = trim(
			model,
			"Window",
			CFrame.new(at - Vector3.new(0, 0, 2)),
			Vector3.new(80, 70, 1),
			if lit then Color3.fromRGB(255, 222, 160) else Kit.Colors.Glass,
			if lit then Enum.Material.Neon else Enum.Material.Glass
		)
		glass.Transparency = if lit then 0.35 else 0.25
		trim(model, "Mullion", CFrame.new(at - Vector3.new(0, 0, 2.6)), Vector3.new(4, 70, 1), white)
		trim(model, "Sill", CFrame.new(at - Vector3.new(0, 43, 4)), Vector3.new(100, 5, 8), white)
		for _, side in { -1, 1 } do
			trim(
				model,
				"Shutter",
				CFrame.new(at + Vector3.new(side * 60, 0, -1.5)),
				Vector3.new(24, 82, 2),
				shutter,
				Enum.Material.WoodPlanks
			)
		end
	end
	-- Front door off-centre, porch roof on two posts, real steps.
	local door = Vector3.new(center.X + 70, 0, face)
	trim(model, "DoorFrame", CFrame.new(door + Vector3.new(0, 56, -1)), Vector3.new(62, 112, 2), white)
	trim(
		model,
		"FrontDoor",
		CFrame.new(door + Vector3.new(0, 51, -2)),
		Vector3.new(48, 100, 1),
		Color3.fromHSV(rng:NextNumber(), 0.6, 0.55),
		Enum.Material.Wood
	)
	trim(
		model,
		"Knob",
		CFrame.new(door + Vector3.new(16, 50, -3)),
		Vector3.new(4, 4, 2),
		Color3.fromRGB(220, 190, 90),
		Enum.Material.Metal
	)
	Kit.box(
		model,
		"PorchStep",
		door + Vector3.new(-40, 0, -28),
		Vector3.new(80, 8, 28),
		Color3.fromRGB(170, 165, 158),
		Enum.Material.Concrete
	)
	Kit.box(
		model,
		"PorchStep",
		door + Vector3.new(-35, 8, -14),
		Vector3.new(70, 6, 14),
		Color3.fromRGB(180, 175, 168),
		Enum.Material.Concrete
	)
	trim(model, "PorchRoof", CFrame.new(door + Vector3.new(0, 128, -26)), Vector3.new(110, 6, 54), white)
	for _, side in { -1, 1 } do
		trim(model, "PorchPost", CFrame.new(door + Vector3.new(side * 50, 64, -48)), Vector3.new(6, 128, 6), white)
	end
	-- Hedges along the front, clear of the porch.
	for _, x in { -230, -110 } do
		trim(
			model,
			"Hedge",
			CFrame.new(center.X + x, 14, face - 18),
			Vector3.new(100, 28, 26),
			Color3.fromRGB(70, 120, 60),
			Enum.Material.Grass
		)
	end
	-- Mailbox at the curb.
	local mail = Vector3.new(center.X + 200, 0, face - 150)
	trim(
		model,
		"MailPost",
		CFrame.new(mail + Vector3.new(0, 22, 0)),
		Vector3.new(5, 44, 5),
		Kit.Colors.Wood,
		Enum.Material.Wood
	)
	trim(
		model,
		"MailBox",
		CFrame.new(mail + Vector3.new(0, 50, 0)),
		Vector3.new(12, 12, 24),
		Color3.fromHSV(rng:NextNumber(), 0.5, 0.6),
		Enum.Material.Metal
	)
end

local function house(m: Instance, center: Vector3, color: Color3, special: string?)
	local model = Kit.model(m, special or "House", true)
	local w, d, h = 560, 480, 300
	facade(model, center, w, d, h, math.floor(center.X + center.Z * 7))
	Kit.block(
		model,
		"Walls",
		center + Vector3.new(0, h / 2, 0),
		Vector3.new(w, h, d),
		color,
		Enum.Material.SmoothPlastic
	)
	Kit.wedge(
		model,
		"Roof",
		CFrame.new(center + Vector3.new(0, h + 90, d / 4)),
		Vector3.new(w + 40, 180, d / 2 + 20),
		Color3.fromRGB(90, 55, 50),
		Enum.Material.Slate
	)
	Kit.wedge(
		model,
		"Roof",
		CFrame.new(center + Vector3.new(0, h + 90, -d / 4)) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(w + 40, 180, d / 2 + 20),
		Color3.fromRGB(90, 55, 50),
		Enum.Material.Slate
	)
	Kit.block(
		model,
		"Door",
		center + Vector3.new(0, 50, d / 2 + 1),
		Vector3.new(50, 100, 2),
		Kit.Colors.Wood,
		Enum.Material.Wood
	)
	for _, x in { -180, 180 } do
		local win = Kit.block(
			model,
			"Window",
			center + Vector3.new(x, 170, d / 2 + 1),
			Vector3.new(80, 70, 2),
			Kit.Colors.Glass,
			Enum.Material.Glass
		)
		win.Transparency = 0.3
	end
	-- Flat chimney ledge so rooftops chain together for parkour.
	Kit.block(
		model,
		"Chimney",
		center + Vector3.new(w / 2 - 80, h + 140, 0),
		Vector3.new(50, 120, 50),
		Kit.Colors.Brick,
		Enum.Material.Brick
	)
	return model
end

local function houses(m: Instance)
	local rng = Random.new(1201)
	local palette = {
		Color3.fromRGB(230, 220, 200),
		Color3.fromRGB(200, 220, 235),
		Color3.fromRGB(235, 210, 190),
		Color3.fromRGB(210, 230, 200),
		Color3.fromRGB(240, 235, 215),
	}
	local function pick(): Color3
		return palette[rng:NextInteger(1, #palette)]
	end
	for _, x in { -2300, -800, 0, 650, 1650, 2350, 3000 } do
		house(m, Vector3.new(x, 0, 1450), pick())
	end
	local vale = house(m, Vector3.new(-1650, 0, 1450), Color3.fromRGB(170, 160, 190), "ValeHouse")
	local _ = vale
	Kit.discovery(m, "ValeHouse", Vector3.new(-1650, 60, 1150), Vector3.new(560, 120, 200))
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(-1650, 0, 1170))
	for _, x in { -2250, -1650, 1650, 2350, 3000 } do
		house(m, Vector3.new(x, 0, -300), pick())
	end
	-- Rooftop run across the north row.
	Kit.discovery(m, "RooftopRun", Vector3.new(0, 420, 1450), Vector3.new(700, 140, 520))
	Kit.orbLine(m, ZONE, Vector3.new(-2300, 302, 1450), Vector3.new(3000, 302, 1450), 18)
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(650, 450, 1450))
	-- Mailbox outside our own house.
	Kit.pillar(m, "MailboxPost", Vector3.new(400, 0, 660), 50, 6, Kit.Colors.Wood, Enum.Material.Wood)
	Kit.box(
		m,
		"Mailbox",
		Vector3.new(385, 50, 650),
		Vector3.new(30, 22, 20),
		Color3.fromRGB(60, 90, 160),
		Enum.Material.Metal
	)
	Kit.discovery(m, "OldMailbox", Vector3.new(400, 50, 660), Vector3.new(80, 100, 80))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(400, 72, 660))
	-- Parked cars and street furniture along the front street.
	for i = 0, 7 do
		local x = -2200 + i * 700
		Kit.interactable(
			m,
			"Car",
			CFrame.new(x, 38, 760),
			Vector3.new(200, 75, 90),
			Color3.fromHSV(rng:NextNumber(), 0.55, 0.8),
			Enum.Material.Metal,
			nil
		)
		Kit.interactable(
			m,
			"TrashBin",
			CFrame.new(x + 300, 25, 640),
			Vector3.new(40, 50, 40),
			Color3.fromRGB(60, 120, 70),
			Enum.Material.Plastic,
			nil
		)
		Kit.interactable(
			m,
			"StreetSign",
			CFrame.new(x + 150, 70, 650),
			Vector3.new(8, 140, 40),
			Color3.fromRGB(60, 160, 80),
			Enum.Material.Metal,
			nil
		)
	end
	Kit.enemySpawner(m, "Crow", Vector3.new(-800, 380, 1450), 3, 600)
	Kit.enemySpawner(m, "Crow", Vector3.new(2350, 380, -300), 3, 500)
end

local function playground(m: Instance)
	local center = Vector3.new(0, 0, -2450)
	local model = Kit.model(m, "Playground", true)
	Kit.box(
		model,
		"Sandbox",
		center + Vector3.new(-800, 0, -550),
		Vector3.new(1600, 2, 1100),
		Color3.fromRGB(220, 200, 150),
		Enum.Material.Sand
	)
	-- Slide tower.
	Kit.box(
		model,
		"SlideTower",
		center + Vector3.new(-100, 0, -100),
		Vector3.new(200, 160, 200),
		Color3.fromRGB(230, 80, 70),
		Enum.Material.SmoothPlastic
	)
	Kit.ramp(
		model,
		"Slide",
		center + Vector3.new(400, 2, 0),
		center + Vector3.new(100, 160, 0),
		80,
		Color3.fromRGB(250, 200, 60),
		Enum.Material.SmoothPlastic
	)
	-- Swing set.
	Kit.rod(
		model,
		"SwingBar",
		center + Vector3.new(-600, 200, -400),
		center + Vector3.new(-200, 200, -400),
		14,
		Kit.Colors.Steel,
		Enum.Material.Metal
	)
	for _, x in { -600, -200 } do
		Kit.rod(
			model,
			"SwingLeg",
			center + Vector3.new(x, 0, -480),
			center + Vector3.new(x, 200, -400),
			12,
			Kit.Colors.Steel,
			Enum.Material.Metal
		)
		Kit.rod(
			model,
			"SwingLeg",
			center + Vector3.new(x, 0, -320),
			center + Vector3.new(x, 200, -400),
			12,
			Kit.Colors.Steel,
			Enum.Material.Metal
		)
	end
	for _, x in { -500, -300 } do
		Kit.box(
			model,
			"SwingSeat",
			center + Vector3.new(x - 30, 50, -415),
			Vector3.new(60, 6, 30),
			Color3.fromRGB(60, 60, 60),
			Enum.Material.Rubber
		)
	end
	-- Jungle gym: a grid of bars to climb.
	for i = 0, 3 do
		for j = 0, 3 do
			Kit.box(
				model,
				"GymBar",
				center + Vector3.new(300 + i * 80, 0, -400 + j * 80),
				Vector3.new(8, 120 + ((i + j) % 2) * 40, 8),
				Color3.fromRGB(80, 160, 230),
				Enum.Material.Metal
			)
		end
	end
	Kit.box(
		model,
		"GymTop",
		center + Vector3.new(296, 160, -404),
		Vector3.new(250, 6, 250),
		Color3.fromRGB(80, 160, 230),
		Enum.Material.Metal
	)
	Kit.discovery(m, "Playground", center + Vector3.new(0, 100, -100), Vector3.new(1400, 200, 900))
	Kit.orbLine(m, ZONE, center + Vector3.new(-700, 2, 200), center + Vector3.new(700, 2, 200), 12)
	Kit.orbLine(m, ZONE, center + Vector3.new(400, 4, 0), center + Vector3.new(120, 162, 0), 6)
	Kit.collectible(m, "HiddenToy", ZONE, center + Vector3.new(-100, 160, -100))
	Kit.collectible(m, "Relic", ZONE, center + Vector3.new(420, 166, -280))
	Kit.enemySpawner(m, "RCCar", center + Vector3.new(0, 2, 300), 3, 600)
	-- Water tower behind the playground.
	local towerBase = Vector3.new(750, 0, -2950)
	for _, o in { Vector3.new(-80, 0, -80), Vector3.new(80, 0, -80), Vector3.new(-80, 0, 80), Vector3.new(80, 0, 80) } do
		Kit.rod(
			model,
			"TowerLeg",
			towerBase + o * 1.6,
			towerBase + o * 0.6 + Vector3.new(0, 700, 0),
			20,
			Kit.Colors.Steel,
			Enum.Material.Metal
		)
	end
	-- Maintenance ladder platforms up one leg.
	for i = 1, 8 do
		Kit.block(
			model,
			"LadderLanding",
			towerBase + Vector3.new(-200 + i * 12, i * 80, -100),
			Vector3.new(80, 6, 80),
			Kit.Colors.Steel,
			Enum.Material.DiamondPlate
		)
	end
	Kit.pillar(
		model,
		"Tank",
		towerBase + Vector3.new(0, 700, 0),
		220,
		300,
		Color3.fromRGB(200, 205, 210),
		Enum.Material.Metal
	)
	Kit.block(
		model,
		"TankRoof",
		towerBase + Vector3.new(0, 923, 0),
		Vector3.new(220, 6, 220),
		Color3.fromRGB(180, 70, 60),
		Enum.Material.Metal
	)
	Kit.discovery(m, "WaterTower", towerBase + Vector3.new(0, 960, 0), Vector3.new(260, 80, 260))
	Kit.collectible(m, "TitanShard", ZONE, towerBase + Vector3.new(0, 926, 0))
end

local function park(m: Instance)
	local center = Vector3.new(2350, 0, -2450)
	Kit.box(
		m,
		"ParkLawn",
		center + Vector3.new(-900, 0, -650),
		Vector3.new(1800, 1, 1300),
		Kit.Colors.DarkGrass,
		Enum.Material.Grass
	)
	Kit.pillar(m, "FountainBasin", center, 30, 400, Kit.Colors.Concrete, Enum.Material.Concrete)
	Kit.pillar(m, "FountainColumn", center + Vector3.new(0, 30, 0), 150, 40, Kit.Colors.Concrete, Enum.Material.Marble)
	Kit.pillar(m, "FountainTop", center + Vector3.new(0, 180, 0), 10, 120, Kit.Colors.Concrete, Enum.Material.Marble)
	pcall(function()
		workspace.Terrain:FillCylinder(CFrame.new(center + Vector3.new(0, 20, 0)), 18, 185, Enum.Material.Water)
	end)
	Kit.discovery(m, "ParkFountain", center + Vector3.new(0, 100, 0), Vector3.new(500, 200, 500))
	Kit.collectible(m, "GoldenOrb", ZONE, center + Vector3.new(0, 190, 0))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Kit.interactable(
			m,
			"Bench",
			CFrame.new(center + Vector3.new(math.cos(a) * 450, 18, math.sin(a) * 450)) * CFrame.Angles(0, -a, 0),
			Vector3.new(140, 36, 40),
			Kit.Colors.Wood,
			Enum.Material.WoodPlanks,
			nil
		)
	end
	Kit.orbRing(m, ZONE, center, 300, 12)
	-- Trees.
	local rng = Random.new(1301)
	for _ = 1, 10 do
		local p = center + Vector3.new(rng:NextNumber(-850, 850), 0, rng:NextNumber(-600, 600))
		if (p - center).Magnitude > 550 then
			Props.tree(m, p, rng:NextNumber(380, 520), rng:NextInteger(1, 1e6))
		end
	end
	-- Storm drain culvert at the park's north-west corner. The pipe opening is
	-- only 40 studs tall: Child-sized or smaller (Shrink Mode for most players).
	local drain = Kit.model(m, "StormDrain", true)
	local base = Vector3.new(1450, 0, -1950)
	Kit.box(
		drain,
		"Headwall",
		base + Vector3.new(0, 0, -60),
		Vector3.new(30, 120, 30),
		Kit.Colors.Concrete,
		Enum.Material.Concrete
	)
	Kit.box(
		drain,
		"Headwall",
		base + Vector3.new(0, 0, 30),
		Vector3.new(30, 120, 30),
		Kit.Colors.Concrete,
		Enum.Material.Concrete
	)
	Kit.box(
		drain,
		"Headwall",
		base + Vector3.new(0, 40, -30),
		Vector3.new(30, 80, 60),
		Kit.Colors.Concrete,
		Enum.Material.Concrete
	)
	Kit.box(
		drain,
		"PipeFloor",
		base + Vector3.new(30, -1, -40),
		Vector3.new(400, 2, 80),
		Color3.fromRGB(90, 95, 100),
		Enum.Material.Concrete
	)
	Kit.box(
		drain,
		"PipeRoof",
		base + Vector3.new(30, 40, -40),
		Vector3.new(400, 4, 80),
		Color3.fromRGB(90, 95, 100),
		Enum.Material.Concrete
	)
	Kit.box(
		drain,
		"PipeWall",
		base + Vector3.new(30, 0, -42),
		Vector3.new(400, 40, 2),
		Color3.fromRGB(90, 95, 100),
		Enum.Material.Concrete
	)
	Kit.box(
		drain,
		"PipeWall",
		base + Vector3.new(30, 0, 40),
		Vector3.new(400, 40, 2),
		Color3.fromRGB(90, 95, 100),
		Enum.Material.Concrete
	)
	Kit.box(
		drain,
		"PipeEnd",
		base + Vector3.new(430, 0, -42),
		Vector3.new(4, 44, 84),
		Color3.fromRGB(90, 95, 100),
		Enum.Material.Concrete
	)
	local glow = Kit.ball(
		drain,
		"DrainGlow",
		base + Vector3.new(380, 12, 0),
		8,
		Color3.fromRGB(90, 200, 255),
		Enum.Material.Neon
	)
	glow.CanCollide = false
	Kit.light(glow, Color3.fromRGB(90, 200, 255), 40, 2)
	Kit.discovery(m, "StormDrain", base + Vector3.new(300, 20, 0), Vector3.new(200, 36, 70))
	Kit.collectible(m, "SecretStar", ZONE, base + Vector3.new(400, 0, 10))
	Kit.enemySpawner(m, "Crow", center + Vector3.new(0, 300, 0), 3, 600)
end

local function construction(m: Instance)
	local model = Kit.model(m, "ConstructionSite", true)
	local base = Vector3.new(-2000, 0, -2500)
	Kit.box(
		model,
		"SiteDirt",
		base + Vector3.new(-500, 0, -600),
		Vector3.new(1000, 2, 1200),
		Kit.Colors.Dirt,
		Enum.Material.Ground
	)
	-- Unfinished building frame: floors to climb.
	for floor = 0, 4 do
		Kit.box(
			model,
			"Slab",
			base + Vector3.new(-350, floor * 150, -350),
			Vector3.new(500, 10, 500),
			Kit.Colors.Concrete,
			Enum.Material.Concrete
		)
		for _, o in
			{
				Vector3.new(-350, 0, -350),
				Vector3.new(130, 0, -350),
				Vector3.new(-350, 0, 130),
				Vector3.new(130, 0, 130),
			}
		do
			Kit.box(
				model,
				"Column",
				base + o + Vector3.new(0, floor * 150, 0),
				Vector3.new(20, 150, 20),
				Kit.Colors.Concrete,
				Enum.Material.Concrete
			)
		end
	end
	-- Stair ramps between floors.
	for floor = 0, 3 do
		local y0 = floor * 150 + 10
		Kit.ramp(
			model,
			"Stairs",
			base + Vector3.new(-300 + (floor % 2) * 300, y0, 200),
			base + Vector3.new(-300 + (floor % 2) * 300, y0 + 150, -100),
			60,
			Kit.Colors.Concrete,
			Enum.Material.Concrete
		)
	end
	-- The crane: a lattice mast and a jib to walk along.
	local craneBase = base + Vector3.new(350, 0, 300)
	Kit.tower(
		model,
		"CraneMast",
		craneBase,
		Vector2.new(50, 50),
		900,
		Color3.fromRGB(240, 200, 40),
		Enum.Material.DiamondPlate
	)
	for i = 1, 11 do
		Kit.block(
			model,
			"MastRung",
			craneBase + Vector3.new(40, i * 75, 0),
			Vector3.new(30, 6, 60),
			Color3.fromRGB(240, 200, 40),
			Enum.Material.Metal
		)
	end
	Kit.block(
		model,
		"Jib",
		craneBase + Vector3.new(-300, 905, 0),
		Vector3.new(800, 20, 40),
		Color3.fromRGB(240, 200, 40),
		Enum.Material.DiamondPlate
	)
	Kit.block(
		model,
		"CounterWeight",
		craneBase + Vector3.new(130, 880, 0),
		Vector3.new(80, 60, 60),
		Kit.Colors.Concrete,
		Enum.Material.Concrete
	)
	Kit.discovery(m, "ConstructionCrane", craneBase + Vector3.new(-200, 950, 0), Vector3.new(900, 80, 100))
	Kit.collectible(m, "TitanShard", ZONE, craneBase + Vector3.new(-650, 915, 0))
	for i = 0, 5 do
		Kit.interactable(
			m,
			"Barricade",
			CFrame.new(base + Vector3.new(-700 + i * 110, 25, 450)),
			Vector3.new(90, 50, 12),
			Color3.fromRGB(240, 140, 40),
			Enum.Material.SmoothPlastic,
			nil
		)
		Kit.interactable(
			m,
			"TrafficCone",
			CFrame.new(base + Vector3.new(-650 + i * 110, 25, 520)),
			Vector3.new(24, 50, 24),
			Color3.fromRGB(255, 120, 30),
			Enum.Material.SmoothPlastic,
			nil
		)
	end
	Kit.orbLine(m, ZONE, base + Vector3.new(-300, 12, 200), base + Vector3.new(-300, 610, -300), 10)
	Kit.collectible(m, "Relic", ZONE, base + Vector3.new(-100, 610, -100))
	Kit.enemySpawner(m, "StrayDrone", base + Vector3.new(0, 300, 0), 4, 700)
end

local function borders(m: Instance)
	local stone = Color3.fromRGB(150, 145, 140)
	local model = Kit.model(m, "BorderWalls", true)
	-- Neighborhood | Downtown (z = 2200): highway sound wall, cross-street gap.
	Kit.wall(
		model,
		"SoundWall",
		"X",
		2200,
		-2600,
		3400,
		0,
		140,
		30,
		{ { 1000, 1320, 140 } },
		stone,
		Enum.Material.Concrete
	)
	Kit.gate(
		model,
		"RoadClosed",
		Vector3.new(1160, 70, 2200),
		Vector3.new(320, 140, 6),
		10,
		"Road closed — Large players can step over"
	)
	-- Titan City wall (x = 3400) across both lower regions, Titan Gate gap.
	Kit.wall(
		model,
		"TitanWall",
		"Z",
		3400,
		-3200,
		8200,
		0,
		500,
		120,
		{ { 2300, 2900, 500 } },
		Kit.Colors.TitanStone,
		Enum.Material.Sandstone
	)
	Kit.gate(
		model,
		"TitanGate",
		Vector3.new(3400, 250, 2600),
		Vector3.new(30, 500, 600),
		12,
		"The Titan Gate opens only for Titans"
	)
	-- Wilderness cliff wall (x = -2600), archway gap.
	Kit.wall(
		model,
		"CliffWall",
		"Z",
		-2600,
		-6000,
		8200,
		0,
		800,
		200,
		{ { 900, 1400, 800 } },
		Kit.Colors.Rock,
		Enum.Material.Rock
	)
	Kit.gate(
		model,
		"WildArch",
		Vector3.new(-2600, 400, 1150),
		Vector3.new(40, 800, 500),
		13,
		"The wilderness calls only to Colossal Titans"
	)
end

function Neighborhood.build(root: Instance)
	local m = Kit.folder(root, "Neighborhood")
	ground(m)
	houses(m)
	playground(m)
	park(m)
	construction(m)
	borders(m)
	Kit.spawnPad(m, ZONE, Vector3.new(265, 1, -1380), 16)
	Kit.fastTravel(m, ZONE, Vector3.new(120, 1, -1420), 16)
	Kit.npc(m, "Bolt", Vector3.new(420, 1, -1420), Vector3.new(-1, 0, 0))
	Kit.station(m, "Upgrades", "Garage Workshop", Vector3.new(560, 1, -1420), 16, Color3.fromRGB(120, 255, 140))
	Kit.station(m, "SkillTree", "Corner Shrine", Vector3.new(-80, 1, -1420), 16, Color3.fromRGB(190, 140, 255))
	Kit.orbLine(m, ZONE, Vector3.new(-2400, 1, -1500), Vector3.new(3200, 1, -1500), 24)
	Kit.orbLine(m, ZONE, Vector3.new(1160, 1, -3000), Vector3.new(1160, 1, 2000), 20)
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(-2500, 1, 2100))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(3300, 1, -3100))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(-1140, 1, -3100))
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(2900, 1, 2000))
end

return Neighborhood
