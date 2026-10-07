--!strict
--[[
	Props
	Reusable set dressing built from primitives at REAL scale (1 inch ≈ 1.1
	studs), so the same everyday object is a cliff when you're tiny and a
	pebble when you're a titan. Each helper takes a seed where variation
	matters, so repeated props never look copy-pasted.

	Decor is anchored, mostly non-colliding and shadow-casting only where it
	reads; nothing here is gameplay.
]]

local Kit = require(script.Parent.Kit)

local Props = {}

local INCH = 13.3 / 12

local function deco(parent: Instance, props: Kit.PartProps): Part
	local p = Kit.part(parent, props)
	p.CanCollide = if props.CanCollide == nil then false else props.CanCollide
	p.CanQuery = false
	return p
end

-- Floorboard seams (thin dark lines) with staggered end joints: at small
-- sizes the gaps between boards are trenches, which sells the scale.
function Props.floorboards(
	parent: Instance,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	y: number,
	boardWidth: number,
	color: Color3,
	seed: number
)
	local rng = Random.new(seed)
	local x = minX + boardWidth
	while x < maxX - 0.5 do
		deco(parent, {
			Name = "BoardSeam",
			Size = Vector3.new(0.22, 0.02, maxZ - minZ),
			Position = Vector3.new(x, y + 0.01, (minZ + maxZ) / 2),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
		})
		-- End joints between boards in this row.
		local z = minZ + rng:NextNumber(10, 60)
		while z < maxZ - 4 do
			deco(parent, {
				Name = "BoardJoint",
				Size = Vector3.new(boardWidth, 0.02, 0.22),
				Position = Vector3.new(x - boardWidth / 2, y + 0.01, z),
				Color = color,
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			})
			z += rng:NextNumber(40, 90)
		end
		x += boardWidth
	end
end

-- A framed painting hung on a wall. `cf` is the centre of the canvas with
-- LookVector pointing out of the wall into the room.
function Props.painting(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	palette: { Color3 },
	seed: number,
	frameColor: Color3?
)
	local rng = Random.new(seed)
	local m = Kit.model(parent, "Painting")
	local frame = frameColor or Color3.fromRGB(176, 136, 72)
	local border = math.max(width, height) * 0.06
	deco(m, {
		Name = "Frame",
		Size = Vector3.new(width + border * 2, height + border * 2, border * 0.8),
		CFrame = cf * CFrame.new(0, 0, border * 0.2),
		Color = frame,
		Material = Enum.Material.Wood,
	})
	deco(m, {
		Name = "Canvas",
		Size = Vector3.new(width, height, border * 0.3),
		CFrame = cf * CFrame.new(0, 0, -border * 0.3),
		Color = palette[1],
		Material = Enum.Material.Fabric,
		CastShadow = false,
	})
	-- Abstract composition: a horizon band and a few soft shapes.
	deco(m, {
		Name = "Paint",
		Size = Vector3.new(width, height * rng:NextNumber(0.3, 0.45), border * 0.32),
		CFrame = cf * CFrame.new(0, -height * 0.3, -border * 0.32),
		Color = palette[2],
		Material = Enum.Material.Fabric,
		CastShadow = false,
	})
	for i = 3, #palette do
		local s = math.min(width, height) * rng:NextNumber(0.18, 0.32)
		deco(m, {
			Name = "Paint",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(border * 0.34, s, s),
			CFrame = cf
				* CFrame.new(rng:NextNumber(-0.35, 0.35) * width, rng:NextNumber(-0.05, 0.3) * height, -border * 0.34)
				* CFrame.Angles(0, math.rad(90), 0),
			Color = palette[i],
			Material = Enum.Material.Fabric,
			CastShadow = false,
		})
	end
end

