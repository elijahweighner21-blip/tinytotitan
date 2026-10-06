--!strict
--[[
	Kit
	Geometry + gameplay-marker helpers for the procedural world.

	The world is a PROTOTYPE built from primitives so the game is fully
	playable out of the box; every region builder documents what its final
	art should be. Gameplay never depends on specific meshes — only on the
	tagged markers this kit creates:

	  Tag                 Attributes                         Consumed by
	  ------------------  ---------------------------------  ------------------------
	  Collectible         CollectibleId, Type, Zone, Hidden  CollectibleService
	  DiscoveryRegion     DiscoveryId                        DiscoveryService
	  FastTravelStation   StationId                          FastTravelService
	  Station             Menu, Label                        InteractionService (client opens menu)
	  Gate                RequiredTier, Message              client collision + ZoneService
	  Interactable        ObjectType, InteractId             InteractionService
	  NPCSpawn            NPCId                              NPCService
	  EnemySpawner        EnemyId, Count, Radius             EnemyService
	  BossArena           BossId, Radius                     BossService
	  Hazard              Damage                             HazardService
	  LockedDoor          KeyItem, Message                   InteractionService
	  Challenge*          ChallengeId, Index                 ChallengeService
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectibleConfig = require(Shared.Config.CollectibleConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local InteractableConfig = require(Shared.Config.InteractableConfig)
local BossConfig = require(Shared.Config.BossConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)

local Kit = {}

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame?,
	Position: Vector3?,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	CastShadow: boolean?,
	Reflectance: number?,
	Shape: Enum.PartType?,
}

local partCount = 0
local collectibleCounters: { [string]: number } = {}
local interactCounter = 0

Kit.Colors = {
	Wood = Color3.fromRGB(160, 110, 70),
	DarkWood = Color3.fromRGB(105, 70, 45),
	LightWood = Color3.fromRGB(205, 165, 115),
	Wall = Color3.fromRGB(232, 226, 214),
	Ceiling = Color3.fromRGB(245, 243, 238),
	Carpet = Color3.fromRGB(150, 135, 120),
	Rug = Color3.fromRGB(150, 70, 60),
	Tile = Color3.fromRGB(225, 225, 220),
	Counter = Color3.fromRGB(70, 75, 85),
	Steel = Color3.fromRGB(190, 195, 200),
	Grass = Color3.fromRGB(90, 150, 70),
	DarkGrass = Color3.fromRGB(60, 115, 50),
	Dirt = Color3.fromRGB(120, 90, 60),
	Asphalt = Color3.fromRGB(55, 58, 62),
	Concrete = Color3.fromRGB(165, 165, 160),
	Brick = Color3.fromRGB(160, 80, 60),
	Glass = Color3.fromRGB(160, 200, 230),
	Gold = Color3.fromRGB(240, 190, 70),
	TitanStone = Color3.fromRGB(215, 190, 140),
	Rock = Color3.fromRGB(120, 115, 110),
	Snow = Color3.fromRGB(240, 245, 250),
	Crystal = Color3.fromRGB(150, 120, 255),
	Water = Color3.fromRGB(80, 150, 220),
	Neon = Color3.fromRGB(120, 220, 255),
}

function Kit.partCount(): number
	return partCount
end

function Kit.part(parent: Instance, props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Anchored = true
	p.Size = Vector3.new(
		math.clamp(props.Size.X, 0.05, 2048),
		math.clamp(props.Size.Y, 0.05, 2048),
		math.clamp(props.Size.Z, 0.05, 2048)
	)
	if props.Shape then
		p.Shape = props.Shape
	end
	if props.CFrame then
		p.CFrame = props.CFrame
	elseif props.Position then
		p.Position = props.Position
	end
	p.Color = props.Color or Color3.fromRGB(200, 200, 200)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.CanQuery = if props.CanQuery == nil then true else props.CanQuery
	p.CanTouch = if props.CanTouch == nil then false else props.CanTouch
	p.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	p.Reflectance = props.Reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	partCount += 1
	return p
end

-- Axis-aligned block from its MIN corner (x, y, z) and size: matches how the
-- region layouts are written ("a desk from x=-150..-60").
function Kit.box(parent: Instance, name: string, min: Vector3, size: Vector3, color: Color3?, material: Enum.Material?): Part
	return Kit.part(parent, {
		Name = name,
		Size = size,
		Position = min + size / 2,
		Color = color,
		Material = material,
	})
end

-- Block centered at `center`.
function Kit.block(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3?, material: Enum.Material?): Part
	return Kit.part(parent, { Name = name, Size = size, Position = center, Color = color, Material = material })
end

function Kit.wedge(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: Color3?, material: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = color or Color3.fromRGB(200, 200, 200)
	w.Material = material or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.CanTouch = false
	w.Parent = parent
	partCount += 1
	return w
end

-- A walkable ramp from `bottom` (ground point) to `top` (ground point at the
-- higher end), `width` wide.
function Kit.ramp(parent: Instance, name: string, bottom: Vector3, top: Vector3, width: number, color: Color3?, material: Enum.Material?): Part
	local flat = Vector3.new(top.X - bottom.X, 0, top.Z - bottom.Z)
	local length = (top - bottom).Magnitude
	local mid = (top + bottom) / 2
	local look = CFrame.lookAt(mid, mid + (top - bottom).Unit)
	local thickness = math.max(0.4, width * 0.08)
	local part = Kit.part(parent, {
		Name = name,
		Size = Vector3.new(width, thickness, length),
		CFrame = look * CFrame.new(0, -thickness / 2, 0),
		Color = color,
		Material = material,
	})
	local _ = flat
	return part
end

-- Cylinder whose axis runs from `a` to `b`.
function Kit.rod(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3?, material: Enum.Material?): Part
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	return Kit.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material,
	})
end

-- Upright cylinder (disc / pillar) standing on `base`.
function Kit.pillar(parent: Instance, name: string, base: Vector3, height: number, diameter: number, color: Color3?, material: Enum.Material?): Part
	return Kit.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

function Kit.ball(parent: Instance, name: string, center: Vector3, diameter: number, color: Color3?, material: Enum.Material?): Part
	return Kit.part(parent, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Position = center,
		Color = color,
		Material = material,
	})
end

function Kit.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.model(parent: Instance, name: string, persistent: boolean?): Model
	local m = Instance.new("Model")
	m.Name = name
	if persistent then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	m.Parent = parent
	return m
end

function Kit.tag(instance: Instance, tag: string, attributes: { [string]: any }?)
	if attributes then
		for k, v in attributes do
			instance:SetAttribute(k, v)
		end
	end
	CollectionService:AddTag(instance, tag)
end

-- Invisible, non-colliding marker volume.
function Kit.region(parent: Instance, name: string, center: Vector3, size: Vector3): Part
	return Kit.part(parent, {
		Name = name,
		Size = size,
		Position = center,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
end

------------------------------------------------------------------ zones

-- Representative player scale for a zone (lowest recommended tier) — used to
-- size collectibles, markers and gaps so they suit the intended players.
function Kit.zoneScale(zoneId: string): number
	local zone = ZoneConfig.get(zoneId)
	if not zone then
		return 1
	end
	return SizeConfig.getTier(zone.RecommendedTiers[1]).Scale
end

function Kit.zoneHeight(zoneId: string): number
	return ScaleMath.height(Kit.zoneScale(zoneId))
end

------------------------------------------------------------------ gameplay markers

function Kit.discovery(parent: Instance, id: string, center: Vector3, size: Vector3): Part
	local r = Kit.region(parent, "Discovery_" .. id, center, size)
	Kit.tag(r, "DiscoveryRegion", { DiscoveryId = id })
	return r
end

local SHAPES = {
	Orb = Enum.PartType.Ball,
	Coin = Enum.PartType.Cylinder,
	Star = Enum.PartType.Ball,
}

-- Places a collectible. Ids are stable as long as placement order is stable.
function Kit.collectible(parent: Instance, typeId: string, zoneId: string, position: Vector3, sizeOverride: number?): Part?
	local def = CollectibleConfig.get(typeId)
	if not def then
		warn("[Kit] unknown collectible type", typeId)
		return nil
	end
	local key = zoneId .. "_" .. typeId
	collectibleCounters[key] = (collectibleCounters[key] or 0) + 1
	local id = key .. "_" .. collectibleCounters[key]
	local size = sizeOverride or Kit.zoneHeight(zoneId) * def.Size
	local shape = SHAPES[def.Shape]
	local dims = if def.Shape == "Coin"
		then Vector3.new(size * 0.18, size, size)
		elseif def.Shape == "Shard" or def.Shape == "Crystal"
		then Vector3.new(size * 0.45, size * 1.1, size * 0.45)
		elseif def.Shape == "Relic" or def.Shape == "Toy" or def.Shape == "Fragment"
		then Vector3.new(size * 0.8, size * 0.8, size * 0.8)
		else Vector3.new(size, size, size)
	local p = Kit.part(parent, {
		Name = id,
		Size = dims,
		Position = position + Vector3.new(0, dims.Y / 2 + size * 0.15, 0),
		Shape = shape,
		Color = def.Color,
		Material = if def.Shape == "Coin" then Enum.Material.Metal else Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Transparency = if def.Hidden then 0.6 else 0,
	})
	if def.Shape == "Coin" then
		p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(90), 0, 0)
	elseif def.Shape == "Shard" or def.Shape == "Crystal" or def.Shape == "Fragment" then
		p.CFrame = CFrame.new(p.Position) * CFrame.Angles(math.rad(15), math.rad(30), math.rad(20))
	end
	Kit.tag(p, "Collectible", { CollectibleId = id, Type = typeId, Zone = zoneId, Hidden = def.Hidden == true })
	return p
end

function Kit.orbLine(parent: Instance, zoneId: string, from: Vector3, to: Vector3, count: number, typeId: string?)
	for i = 0, count - 1 do
		local t = if count == 1 then 0.5 else i / (count - 1)
		Kit.collectible(parent, typeId or "GrowthOrb", zoneId, from:Lerp(to, t))
	end
end

function Kit.orbRing(parent: Instance, zoneId: string, center: Vector3, radius: number, count: number, typeId: string?)
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		Kit.collectible(parent, typeId or "GrowthOrb", zoneId, center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
	end
end

function Kit.station(parent: Instance, menu: string, label: string, position: Vector3, scale: number, color: Color3?): Model
	local m = Kit.model(parent, "Station_" .. menu)
	local h = ScaleMath.height(scale)
	local base = Kit.pillar(m, "Base", position, h * 0.25, h * 1.4, Color3.fromRGB(40, 45, 60), Enum.Material.Metal)
	local core = Kit.ball(m, "Core", position + Vector3.new(0, h * 0.7, 0), h * 0.45, color or Kit.Colors.Neon, Enum.Material.Neon)
	core.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = core.Color
	light.Range = math.clamp(h * 3, 4, 60)
	light.Brightness = 1.5
	light.Parent = core
	m.PrimaryPart = base
	Kit.tag(base, "Station", { Menu = menu, Label = label })
	return m
end

function Kit.fastTravel(parent: Instance, zoneId: string, position: Vector3, scale: number): Part
	local h = ScaleMath.height(scale)
	local pad = Kit.pillar(parent, "FastTravel_" .. zoneId, position, h * 0.08, h * 2.4, Color3.fromRGB(60, 200, 255), Enum.Material.Neon)
	pad.Transparency = 0.2
	pad.CanCollide = true
	local ring = Kit.pillar(parent, "FastTravelRing_" .. zoneId, position + Vector3.new(0, h * 1.6, 0), h * 0.06, h * 2.2, Color3.fromRGB(150, 230, 255), Enum.Material.Neon)
	ring.CanCollide = false
	ring.Transparency = 0.5
	Kit.tag(pad, "FastTravelStation", { StationId = zoneId })
	return pad
end

-- A size gate: a shimmering barrier the client makes passable once the player
-- reaches RequiredTier. `size`/`center` describe the doorway it fills.
function Kit.gate(parent: Instance, name: string, center: Vector3, size: Vector3, requiredTier: number, message: string?): Part
	local tier = SizeConfig.getTier(requiredTier)
	local g = Kit.part(parent, {
		Name = "Gate_" .. name,
		Size = size,
		Position = center,
		Color = tier.Color,
		Material = Enum.Material.ForceField,
		Transparency = 0.35,
		CastShadow = false,
	})
	Kit.tag(g, "Gate", { RequiredTier = requiredTier, Message = message or ("Requires: " .. tier.Name) })
	return g
end

function Kit.npc(parent: Instance, npcId: string, position: Vector3, facing: Vector3?)
	local marker = Kit.region(parent, "NPC_" .. npcId, position, Vector3.new(1, 1, 1))
	local look = facing or Vector3.new(0, 0, 1)
	marker.CFrame = CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z))
	Kit.tag(marker, "NPCSpawn", { NPCId = npcId })
end

function Kit.enemySpawner(parent: Instance, enemyId: string, position: Vector3, count: number, radius: number)
	local marker = Kit.region(parent, "Spawner_" .. enemyId, position, Vector3.new(1, 1, 1))
	Kit.tag(marker, "EnemySpawner", { EnemyId = enemyId, Count = count, Radius = radius })
end

-- Arena radius comes from BossConfig (ArenaRadius × boss height) so the
-- placement and the server's arena checks can never disagree.
function Kit.bossArena(parent: Instance, bossId: string, center: Vector3)
	local def = BossConfig.get(bossId)
	if not def then
		warn("[Kit] unknown boss", bossId)
		return
	end
	local radius = def.ArenaRadius * ScaleMath.height(def.Scale)
	local marker = Kit.region(parent, "BossArena_" .. bossId, center, Vector3.new(1, 1, 1))
	Kit.tag(marker, "BossArena", { BossId = bossId, Radius = radius })
	-- Visible arena ring so players know where the fight is.
	local ring = Kit.pillar(parent, "ArenaRing_" .. bossId, center - Vector3.new(0, 0.02, 0), math.max(0.05, radius * 0.004), radius * 2, Color3.fromRGB(255, 80, 80), Enum.Material.Neon)
	ring.Transparency = 0.85
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
end

function Kit.interactable(parent: Instance, objectType: string, cframe: CFrame, size: Vector3, color: Color3?, material: Enum.Material?, shape: Enum.PartType?): Part?
	if not InteractableConfig.get(objectType) then
		warn("[Kit] unknown interactable", objectType)
		return nil
	end
	interactCounter += 1
	local p = Kit.part(parent, {
		Name = objectType,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material,
		Shape = shape,
	})
	Kit.tag(p, "Interactable", { ObjectType = objectType, InteractId = "IO_" .. interactCounter, Home = cframe })
	return p
end

function Kit.hazard(part: BasePart, damage: number)
	Kit.tag(part, "Hazard", { Damage = damage })
end

function Kit.spawnPad(parent: Instance, zoneId: string, position: Vector3, scale: number)
	local h = ScaleMath.height(scale)
	local pad = Kit.pillar(parent, "Spawn_" .. zoneId, position - Vector3.new(0, 0.01, 0), math.max(0.05, h * 0.05), h * 3, Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	pad.Transparency = 0.6
	pad.CanCollide = false
	pad.CastShadow = false
end

-- Wall along X (fixed Z) or Z (fixed X) with rectangular openings.
-- openings: { { from, to, top, bottom? } } measured along the wall axis;
-- `top`/`bottom` are heights above `base` (bottom defaults to 0 = doorway).
function Kit.wall(
	parent: Instance,
	name: string,
	axis: "X" | "Z",
	fixed: number,
	from: number,
	to: number,
	base: number,
	height: number,
	thickness: number,
	openings: { { number } }?,
	color: Color3?,
	material: Enum.Material?
)
	local holes: { { number } } = if openings then table.clone(openings) else {}
	table.sort(holes, function(a: { number }, b: { number }): boolean
		return a[1] < b[1]
	end)
	local cursor = from
	local function segment(a: number, b: number, y0: number, y1: number)
		if b - a <= 0.01 or y1 - y0 <= 0.01 then
			return
		end
		local len = b - a
		local mid = (a + b) / 2
		local size = if axis == "X" then Vector3.new(len, y1 - y0, thickness) else Vector3.new(thickness, y1 - y0, len)
		local center = if axis == "X" then Vector3.new(mid, (y0 + y1) / 2, fixed) else Vector3.new(fixed, (y0 + y1) / 2, mid)
		-- Split anything longer than the part size limit.
		if len > 2048 then
			segment(a, mid, y0, y1)
			segment(mid, b, y0, y1)
			return
		end
		Kit.block(parent, name, center, size, color or Kit.Colors.Wall, material or Enum.Material.SmoothPlastic)
	end
	for _, hole in holes do
		segment(cursor, hole[1], base, base + height)
		segment(hole[1], hole[2], base + hole[3], base + height)
		local bottom = hole[4] or 0
		if bottom > 0 then
			segment(hole[1], hole[2], base, base + bottom)
		end
		cursor = hole[2]
	end
	segment(cursor, to, base, base + height)
end

-- Large flat ground made of <=2048 tiles. Top surface at `topY`.
function Kit.ground(parent: Instance, name: string, minX: number, minZ: number, maxX: number, maxZ: number, topY: number, thickness: number, color: Color3, material: Enum.Material)
	local step = 2000
	local x = minX
	while x < maxX do
		local w = math.min(step, maxX - x)
		local z = minZ
		while z < maxZ do
			local d = math.min(step, maxZ - z)
			Kit.box(parent, name, Vector3.new(x, topY - thickness, z), Vector3.new(w, thickness, d), color, material)
			z += d
		end
		x += w
	end
end

-- A tall tower assembled from stacked blocks (handles >2048 heights).
function Kit.tower(parent: Instance, name: string, base: Vector3, footprint: Vector2, height: number, color: Color3, material: Enum.Material): { Part }
	local parts = {}
	local remaining = height
	local y = base.Y
	while remaining > 0.01 do
		local h = math.min(2000, remaining)
		table.insert(parts, Kit.block(parent, name, Vector3.new(base.X, y + h / 2, base.Z), Vector3.new(footprint.X, h, footprint.Y), color, material))
		y += h
		remaining -= h
	end
	return parts
end

function Kit.light(part: BasePart, color: Color3, range: number, brightness: number?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.clamp(range, 2, 60)
	light.Brightness = brightness or 1
	light.Shadows = false
	light.Parent = part
end

return Kit
