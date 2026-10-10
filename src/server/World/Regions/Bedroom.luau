--!strict
--[[
	Bedroom — Region 2 (x -280..0, z 0..320) + Playroom (z -300..0)

	For Ant- to Toy-sized players (2–7.5 studs tall, jump 3–10 studs).
	Climbing routes:
	  * Floor → cable vines → DESKTOP (33) → monitor stand → orbs
	  * Floor → toy blocks → dresser drawers → DRESSER PEAK (47)
	  * Floor → bookshelf shelves (every 18) → TOP SHELF (90)
	    → wall shelf (88) → behind the painting (secret)
	  * Desk chair → desk → book stack → WINDOWSILL (50)
	  * Under the bed (10-stud gap) and the Forgotten Vent (9-stud opening,
	    built in House) only fit small players.

	Final art: bed with quilt, desk with laptop and stationery, wooden dresser,
	bookshelf with real books, posters, a toy chest full of toys.
]]

local Kit = require(script.Parent.Parent.Kit)
local Props = require(script.Parent.Parent.Props)

local Bedroom = {}

local ZONE = "Bedroom"

local function bed(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "Bed", true)
	for _, corner in
		{ Vector3.new(-278, 0, 182), Vector3.new(-178, 0, 182), Vector3.new(-278, 0, 292), Vector3.new(-178, 0, 292) }
	do
		Kit.box(model, "BedLeg", corner, Vector3.new(6, 10, 6), C.DarkWood, Enum.Material.Wood)
	end
	Kit.box(model, "BedFrame", Vector3.new(-280, 10, 180), Vector3.new(110, 6, 120), C.Wood, Enum.Material.Wood)
	Kit.box(
		model,
		"Mattress",
		Vector3.new(-278, 16, 182),
		Vector3.new(106, 11, 116),
		Color3.fromRGB(235, 235, 245),
		Enum.Material.Fabric
	)
	Kit.box(
		model,
		"Quilt",
		Vector3.new(-250, 27, 182),
		Vector3.new(78, 1.5, 116),
		Color3.fromRGB(80, 120, 190),
		Enum.Material.Fabric
	)
	Kit.box(
		model,
		"Pillow",
		Vector3.new(-276, 27, 195),
		Vector3.new(22, 6, 40),
		Color3.fromRGB(250, 250, 250),
		Enum.Material.Fabric
	)
	Kit.box(
		model,
		"Pillow",
		Vector3.new(-276, 27, 245),
		Vector3.new(22, 6, 40),
		Color3.fromRGB(250, 250, 250),
		Enum.Material.Fabric
	)
	Kit.box(model, "Headboard", Vector3.new(-282, 0, 180), Vector3.new(4, 60, 120), C.Wood, Enum.Material.Wood)
	Kit.skin(model, "Bed", model:GetChildren())
	-- A dangling quilt corner makes a ramp from the floor onto the bed.
	Kit.ramp(
		model,
		"QuiltDrape",
		Vector3.new(-160, 0, 290),
		Vector3.new(-176, 27, 290),
		18,
		Color3.fromRGB(80, 120, 190),
		Enum.Material.Fabric
	)
	Kit.discovery(m, "UnderTheBed", Vector3.new(-230, 5, 240), Vector3.new(90, 9, 100))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(-250, 0, 260))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(-200, 0, 210))
	Kit.orbLine(m, ZONE, Vector3.new(-185, 0, 200), Vector3.new(-265, 0, 280), 6)
	Kit.orbLine(m, ZONE, Vector3.new(-200, 28.5, 200), Vector3.new(-200, 28.5, 280), 5)
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(-265, 33, 220))
	Kit.enemySpawner(m, "Spider", Vector3.new(-230, 0, 230), 2, 30)
end

