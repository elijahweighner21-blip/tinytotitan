--!strict
--[[
	Kitchen — Region 3 (x 0..320, z -300..0)

	Initially enormous (Mouse/Toy players are 4.5–7.5 studs tall), later just a
	kitchen (Child players, 35 tall, jump straight onto the 40-stud counters).

	THE GREAT CLIMB (table top at 33) for Mouse-sized:
	  cereal box (12) → cereal rings → chair seat (18) → SPOON BRIDGE → table
	Counter route: trash can → step stool → counter (40) → stove → fridge (80)
	Secrets: behind the fridge (7-wide gap), under the oven (8-tall gap).
	Hazards: water droplets near the sink (damaging for small players).

	Final art: modelled appliances, tiled backsplash, cabinet handles, food.
]]

local Kit = require(script.Parent.Parent.Kit)

local Kitchen = {}

local ZONE = "Kitchen"

local function counters(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "Counters", true)
	-- Back counter along z = -300 (x 0..225, leaving the back door clear).
	Kit.box(
		model,
		"BaseCabinet",
		Vector3.new(2, 4.4, -298),
		Vector3.new(223, 33.6, 25),
		Color3.fromRGB(240, 240, 235),
		Enum.Material.Wood
	)
	Kit.box(
		model,
		"ToeKick",
		Vector3.new(2, 0, -298),
		Vector3.new(223, 4.4, 21),
		Color3.fromRGB(60, 60, 60),
		Enum.Material.SmoothPlastic
	)
	Kit.box(model, "CounterTop", Vector3.new(0, 38, -300), Vector3.new(227, 2, 29), C.Counter, Enum.Material.Granite)
	-- Side counter along x = 320 (z -300..-40) with the stove/oven.
	Kit.box(
		model,
		"BaseCabinet",
		Vector3.new(295, 4.4, -300),
		Vector3.new(23, 33.6, 100),
		Color3.fromRGB(240, 240, 235),
		Enum.Material.Wood
	)
	Kit.box(
		model,
		"BaseCabinet",
		Vector3.new(295, 4.4, -150),
		Vector3.new(23, 33.6, 110),
		Color3.fromRGB(240, 240, 235),
		Enum.Material.Wood
	)
	Kit.box(
		model,
		"ToeKick",
		Vector3.new(298, 0, -300),
		Vector3.new(20, 4.4, 100),
		Color3.fromRGB(60, 60, 60),
		Enum.Material.SmoothPlastic
	)
	Kit.box(
		model,
		"ToeKick",
		Vector3.new(298, 0, -150),
		Vector3.new(20, 4.4, 110),
		Color3.fromRGB(60, 60, 60),
		Enum.Material.SmoothPlastic
	)
	Kit.box(model, "CounterTop", Vector3.new(293, 38, -300), Vector3.new(27, 2, 260), C.Counter, Enum.Material.Granite)
	-- Oven: raised on a drawer with an 8-stud gap underneath (Under the Oven).
	Kit.box(
		model,
		"OvenBody",
		Vector3.new(295, 8, -200),
		Vector3.new(23, 30, 50),
		Color3.fromRGB(30, 30, 35),
		Enum.Material.Metal
	)
	Kit.box(
		model,
		"OvenBack",
		Vector3.new(316, 0, -200),
		Vector3.new(2, 8, 50),
		Color3.fromRGB(60, 60, 60),
		Enum.Material.Metal
	)
	local window = Kit.box(
		model,
		"OvenWindow",
		Vector3.new(294.5, 14, -192),
		Vector3.new(0.6, 16, 34),
		Color3.fromRGB(60, 40, 30),
		Enum.Material.Glass
	)
	window.Transparency = 0.3
	for i = 0, 3 do
		local burner = Kit.pillar(
			model,
			"Burner",
			Vector3.new(300 + (i % 2) * 12, 40, -192 + math.floor(i / 2) * 22),
			0.6,
			9,
			Color3.fromRGB(25, 25, 25),
			Enum.Material.Metal
		)
		local _ = burner
	end
	Kit.discovery(m, "StoveTop", Vector3.new(306, 44, -175), Vector3.new(24, 8, 50))
	Kit.discovery(m, "UnderTheOven", Vector3.new(305, 4, -175), Vector3.new(20, 7, 46))
	Kit.collectible(m, "SecretStar", ZONE, Vector3.new(310, 0, -170))
	Kit.discovery(m, "CounterCliffs", Vector3.new(306, 44, -90), Vector3.new(24, 8, 90))
	-- Upper cabinets.
	Kit.box(
		model,
		"UpperCabinet",
		Vector3.new(2, 75, -300),
		Vector3.new(223, 35, 14),
		Color3.fromRGB(240, 240, 235),
		Enum.Material.Wood
	)
	-- Sink basin in the back counter.
	Kit.box(model, "Sink", Vector3.new(80, 30, -296), Vector3.new(50, 8, 21), C.Steel, Enum.Material.Metal)
	Kit.rod(model, "Faucet", Vector3.new(105, 40, -296), Vector3.new(105, 55, -290), 2, C.Steel, Enum.Material.Metal)
	Kit.discovery(m, "SinkBasin", Vector3.new(105, 35, -286), Vector3.new(46, 12, 18))
	-- Step stool + trash can route onto the counter.
	Kit.box(
		model,
		"StepStool",
		Vector3.new(200, 0, -260),
		Vector3.new(20, 14, 16),
		Color3.fromRGB(230, 90, 70),
		Enum.Material.SmoothPlastic
	)
	Kit.box(
		model,
		"StepStool",
		Vector3.new(200, 14, -268),
		Vector3.new(20, 10, 8),
		Color3.fromRGB(230, 90, 70),
		Enum.Material.SmoothPlastic
	)
	Kit.orbLine(m, ZONE, Vector3.new(20, 40, -287), Vector3.new(215, 40, -287), 10)
	Kit.orbLine(m, ZONE, Vector3.new(306, 40, -280), Vector3.new(306, 40, -60), 8)
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(40, 40, -290))
	Kit.collectible(m, "Relic", ZONE, Vector3.new(306, 40, -260))
	Kit.interactable(
		m,
		"SodaCan",
		CFrame.new(150, 47, -288),
		Vector3.new(7, 14, 7),
		Color3.fromRGB(200, 30, 30),
		Enum.Material.Metal,
		nil
	)
	Kit.interactable(
		m,
		"Apple",
		CFrame.new(175, 45, -288),
		Vector3.new(9, 9, 9),
		Color3.fromRGB(200, 40, 40),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	Kit.interactable(
		m,
		"EggCarton",
		CFrame.new(60, 43, -288),
		Vector3.new(24, 6, 10),
		Color3.fromRGB(220, 210, 190),
		Enum.Material.Cardboard
	)
end

local function fridge(m: Instance)
	local model = Kit.model(m, "Fridge", true)
	Kit.box(
		model,
		"FridgeBody",
		Vector3.new(275, 0, -40),
		Vector3.new(36, 80, 36),
		Color3.fromRGB(235, 238, 240),
		Enum.Material.Metal
	)
	Kit.box(
		model,
		"FridgeDoorLine",
		Vector3.new(274.6, 30, -40),
		Vector3.new(0.4, 1, 36),
		Color3.fromRGB(150, 150, 155),
		Enum.Material.Metal
	)
	Kit.box(
		model,
		"Handle",
		Vector3.new(273, 36, -10),
		Vector3.new(1.5, 30, 2),
		Color3.fromRGB(150, 150, 155),
		Enum.Material.Metal
	)
	-- Magnets as hand-holds up the door for climbers.
	for i = 0, 6 do
		Kit.box(
			model,
			"Magnet",
			Vector3.new(272.5, 8 + i * 10, -32 + (i % 2) * 10),
			Vector3.new(2.5, 3, 6),
			Color3.fromHSV(i / 7, 0.7, 0.9),
			Enum.Material.SmoothPlastic
		)
	end
	Kit.discovery(m, "FridgeTop", Vector3.new(293, 84, -22), Vector3.new(34, 8, 34))
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(293, 80, -22))
	-- Behind the fridge: a 7-wide gap to the wall with a hidden workbench.
	Kit.box(
		m,
		"HiddenBench",
		Vector3.new(311.5, 0, -36),
		Vector3.new(6.5, 10, 14),
		Kit.Colors.DarkWood,
		Enum.Material.Wood
	)
	local vial =
		Kit.pillar(m, "SerumVial", Vector3.new(314, 10, -30), 3, 1.2, Color3.fromRGB(120, 255, 160), Enum.Material.Neon)
	Kit.light(vial, Color3.fromRGB(120, 255, 160), 10, 1)
	Kit.discovery(m, "BehindTheFridge", Vector3.new(314.5, 15, -22), Vector3.new(6, 26, 36))
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(314, 10, -40))
end