-- A wall power outlet (real size), optionally with a charger plugged in.
-- `cf`: on the wall surface at the plate centre, LookVector into the room.
function Props.outlet(parent: Instance, cf: CFrame, withCharger: boolean?)
	local m = Kit.model(parent, "Outlet")
	local plate = Color3.fromRGB(246, 244, 238)
	deco(m, {
		Name = "Plate",
		Size = Vector3.new(2.8 * INCH, 4.5 * INCH, 0.25 * INCH),
		CFrame = cf * CFrame.new(0, 0, -0.12 * INCH),
		Color = plate,
		Material = Enum.Material.SmoothPlastic,
	})
	for _, dy in { 1, -1 } do
		local socket = cf * CFrame.new(0, dy * 0.75 * INCH, -0.3 * INCH)
		deco(m, {
			Name = "Socket",
			Size = Vector3.new(1.4 * INCH, 1.2 * INCH, 0.12 * INCH),
			CFrame = socket,
			Color = Color3.fromRGB(236, 233, 226),
			Material = Enum.Material.SmoothPlastic,
		})
		for _, dx in { -0.25, 0.25 } do
			deco(m, {
				Name = "Slot",
				Size = Vector3.new(0.1 * INCH, 0.4 * INCH, 0.06 * INCH),
				CFrame = socket * CFrame.new(dx * INCH, 0.1 * INCH, -0.07 * INCH),
				Color = Color3.fromRGB(40, 40, 44),
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
			})
		end
	end
	if withCharger then
		local plug = cf * CFrame.new(0, -0.75 * INCH, -0.9 * INCH)
		deco(m, {
			Name = "Charger",
			Size = Vector3.new(1.5 * INCH, 1.5 * INCH, 1.2 * INCH),
			CFrame = plug,
			Color = Color3.fromRGB(250, 250, 252),
			Material = Enum.Material.SmoothPlastic,
		})
		local led = deco(m, {
			Name = "ChargerLed",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.18 * INCH, 0.18 * INCH, 0.18 * INCH),
			CFrame = plug * CFrame.new(0.45 * INCH, 0.45 * INCH, -0.6 * INCH),
			Color = Color3.fromRGB(90, 255, 140),
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		Kit.light(led, Color3.fromRGB(90, 255, 140), 6, 0.6)
	end
end

-- A potted house plant with seeded leaf variation. `height` = total height.
function Props.plant(parent: Instance, base: Vector3, height: number, seed: number, potColor: Color3?)
	local rng = Random.new(seed)
	local m = Kit.model(parent, "Plant")
	local potH = height * 0.32
	local potD = height * 0.34
	local pot = Kit.pillar(m, "Pot", base, potH, potD, potColor or Color3.fromRGB(196, 110, 74), Enum.Material.Slate)
	pot.CanCollide = true
	local rim = Kit.pillar(
		m,
		"PotRim",
		base + Vector3.new(0, potH * 0.86, 0),
		potH * 0.16,
		potD * 1.08,
		(potColor or Color3.fromRGB(196, 110, 74)):Lerp(Color3.new(1, 1, 1), 0.12),
		Enum.Material.Slate
	)
	rim.CanCollide = false
	local soil = Kit.pillar(
		m,
		"Soil",
		base + Vector3.new(0, potH * 0.97, 0),
		potH * 0.04,
		potD * 0.95,
		Color3.fromRGB(70, 50, 36),
		Enum.Material.Ground
	)
	soil.CanCollide = false
	local top = base + Vector3.new(0, potH, 0)
	local leafCount = rng:NextInteger(9, 14)
	for i = 1, leafCount do
		local yaw = (i / leafCount) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local tilt = rng:NextNumber(0.35, 1.0)
		local len = height * rng:NextNumber(0.42, 0.68)
		local green = Color3.fromRGB(rng:NextInteger(50, 80), rng:NextInteger(130, 170), rng:NextInteger(60, 90))
		deco(m, {
			Name = "Leaf",
			Size = Vector3.new(len * 0.28, len, len * 0.04),
			CFrame = CFrame.new(top)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(tilt, 0, 0)
				* CFrame.new(0, len * 0.5, 0),
			Color = green,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	return m
end

-- A floor lamp: weighted base, thin pole, glowing fabric shade and a warm
-- light (placed at shade height, so it lights the floor around it).
function Props.floorLamp(parent: Instance, base: Vector3, height: number, shadeColor: Color3?)
	local m = Kit.model(parent, "FloorLamp")
	local metal = Color3.fromRGB(60, 58, 56)
	local foot = Kit.pillar(m, "Foot", base, height * 0.02, height * 0.2, metal, Enum.Material.Metal)
	foot.CanCollide = true
	local pole = Kit.pillar(m, "Pole", base, height * 0.88, height * 0.018, metal, Enum.Material.Metal)
	pole.CanCollide = true
	local shade = Kit.pillar(
		m,
		"Shade",
		base + Vector3.new(0, height * 0.8, 0),
		height * 0.2,
		height * 0.26,
		shadeColor or Color3.fromRGB(250, 236, 210),
		Enum.Material.Fabric
	)
	shade.CanCollide = false
	local bulb = Kit.ball(
		m,
		"Bulb",
		base + Vector3.new(0, height * 0.86, 0),
		height * 0.05,
		Color3.fromRGB(255, 236, 200),
		Enum.Material.Neon
	)
	bulb.CanCollide = false
	Kit.light(bulb, Color3.fromRGB(255, 214, 165), 60, 1.6)
	return m
end

-- A push pin (used as a lamp post at tiny scale).
function Props.pushPin(parent: Instance, base: Vector3, color: Color3): Vector3
	local head = 0.45 * INCH
	local pin = Kit.pillar(
		parent,
		"PinNeedle",
		base,
		0.5 * INCH,
		0.05 * INCH,
		Color3.fromRGB(200, 200, 205),
		Enum.Material.Metal
	)
	pin.CanCollide = false
	local cap = Kit.pillar(
		parent,
		"PinHead",
		base + Vector3.new(0, 0.5 * INCH, 0),
		head,
		0.4 * INCH,
		color,
		Enum.Material.Glass
	)
	cap.CanCollide = true
	local grip = Kit.pillar(
		parent,
		"PinGrip",
		base + Vector3.new(0, 0.5 * INCH + head, 0),
		0.1 * INCH,
		0.55 * INCH,
		color,
		Enum.Material.Glass
	)
	grip.CanCollide = false
	return base + Vector3.new(0, 0.5 * INCH + head + 0.1 * INCH, 0)
end

-- A sagging thread strung with little glowing beads.
function Props.stringLights(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	beads: number,
	sag: number,
	colors: { Color3 }
)
	local m = Kit.model(parent, "StringLights")
	local function at(t: number): Vector3
		return from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
	end
	local steps = beads * 2
	for i = 0, steps - 1 do
		local a, b = at(i / steps), at((i + 1) / steps)
		deco(m, {
			Name = "Thread",
			Size = Vector3.new(0.06, 0.06, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = Color3.fromRGB(60, 50, 45),
			Material = Enum.Material.Fabric,
			CastShadow = false,
		})
	end
	for i = 1, beads do
		local bead = deco(m, {
			Name = "Bead",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.32, 0.32, 0.32),
			Position = at(i / (beads + 1)) - Vector3.new(0, 0.18, 0),
			Color = colors[(i - 1) % #colors + 1],
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		if i % 5 == 0 then
			Kit.light(bead, bead.Color, 8, 0.7)
		end
	end
	return m
end

return Props