local function desk(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "Desk", true)
	for _, corner in
		{ Vector3.new(-150, 0, 4), Vector3.new(-63, 0, 4), Vector3.new(-150, 0, 41), Vector3.new(-63, 0, 41) }
	do
		Kit.box(model, "DeskLeg", corner, Vector3.new(3, 31, 3), C.Steel, Enum.Material.Metal)
	end
	Kit.box(model, "DeskTop", Vector3.new(-150, 31, 4), Vector3.new(90, 2, 40), C.LightWood, Enum.Material.Wood)
	Kit.box(model, "MonitorStand", Vector3.new(-112, 33, 10), Vector3.new(14, 6, 10), C.Steel, Enum.Material.Metal)
	local monitor = Kit.box(
		model,
		"Monitor",
		Vector3.new(-124, 39, 10),
		Vector3.new(38, 22, 2),
		Color3.fromRGB(20, 20, 30),
		Enum.Material.Glass
	)
	Kit.light(monitor, Color3.fromRGB(120, 180, 255), 30, 0.5)
	Kit.box(
		model,
		"Keyboard",
		Vector3.new(-125, 33, 22),
		Vector3.new(30, 1, 9),
		Color3.fromRGB(40, 40, 45),
		Enum.Material.SmoothPlastic
	)
	-- Book stack: steps from the desk up to the window ledge height.
	Kit.box(
		model,
		"Book",
		Vector3.new(-148, 33, 30),
		Vector3.new(14, 4, 11),
		Color3.fromRGB(180, 60, 60),
		Enum.Material.SmoothPlastic
	)
	Kit.box(
		model,
		"Book",
		Vector3.new(-147, 37, 30),
		Vector3.new(12, 4, 10),
		Color3.fromRGB(60, 120, 180),
		Enum.Material.SmoothPlastic
	)
	Kit.box(
		model,
		"Book",
		Vector3.new(-146, 41, 30),
		Vector3.new(10, 4, 9),
		Color3.fromRGB(70, 160, 90),
		Enum.Material.SmoothPlastic
	)
	Kit.pillar(
		model,
		"PencilCup",
		Vector3.new(-80, 33, 15),
		9,
		6,
		Color3.fromRGB(220, 190, 60),
		Enum.Material.SmoothPlastic
	)
	for i = 0, 3 do
		Kit.rod(
			model,
			"Pencil",
			Vector3.new(-82 + i, 37, 13 + i),
			Vector3.new(-84 + i * 2, 49, 9 + i * 2),
			0.8,
			Color3.fromRGB(240, 200, 40),
			Enum.Material.Wood
		)
	end
	Kit.interactable(
		model,
		"Eraser",
		CFrame.new(-95, 34.5, 32),
		Vector3.new(5, 3, 3),
		Color3.fromRGB(255, 160, 170),
		Enum.Material.SmoothPlastic
	)
	Kit.interactable(
		model,
		"PaperStack",
		CFrame.new(-70, 35, 30),
		Vector3.new(10, 4, 8),
		Color3.fromRGB(250, 250, 245),
		Enum.Material.SmoothPlastic
	)
	-- Cable vines: charger cables hanging from the desk to the floor.
	local black = Color3.fromRGB(25, 25, 30)
	Kit.ramp(model, "CableVine", Vector3.new(-132, 0, 92), Vector3.new(-132, 33, 44), 2, black, Enum.Material.Rubber)
	Kit.ramp(
		model,
		"CableVine",
		Vector3.new(-90, 0, 88),
		Vector3.new(-96, 33, 44),
		1.4,
		Color3.fromRGB(240, 240, 240),
		Enum.Material.Rubber
	)
	Kit.discovery(m, "CableVines", Vector3.new(-120, 16, 68), Vector3.new(50, 30, 40))
	Kit.discovery(m, "DeskSummit", Vector3.new(-105, 37, 24), Vector3.new(86, 8, 38))
	Kit.orbLine(m, ZONE, Vector3.new(-132, 2, 88), Vector3.new(-132, 30, 50), 6)
	Kit.orbLine(m, ZONE, Vector3.new(-145, 33, 20), Vector3.new(-70, 33, 20), 6)
	Kit.collectible(m, "Relic", ZONE, Vector3.new(-105, 39, 15))
	-- Chair in front of the desk (seat 18).
	for _, corner in
		{ Vector3.new(-118, 0, 50), Vector3.new(-95, 0, 50), Vector3.new(-118, 0, 72), Vector3.new(-95, 0, 72) }
	do
		Kit.box(model, "ChairLeg", corner, Vector3.new(2, 16, 2), C.Steel, Enum.Material.Metal)
	end
	Kit.box(
		model,
		"ChairSeat",
		Vector3.new(-120, 16, 48),
		Vector3.new(28, 2, 28),
		Color3.fromRGB(50, 50, 60),
		Enum.Material.Fabric
	)
	Kit.box(
		model,
		"ChairBack",
		Vector3.new(-120, 18, 74),
		Vector3.new(28, 30, 2),
		Color3.fromRGB(50, 50, 60),
		Enum.Material.Fabric
	)