local function table_(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "KitchenTable", true)
	for _, corner in
		{ Vector3.new(102, 0, -183), Vector3.new(195, 0, -183), Vector3.new(102, 0, -120), Vector3.new(195, 0, -120) }
	do
		Kit.box(model, "TableLeg", corner, Vector3.new(3, 31, 3), C.Wood, Enum.Material.Wood)
	end
	Kit.box(model, "TableTop", Vector3.new(100, 31, -185), Vector3.new(100, 2, 70), C.Wood, Enum.Material.Wood)
	Kit.pillar(
		model,
		"Plate",
		Vector3.new(130, 33, -160),
		0.6,
		18,
		Color3.fromRGB(250, 250, 250),
		Enum.Material.SmoothPlastic
	)
	Kit.pillar(
		model,
		"Mug",
		Vector3.new(170, 33, -140),
		8,
		7,
		Color3.fromRGB(60, 120, 200),
		Enum.Material.SmoothPlastic
	)
	Kit.box(
		model,
		"Napkin",
		Vector3.new(150, 33, -175),
		Vector3.new(12, 0.3, 12),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.Fabric
	)
	-- Chairs (seat 18).
	local function chair(seat: Vector3, backDir: Vector3)
		for _, o in { Vector3.new(-8, 0, -8), Vector3.new(8, 0, -8), Vector3.new(-8, 0, 8), Vector3.new(8, 0, 8) } do
			Kit.box(
				model,
				"ChairLeg",
				seat + o - Vector3.new(1, 0, 1),
				Vector3.new(2, 16, 2),
				C.DarkWood,
				Enum.Material.Wood
			)
		end
		Kit.block(model, "ChairSeat", seat + Vector3.new(0, 17, 0), Vector3.new(20, 2, 20), C.Wood, Enum.Material.Wood)
		Kit.block(
			model,
			"ChairBack",
			seat + backDir * 9 + Vector3.new(0, 31, 0),
			if backDir.X ~= 0 then Vector3.new(2, 26, 20) else Vector3.new(20, 26, 2),
			C.Wood,
			Enum.Material.Wood
		)
	end
	chair(Vector3.new(150, 0, -205), Vector3.new(0, 0, -1))
	chair(Vector3.new(150, 0, -100), Vector3.new(0, 0, 1))
	chair(Vector3.new(80, 0, -152), Vector3.new(-1, 0, 0))
	chair(Vector3.new(220, 0, -152), Vector3.new(1, 0, 0))
	-- THE SPOON BRIDGE: from the south chair seat up to the table edge.
	Kit.ramp(
		model,
		"SpoonBridge",
		Vector3.new(138, 18, -210),
		Vector3.new(160, 33, -180),
		4,
		C.Steel,
		Enum.Material.Metal
	)
	Kit.ball(model, "SpoonBowl", Vector3.new(136, 18.5, -212), 6, C.Steel, Enum.Material.Metal)
	-- Cereal box tipped over by the chair, with rings as steps (12 -> 18).
	Kit.interactable(
		m,
		"CerealBox",
		CFrame.new(130, 6, -240),
		Vector3.new(30, 12, 20),
		Color3.fromRGB(240, 170, 40),
		Enum.Material.Cardboard
	)
	-- Stacks of cereal rings bridge the box top (12) to the chair seat (18).
	for i = 0, 3 do
		Kit.pillar(
			model,
			"CerealStack",
			Vector3.new(136 + i * 3, 0, -227 + i * 3.5),
			13 + i * 1.3,
			4,
			Color3.fromRGB(230, 180, 90),
			Enum.Material.Sand
		)
	end
	Kit.ramp(
		model,
		"CerealRamp",
		Vector3.new(105, 0, -240),
		Vector3.new(118, 12, -240),
		10,
		Color3.fromRGB(240, 170, 40),
		Enum.Material.Cardboard
	)
	Kit.discovery(m, "CerealWreck", Vector3.new(128, 8, -238), Vector3.new(44, 16, 30))
	local rng = Random.new(808)
	for _ = 1, 18 do
		Kit.part(m, {
			Name = "CerealPiece",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 3.4, 3.4),
			CFrame = CFrame.new(rng:NextNumber(95, 175), 0.6, rng:NextNumber(-270, -215))
				* CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)),
			Color = Color3.fromRGB(230, 180, 90),
			Material = Enum.Material.Sand,
		})
	end
	Kit.discovery(m, "TableSummit", Vector3.new(150, 38, -150), Vector3.new(96, 10, 66))
	Kit.orbRing(m, ZONE, Vector3.new(150, 33, -150), 28, 10)
	Kit.collectible(m, "GoldenOrb", ZONE, Vector3.new(170, 41, -140))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(185, 33, -125))
	Kit.orbLine(m, ZONE, Vector3.new(100, 0, -240), Vector3.new(118, 12, -240), 3)
	Kit.orbLine(m, ZONE, Vector3.new(142, 19, -205), Vector3.new(158, 32, -183), 4)
