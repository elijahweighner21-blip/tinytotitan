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
	colors: { Color3 },
	beadSize: number?
)
	local bs = beadSize or 0.32
	local m = Kit.model(parent, "StringLights")
	local function at(t: number): Vector3
		return from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
	end
	local steps = beads * 2
	for i = 0, steps - 1 do
		local a, b = at(i / steps), at((i + 1) / steps)
		deco(m, {
			Name = "Thread",
			Size = Vector3.new(bs * 0.2, bs * 0.2, (b - a).Magnitude),
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
			Size = Vector3.new(bs, bs, bs),
			Position = at(i / (beads + 1)) - Vector3.new(0, bs * 0.55, 0),
			Color = colors[(i - 1) % #colors + 1],
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		if i % 5 == 0 then
			Kit.light(bead, bead.Color, bs * 25, 0.7)
		end
	end
	return m
end

-- A stylised pine: trunk plus three stacked tiers. Seeded colour/shape.
function Props.pine(parent: Instance, base: Vector3, height: number, seed: number, collide: boolean?)
	local rng = Random.new(seed)
	local m = Kit.model(parent, "Pine")
	local trunk =
		Kit.pillar(m, "Trunk", base, height * 0.3, height * 0.07, Color3.fromRGB(96, 66, 46), Enum.Material.Wood)
	trunk.CanCollide = collide == true
	local green = Color3.fromRGB(rng:NextInteger(40, 62), rng:NextInteger(96, 122), rng:NextInteger(62, 80))
	local tiers = 3
	for i = 0, tiers - 1 do
		local t = i / tiers
		local w = height * (0.5 - t * 0.13) * rng:NextNumber(0.9, 1.1)
		local tier = Kit.part(m, {
			Name = "Needles",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(w, height * 0.34, w),
			CFrame = CFrame.new(base + Vector3.new(0, height * (0.32 + t * 0.24), 0))
				* CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Color = green:Lerp(Color3.fromRGB(110, 150, 90), t * 0.35),
			Material = Enum.Material.Grass,
		})
		tier.CanCollide = collide == true
	end
	local tip = Kit.part(m, {
		Name = "Tip",
		Size = Vector3.new(height * 0.16, height * 0.22, height * 0.16),
		CFrame = CFrame.new(base + Vector3.new(0, height * 0.9, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = green:Lerp(Color3.fromRGB(120, 160, 95), 0.45),
		Material = Enum.Material.Grass,
	})
	tip.CanCollide = false
	return m
end

-- A weathered boulder: two or three overlapping rounded blocks.
function Props.boulder(parent: Instance, base: Vector3, size: number, seed: number, color: Color3?)
	local rng = Random.new(seed)
	local m = Kit.model(parent, "Boulder")
	local tone = color or Color3.fromRGB(122, 118, 112)
	for i = 1, rng:NextInteger(2, 3) do
		local s = size * rng:NextNumber(0.55, 1)
		Kit.part(m, {
			Name = "Rock",
			Size = Vector3.new(s, s * rng:NextNumber(0.5, 0.8), s * rng:NextNumber(0.7, 1)),
			CFrame = CFrame.new(
				base + Vector3.new(rng:NextNumber(-0.3, 0.3) * size, s * 0.25, rng:NextNumber(-0.3, 0.3) * size)
			) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
			Color = tone:Lerp(Color3.fromRGB(90, 88, 84), rng:NextNumber(0, 0.4)),
			Material = if i == 1 then Enum.Material.Rock else Enum.Material.Slate,
		})
	end
	return m
end

-- A coffee mug standing on `base` (real size: 3.8 in tall).
function Props.mug(parent: Instance, base: Vector3, color: Color3, yaw: number?)
	local m = Kit.model(parent, "Mug")
	local h, d = 3.8 * INCH, 3.2 * INCH
	local body = Kit.pillar(m, "Body", base, h, d, color, Enum.Material.SmoothPlastic)
	body.CanCollide = true
	local coffee = Kit.pillar(
		m,
		"Coffee",
		base + Vector3.new(0, h * 0.86, 0),
		h * 0.12,
		d * 0.86,
		Color3.fromRGB(70, 42, 28),
		Enum.Material.SmoothPlastic
	)
	coffee.CanCollide = false
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw or 0, 0)
	deco(m, {
		Name = "Handle",
		Size = Vector3.new(0.5 * INCH, h * 0.6, 1.2 * INCH),
		CFrame = cf * CFrame.new(d * 0.62, h * 0.5, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	return m
end

-- A dinner plate (10.5 in), optionally with food on it.
function Props.plate(parent: Instance, base: Vector3, food: Color3?)
	local m = Kit.model(parent, "Plate")
	local plate = Kit.pillar(
		m,
		"Plate",
		base,
		0.7 * INCH,
		10.5 * INCH,
		Color3.fromRGB(246, 246, 242),
		Enum.Material.SmoothPlastic
	)
	plate.CanCollide = true
	if food then
		deco(m, {
			Name = "Food",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4 * INCH, 1.6 * INCH, 3.4 * INCH),
			Position = base + Vector3.new(0, 1 * INCH, 0),
			Color = food,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	return m
end

-- A bowl heaped with fruit.
function Props.fruitBowl(parent: Instance, base: Vector3, seed: number)
	local rng = Random.new(seed)
	local m = Kit.model(parent, "FruitBowl")
	local bowl =
		Kit.pillar(m, "Bowl", base, 3.5 * INCH, 11 * INCH, Color3.fromRGB(210, 120, 70), Enum.Material.SmoothPlastic)
	bowl.CanCollide = true
	local fruit = {
		Color3.fromRGB(230, 50, 40),
		Color3.fromRGB(250, 170, 30),
		Color3.fromRGB(130, 200, 60),
		Color3.fromRGB(250, 220, 70),
		Color3.fromRGB(160, 40, 120),
	}
	for i = 1, 7 do
		local a = i * 0.9
		local r = if i == 7 then 0 else 2.6 * INCH
		local s = rng:NextNumber(2.6, 3.3) * INCH
		deco(m, {
			Name = "Fruit",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s, s),
			Position = base
				+ Vector3.new(math.cos(a) * r, 3.4 * INCH + (if i == 7 then 1.6 * INCH else 0), math.sin(a) * r),
			Color = fruit[rng:NextInteger(1, #fruit)],
			Material = Enum.Material.SmoothPlastic,
		})
	end
	return m
end

-- A pendant lamp hanging from the ceiling at `top` down to `y`.
function Props.pendantLamp(parent: Instance, top: Vector3, y: number, shadeColor: Color3)
	local m = Kit.model(parent, "Pendant")
	local cordLen = top.Y - y
	deco(m, {
		Name = "Cord",
		Size = Vector3.new(0.4, cordLen, 0.4),
		Position = Vector3.new(top.X, y + cordLen / 2, top.Z),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
	})
	deco(m, {
		Name = "Shade",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(16, 9, 16),
		Position = Vector3.new(top.X, y, top.Z),
		Color = shadeColor,
		Material = Enum.Material.Metal,
	})
	local bulb = deco(m, {
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Position = Vector3.new(top.X, y - 3.5, top.Z),
		Color = Color3.fromRGB(255, 240, 210),
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	Kit.light(bulb, Color3.fromRGB(255, 226, 185), 60, 1.6)
	return m
end

-- Grout lines for a tiled floor/wall: a grid of thin lines every `tile`.
function Props.tileGrid(
	parent: Instance,
	minX: number,
	minZ: number,
	maxX: number,
	maxZ: number,
	y: number,
	tile: number,
	color: Color3
)
	local x = minX + tile
	while x < maxX do
		deco(parent, {
			Name = "Grout",
			Size = Vector3.new(0.25, 0.02, maxZ - minZ),
			Position = Vector3.new(x, y + 0.01, (minZ + maxZ) / 2),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
		})
		x += tile
	end
	local z = minZ + tile
	while z < maxZ do
		deco(parent, {
			Name = "Grout",
			Size = Vector3.new(maxX - minX, 0.02, 0.25),
			Position = Vector3.new((minX + maxX) / 2, y + 0.01, z),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
		})
		z += tile
	end
end

-- A poster: a printed sheet with a bold graphic and a title.
function Props.poster(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	bg: Color3,
	accent: Color3,
	title: string
)
	local sheet = deco(parent, {
		Name = "Poster",
		Size = Vector3.new(width, height, 0.15),
		CFrame = cf * CFrame.new(0, 0, -0.08),
		Color = bg,
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(300, 300 * height / width)
	gui.LightInfluence = 1
	gui.Parent = sheet
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.42)
	circle.Size = UDim2.fromScale(0.62, 0.62 * width / height)
	circle.BackgroundColor3 = accent
	circle.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.08, 0.8)
	label.Size = UDim2.fromScale(0.84, 0.13)
	label.TextScaled = true
	label.Text = title
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.Parent = gui
	return sheet
end

-- A pencil lying on the floor (7.5 in): body, wood tip, graphite, eraser.
function Props.pencil(parent: Instance, base: Vector3, yaw: number, color: Color3?)
	local m = Kit.model(parent, "Pencil")
	local d = 0.3 * INCH
	local cf = CFrame.new(base + Vector3.new(0, d / 2, 0)) * CFrame.Angles(0, yaw, 0)
	local body = Kit.part(m, {
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6.4 * INCH, d, d),
		CFrame = cf,
		Color = color or Color3.fromRGB(250, 200, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	body.CanCollide = true
	deco(m, {
		Name = "Tip",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8 * INCH, d * 0.7, d * 0.7),
		CFrame = cf * CFrame.new(3.6 * INCH, 0, 0),
		Color = Color3.fromRGB(230, 200, 160),
		Material = Enum.Material.Wood,
	})
	deco(m, {
		Name = "Graphite",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3 * INCH, d * 0.3, d * 0.3),
		CFrame = cf * CFrame.new(4.1 * INCH, 0, 0),
		Color = Color3.fromRGB(50, 50, 55),
		Material = Enum.Material.Slate,
	})
	deco(m, {
		Name = "Ferrule",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5 * INCH, d * 1.05, d * 1.05),
		CFrame = cf * CFrame.new(-3.4 * INCH, 0, 0),
		Color = Color3.fromRGB(200, 200, 205),
		Material = Enum.Material.Metal,
	})
	deco(m, {
		Name = "Eraser",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6 * INCH, d, d),
		CFrame = cf * CFrame.new(-3.9 * INCH, 0, 0),
		Color = Color3.fromRGB(240, 130, 150),
		Material = Enum.Material.Rubber,
	})
	return m
end

-- A loose sheet of paper on the floor (8.5 x 11 in), with ruled lines.
function Props.paper(parent: Instance, base: Vector3, yaw: number)
	local m = Kit.model(parent, "Paper")
	local cf = CFrame.new(base + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, yaw, 0)
	deco(m, {
		Name = "Sheet",
		Size = Vector3.new(8.5 * INCH, 0.05, 11 * INCH),
		CFrame = cf,
		Color = Color3.fromRGB(250, 250, 246),
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
	})
	for i = 1, 8 do
		deco(m, {
			Name = "Rule",
			Size = Vector3.new(7.5 * INCH, 0.06, 0.1),
			CFrame = cf * CFrame.new(0, 0.01, -4.5 * INCH + i * 1.1 * INCH),
			Color = Color3.fromRGB(140, 180, 230),
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
		})
	end
	return m
end

-- A sneaker on the floor (11 in long).
function Props.sneaker(parent: Instance, base: Vector3, yaw: number, color: Color3)
	local m = Kit.model(parent, "Sneaker")
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local sole = Kit.part(m, {
		Name = "Sole",
		Size = Vector3.new(4 * INCH, 1.1 * INCH, 11 * INCH),
		CFrame = cf * CFrame.new(0, 0.55 * INCH, 0),
		Color = Color3.fromRGB(245, 245, 240),
		Material = Enum.Material.Rubber,
	})
	sole.CanCollide = true
	local upper = Kit.part(m, {
		Name = "Upper",
		Size = Vector3.new(3.6 * INCH, 2.6 * INCH, 7 * INCH),
		CFrame = cf * CFrame.new(0, 2.3 * INCH, 1.6 * INCH),
		Color = color,
		Material = Enum.Material.Fabric,
	})
	upper.CanCollide = true
	local toe = Kit.part(m, {
		Name = "Toe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.6 * INCH, 2.4 * INCH, 5 * INCH),
		CFrame = cf * CFrame.new(0, 1.6 * INCH, -3 * INCH),
		Color = color,
		Material = Enum.Material.Fabric,
	})
	toe.CanCollide = true
	deco(m, {
		Name = "Swoosh",
		Size = Vector3.new(3.7 * INCH, 0.5 * INCH, 4 * INCH),
		CFrame = cf * CFrame.new(0, 2 * INCH, 0.8 * INCH),
		Color = Color3.fromRGB(250, 250, 250),
		Material = Enum.Material.SmoothPlastic,
	})
	return m
end

-- A heap of clothes: a few soft folded/slumped layers.
function Props.clothes(parent: Instance, base: Vector3, seed: number)
	local rng = Random.new(seed)
	local m = Kit.model(parent, "Clothes")
	local colors = {
		Color3.fromRGB(70, 90, 140),
		Color3.fromRGB(200, 70, 70),
		Color3.fromRGB(230, 225, 215),
		Color3.fromRGB(60, 60, 65),
		Color3.fromRGB(120, 170, 120),
	}
	for i = 1, 4 do
		local w = rng:NextNumber(14, 22) * INCH
		local c = Kit.part(m, {
			Name = "Cloth",
			Size = Vector3.new(w, rng:NextNumber(1.2, 2.4) * INCH, w * rng:NextNumber(0.6, 0.9)),
			CFrame = CFrame.new(
				base + Vector3.new(rng:NextNumber(-4, 4) * INCH, (i - 0.5) * 1.6 * INCH, rng:NextNumber(-4, 4) * INCH)
			) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6), rng:NextNumber(-0.12, 0.12)),
			Color = colors[rng:NextInteger(1, #colors)],
			Material = Enum.Material.Fabric,
		})
		c.CanCollide = true
	end
	return m
end

-- A leafy broadleaf tree: trunk, two branches and a clustered crown of
-- overlapping canopy balls in varied greens. `height` = total height.
function Props.tree(parent: Instance, base: Vector3, height: number, seed: number)
	local rng = Random.new(seed)
	local m = Kit.model(parent, "Tree")
	local bark = Color3.fromRGB(rng:NextInteger(92, 112), rng:NextInteger(68, 80), rng:NextInteger(48, 56))
	local trunk = Kit.pillar(m, "Trunk", base, height * 0.55, height * 0.09, bark, Enum.Material.Wood)
	trunk.CanCollide = true
	for i = 1, 2 do
		local a = rng:NextNumber(0, 6) + i * 3
		local len = height * 0.28
		Kit.part(m, {
			Name = "Branch",
			Size = Vector3.new(height * 0.045, len, height * 0.045),
			CFrame = CFrame.new(base + Vector3.new(0, height * (0.42 + i * 0.06), 0))
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(math.rad(42), 0, 0)
				* CFrame.new(0, len / 2, 0),
			Color = bark,
			Material = Enum.Material.Wood,
		}).CanCollide =
			false
	end
	local hue = Color3.fromRGB(rng:NextInteger(66, 104), rng:NextInteger(132, 168), rng:NextInteger(62, 84))
	local crownY = height * 0.68
	for i = 1, rng:NextInteger(5, 7) do
		local s = height * rng:NextNumber(0.34, 0.5)
		local a = i * 1.3 + rng:NextNumber(-0.3, 0.3)
		local r = if i == 1 then 0 else height * rng:NextNumber(0.14, 0.24)
		Kit.part(m, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s * 0.85, s),
			Position = base
				+ Vector3.new(math.cos(a) * r, crownY + rng:NextNumber(-0.06, 0.12) * height, math.sin(a) * r),
			Color = hue:Lerp(Color3.fromRGB(150, 190, 90), rng:NextNumber(0, 0.3)),
			Material = Enum.Material.Grass,
		}).CanCollide =
			false
	end
	return m
end

return Props
