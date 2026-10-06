--!strict
--[[
	Backyard — Region 4 (x -400..720, z -1200..-300)

	Pet- to Human-sized (15–80 studs tall). The pet door drops you onto the
	patio. At Pet size the grass forest towers over you; at Human size the
	whole yard is just a lawn and you can hop the 80-stud fence.

	Landmarks: grass forest, garden rows, patio set, pool (real terrain water),
	shed (squeeze through the broken panel), birdbath, the big oak (branch
	platforms up to the canopy) and the fence gate to the neighbourhood.

	Final art: grass meshes with wind, flower beds, a weathered shed, pool
	tiles, an oak tree model with leaf cards.
]]

local Kit = require(script.Parent.Parent.Kit)

local Backyard = {}

local ZONE = "Backyard"

local function fence(m: Instance)
	local wood = Color3.fromRGB(150, 120, 90)
	local model = Kit.model(m, "Fence", true)
	local H = 80
	Kit.wall(model, "Fence", "Z", -400, -1200, -300, 0, H, 4, nil, wood, Enum.Material.WoodPlanks)
	Kit.wall(model, "Fence", "Z", 720, -1200, -300, 0, H, 4, nil, wood, Enum.Material.WoodPlanks)
	Kit.wall(model, "Fence", "X", -1200, -400, 720, 0, H, 4, { { 230, 300, H } }, wood, Enum.Material.WoodPlanks)
	Kit.wall(model, "Fence", "X", -302, -400, -284, 0, H, 4, nil, wood, Enum.Material.WoodPlanks)
	Kit.wall(model, "Fence", "X", -302, 324, 720, 0, H, 4, nil, wood, Enum.Material.WoodPlanks)
	-- Fence posts double as a parkour line.
	for i = 0, 22 do
		Kit.box(model, "FencePost", Vector3.new(-404 + i * 50, 0, -1206), Vector3.new(10, H + 6, 10), wood:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Wood)
	end
	Kit.gate(m, "YardGate", Vector3.new(265, 40, -1200), Vector3.new(70, 80, 2), 9, "Human-Sized players can open the yard gate (or jump the fence!)")
	Kit.discovery(m, "FenceTop", Vector3.new(160, 92, -1200), Vector3.new(1100, 16, 14))
	Kit.orbLine(m, ZONE, Vector3.new(-380, 86, -1206), Vector3.new(200, 86, -1206), 12)
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(700, 86, -1206))
end

local function grassForest(m: Instance)
	local rng = Random.new(1101)
	for _ = 1, 170 do
		local x = rng:NextNumber(-390, -60)
		local z = rng:NextNumber(-660, -320)
		local h = rng:NextNumber(18, 36)
		local blade = Kit.part(m, {
			Name = "GrassBlade",
			Size = Vector3.new(1.4, h, 3.2),
			CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)),
			Color = Kit.Colors.Grass:Lerp(Kit.Colors.DarkGrass, rng:NextNumber()),
			Material = Enum.Material.Grass,
			CanCollide = rng:NextNumber() < 0.35,
			CastShadow = false,
		})
		Kit.tag(blade, "Sway")
	end
	-- Stepping stones path through the forest.
	for i = 0, 8 do
		Kit.pillar(m, "SteppingStone", Vector3.new(-90 - i * 32, 0, -380 - i * 28), 2, 22, Kit.Colors.Rock, Enum.Material.Slate)
	end
	Kit.discovery(m, "GrassForest", Vector3.new(-220, 20, -490), Vector3.new(300, 40, 300))
	Kit.orbLine(m, ZONE, Vector3.new(-90, 2, -380), Vector3.new(-346, 2, -604), 9)
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(-300, 0, -600))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(-150, 0, -420))
	Kit.enemySpawner(m, "GardenBeetle", Vector3.new(-250, 0, -500), 3, 120)
end