end

local function trash(m: Instance)
	local model = Kit.model(m, "TrashCorner", true)
	Kit.pillar(model, "TrashCan", Vector3.new(25, 0, -35), 30, 22, Color3.fromRGB(150, 155, 160), Enum.Material.Metal)
	local rng = Random.new(909)
	for _ = 1, 10 do
		Kit.ball(
			model,
			"TrashBag",
			Vector3.new(rng:NextNumber(10, 60), rng:NextNumber(2, 8), rng:NextNumber(-80, -50)),
			rng:NextNumber(6, 14),
			Color3.fromRGB(30, 30, 35),
			Enum.Material.Plastic
		)
	end
	Kit.discovery(m, "TrashMountain", Vector3.new(35, 20, -55), Vector3.new(60, 20, 50))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(25, 30, -35))
	Kit.enemySpawner(m, "Cockroach", Vector3.new(40, 0, -70), 4, 35)
	Kit.enemySpawner(m, "Fly", Vector3.new(30, 25, -50), 3, 30)
end

local function droplets(m: Instance)
	-- Water droplets around the sink area: dangerous at small sizes only
	-- (damage scales with size difference in HazardService).
	local rng = Random.new(1010)
	for _ = 1, 10 do
		local d = rng:NextNumber(3, 6)
		local drop = Kit.ball(
			m,
			"WaterDroplet",
			Vector3.new(rng:NextNumber(60, 140), d * 0.35, rng:NextNumber(-270, -255)),
			d,
			Kit.Colors.Water,
			Enum.Material.Glass
		)
		drop.Transparency = 0.35
		drop.CanCollide = false
		drop.CanTouch = true
		Kit.hazard(drop, 18)
	end
	Kit.enemySpawner(m, "Fly", Vector3.new(105, 50, -280), 3, 30)
