--!strict
--[[
	House
	The shell shared by the indoor regions: floors, walls, doorways, ceiling,
	roof, plus the size gates between rooms.

	Layout (top-down, floor at y = 0, 1 ft ≈ 13.3 studs, ceilings ~10.5 ft):
	    z=320 ┌─────────────┬───────────────┐ front wall (vent duct)
	          │  BEDROOM    │  LIVING ROOM  │
	          │ x -280..0   │ "FLOOR WORLD" │
	      z=0 ├────door─────┼─────arch──────┤
	          │  PLAYROOM   │   KITCHEN     │
	   z=-300 └─────────────┴──back door────┘ (pet door → backyard)

	Final art: replace with a modelled house interior (baseboards, trim,
	outlets, light switches) — keep doorway sizes, they are gameplay.
]]

local Kit = require(script.Parent.Parent.Kit)

local House = {}

local WALL_H = 140
local T = 4

-- A window in a wall opening: glass, a white frame, a sill and two curtains.
-- `inward` is +1/-1: which side of the wall is the room.
local function window(
	m: Instance,
	axis: "X" | "Z",
	fixed: number,
	from: number,
	to: number,
	bottom: number,
	top: number,
	inward: number,
	curtain: Color3
)
	local C = Kit.Colors
	local frame = Color3.fromRGB(250, 248, 242)
	local len = to - from
	local mid = (from + to) / 2
	local h = top - bottom
	local function at(along: number, y: number, depth: number): Vector3
		if axis == "X" then
			return Vector3.new(along, y, fixed + depth * inward)
		end
		return Vector3.new(fixed + depth * inward, y, along)
	end
	local function size(along: number, y: number, depth: number): Vector3
		if axis == "X" then
			return Vector3.new(along, y, depth)
		end
		return Vector3.new(depth, y, along)
	end
	local glass =
		Kit.block(m, "WindowGlass", at(mid, bottom + h / 2, 0), size(len, h, 0.6), C.Glass, Enum.Material.Glass)
	glass.Transparency = 0.75
	glass.CastShadow = false
	-- Frame and a cross mullion.
	Kit.block(m, "WindowFrame", at(mid, top - 1.5, 0), size(len + 4, 3, 6), frame, Enum.Material.Wood)
	Kit.block(m, "WindowFrame", at(mid, bottom + h / 2, 0), size(len, 2, 5), frame, Enum.Material.Wood)
	Kit.block(m, "WindowFrame", at(mid, bottom + h / 2, 0), size(2, h, 5), frame, Enum.Material.Wood)
	Kit.block(m, "WindowFrame", at(from + 1, bottom + h / 2, 0), size(2.5, h, 6), frame, Enum.Material.Wood)
	Kit.block(m, "WindowFrame", at(to - 1, bottom + h / 2, 0), size(2.5, h, 6), frame, Enum.Material.Wood)
	Kit.block(m, "Windowsill", at(mid, bottom - 1, 4), size(len + 10, 3, 12), frame, Enum.Material.Wood)
	-- Curtains gathered at each side, plus the rod.
	for _, side in { from - 6, to + 6 } do
		local c = Kit.block(
			m,
			"Curtain",
			at(side, bottom + h / 2 + 6, 5),
			size(12, h + 16, 2.5),
			curtain,
			Enum.Material.Fabric
		)
		c.CastShadow = true
	end
	Kit.block(
		m,
		"CurtainRod",
		at(mid, top + 10, 6),
		size(len + 34, 1.5, 1.5),
		Color3.fromRGB(70, 60, 55),
		Enum.Material.Metal
	)
end