local function garden(m: Instance)
	local soil = Kit.Colors.Dirt
	for row = 0, 3 do
		local z = -1080 + row * 60
		Kit.box(m, "RaisedBed", Vector3.new(-360, 0, z), Vector3.new(240, 14, 36), Color3.fromRGB(130, 90, 60), Enum.Material.WoodPlanks)
		Kit.box(m, "Soil", Vector3.new(-356, 14, z + 4), Vector3.new(232, 2, 28), soil, Enum.Material.Ground)
		for i = 0, 6 do
			local base = Vector3.new(-340 + i * 33, 16, z + 18)
			Kit.pillar(m, "Stake", base, 40, 2, Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
			Kit.ball(m, "Plant", base + Vector3.new(0, 26, 0), 16, Kit.Colors.DarkGrass, Enum.Material.Grass)
			if (i + row) % 3 == 0 then
				Kit.ball(m, "Tomato", base + Vector3.new(5, 20, 4), 5, Color3.fromRGB(220, 50, 40), Enum.Material.SmoothPlastic)
			end
		end
	end
	Kit.discovery(m, "GardenRows", Vector3.new(-240, 20, -990), Vector3.new(250, 40, 240))
	Kit.orbLine(m, ZONE, Vector3.new(-350, 16, -1062), Vector3.new(-130, 16, -1062), 7)
	Kit.orbLine(m, ZONE, Vector3.new(-350, 16, -942), Vector3.new(-130, 16, -942), 7)
	Kit.interactable(m, "FlowerPot", CFrame.new(-80, 12, -900), Vector3.new(18, 24, 18), Color3.fromRGB(190, 100, 70), Enum.Material.SmoothPlastic, nil)
	Kit.interactable(m, "GardenGnome", CFrame.new(-90, 15, -1000), Vector3.new(12, 30, 12), Color3.fromRGB(200, 60, 60), Enum.Material.SmoothPlastic, nil)
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(-240, 16, -1010))
	Kit.enemySpawner(m, "Wasp", Vector3.new(-240, 60, -990), 4, 120)
end