end

local function windowsill(m: Instance)
	-- From the desk book stack (45) a ruler bridge spans to the sill (50).
	Kit.ramp(
		m,
		"RulerBridge",
		Vector3.new(-150, 45, 34),
		Vector3.new(-262, 50, 100),
		3,
		Color3.fromRGB(240, 210, 90),
		Enum.Material.Wood
	)
	Kit.box(m, "RulerSupport", Vector3.new(-212, 0, 66), Vector3.new(2, 46, 2), Kit.Colors.Steel, Enum.Material.Metal)
	Kit.discovery(m, "Windowsill", Vector3.new(-272, 54, 130), Vector3.new(14, 8, 80))
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(-273, 50, 160))
	Kit.orbLine(m, ZONE, Vector3.new(-272, 50, 95), Vector3.new(-272, 50, 165), 5)
	local plant = Kit.pillar(
		m,
		"PlantPot",
		Vector3.new(-272, 50, 110),
		7,
		7,
		Color3.fromRGB(190, 100, 70),
		Enum.Material.SmoothPlastic
	)
	local _ = plant
	Kit.ball(m, "PlantLeaves", Vector3.new(-272, 62, 110), 12, Color3.fromRGB(80, 160, 70), Enum.Material.Grass)
end

local function dresser(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "Dresser", true)
	Kit.box(model, "DresserBody", Vector3.new(-270, 0, 20), Vector3.new(55, 47, 40), C.Wood, Enum.Material.Wood)
	-- Pulled-out drawers form a staircase on the front.
	for i = 0, 3 do
		Kit.box(
			model,
			"Drawer",
			Vector3.new(-215, 4 + i * 11, 22),
			Vector3.new(4 + (3 - i) * 4, 2, 36),
			C.LightWood,
			Enum.Material.Wood
		)
	end
	-- Toy blocks as the first step.
	Kit.interactable(
		m,
		"ToyBlock",
		CFrame.new(-200, 3, 40),
		Vector3.new(6, 6, 6),
		Color3.fromRGB(240, 80, 80),
		Enum.Material.SmoothPlastic
	)
	Kit.interactable(
		m,
		"ToyBlock",
		CFrame.new(-206, 3, 52),
		Vector3.new(6, 6, 6),
		Color3.fromRGB(80, 160, 240),
		Enum.Material.SmoothPlastic
	)
	Kit.box(
		model,
		"JewelryBox",
		Vector3.new(-262, 47, 28),
		Vector3.new(14, 7, 10),
		Color3.fromRGB(120, 40, 80),
		Enum.Material.Fabric
	)
	Kit.skin(model, "Dresser", model:GetChildren())
	Kit.discovery(m, "DresserPeak", Vector3.new(-242, 51, 40), Vector3.new(50, 8, 36))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(-230, 47, 45))
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(-255, 54, 33))
	Kit.orbLine(m, ZONE, Vector3.new(-212, 6, 30), Vector3.new(-212, 39, 50), 5)
end