end

function Kitchen.build(root: Instance)
	local m = Kit.folder(root, "Kitchen")
	counters(m)
	fridge(m)
	table_(m)
	trash(m)
	droplets(m)
	Kit.spawnPad(m, ZONE, Vector3.new(170, 0, -30), 0.9)
	Kit.fastTravel(m, ZONE, Vector3.new(200, 0, -40), 0.9)
	Kit.npc(m, "Crumb", Vector3.new(80, 0, -60), Vector3.new(1, 0, 0))
	Kit.station(m, "Upgrades", "Kitchen Lab", Vector3.new(240, 0, -20), 0.9, Color3.fromRGB(120, 255, 140))
	Kit.orbLine(m, ZONE, Vector3.new(170, 0, -45), Vector3.new(120, 0, -100), 6)
	Kit.orbLine(m, ZONE, Vector3.new(240, 0, -100), Vector3.new(240, 0, -260), 7)
	Kit.collectible(m, "Relic", ZONE, Vector3.new(15, 0, -285))
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(25, 75, -295))
	Kit.enemySpawner(m, "ToyRobot", Vector3.new(220, 0, -100), 2, 40)
	Kit.enemySpawner(m, "Cockroach", Vector3.new(150, 0, -150), 3, 30)
	-- Back-door landing area (pet door leads to the backyard).
	Kit.orbLine(m, ZONE, Vector3.new(260, 0, -250), Vector3.new(260, 0, -295), 3)
end

return Kitchen