local function patio(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "Patio", true)
	Kit.box(model, "PatioSlab", Vector3.new(150, 0, -520), Vector3.new(320, 2, 214), C.Concrete, Enum.Material.Concrete)
	Kit.pillar(model, "PatioTableTop", Vector3.new(300, 33, -430), 2, 80, Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	Kit.pillar(model, "PatioTableLeg", Vector3.new(300, 2, -430), 31, 6, Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
	Kit.pillar(model, "UmbrellaPole", Vector3.new(300, 35, -430), 70, 3, Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
	Kit.part(model, { Name = "Umbrella", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 150, 150), CFrame = CFrame.new(300, 105, -430) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(230, 80, 70), Material = Enum.Material.Fabric })
	for _, offset in { Vector3.new(-60, 0, 0), Vector3.new(60, 0, 0), Vector3.new(0, 0, -60) } do
		local seat = Vector3.new(300, 0, -430) + offset
		Kit.box(model, "PatioChair", seat - Vector3.new(12, 0, 12), Vector3.new(24, 20, 24), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	end
	Kit.discovery(m, "PatioTable", Vector3.new(300, 40, -430), Vector3.new(80, 12, 80))
	Kit.orbRing(m, ZONE, Vector3.new(300, 35, -430), 30, 6)
	Kit.collectible(m, "GoldenOrb", ZONE, Vector3.new(300, 35, -430))
	Kit.station(m, "SkillTree", "Garden Shrine", Vector3.new(190, 2, -470), 3, Color3.fromRGB(190, 140, 255))
	Kit.station(m, "Upgrades", "Potting Bench Lab", Vector3.new(190, 2, -400), 3, Color3.fromRGB(120, 255, 140))
	Kit.interactable(m, "TennisBall", CFrame.new(250, 9, -500), Vector3.new(14, 14, 14), Color3.fromRGB(210, 240, 60), Enum.Material.Fabric, Enum.PartType.Ball)
end

local function pool(m: Instance)
	local C = Kit.Colors
	local model = Kit.model(m, "Pool", true)
	-- Deck around a basin; the water is real terrain water (swimmable).
	Kit.box(model, "PoolDeck", Vector3.new(430, 0, -930), Vector3.new(280, 4, 40), C.Concrete, Enum.Material.Concrete)
	Kit.box(model, "PoolDeck", Vector3.new(430, 0, -650), Vector3.new(280, 4, 40), C.Concrete, Enum.Material.Concrete)
	Kit.box(model, "PoolDeck", Vector3.new(430, 0, -890), Vector3.new(30, 4, 240), C.Concrete, Enum.Material.Concrete)
	Kit.box(model, "PoolDeck", Vector3.new(680, 0, -890), Vector3.new(30, 4, 240), C.Concrete, Enum.Material.Concrete)
	Kit.box(model, "PoolFloor", Vector3.new(460, -60, -890), Vector3.new(220, 2, 240), Color3.fromRGB(90, 170, 220), Enum.Material.Marble)
	for _, wall in {
		{ Vector3.new(460, -60, -892), Vector3.new(220, 64, 2) },
		{ Vector3.new(460, -60, -650), Vector3.new(220, 64, 2) },
		{ Vector3.new(458, -60, -890), Vector3.new(2, 64, 240) },
		{ Vector3.new(680, -60, -890), Vector3.new(2, 64, 240) },
	} do
		Kit.box(model, "PoolWall", wall[1], wall[2], Color3.fromRGB(110, 190, 230), Enum.Material.Marble)
	end
	-- Ladder out.
	for i = 0, 5 do
		Kit.box(model, "PoolStep", Vector3.new(462, -58 + i * 10, -700 - i * 6), Vector3.new(30, 2, 8), C.Steel, Enum.Material.Metal)
	end
	pcall(function()
		workspace.Terrain:FillBlock(CFrame.new(570, -30, -770), Vector3.new(216, 56, 236), Enum.Material.Water)
	end)
	Kit.discovery(m, "PoolDeck", Vector3.new(570, 10, -920), Vector3.new(250, 20, 30))
	Kit.collectible(m, "Relic", ZONE, Vector3.new(600, -58, -800))
	Kit.orbLine(m, ZONE, Vector3.new(445, 4, -920), Vector3.new(695, 4, -920), 8)
	Kit.enemySpawner(m, "Frog", Vector3.new(600, 4, -640), 2, 80)
end

local function shed(m: Instance)
	local wood = Color3.fromRGB(120, 90, 70)
	local model = Kit.model(m, "Shed", true)
	-- Walls with a broken lower panel (24 tall) that small players squeeze through.
	Kit.wall(model, "ShedWall", "X", -1000, -360, -200, 0, 120, 4, { { -300, -270, 24 } }, wood, Enum.Material.WoodPlanks)
	Kit.wall(model, "ShedWall", "X", -1150, -360, -200, 0, 120, 4, nil, wood, Enum.Material.WoodPlanks)
	Kit.wall(model, "ShedWall", "Z", -360, -1150, -1000, 0, 120, 4, nil, wood, Enum.Material.WoodPlanks)
	Kit.wall(model, "ShedWall", "Z", -200, -1150, -1000, 0, 120, 4, nil, wood, Enum.Material.WoodPlanks)
	Kit.box(model, "ShedRoof", Vector3.new(-366, 120, -1156), Vector3.new(172, 6, 162), Color3.fromRGB(90, 60, 50), Enum.Material.Slate)
	Kit.box(model, "Workbench", Vector3.new(-350, 0, -1140), Vector3.new(80, 30, 30), Kit.Colors.DarkWood, Enum.Material.Wood)
	Kit.box(model, "Cabinet", Vector3.new(-240, 0, -1140), Vector3.new(30, 60, 25), Color3.fromRGB(80, 80, 90), Enum.Material.Metal)
	local cabinetDoor = Kit.box(model, "CabinetDoor", Vector3.new(-240, 0, -1116), Vector3.new(30, 60, 2), Color3.fromRGB(100, 100, 110), Enum.Material.Metal)
	Kit.tag(cabinetDoor, "LockedDoor", { KeyItem = "ShedKey", Message = "Locked. Fern's shed key would open it.", InteractId = "ShedCabinet" })
	Kit.collectible(m, "Relic", ZONE, Vector3.new(-226, 0, -1130))
	Kit.discovery(m, "ShedInterior", Vector3.new(-280, 30, -1075), Vector3.new(150, 60, 140))
	Kit.collectible(m, "TitanShard", ZONE, Vector3.new(-330, 30, -1130))
	Kit.interactable(m, "Crate", CFrame.new(-300, 12, -1050), Vector3.new(24, 24, 24), Color3.fromRGB(170, 130, 80), Enum.Material.WoodPlanks)
	-- Gnome shrine hidden behind the shed.
	Kit.pillar(m, "ShrinePlinth", Vector3.new(-380, 0, -1180), 8, 16, Kit.Colors.Rock, Enum.Material.Cobblestone)
	Kit.box(m, "GnomeStatue", Vector3.new(-385, 8, -1185), Vector3.new(10, 22, 10), Color3.fromRGB(120, 160, 200), Enum.Material.Marble)
	Kit.discovery(m, "GnomeShrine", Vector3.new(-380, 15, -1180), Vector3.new(30, 30, 30))
	Kit.collectible(m, "SecretStar", ZONE, Vector3.new(-370, 0, -1190))
end

local function oak(m: Instance)
	local bark = Color3.fromRGB(100, 75, 50)
	local model = Kit.model(m, "Oak", true)
	local base = Vector3.new(560, 0, -450)
	Kit.pillar(model, "Trunk", base, 300, 44, bark, Enum.Material.Wood)
	-- Spiral of branches as platforms.
	for i = 0, 9 do
		local a = i * 1.2
		local y = 40 + i * 24
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		Kit.rod(model, "Branch", base + Vector3.new(0, y, 0), base + dir * 70 + Vector3.new(0, y + 10, 0), 12, bark, Enum.Material.Wood)
		Kit.block(model, "BranchPad", base + dir * 60 + Vector3.new(0, y + 10, 0), Vector3.new(24, 4, 24), bark, Enum.Material.Wood)
	end
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		Kit.ball(model, "Leaves", base + Vector3.new(math.cos(a) * 70, 300, math.sin(a) * 70), 120, Kit.Colors.DarkGrass, Enum.Material.Grass)
	end
	Kit.block(model, "CanopyPlatform", base + Vector3.new(0, 300, 0), Vector3.new(100, 6, 100), bark, Enum.Material.Wood)
	Kit.discovery(m, "OakCanopy", base + Vector3.new(0, 320, 0), Vector3.new(160, 40, 160))
	Kit.collectible(m, "TitanShard", ZONE, base + Vector3.new(20, 303, 20))
	Kit.collectible(m, "GoldenOrb", ZONE, base + Vector3.new(-20, 303, -20))
	Kit.orbLine(m, ZONE, base + Vector3.new(60, 54, 0), base + Vector3.new(0, 300, 60), 8)
end

local function birdbath(m: Instance)
	local stone = Color3.fromRGB(190, 190, 185)
	Kit.pillar(m, "BirdbathPedestal", Vector3.new(100, 0, -760), 50, 18, stone, Enum.Material.Concrete)
	Kit.pillar(m, "BirdbathBowl", Vector3.new(100, 50, -760), 6, 60, stone, Enum.Material.Concrete)
	local water = Kit.pillar(m, "BirdbathWater", Vector3.new(100, 55, -760), 1, 52, Kit.Colors.Water, Enum.Material.Glass)
	water.Transparency = 0.4
	-- Stacked rocks to reach the bowl.
	for i = 0, 3 do
		Kit.box(m, "Rock", Vector3.new(130 + i * 14, 0, -770), Vector3.new(18, 12 + i * 12, 18), Kit.Colors.Rock, Enum.Material.Slate)
	end
	Kit.discovery(m, "BirdbathSummit", Vector3.new(100, 62, -760), Vector3.new(60, 16, 60))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(100, 56, -760))
end

function Backyard.build(root: Instance)
	local m = Kit.folder(root, "Backyard")
	Kit.ground(m, "Lawn", -400, -1200, 720, -300, 0, 6, Kit.Colors.Grass, Enum.Material.Grass)
	fence(m)
	grassForest(m)
	garden(m)
	patio(m)
	pool(m)
	shed(m)
	oak(m)
	birdbath(m)
	Kit.bossArena(m, "Lawnmower", Vector3.new(150, 0, -850))
	Kit.spawnPad(m, ZONE, Vector3.new(265, 2, -370), 3)
	Kit.fastTravel(m, ZONE, Vector3.new(220, 2, -360), 3)
	Kit.npc(m, "Fern", Vector3.new(330, 2, -400), Vector3.new(-1, 0, 0))
	Kit.orbLine(m, ZONE, Vector3.new(265, 2, -380), Vector3.new(150, 2, -700), 10)
	Kit.orbLine(m, ZONE, Vector3.new(400, 0, -1000), Vector3.new(0, 0, -1150), 10)
	Kit.collectible(m, "Relic", ZONE, Vector3.new(-50, 0, -1180))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(700, 0, -320))
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(0, 0, -800))
	Kit.collectible(m, "MemoryFragment", ZONE, Vector3.new(690, 0, -1180))
	Kit.enemySpawner(m, "Wasp", Vector3.new(300, 80, -700), 3, 150)
	Kit.enemySpawner(m, "GardenBeetle", Vector3.new(450, 0, -1100), 2, 100)
end

return Backyard