local function bookshelf(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "Bookshelf", true)
	Kit.box(model, "ShelfBack", Vector3.new(-6, 0, 60), Vector3.new(4, 92, 60), C.DarkWood, Enum.Material.Wood)
	Kit.box(model, "ShelfSide", Vector3.new(-46, 0, 58), Vector3.new(42, 92, 2), C.DarkWood, Enum.Material.Wood)
	Kit.box(model, "ShelfSide", Vector3.new(-46, 0, 120), Vector3.new(42, 92, 2), C.DarkWood, Enum.Material.Wood)
	local rng = Random.new(606)
	for level = 0, 5 do
		local y = level * 18
		Kit.box(model, "Shelf", Vector3.new(-46, y, 60), Vector3.new(40, 2, 60), C.DarkWood, Enum.Material.Wood)
		if level < 5 then
			-- Books leave gaps so climbers can hop shelf to shelf.
			local z = 61
			while z < 112 do
				local w = rng:NextNumber(2, 4)
				if rng:NextNumber() < 0.8 then
					local h = rng:NextNumber(9, 15)
					Kit.box(
						model,
						"Book",
						Vector3.new(-30, y + 2, z),
						Vector3.new(24, h, w),
						Color3.fromHSV(rng:NextNumber(), 0.5, 0.75),
						Enum.Material.SmoothPlastic
					)
				end
				z += w + 0.3
			end
		end
	end
	-- Ladder of sticky notes up the shelf side for small climbers.
	for i = 0, 9 do
		Kit.box(
			model,
			"StickyNote",
			Vector3.new(-50, 4 + i * 9, 56 - (i % 2) * 3),
			Vector3.new(5, 0.6, 5),
			Color3.fromRGB(255, 240, 120),
			Enum.Material.SmoothPlastic
		)
	end
	Kit.discovery(m, "TopShelf", Vector3.new(-26, 95, 90), Vector3.new(40, 8, 60))
	Kit.collectible(m, "Relic", ZONE, Vector3.new(-26, 92, 112))
	Kit.orbLine(m, ZONE, Vector3.new(-26, 92, 66), Vector3.new(-26, 92, 105), 4)
	-- Wall shelf from the bookshelf top along the wall to the painting.
	Kit.box(m, "WallShelf", Vector3.new(-12, 86, 120), Vector3.new(10, 2, 114), C.LightWood, Enum.Material.Wood)
	Kit.orbLine(m, ZONE, Vector3.new(-7, 88, 130), Vector3.new(-7, 88, 225), 6)
	-- The painting: hung off the wall with a gap behind it.
	local frame = Kit.box(
		m,
		"PaintingFrame",
		Vector3.new(-5, 58, 232),
		Vector3.new(0.6, 38, 46),
		Color3.fromRGB(160, 120, 40),
		Enum.Material.Wood
	)
	local _ = frame
	-- Ledge inside the gap so climbers who drop behind the frame land at the
	-- cavity opening (y 62..92) instead of falling to the floor.
	Kit.box(m, "GapLedge", Vector3.new(-4.4, 60, 235), Vector3.new(2.4, 2, 40), Kit.Colors.DarkWood, Enum.Material.Wood)
	Kit.box(
		m,
		"PaintingCanvas",
		Vector3.new(-5.3, 61, 235),
		Vector3.new(0.4, 32, 40),
		Color3.fromRGB(70, 110, 160),
		Enum.Material.Fabric
	)
	Kit.enemySpawner(m, "Spider", Vector3.new(-30, 0, 140), 3, 25)
end

local function toyChest(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "ToyChest", true)
	Kit.box(model, "ChestBase", Vector3.new(-110, 0, 270), Vector3.new(40, 2, 40), C.Wood, Enum.Material.Wood)
	Kit.box(model, "ChestWall", Vector3.new(-110, 2, 270), Vector3.new(2, 18, 40), C.Wood, Enum.Material.Wood)
	Kit.box(model, "ChestWall", Vector3.new(-72, 2, 270), Vector3.new(2, 18, 40), C.Wood, Enum.Material.Wood)
	Kit.box(model, "ChestWall", Vector3.new(-110, 2, 270), Vector3.new(40, 18, 2), C.Wood, Enum.Material.Wood)
	Kit.box(model, "ChestWall", Vector3.new(-110, 2, 308), Vector3.new(40, 10, 2), C.Wood, Enum.Material.Wood)
	Kit.part(model, {
		Name = "ChestLid",
		Size = Vector3.new(40, 2, 40),
		CFrame = CFrame.new(-90, 34, 312) * CFrame.Angles(math.rad(-70), 0, 0),
		Color = C.Wood,
		Material = Enum.Material.Wood,
	})
	Kit.skin(model, "ToyChest", model:GetChildren())
	Kit.interactable(
		model,
		"Dice",
		CFrame.new(-98, 6, 284),
		Vector3.new(6, 6, 6),
		Color3.fromRGB(250, 250, 250),
		Enum.Material.SmoothPlastic
	)
	Kit.interactable(
		model,
		"ToyTower",
		CFrame.new(-85, 7, 290),
		Vector3.new(6, 10, 6),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.SmoothPlastic
	)
	Kit.discovery(m, "ToyChest", Vector3.new(-91, 8, 289), Vector3.new(34, 14, 34))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(-100, 2, 300))
	Kit.enemySpawner(m, "WindupToy", Vector3.new(-150, 0, 270), 2, 25)
