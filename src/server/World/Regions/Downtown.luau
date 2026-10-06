--!strict
--[[
	Downtown — Region 6 (x -2600..3400, z 2200..8200)

	Large- to Titan-sized (150–600 studs tall). A grid of city blocks with
	skyscrapers 400–3200 tall: at first vertical traversal is everything
	(ledges, rooftops, the sky bridge), and by Titan size the buildings are
	landmarks you hop between.

	Landmarks: subway entrance (spawn), parking spiral, clock tower, sky
	bridge, billboard ledge, Vale Industries tower (with a maintenance hatch
	only small players fit through → the server room), the tallest rooftop,
	and a central plaza where GUARDIAN MK-IV patrols.

	Final art: glass curtain walls, signage, street lights, traffic.
]]

local Kit = require(script.Parent.Parent.Kit)

local Downtown = {}

local ZONE = "Downtown"

local BLOCK = 800
local XS = { -2500, -1350, -200, 950, 2100 }
local ZS = { 2500, 3650, 4800, 5950, 7100 }

local PLAZA_CENTER = Vector3.new(800, 0, 6400)
local PLAZA_RADIUS = 1150

local function inPlaza(x: number, z: number): boolean
	local cx, cz = x + BLOCK / 2, z + BLOCK / 2
	return (Vector3.new(cx, 0, cz) - PLAZA_CENTER).Magnitude < PLAZA_RADIUS + BLOCK * 0.45
end

local function building(parent: Instance, name: string, min: Vector3, footprint: Vector2, height: number, color: Color3)
	local model = Kit.model(parent, name, height > 1200)
	local center = Vector3.new(min.X + footprint.X / 2, 0, min.Z + footprint.Y / 2)
	Kit.tower(model, "Body", center, footprint, height, color, Enum.Material.Glass)
	-- Ledges every ~200 studs on one face make every tower climbable.
	for y = 180, height - 100, 200 do
		Kit.block(model, "Ledge", center + Vector3.new(footprint.X / 2 + 20, y, 0), Vector3.new(40, 12, footprint.Y * 0.6), Kit.Colors.Concrete, Enum.Material.Concrete)
	end
	Kit.block(model, "Roof", center + Vector3.new(0, height + 6, 0), Vector3.new(footprint.X + 20, 12, footprint.Y + 20), Color3.fromRGB(70, 70, 75), Enum.Material.Concrete)
	return center
end

local landmarks: { [string]: boolean } = {}