function House.build(root: Instance)
	local m = Kit.model(root, "HouseShell", true)
	local C = Kit.Colors

	-- Floors --------------------------------------------------------------
	-- Living room hardwood, split around the Floor Crack (x 292..296, z 180..300).
	Kit.box(m, "LivingFloor", Vector3.new(0, -T, 0), Vector3.new(292, T, 320), C.LightWood, Enum.Material.WoodPlanks)
	Kit.box(m, "LivingFloor", Vector3.new(296, -T, 0), Vector3.new(24, T, 320), C.LightWood, Enum.Material.WoodPlanks)
	Kit.box(m, "LivingFloor", Vector3.new(292, -T, 0), Vector3.new(4, T, 180), C.LightWood, Enum.Material.WoodPlanks)
	Kit.box(m, "LivingFloor", Vector3.new(292, -T, 300), Vector3.new(4, T, 20), C.LightWood, Enum.Material.WoodPlanks)
	Kit.box(m, "BedroomFloor", Vector3.new(-280, -T, 0), Vector3.new(280, T, 320), C.Carpet, Enum.Material.Fabric)
	Kit.box(
		m,
		"PlayroomFloor",
		Vector3.new(-280, -T, -300),
		Vector3.new(280, T, 300),
		Color3.fromRGB(110, 150, 190),
		Enum.Material.Fabric
	)
	Kit.box(m, "KitchenFloor", Vector3.new(0, -T, -300), Vector3.new(320, T, 300), C.Tile, Enum.Material.Marble)

	-- Floor Crack cave (only small players fit through the 4-stud gap).
	local cave = Kit.model(root, "CrackCave")
	Kit.box(cave, "CaveFloor", Vector3.new(278, -18, 172), Vector3.new(34, 4, 136), C.DarkWood, Enum.Material.Wood)
	Kit.box(cave, "CaveWall", Vector3.new(278, -14, 172), Vector3.new(2, 10, 136), C.DarkWood, Enum.Material.Wood)
	Kit.box(cave, "CaveWall", Vector3.new(310, -14, 172), Vector3.new(2, 10, 136), C.DarkWood, Enum.Material.Wood)
	Kit.box(cave, "CaveWall", Vector3.new(278, -14, 170), Vector3.new(34, 10, 2), C.DarkWood, Enum.Material.Wood)
	Kit.box(cave, "CaveWall", Vector3.new(278, -14, 308), Vector3.new(34, 10, 2), C.DarkWood, Enum.Material.Wood)
	-- Step blocks back up to the crack (each < a microscopic jump).
	for i = 0, 6 do
		Kit.box(
			cave,
			"CaveStep",
			Vector3.new(289, -14, 200 + i * 6),
			Vector3.new(6, 1.3 + i * 1.3, 5),
			C.Wood,
			Enum.Material.Wood
		)
	end
	local glow =
		Kit.ball(cave, "CaveGlow", Vector3.new(298, -11, 260), 1.2, Color3.fromRGB(150, 220, 255), Enum.Material.Neon)
	glow.CanCollide = false
	Kit.light(glow, Color3.fromRGB(150, 220, 255), 18, 1.5)

	-- Exterior walls ----------------------------------------------------------
	-- Front (z = 320): front door (decor, closed) + Forgotten Vent opening.
	Kit.wall(m, "FrontWall", "X", 322, -284, 324, 0, WALL_H, T, {
		{ -250, -175, 112, 38 },
		{ -130, -110, 9 },
		{ 215, 300, 112, 38 },
	}, C.Wall)
	Kit.box(m, "FrontDoor", Vector3.new(140, 0, 318.5), Vector3.new(50, 100, 1.5), C.Wood, Enum.Material.Wood)
	-- Back (z = -300): kitchen back door with a pet door at the bottom.
	Kit.wall(m, "BackWall", "X", -302, -284, 324, 0, WALL_H, T, {
		{ 230, 290, 100 },
	}, C.Wall)
	Kit.box(m, "BackDoorPanel", Vector3.new(230, 24, -302.75), Vector3.new(60, 76, 1.5), C.Wood, Enum.Material.Wood)
	Kit.box(m, "BackDoorPanel", Vector3.new(230, 0, -302.75), Vector3.new(18, 24, 1.5), C.Wood, Enum.Material.Wood)
	Kit.box(m, "BackDoorPanel", Vector3.new(272, 0, -302.75), Vector3.new(18, 24, 1.5), C.Wood, Enum.Material.Wood)
	Kit.gate(
		m,
		"PetDoor",
		Vector3.new(260, 12, -302),
		Vector3.new(24, 24, 1.2),
		7,
		"Pet-Sized players can push through the pet door"
	)
	-- West (x = -280): bedroom window.
	Kit.wall(m, "WestWall", "Z", -282, -302, 324, 0, WALL_H, T, {
		{ -220, -140, 110, 40 },
		{ 90, 170, 110, 50 },
	}, C.Wall)
	window(m, "Z", -282, 90, 170, 50, 110, 1, Color3.fromRGB(120, 150, 200))
	-- East (x = 320).
	Kit.wall(m, "EastWall", "Z", 322, -302, 324, 0, WALL_H, T, {
		{ -250, -170, 110, 40 },
		{ 60, 140, 112, 38 },
	}, C.Wall)
	-- Glazing, frames, sills and curtains for every window opening.
	window(m, "X", 322, -250, -175, 38, 112, -1, Color3.fromRGB(120, 150, 200))
	window(m, "X", 322, 215, 300, 38, 112, -1, Color3.fromRGB(205, 120, 90))
	window(m, "Z", -282, -220, -140, 40, 110, 1, Color3.fromRGB(240, 190, 90))
	window(m, "Z", 322, -250, -170, 40, 110, -1, Color3.fromRGB(110, 170, 140))
	window(m, "Z", 322, 60, 140, 38, 112, -1, Color3.fromRGB(205, 120, 90))

	-- Interior walls --------------------------------------------------------
	-- Bedroom | Living (x = 0): doorway + painting cavity window.
	Kit.wall(m, "BedroomLivingWall", "Z", 0, 0, 320, 0, WALL_H, T, {
		{ 140, 190, 100 },
		{ 235, 275, 92, 62 },
	}, C.Wall)
	-- Living | Kitchen (z = 0): wide arch.
	Kit.wall(m, "LivingKitchenWall", "X", 0, 2, 320, 0, WALL_H, T, {
		{ 120, 220, 110 },
	}, C.Wall)
	-- Bedroom | Playroom (z = 0).
	Kit.wall(m, "BedroomPlayroomWall", "X", 0, -280, -2, 0, WALL_H, T, {
		{ -160, -110, 100 },
	}, C.Wall)
	-- Playroom | Kitchen (x = 0).
	Kit.wall(m, "PlayroomKitchenWall", "Z", 0, -300, -2, 0, WALL_H, T, nil, C.Wall)

	-- Ceiling + roof ------------------------------------------------------------
	Kit.box(
		m,
		"Ceiling",
		Vector3.new(-284, WALL_H, -304),
		Vector3.new(608, T, 628),
		C.Ceiling,
		Enum.Material.SmoothPlastic
	)
	Kit.wedge(
		m,
		"Roof",
		CFrame.new(20, WALL_H + T + 80, -150) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(640, 160, 330),
		Color3.fromRGB(110, 60, 50),
		Enum.Material.Slate
	)
	Kit.wedge(
		m,
		"Roof",
		CFrame.new(20, WALL_H + T + 80, 170),
		Vector3.new(640, 160, 330),
		Color3.fromRGB(110, 60, 50),
		Enum.Material.Slate
	)
	-- Lighting. Roblox lights reach at most 60 studs, so ceiling fixtures
	-- (138 studs up) are decorative; warm fill lights at lamp height light
	-- the floor where small players actually are.
	for _, pos in
		{
			Vector3.new(160, 139, 160),
			Vector3.new(-140, 139, 160),
			Vector3.new(-140, 139, -150),
			Vector3.new(160, 139, -150),
		}
	do
		local rim =
			Kit.pillar(m, "CeilingLampRim", pos - Vector3.new(0, 2, 0), 3, 36, C.Ceiling, Enum.Material.SmoothPlastic)
		rim.CFrame = CFrame.new(pos - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		rim.CanCollide = false
		local lamp = Kit.pillar(
			m,
			"CeilingLamp",
			pos - Vector3.new(0, 3.5, 0),
			1,
			30,
			Color3.fromRGB(255, 244, 222),
			Enum.Material.Neon
		)
		lamp.CFrame = CFrame.new(pos - Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
		lamp.CanCollide = false
	end
	local fills: { { any } } = {
		-- living room / floor world
		{ Vector3.new(80, 42, 80), Color3.fromRGB(255, 220, 180) },
		{ Vector3.new(240, 42, 80), Color3.fromRGB(255, 225, 190) },
		{ Vector3.new(80, 42, 240), Color3.fromRGB(255, 215, 175) },
		{ Vector3.new(240, 42, 240), Color3.fromRGB(255, 225, 190) },
		-- bedroom
		{ Vector3.new(-70, 42, 80), Color3.fromRGB(255, 210, 190) },
		{ Vector3.new(-210, 42, 80), Color3.fromRGB(230, 205, 255) },
		{ Vector3.new(-70, 42, 240), Color3.fromRGB(255, 214, 186) },
		{ Vector3.new(-210, 42, 240), Color3.fromRGB(255, 210, 200) },
		-- playroom
		{ Vector3.new(-70, 42, -80), Color3.fromRGB(255, 230, 200) },
		{ Vector3.new(-210, 42, -80), Color3.fromRGB(210, 225, 255) },
		{ Vector3.new(-70, 42, -220), Color3.fromRGB(255, 230, 200) },
		{ Vector3.new(-210, 42, -220), Color3.fromRGB(255, 225, 205) },
		-- kitchen (cooler, brighter)
		{ Vector3.new(80, 46, -80), Color3.fromRGB(245, 248, 255) },
		{ Vector3.new(240, 46, -80), Color3.fromRGB(250, 250, 255) },
		{ Vector3.new(80, 46, -220), Color3.fromRGB(255, 248, 235) },
		{ Vector3.new(240, 46, -220), Color3.fromRGB(245, 248, 255) },
	}
	for _, fill in fills do
		local anchor = Kit.part(m, {
			Name = "FillLight",
			Size = Vector3.new(1, 1, 1),
			Position = fill[1],
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		Kit.light(anchor, fill[2], 60, 1.1)
	end

	-- Baseboards: a thin trim line where walls meet the floor reads as
	-- "house" at every scale.
	local trim = Color3.fromRGB(248, 245, 238)
	for _, b in
		{
			{ Vector3.new(-280, 0, 318), Vector3.new(600, 6, 2) },
			{ Vector3.new(-280, 0, -300), Vector3.new(600, 6, 2) },
			{ Vector3.new(-280, 0, -300), Vector3.new(2, 6, 620) },
			{ Vector3.new(318, 0, -300), Vector3.new(2, 6, 620) },
		}
	do
		Kit.box(m, "Baseboard", b[1], b[2], trim, Enum.Material.SmoothPlastic)
	end

	-- Size gates between rooms ---------------------------------------------
	-- Bedroom doorway: a 2.8-stud threshold strip (Ant-Sized can hop it).
	Kit.box(m, "Threshold", Vector3.new(-2, 0, 140), Vector3.new(4, 2.8, 50), C.DarkWood, Enum.Material.Wood)
	Kit.gate(m, "BedroomDoor", Vector3.new(0, 51.4, 165), Vector3.new(1.2, 97.2, 50), 3)
	-- Kitchen arch: a raised tile step (Mouse-Sized can hop it).
	Kit.box(m, "TileStep", Vector3.new(120, 0, -2), Vector3.new(100, 5.5, 4), C.Tile, Enum.Material.Marble)
	Kit.gate(m, "KitchenArch", Vector3.new(170, 57.75, 0), Vector3.new(100, 104.5, 1.2), 5)

	-- Forgotten Vent duct (outside the front wall; only small players fit).
	local duct = Kit.model(root, "VentDuct")
	Kit.box(duct, "DuctFloor", Vector3.new(-132, -1, 324), Vector3.new(24, 1, 80), C.Steel, Enum.Material.Metal)
	Kit.box(duct, "DuctRoof", Vector3.new(-132, 9, 324), Vector3.new(24, 1, 80), C.Steel, Enum.Material.Metal)
	Kit.box(duct, "DuctSide", Vector3.new(-132, 0, 324), Vector3.new(2, 9, 80), C.Steel, Enum.Material.Metal)
	Kit.box(duct, "DuctSide", Vector3.new(-110, 0, 324), Vector3.new(2, 9, 80), C.Steel, Enum.Material.Metal)
	Kit.box(duct, "DuctEnd", Vector3.new(-132, 0, 404), Vector3.new(24, 9, 2), C.Steel, Enum.Material.Metal)
	local notebook = Kit.box(
		duct,
		"Notebook",
		Vector3.new(-125, 0, 385),
		Vector3.new(8, 0.6, 6),
		Color3.fromRGB(200, 60, 60),
		Enum.Material.Fabric
	)
	Kit.light(notebook, Color3.fromRGB(255, 200, 150), 10, 0.6)
	Kit.discovery(duct, "ForgottenVent", Vector3.new(-120, 4.5, 380), Vector3.new(18, 8, 40))
	Kit.collectible(duct, "MemoryFragment", "Bedroom", Vector3.new(-118, 0, 395))

	-- Painting cavity (living-room side of the bedroom wall).
	local cavity = Kit.model(root, "PaintingCavity")
	Kit.box(cavity, "CavityFloor", Vector3.new(2, 60, 233), Vector3.new(12, 2, 44), C.DarkWood, Enum.Material.Wood)
	Kit.box(cavity, "CavityBack", Vector3.new(14, 60, 233), Vector3.new(2, 36, 44), C.DarkWood, Enum.Material.Wood)
	Kit.box(cavity, "CavityTop", Vector3.new(2, 94, 233), Vector3.new(14, 2, 44), C.DarkWood, Enum.Material.Wood)
	Kit.box(cavity, "CavitySide", Vector3.new(2, 62, 231), Vector3.new(12, 32, 2), C.DarkWood, Enum.Material.Wood)
	Kit.box(cavity, "CavitySide", Vector3.new(2, 62, 277), Vector3.new(12, 32, 2), C.DarkWood, Enum.Material.Wood)
	Kit.box(
		cavity,
		"Safe",
		Vector3.new(6, 62, 250),
		Vector3.new(7, 7, 8),
		Color3.fromRGB(60, 60, 70),
		Enum.Material.DiamondPlate
	)
	Kit.discovery(cavity, "BehindThePainting", Vector3.new(6, 76, 255), Vector3.new(12, 30, 40))
	Kit.collectible(cavity, "SecretStar", "Bedroom", Vector3.new(8, 69, 262))
end

return House