end

local function lab(m: Instance)
	-- The Growth Laboratory: Nova's upgrade bench on the floor by the door.
	local glass = Kit.box(
		m,
		"LabDome",
		Vector3.new(-62, 0, 278),
		Vector3.new(24, 14, 24),
		Color3.fromRGB(150, 230, 255),
		Enum.Material.Glass
	)
	glass.Transparency = 0.75
	glass.CanCollide = false
	Kit.station(m, "Upgrades", "Growth Laboratory", Vector3.new(-50, 0, 290), 0.7, Color3.fromRGB(120, 255, 140))
	Kit.station(m, "SkillTree", "Skill Shrine", Vector3.new(-20, 0, 205), 0.7, Color3.fromRGB(190, 140, 255))
	Kit.npc(m, "LabTech", Vector3.new(-40, 0, 282), Vector3.new(1, 0, -1))
	Kit.npc(m, "Pip", Vector3.new(-60, 0, 215), Vector3.new(1, 0, 0))
	Kit.spawnPad(m, ZONE, Vector3.new(-30, 0, 240), 0.5)
	Kit.fastTravel(m, ZONE, Vector3.new(-20, 0, 255), 0.5)
end

local function playroom(m: Instance)
	local C = Kit.Colors
	-- Play mat, block towers and a toy train track: decoration + combat space.
	Kit.box(
		m,
		"PlayMat",
		Vector3.new(-250, 0, -260),
		Vector3.new(200, 0.6, 200),
		Color3.fromRGB(240, 200, 90),
		Enum.Material.Fabric
	)
	local rng = Random.new(707)
	for i = 1, 12 do
		local pos = Vector3.new(rng:NextNumber(-260, -40), 0, rng:NextNumber(-280, -120))
		local h = rng:NextInteger(1, 5)
		for j = 0, h - 1 do
			Kit.box(
				m,
				"BlockTower",
				pos + Vector3.new(0, j * 6, 0),
				Vector3.new(6, 6, 6),
				Color3.fromHSV(rng:NextNumber(), 0.6, 0.9),
				Enum.Material.SmoothPlastic
			)
		end
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		Kit.box(
			m,
			"TrainTrack",
			Vector3.new(-150 + math.cos(a) * 60, 0, -180 + math.sin(a) * 60),
			Vector3.new(8, 0.8, 3),
			C.DarkWood,
			Enum.Material.Wood
		)
	end
	Kit.orbRing(m, ZONE, Vector3.new(-150, 0, -180), 50, 10)
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(-260, 0, -280))
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(-30, 0, -280))
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(-200, 30, -200))
	Kit.box(m, "ShelfTower", Vector3.new(-210, 0, -210), Vector3.new(16, 24, 16), C.Wood, Enum.Material.Wood)
	for i = 1, 3 do
		Kit.interactable(
			m,
			"ToyTower",
			CFrame.new(-100 + i * 20, 5, -100),
			Vector3.new(5, 10, 5),
			Color3.fromRGB(100, 200, 255),
			Enum.Material.SmoothPlastic
		)
	end
	Kit.enemySpawner(m, "WindupToy", Vector3.new(-150, 0, -220), 3, 50)
	Kit.enemySpawner(m, "Moth", Vector3.new(-100, 30, -150), 3, 40)
