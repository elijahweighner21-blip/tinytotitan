--!strict
--[[
	CreatureBuilder
	Procedural enemy / boss bodies. Every creature is a Model whose
	PrimaryPart "Root" is an invisible box (the physics body moved by
	AlignPosition / AlignOrientation) with decorative parts welded to it.
	Visual parts are massless, non-colliding and non-queryable so creatures
	are cheap for physics and raycasts.

	Height H = 5 × scale (same convention as player characters).

	Final art: swap in meshes by giving the model a "Visual" child and
	hiding the generated parts — the Root contract stays the same.
]]

local CreatureBuilder = {}

local function weldTo(root: BasePart, part: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = root.Parent
end

local function piece(root: BasePart, name: string, shape: Enum.PartType?, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	p.CFrame = root.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	weldTo(root, p)
	return p
end

local function ball(root: BasePart, name: string, d: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
	return piece(root, name, Enum.PartType.Ball, d, CFrame.new(offset), color, material)
end

local function box(root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	return piece(root, name, nil, size, offset, color, material)
end

local function legs(root: BasePart, H: number, count: number, length: number, color: Color3)
	for i = 1, count do
		local side = if i % 2 == 0 then 1 else -1
		local row = math.ceil(i / 2) - (count / 4) - 0.5
		local cf = CFrame.new(side * H * 0.35, -H * 0.25, row * H * 0.3) * CFrame.Angles(0, 0, side * math.rad(55))
		box(root, "Leg", Vector3.new(H * length, H * 0.06, H * 0.06), cf, color)
	end
end

local function eyes(root: BasePart, H: number, forward: number, height: number, color: Color3?)
	for _, x in { -1, 1 } do
		local e = ball(root, "Eye", Vector3.new(H * 0.12, H * 0.12, H * 0.12), Vector3.new(x * H * 0.12, height, -forward), color or Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		local _ = e
	end
end

local builders: { [string]: (root: BasePart, H: number, color: Color3) -> () } = {}

builders.Insect = function(root, H, color)
	ball(root, "Thorax", Vector3.new(H * 0.45, H * 0.4, H * 0.5), Vector3.new(0, 0, 0), color)
	ball(root, "Abdomen", Vector3.new(H * 0.55, H * 0.45, H * 0.75), Vector3.new(0, H * 0.05, H * 0.55), color)
	ball(root, "Head", Vector3.new(H * 0.4, H * 0.35, H * 0.4), Vector3.new(0, H * 0.05, -H * 0.42), color)
	eyes(root, H, H * 0.58, H * 0.12, Color3.fromRGB(20, 20, 20))
	legs(root, H, 6, 0.6, color:Lerp(Color3.new(0, 0, 0), 0.3))
end

builders.Mite = function(root, H, color)
	ball(root, "Body", Vector3.new(H * 0.8, H * 0.6, H * 0.9), Vector3.new(0, 0, 0), color, Enum.Material.Fabric)
	legs(root, H, 8, 0.45, color:Lerp(Color3.new(0, 0, 0), 0.3))
	eyes(root, H, H * 0.42, H * 0.1, Color3.fromRGB(30, 30, 30))
end

builders.Beetle = function(root, H, color)
	ball(root, "Shell", Vector3.new(H * 0.9, H * 0.55, H * 1.2), Vector3.new(0, H * 0.05, 0), color, Enum.Material.Glass)
	ball(root, "Head", Vector3.new(H * 0.45, H * 0.35, H * 0.4), Vector3.new(0, 0, -H * 0.62), color:Lerp(Color3.new(0, 0, 0), 0.4))
	box(root, "Horn", Vector3.new(H * 0.08, H * 0.08, H * 0.45), CFrame.new(0, H * 0.1, -H * 0.9) * CFrame.Angles(math.rad(-25), 0, 0), color:Lerp(Color3.new(0, 0, 0), 0.5))
	legs(root, H, 6, 0.55, color:Lerp(Color3.new(0, 0, 0), 0.5))
end

builders.Spider = function(root, H, color)
	ball(root, "Body", Vector3.new(H * 0.4, H * 0.35, H * 0.4), Vector3.new(0, 0, -H * 0.15), color)
	ball(root, "Abdomen", Vector3.new(H * 0.6, H * 0.5, H * 0.65), Vector3.new(0, H * 0.08, H * 0.35), color)
	legs(root, H, 8, 0.95, color)
	eyes(root, H, H * 0.35, H * 0.1, Color3.fromRGB(255, 50, 50))
end

local function wings(root: BasePart, H: number, color: Color3, transparency: number)
	for _, x in { -1, 1 } do
		local w = box(root, "Wing", Vector3.new(H * 0.9, H * 0.04, H * 0.55), CFrame.new(x * H * 0.55, H * 0.2, 0) * CFrame.Angles(0, 0, x * math.rad(12)), color, Enum.Material.Glass)
		w.Transparency = transparency
	end
end

builders.Moth = function(root, H, color)
	ball(root, "Body", Vector3.new(H * 0.3, H * 0.3, H * 0.8), Vector3.new(0, 0, 0), color, Enum.Material.Fabric)
	wings(root, H * 1.3, color:Lerp(Color3.new(1, 1, 1), 0.2), 0.1)
	eyes(root, H, H * 0.42, H * 0.05, Color3.fromRGB(30, 30, 30))
end

builders.Fly = function(root, H, color)
	ball(root, "Body", Vector3.new(H * 0.45, H * 0.4, H * 0.6), Vector3.new(0, 0, 0), color)
	wings(root, H, Color3.fromRGB(200, 220, 230), 0.5)
	eyes(root, H, H * 0.32, H * 0.08, Color3.fromRGB(180, 30, 30))
end

builders.Wasp = function(root, H, color)
	ball(root, "Thorax", Vector3.new(H * 0.35, H * 0.35, H * 0.4), Vector3.new(0, 0, -H * 0.1), Color3.fromRGB(30, 30, 30))
	ball(root, "Abdomen", Vector3.new(H * 0.4, H * 0.4, H * 0.7), Vector3.new(0, 0, H * 0.4), color)
	for i = 0, 2 do
		box(root, "Stripe", Vector3.new(H * 0.42, H * 0.42, H * 0.06), CFrame.new(0, 0, H * (0.25 + i * 0.15)), Color3.fromRGB(20, 20, 20))
	end
	box(root, "Stinger", Vector3.new(H * 0.05, H * 0.05, H * 0.25), CFrame.new(0, 0, H * 0.82), Color3.fromRGB(20, 20, 20))
	wings(root, H, Color3.fromRGB(220, 230, 240), 0.5)
end

builders.Roach = function(root, H, color)
	ball(root, "Body", Vector3.new(H * 0.75, H * 0.3, H * 1.3), Vector3.new(0, 0, 0), color, Enum.Material.Glass)
	box(root, "Antenna", Vector3.new(H * 0.03, H * 0.03, H * 0.9), CFrame.new(-H * 0.1, H * 0.1, -H * 1.0) * CFrame.Angles(math.rad(15), math.rad(10), 0), color)
	box(root, "Antenna", Vector3.new(H * 0.03, H * 0.03, H * 0.9), CFrame.new(H * 0.1, H * 0.1, -H * 1.0) * CFrame.Angles(math.rad(15), math.rad(-10), 0), color)
	legs(root, H, 6, 0.55, color:Lerp(Color3.new(0, 0, 0), 0.3))
end

builders.Toy = function(root, H, color)
	box(root, "Legs", Vector3.new(H * 0.35, H * 0.4, H * 0.2), CFrame.new(0, -H * 0.3, 0), Color3.fromRGB(30, 40, 80))
	box(root, "Torso", Vector3.new(H * 0.45, H * 0.4, H * 0.25), CFrame.new(0, H * 0.1, 0), color)
	ball(root, "Head", Vector3.new(H * 0.3, H * 0.3, H * 0.3), Vector3.new(0, H * 0.45, 0), Color3.fromRGB(240, 200, 170))
	box(root, "Hat", Vector3.new(H * 0.28, H * 0.25, H * 0.28), CFrame.new(0, H * 0.65, 0), Color3.fromRGB(20, 20, 30))
	box(root, "Key", Vector3.new(H * 0.05, H * 0.3, H * 0.3), CFrame.new(0, H * 0.15, H * 0.2), Color3.fromRGB(220, 190, 60), Enum.Material.Metal)
	box(root, "Rifle", Vector3.new(H * 0.06, H * 0.06, H * 0.5), CFrame.new(H * 0.28, H * 0.15, -H * 0.15), Color3.fromRGB(60, 50, 40))
end

builders.Robot = function(root, H, color)
	box(root, "Body", Vector3.new(H * 0.6, H * 0.6, H * 0.45), CFrame.new(0, 0, 0), color, Enum.Material.Metal)
	box(root, "Head", Vector3.new(H * 0.4, H * 0.3, H * 0.35), CFrame.new(0, H * 0.45, 0), color, Enum.Material.Metal)
	box(root, "Visor", Vector3.new(H * 0.32, H * 0.08, H * 0.02), CFrame.new(0, H * 0.48, -H * 0.18), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	for _, x in { -1, 1 } do
		box(root, "Arm", Vector3.new(H * 0.12, H * 0.5, H * 0.12), CFrame.new(x * H * 0.38, 0, 0), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Metal)
		box(root, "Tread", Vector3.new(H * 0.18, H * 0.2, H * 0.55), CFrame.new(x * H * 0.22, -H * 0.4, 0), Color3.fromRGB(40, 40, 40))
	end
end

builders.Frog = function(root, H, color)
	ball(root, "Body", Vector3.new(H * 0.9, H * 0.6, H * 0.9), Vector3.new(0, -H * 0.1, 0), color, Enum.Material.SmoothPlastic)
	for _, x in { -1, 1 } do
		ball(root, "EyeBulge", Vector3.new(H * 0.25, H * 0.25, H * 0.25), Vector3.new(x * H * 0.25, H * 0.22, -H * 0.25), color)
		ball(root, "Pupil", Vector3.new(H * 0.12, H * 0.12, H * 0.12), Vector3.new(x * H * 0.25, H * 0.25, -H * 0.36), Color3.fromRGB(20, 20, 20))
		box(root, "BackLeg", Vector3.new(H * 0.2, H * 0.2, H * 0.6), CFrame.new(x * H * 0.45, -H * 0.35, H * 0.2), color:Lerp(Color3.new(0, 0, 0), 0.2))
	end
end

builders.Crow = function(root, H, color)
	ball(root, "Body", Vector3.new(H * 0.5, H * 0.45, H * 0.8), Vector3.new(0, 0, 0), color)
	ball(root, "Head", Vector3.new(H * 0.3, H * 0.3, H * 0.3), Vector3.new(0, H * 0.2, -H * 0.42), color)
	box(root, "Beak", Vector3.new(H * 0.08, H * 0.08, H * 0.25), CFrame.new(0, H * 0.18, -H * 0.65), Color3.fromRGB(60, 60, 60))
	wings(root, H * 1.4, color, 0)
	eyes(root, H, H * 0.55, H * 0.25, Color3.fromRGB(240, 220, 60))
end

builders.Car = function(root, H, color)
	box(root, "Chassis", Vector3.new(H * 0.8, H * 0.35, H * 1.5), CFrame.new(0, -H * 0.15, 0), color, Enum.Material.Metal)
	box(root, "Cabin", Vector3.new(H * 0.65, H * 0.3, H * 0.7), CFrame.new(0, H * 0.15, H * 0.1), Color3.fromRGB(40, 60, 80), Enum.Material.Glass)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			piece(root, "Wheel", Enum.PartType.Cylinder, Vector3.new(H * 0.15, H * 0.35, H * 0.35), CFrame.new(x * H * 0.42, -H * 0.32, z * H * 0.5), Color3.fromRGB(20, 20, 20))
		end
	end
	box(root, "Antenna", Vector3.new(H * 0.02, H * 0.5, H * 0.02), CFrame.new(H * 0.25, H * 0.5, H * 0.5), Color3.fromRGB(30, 30, 30))
end

builders.Drone = function(root, H, color)
	piece(root, "Disc", Enum.PartType.Cylinder, Vector3.new(H * 0.2, H * 0.8, H * 0.8), CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Metal)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		piece(root, "Rotor", Enum.PartType.Cylinder, Vector3.new(H * 0.04, H * 0.4, H * 0.4), CFrame.new(math.cos(a) * H * 0.5, H * 0.1, math.sin(a) * H * 0.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 50), Enum.Material.Metal).Transparency = 0.3
	end
	ball(root, "Eye", Vector3.new(H * 0.22, H * 0.22, H * 0.22), Vector3.new(0, -H * 0.08, -H * 0.35), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
end

builders.Sentinel = function(root, H, color)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, x in { -1, 1 } do
		box(root, "Leg", Vector3.new(H * 0.16, H * 0.45, H * 0.18), CFrame.new(x * H * 0.12, -H * 0.27, 0), dark, Enum.Material.Metal)
		box(root, "Arm", Vector3.new(H * 0.14, H * 0.4, H * 0.14), CFrame.new(x * H * 0.32, H * 0.1, 0), dark, Enum.Material.Metal)
	end
	box(root, "Torso", Vector3.new(H * 0.5, H * 0.4, H * 0.28), CFrame.new(0, H * 0.15, 0), color, Enum.Material.Metal)
	box(root, "Head", Vector3.new(H * 0.25, H * 0.2, H * 0.22), CFrame.new(0, H * 0.45, 0), color, Enum.Material.Metal)
	box(root, "Visor", Vector3.new(H * 0.2, H * 0.05, H * 0.02), CFrame.new(0, H * 0.46, -H * 0.12), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
end

builders.Golem = function(root, H, color)
	local rock = color
	ball(root, "Body", Vector3.new(H * 0.7, H * 0.6, H * 0.55), Vector3.new(0, H * 0.05, 0), rock, Enum.Material.Rock)
	ball(root, "Head", Vector3.new(H * 0.3, H * 0.28, H * 0.3), Vector3.new(0, H * 0.42, -H * 0.05), rock, Enum.Material.Rock)
	for _, x in { -1, 1 } do
		ball(root, "Fist", Vector3.new(H * 0.3, H * 0.3, H * 0.3), Vector3.new(x * H * 0.45, -H * 0.1, -H * 0.1), rock:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Rock)
		box(root, "Leg", Vector3.new(H * 0.2, H * 0.35, H * 0.22), CFrame.new(x * H * 0.15, -H * 0.32, 0), rock, Enum.Material.Rock)
	end
	ball(root, "Core", Vector3.new(H * 0.12, H * 0.12, H * 0.12), Vector3.new(0, H * 0.12, -H * 0.28), Color3.fromRGB(255, 140, 60), Enum.Material.Neon)
end

-- Bosses ----------------------------------------------------------------------

builders.Vacuum = function(root, H, color)
	piece(root, "Shell", Enum.PartType.Cylinder, Vector3.new(H * 0.35, H * 1.6, H * 1.6), CFrame.new(0, -H * 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Metal)
	piece(root, "Bumper", Enum.PartType.Cylinder, Vector3.new(H * 0.2, H * 1.7, H * 1.7), CFrame.new(0, -H * 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 30, 30))
	piece(root, "TopLight", Enum.PartType.Cylinder, Vector3.new(H * 0.05, H * 0.4, H * 0.4), CFrame.new(0, -H * 0.07, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	box(root, "Intake", Vector3.new(H * 1.2, H * 0.05, H * 0.2), CFrame.new(0, -H * 0.42, -H * 0.6), Color3.fromRGB(20, 20, 20))
end

builders.Mower = function(root, H, color)
	box(root, "Deck", Vector3.new(H * 1.0, H * 0.35, H * 1.2), CFrame.new(0, -H * 0.2, 0), color, Enum.Material.Metal)
	box(root, "Engine", Vector3.new(H * 0.5, H * 0.35, H * 0.5), CFrame.new(0, H * 0.12, H * 0.1), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	box(root, "Handle", Vector3.new(H * 0.8, H * 0.06, H * 0.06), CFrame.new(0, H * 0.45, H * 0.9), Color3.fromRGB(30, 30, 30))
	for _, x in { -1, 1 } do
		box(root, "HandleBar", Vector3.new(H * 0.06, H * 0.8, H * 0.06), CFrame.new(x * H * 0.38, H * 0.1, H * 0.75) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(30, 30, 30))
		for _, z in { -1, 1 } do
			piece(root, "Wheel", Enum.PartType.Cylinder, Vector3.new(H * 0.12, H * 0.32, H * 0.32), CFrame.new(x * H * 0.52, -H * 0.34, z * H * 0.48), Color3.fromRGB(20, 20, 20))
		end
	end
end

builders.Mech = function(root, H, color)
	builders.Sentinel(root, H, color)
	for _, x in { -1, 1 } do
		box(root, "MissilePod", Vector3.new(H * 0.2, H * 0.18, H * 0.3), CFrame.new(x * H * 0.32, H * 0.42, 0), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	end
	ball(root, "Core", Vector3.new(H * 0.16, H * 0.16, H * 0.16), Vector3.new(0, H * 0.18, -H * 0.15), Color3.fromRGB(80, 200, 255), Enum.Material.Neon)
end

builders.Colossus = function(root, H, color)
	builders.Golem(root, H, color)
	for i = 0, 4 do
		local a = i / 5 * math.pi
		box(root, "Crystal", Vector3.new(H * 0.08, H * 0.35, H * 0.08), CFrame.new(math.cos(a) * H * 0.3, H * 0.4, H * 0.15) * CFrame.Angles(0, 0, math.cos(a) * 0.5), Color3.fromRGB(190, 140, 255), Enum.Material.Neon)
	end
end

function CreatureBuilder.build(name: string, shape: string, color: Color3, scale: number): Model
	local H = 5 * scale
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(H * 0.8, H, H * 0.8)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.CastShadow = false
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	local build = builders[shape] or builders.Insect
	build(root, H, color)
	return model
end

return CreatureBuilder