local function cityBlocks(m: Instance)
	local rng = Random.new(1401)
	local palette = {
		Color3.fromRGB(120, 150, 180),
		Color3.fromRGB(90, 110, 140),
		Color3.fromRGB(150, 170, 190),
		Color3.fromRGB(110, 120, 130),
		Color3.fromRGB(170, 160, 150),
	}
	for _, x in XS do
		for _, z in ZS do
			local key = x .. "," .. z
			if inPlaza(x, z) or landmarks[key] then
				continue
			end
			Kit.box(m, "Sidewalk", Vector3.new(x, 0, z), Vector3.new(BLOCK, 3, BLOCK), Kit.Colors.Concrete, Enum.Material.Concrete)
			-- 1–4 buildings per block.
			local split = rng:NextInteger(1, 4)
			local half = BLOCK / 2
			local slots: { { number } } = if split == 1
				then { { 0, 0, BLOCK, BLOCK } }
				elseif split == 2 then { { 0, 0, half, BLOCK }, { half, 0, half, BLOCK } }
				else { { 0, 0, half, half }, { half, 0, half, half }, { 0, half, half, half }, { half, half, half, half } }
			for i, slot in slots do
				if i > split and split ~= 3 then
					break
				end
				local inset = 40
				local h = rng:NextNumber(400, 1800)
				building(m, "Tower", Vector3.new(x + slot[1] + inset, 3, z + slot[2] + inset), Vector2.new(slot[3] - inset * 2, slot[4] - inset * 2), h, palette[rng:NextInteger(1, #palette)])
			end
		end
	end
end

local function landmarkBuildings(m: Instance)
	-- Station Square around the subway / spawn stays open.
	landmarks["-200,2500"] = true
	-- Parking spiral (block -2500, 2500).
	landmarks["-2500,2500"] = true
	local garage = Kit.model(m, "ParkingSpiral", true)
	local gc = Vector3.new(-2100, 0, 2900)
	Kit.tower(garage, "Core", gc, Vector2.new(200, 200), 950, Kit.Colors.Concrete, Enum.Material.Concrete)
	for i = 0, 15 do
		local a = i / 4 * math.pi * 2
		local y = i * 56
		local p = gc + Vector3.new(math.cos(a) * 260, y, math.sin(a) * 260)
		Kit.block(garage, "Ramp", p, Vector3.new(220, 10, 220), Color3.fromRGB(140, 140, 135), Enum.Material.Concrete)
	end
	Kit.discovery(m, "ParkingSpiral", gc + Vector3.new(0, 500, 0), Vector3.new(800, 1000, 800))
	Kit.collectible(m, "LostCoin", ZONE, gc + Vector3.new(0, 950, 0))

	-- Clock tower (block -1350, 4800).
	landmarks["-1350,4800"] = true
	local clock = Kit.model(m, "ClockTower", true)
	local cc = Vector3.new(-950, 0, 5200)
	Kit.tower(clock, "Tower", cc, Vector2.new(300, 300), 1800, Color3.fromRGB(150, 120, 100), Enum.Material.Brick)
	for y = 150, 1700, 160 do
		Kit.block(clock, "Ledge", cc + Vector3.new(170, y, 0), Vector3.new(40, 12, 200), Kit.Colors.Concrete, Enum.Material.Concrete)
	end
	local face = Kit.pillar(clock, "ClockFace", cc + Vector3.new(0, 1500, 151), 4, 220, Color3.fromRGB(250, 245, 230), Enum.Material.SmoothPlastic)
	face.CFrame = CFrame.new(cc + Vector3.new(0, 1500, 152)) * CFrame.Angles(0, math.rad(90), 0)
	Kit.light(face, Color3.fromRGB(255, 240, 200), 60, 1)
	Kit.discovery(m, "ClockTower", cc + Vector3.new(0, 1850, 0), Vector3.new(340, 120, 340))
	Kit.collectible(m, "TitanShard", ZONE, cc + Vector3.new(0, 1806, 0))

	-- Sky bridge between two towers (blocks -2500/5950 and -1350/5950).
	landmarks["-2500,5950"] = true
	landmarks["-1350,5950"] = true
	local a = building(m, "BridgeTowerWest", Vector3.new(-2400, 3, 6050), Vector2.new(600, 600), 1600, Color3.fromRGB(110, 140, 170))
	local b = building(m, "BridgeTowerEast", Vector3.new(-1250, 3, 6050), Vector2.new(600, 600), 1600, Color3.fromRGB(110, 140, 170))
	local bridge = Kit.block(m, "SkyBridge", Vector3.new((a.X + b.X) / 2, 1200, a.Z), Vector3.new(b.X - a.X - 500, 30, 160), Kit.Colors.Glass, Enum.Material.Glass)
	bridge.Transparency = 0.25
	Kit.discovery(m, "SkyBridge", Vector3.new((a.X + b.X) / 2, 1260, a.Z), Vector3.new(560, 100, 180))
	Kit.orbLine(m, ZONE, Vector3.new(a.X + 320, 1215, a.Z), Vector3.new(b.X - 320, 1215, a.Z), 6)

	-- Billboard tower (block 2100, 3650).
	landmarks["2100,3650"] = true
	local bc = building(m, "BillboardTower", Vector3.new(2180, 3, 3730), Vector2.new(640, 640), 1000, Color3.fromRGB(90, 100, 120))
	local board = Kit.block(m, "Billboard", bc + Vector3.new(-330, 760, 0), Vector3.new(10, 260, 500), Color3.fromRGB(255, 90, 140), Enum.Material.Neon)
	local _ = board
	Kit.block(m, "BillboardLedge", bc + Vector3.new(-360, 625, 0), Vector3.new(60, 10, 520), Kit.Colors.Steel, Enum.Material.DiamondPlate)
	Kit.discovery(m, "BillboardLedge", bc + Vector3.new(-360, 680, 0), Vector3.new(80, 100, 520))
	Kit.collectible(m, "Relic", ZONE, bc + Vector3.new(-360, 631, 150))
	for i = 0, 3 do
		Kit.interactable(m, "BillboardPanel", CFrame.new(bc + Vector3.new(0, 1040, -240 + i * 160)), Vector3.new(120, 80, 10), Color3.fromRGB(80, 200, 255), Enum.Material.Neon, nil)
	end

	-- Vale Industries (block 950, 3650): hollow lobby, tiny hatch, server room.
	landmarks["950,3650"] = true
	local vale = Kit.model(m, "ValeIndustries", true)
	local vc = Vector3.new(1350, 0, 4050)
	local W = 680
	Kit.wall(vale, "Lobby", "X", vc.Z - W / 2, vc.X - W / 2, vc.X + W / 2, 3, 300, 20, { { vc.X - 30, vc.X + 30, 85 } }, Color3.fromRGB(200, 205, 215), Enum.Material.Concrete)
	Kit.wall(vale, "Lobby", "X", vc.Z + W / 2, vc.X - W / 2, vc.X + W / 2, 3, 300, 20, nil, Color3.fromRGB(200, 205, 215), Enum.Material.Concrete)
	Kit.wall(vale, "Lobby", "Z", vc.X - W / 2, vc.Z - W / 2, vc.Z + W / 2, 3, 300, 20, nil, Color3.fromRGB(200, 205, 215), Enum.Material.Concrete)
	Kit.wall(vale, "Lobby", "Z", vc.X + W / 2, vc.Z - W / 2, vc.Z + W / 2, 3, 300, 20, nil, Color3.fromRGB(200, 205, 215), Enum.Material.Concrete)
	Kit.block(vale, "LobbyFloor", vc + Vector3.new(0, 2, 0), Vector3.new(W, 4, W), Color3.fromRGB(40, 45, 55), Enum.Material.Marble)
	Kit.tower(vale, "Tower", vc + Vector3.new(0, 303, 0), Vector2.new(W, W), 2100, Color3.fromRGB(60, 140, 200), Enum.Material.Glass)
	local rng = Random.new(1402)
	for i = 0, 9 do
		local rack = Kit.block(vale, "ServerRack", vc + Vector3.new(-250 + i * 55, 40, -100 + (i % 2) * 200), Vector3.new(30, 80, 120), Color3.fromRGB(25, 25, 30), Enum.Material.Metal)
		if rng:NextNumber() < 0.6 then
			local led = Kit.block(vale, "RackLight", rack.Position + Vector3.new(0, 20, 61), Vector3.new(20, 4, 1), Color3.fromRGB(80, 255, 140), Enum.Material.Neon)
			led.CanCollide = false
		end
	end
	Kit.discovery(m, "ServerRoom", vc + Vector3.new(0, 60, 0), Vector3.new(W - 60, 110, W - 60))
	Kit.collectible(m, "SecretStar", ZONE, vc + Vector3.new(200, 4, 200))
	Kit.collectible(m, "MemoryFragment", ZONE, vc + Vector3.new(-200, 4, 200))

	-- The tallest rooftop (block 2100, 7100).
	landmarks["2100,7100"] = true
	local hc = building(m, "Pinnacle", Vector3.new(2150, 3, 7150), Vector2.new(700, 700), 3200, Color3.fromRGB(70, 90, 120))
	Kit.discovery(m, "HighestRooftop", hc + Vector3.new(0, 3300, 0), Vector3.new(740, 200, 740))
	Kit.collectible(m, "TitanShard", ZONE, hc + Vector3.new(0, 3212, 0))
	Kit.collectible(m, "GoldenOrb", ZONE, hc + Vector3.new(200, 3212, 200))
	local antenna = Kit.pillar(m, "Antenna", hc + Vector3.new(0, 3212, 0), 400, 20, Kit.Colors.Steel, Enum.Material.Metal)
	local beacon = Kit.ball(m, "AntennaBeacon", antenna.Position + Vector3.new(0, 210, 0), 40, Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	Kit.light(beacon, Color3.fromRGB(255, 60, 60), 60, 2)
end

local function plaza(m: Instance)
	Kit.pillar(m, "Plaza", PLAZA_CENTER - Vector3.new(0, 0.5, 0), 4, PLAZA_RADIUS * 2, Color3.fromRGB(190, 185, 175), Enum.Material.Pavement)
	Kit.pillar(m, "PlazaMonument", PLAZA_CENTER + Vector3.new(0, 3.5, 0), 120, 260, Kit.Colors.Concrete, Enum.Material.Marble)
	Kit.bossArena(m, "Guardian", PLAZA_CENTER + Vector3.new(0, 3.5, 0))
	Kit.orbRing(m, ZONE, PLAZA_CENTER + Vector3.new(0, 4, 0), 700, 14)
	Kit.enemySpawner(m, "Sentinel", PLAZA_CENTER + Vector3.new(0, 4, -900), 3, 500)
end

function Downtown.build(root: Instance)
	local m = Kit.folder(root, "Downtown")
	Kit.ground(m, "Street", -2600, 2200, 3400, 8200, 0, 6, Kit.Colors.Asphalt, Enum.Material.Asphalt)
	landmarkBuildings(m)
	cityBlocks(m)
	plaza(m)
	-- Subway entrance at the spawn.
	local subway = Kit.model(m, "SubwayEntrance", true)
	Kit.box(subway, "Stairwell", Vector3.new(60, 0, 2620), Vector3.new(200, 60, 120), Color3.fromRGB(60, 120, 70), Enum.Material.Metal)
	local sign = Kit.box(subway, "SubwaySign", Vector3.new(120, 60, 2660), Vector3.new(80, 50, 10), Color3.fromRGB(40, 160, 80), Enum.Material.Neon)
	local _ = sign
	Kit.discovery(m, "SubwayEntrance", Vector3.new(160, 60, 2680), Vector3.new(260, 120, 200))
	Kit.spawnPad(m, ZONE, Vector3.new(400, 0, 2350), 30)
	Kit.fastTravel(m, ZONE, Vector3.new(700, 0, 2450), 30)
	Kit.npc(m, "Vale", Vector3.new(760, 0, 2420), Vector3.new(-1, 0, 0))
	Kit.station(m, "Upgrades", "Vale Labs Terminal", Vector3.new(150, 0, 2280), 30, Color3.fromRGB(120, 255, 140))
	Kit.station(m, "SkillTree", "Neon Shrine", Vector3.new(-100, 0, 2280), 30, Color3.fromRGB(190, 140, 255))
	Kit.orbLine(m, ZONE, Vector3.new(-2400, 1, 3550), Vector3.new(3200, 1, 3550), 18)
	Kit.orbLine(m, ZONE, Vector3.new(1850, 1, 2400), Vector3.new(1850, 1, 8000), 18)
	Kit.collectible(m, "LostCoin", ZONE, Vector3.new(-2550, 1, 8100))
	Kit.collectible(m, "HiddenToy", ZONE, Vector3.new(3300, 1, 2300))
	Kit.collectible(m, "Relic", ZONE, Vector3.new(-1500, 1, 7000))
	Kit.enemySpawner(m, "SecurityDrone", Vector3.new(-500, 600, 4200), 4, 1200)
	Kit.enemySpawner(m, "SecurityDrone", Vector3.new(2500, 600, 5500), 4, 1200)
	Kit.enemySpawner(m, "Sentinel", Vector3.new(-1500, 1, 3500), 2, 600)
end

return Downtown