end

-- Lived-in details: posters, a glowing gaming desk, fairy lights over the
-- bed, clothes, shoes and school stuff on the floor.
local function decor(m: Instance)
	local d = Kit.model(m, "BedroomDecor")
	Props.poster(
		d,
		CFrame.lookAt(Vector3.new(-120, 82, 320), Vector3.new(-120, 82, 0)),
		30,
		42,
		Color3.fromRGB(38, 44, 92),
		Color3.fromRGB(255, 170, 70),
		"LEVEL UP"
	)
	Props.poster(
		d,
		CFrame.lookAt(Vector3.new(-62, 86, 320), Vector3.new(-62, 86, 0)),
		26,
		36,
		Color3.fromRGB(230, 70, 90),
		Color3.fromRGB(255, 230, 120),
		"TITAN"
	)
	Props.poster(
		d,
		CFrame.lookAt(Vector3.new(-100, 92, 2), Vector3.new(-100, 92, 320)),
		40,
		26,
		Color3.fromRGB(24, 26, 40),
		Color3.fromRGB(120, 90, 255),
		"GAME ON"
	)
	-- Gaming desk glow: an LED strip along the desk front and a screen light.
	local strip = Kit.block(
		d,
		"DeskLed",
		Vector3.new(-105, 30.7, 43.6),
		Vector3.new(88, 0.5, 0.5),
		Color3.fromRGB(160, 90, 255),
		Enum.Material.Neon
	)
	strip.CanCollide = false
	Kit.light(strip, Color3.fromRGB(160, 100, 255), 24, 0.8)
	local screenGlow = Kit.part(d, {
		Name = "ScreenGlow",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(-112, 46, 24),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	Kit.light(screenGlow, Color3.fromRGB(110, 200, 255), 30, 1.2)
	-- Fairy lights over the bed.
	local warm = { Color3.fromRGB(255, 214, 140), Color3.fromRGB(255, 190, 120), Color3.fromRGB(255, 230, 170) }
	Props.stringLights(d, Vector3.new(-277, 112, 176), Vector3.new(-277, 112, 304), 16, 9, warm, 1.6)
	-- Floor life.
	Props.clothes(d, Vector3.new(-152, 0, 286), 41)
	Props.sneaker(d, Vector3.new(-205, 0, 160), 0.4, Color3.fromRGB(220, 60, 60))
	Props.sneaker(d, Vector3.new(-190, 0, 157), 0.1, Color3.fromRGB(220, 60, 60))
	Props.pencil(d, Vector3.new(-132, 0, 62), 0.6)
	Props.pencil(d, Vector3.new(-92, 0, 74), 2.1, Color3.fromRGB(80, 160, 230))
	Props.paper(d, Vector3.new(-120, 0, 54), 0.3)
	Props.paper(d, Vector3.new(-78, 0, 86), -0.5)
	Props.outlet(d, CFrame.lookAt(Vector3.new(-40, 15.5, 2), Vector3.new(-40, 15.5, 320)), true)
	Props.plant(d, Vector3.new(-242, 47, 40), 20, 52, Color3.fromRGB(230, 230, 225))
end

function Bedroom.build(root: Instance)
	local m = Kit.folder(root, "Bedroom")
	decor(m)
	bed(m)
	desk(m)
	windowsill(m)
	dresser(m)
	bookshelf(m)
	toyChest(m)
	lab(m)
	playroom(m)
	Kit.box(
		m,
		"Rug",
		Vector3.new(-200, 0, 90),
		Vector3.new(120, 0.6, 80),
		Color3.fromRGB(200, 170, 220),
		Enum.Material.Fabric
	)
	Kit.bossArena(m, "Vacuum", Vector3.new(-125, 0, 140))
	Kit.orbLine(m, ZONE, Vector3.new(-30, 0, 180), Vector3.new(-160, 0, 150), 7)
	Kit.enemySpawner(m, "Moth", Vector3.new(-200, 40, 120), 3, 50)
end

return Bedroom
