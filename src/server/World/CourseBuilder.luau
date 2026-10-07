--!strict
--[[
	CourseBuilder
	Builds every challenge's "training simulation" pocket course from
	ChallengeConfig and records the authoritative layout in `Registry`, which
	ChallengeService uses for validation (the server never trusts a client
	claim of "checkpoint reached" — it checks positions against this data).

	Pockets live beyond the playable world (z > 14000, outside every zone box)
	so they never interfere with exploration or zone enforcement. Each pocket
	is sized from the intended tier's real jump distance and height, so every
	gap is jumpable by design.

	Final art: replace platform blocks with themed props (crumbs, books,
	rooftops...) keeping the same positions; the registry is unaffected.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChallengeConfig = require(Shared.Config.ChallengeConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)

local Kit = require(script.Parent.Kit)

export type CourseData = {
	Id: string,
	Kind: string,
	Body: number,
	Origin: Vector3,
	Start: Vector3, -- ground point where the run starts
	StartFacing: Vector3,
	Checkpoints: { Vector3 },
	CheckpointRadius: number,
	Finish: Vector3?,
	FinishRadius: number,
	Tokens: { Vector3 },
	Targets: { Vector3 },
	FloorY: number,
	FailY: number,
	Hazard: { BaseY: number, Speed: number, Delay: number }?, -- rising water
	LavaY: number?, -- touching below this fails
	Takeoff: { Point: Vector3, Direction: Vector3 }?,
	Bounds: number, -- radius from Origin; leaving it fails the run
	Pad: Vector3, -- world start pad position
}

local CourseBuilder = {}

CourseBuilder.Registry = {} :: { [string]: CourseData }

local POCKET_Y = 400
local POCKET_Z = 16000
local ROW_LIMIT = 15000

local function themeFor(zoneId: string): (Color3, Color3, Enum.Material)
	local zone = ZoneConfig.get(zoneId)
	local accent = if zone then zone.MapColor else Color3.fromRGB(200, 200, 200)
	return accent, Color3.fromRGB(40, 44, 58), Enum.Material.SmoothPlastic
end

local function platform(
	parent: Instance,
	name: string,
	center: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = Kit.block(parent, name, center - Vector3.new(0, size.Y / 2, 0), size, color, material)
	return p
end

local function marker(parent: Instance, tag: string, id: string, index: number, position: Vector3, radius: number)
	local r = Kit.region(parent, tag .. index, position, Vector3.new(radius, radius, radius))
	Kit.tag(r, tag, { ChallengeId = id, Index = index })
end

local function glowRing(parent: Instance, position: Vector3, radius: number, color: Color3)
	local ring =
		Kit.pillar(parent, "Ring", position, math.max(0.05, radius * 0.06), radius * 2, color, Enum.Material.Neon)
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Transparency = 0.45
	ring.CastShadow = false
end

-- Footprint radius estimate used for packing pockets.
local function estimateRadius(def: ChallengeConfig.ChallengeDef): number
	local body, _, _, jd = ChallengeConfig.physics(def.RequiredTier)
	local c = def.Course
	if c.Kind == "Tower" or c.Kind == "Escape" then
		return body * 12
	elseif c.Kind == "Arena" then
		return c.Width * body * 0.75 + body * 4
	elseif c.Kind == "Runway" then
		return body * 40
	end
	local step = c.Gap * jd + c.Width * body
	return math.max(body * 10, step * c.Segments * 0.45)
end

------------------------------------------------------------------ kinds

local function buildLinear(
	parent: Instance,
	def: ChallengeConfig.ChallengeDef,
	origin: Vector3,
	data: CourseData,
	stones: boolean
)
	local body, _, _, jd, jh = ChallengeConfig.physics(def.RequiredTier)
	local c = def.Course
	local rng = Random.new(c.Seed)
	local accent, dark, material = themeFor(def.Zone)
	local width = c.Width * body
	local thickness = math.max(0.3, body * 0.35)

	local heading = 0
	local pos = origin
	platform(parent, "StartPlatform", pos, Vector3.new(body * 5, thickness, body * 5), dark, material)
	data.Start = pos + Vector3.new(0, 0, 0)
	local radius = 0
	for i = 1, c.Segments do
		-- Gentle seeded turns keep the pocket compact; every 4th segment
		-- turns harder so long courses fold back on themselves.
		local turn = rng:NextNumber(-0.45, 0.45)
			+ (if i % 4 == 0 then (if rng:NextNumber() < 0.5 then -1.2 else 1.2) else 0)
		heading += turn
		local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
		local gap = c.Gap * jd * rng:NextNumber(0.85, 1.1)
		local rise = c.Rise * jh * rng:NextNumber(-0.3, 1)
		local size = width * rng:NextNumber(0.85, 1.15)
		pos = pos + dir * (gap + size) + Vector3.new(0, rise, 0)
		local color = if i == c.Segments then accent else (if i % 2 == 0 then dark else accent:Lerp(dark, 0.55))
		platform(parent, "Platform" .. i, pos, Vector3.new(size, thickness, size), color, material)
		-- Occasional low wall to hop over (Vault practice) on wide platforms.
		if not stones and i % 3 == 0 and i < c.Segments then
			Kit.block(
				parent,
				"Hurdle" .. i,
				pos + Vector3.new(0, body * 0.3, 0),
				Vector3.new(size * 0.15, body * 0.6, size * 0.9),
				accent,
				Enum.Material.Neon
			)
		end
		table.insert(data.Checkpoints, pos)
		marker(parent, "ChallengeCheckpoint", def.Id, i, pos + Vector3.new(0, body * 0.5, 0), size)
		radius = math.max(radius, (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude)
	end
	data.Finish = pos
	data.FinishRadius = width * 0.75 + body
	glowRing(parent, pos, width * 0.6, Color3.fromRGB(255, 230, 120))
	Kit.tag(
		Kit.region(parent, "Finish", pos + Vector3.new(0, body, 0), Vector3.new(width, body * 2, width)),
		"ChallengeFinish",
		{ ChallengeId = def.Id }
	)
	data.CheckpointRadius = width * 0.6 + body * 0.75
	data.Bounds = radius + body * 25
	local lowest = origin.Y
	for _, p in data.Checkpoints do
		lowest = math.min(lowest, p.Y)
	end
	data.FloorY = lowest
	data.FailY = lowest - body * 10
	if stones then
		local lavaY = lowest - body * 1.2
		data.LavaY = lavaY + body * 0.2
		local span = radius * 2 + body * 30
		local lava = Kit.block(
			parent,
			"Lava",
			Vector3.new(origin.X, lavaY, origin.Z),
			Vector3.new(math.min(span, 2048), body * 0.4, math.min(span, 2048)),
			Color3.fromRGB(255, 90, 30),
			Enum.Material.Neon
		)
		lava.CanCollide = true
		Kit.tag(lava, "ChallengeHazard", { ChallengeId = def.Id })
		data.FailY = lavaY - body * 2
	end
end

local function buildTower(
	parent: Instance,
	def: ChallengeConfig.ChallengeDef,
	origin: Vector3,
	data: CourseData,
	escape: boolean
)
	local body, _, _, jd, jh = ChallengeConfig.physics(def.RequiredTier)
	local c = def.Course
	local rng = Random.new(c.Seed)
	local accent, dark, material = themeFor(def.Zone)
	local width = c.Width * body
	local thickness = math.max(0.3, body * 0.3)
	local step = c.Gap * jd + width
	local ringRadius = math.max(body * 3, step * 6 / (2 * math.pi))
	local columnHeight = c.Segments * c.Rise * jh + body * 4

	Kit.tower(
		parent,
		"Column",
		origin + Vector3.new(0, 0, 0),
		Vector2.new(ringRadius * 0.9, ringRadius * 0.9),
		columnHeight,
		dark,
		Enum.Material.Concrete
	)
	local startPos = origin + Vector3.new(ringRadius + width, 0, 0)
	platform(parent, "StartPlatform", startPos, Vector3.new(body * 5, thickness, body * 5), dark, material)
	data.Start = startPos
	local angle = 0
	local y = origin.Y
	for i = 1, c.Segments do
		angle += step / (ringRadius + width * 0.5)
		y += c.Rise * jh * rng:NextNumber(0.85, 1)
		local r = ringRadius + width * 0.5
		local pos = Vector3.new(origin.X + math.cos(angle) * r, y, origin.Z + math.sin(angle) * r)
		local color = if i == c.Segments then accent else (if i % 2 == 0 then dark else accent:Lerp(dark, 0.5))
		platform(parent, "Ledge" .. i, pos, Vector3.new(width, thickness, width), color, material)
		table.insert(data.Checkpoints, pos)
		marker(parent, "ChallengeCheckpoint", def.Id, i, pos + Vector3.new(0, body * 0.5, 0), width)
	end
	local top = data.Checkpoints[#data.Checkpoints]
	data.Finish = top
	data.FinishRadius = width + body
	glowRing(parent, top, width * 0.6, Color3.fromRGB(255, 230, 120))
	Kit.tag(
		Kit.region(parent, "Finish", top + Vector3.new(0, body, 0), Vector3.new(width, body * 2, width)),
		"ChallengeFinish",
		{ ChallengeId = def.Id }
	)
	data.CheckpointRadius = width * 0.6 + body * 0.75
	data.Bounds = ringRadius + body * 30
	data.FloorY = origin.Y
	data.FailY = origin.Y - body * 10
	-- Safety floor so a fall restarts the climb instead of failing outright
	-- (except in the escape, where falling into the water is the danger).
	local floorSize = math.min((ringRadius + width * 3) * 2, 2048)
	Kit.block(
		parent,
		"Floor",
		origin - Vector3.new(0, thickness / 2, 0),
		Vector3.new(floorSize, thickness, floorSize),
		dark,
		material
	)
	if escape then
		local ideal = ChallengeConfig.idealTime(def.RequiredTier, c)
		data.Hazard = {
			BaseY = origin.Y - body * 0.5,
			Speed = (top.Y - origin.Y) / (ideal * 2.4),
			Delay = 3,
		}
		local water = Kit.block(
			parent,
			"Water",
			origin - Vector3.new(0, body * 0.6, 0),
			Vector3.new(floorSize, body * 0.2, floorSize),
			Kit.Colors.Water,
			Enum.Material.Glass
		)
		water.Transparency = 0.4
		water.CanCollide = false
		Kit.tag(water, "ChallengeHazard", { ChallengeId = def.Id, Rising = true })
		-- Shaft walls give the escape its claustrophobic feel.
		local shaft = ringRadius + width * 1.6
		for _, offset in
			{ Vector3.new(shaft, 0, 0), Vector3.new(-shaft, 0, 0), Vector3.new(0, 0, shaft), Vector3.new(0, 0, -shaft) }
		do
			local size = if offset.X ~= 0 then Vector2.new(thickness, shaft * 2) else Vector2.new(shaft * 2, thickness)
			for _, piece in
				Kit.tower(
					parent,
					"Shaft",
					origin + offset,
					size,
					columnHeight,
					Kit.Colors.Concrete,
					Enum.Material.Concrete
				)
			do
				piece.Transparency = 0.15
			end
		end
	end
end

local function buildArena(parent: Instance, def: ChallengeConfig.ChallengeDef, origin: Vector3, data: CourseData)
	local body, _, _, _, jh = ChallengeConfig.physics(def.RequiredTier)
	local c = def.Course
	local rng = Random.new(c.Seed)
	local accent, dark, material = themeFor(def.Zone)
	local size = c.Width * body
	local thickness = math.max(0.3, body * 0.3)
	platform(parent, "ArenaFloor", origin, Vector3.new(size, thickness, size), dark, material)
	for i, offset in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local wallSize = if offset.X ~= 0
			then Vector3.new(thickness, body * 1.5, size)
			else Vector3.new(size, body * 1.5, thickness)
		Kit.block(
			parent,
			"ArenaWall" .. i,
			origin + offset * size / 2 + Vector3.new(0, body * 0.75, 0),
			wallSize,
			accent,
			Enum.Material.Neon
		).Transparency =
			0.5
	end
	data.Start = origin + Vector3.new(0, 0, size * 0.4)
	data.FloorY = origin.Y
	data.FailY = origin.Y - body * 6
	data.Bounds = size * 0.75 + body * 6
	local count = c.Targets or c.Segments
	local kind = def.Type
	for i = 1, count do
		local p = origin + Vector3.new(rng:NextNumber(-0.42, 0.42) * size, 0, rng:NextNumber(-0.42, 0.42) * size)
		if kind == "TargetBreak" then
			-- Targets sit on pedestals of varying height.
			local h = c.Rise * jh * rng:NextNumber(0, 1.5)
			if h > body * 0.2 then
				Kit.block(
					parent,
					"Pedestal" .. i,
					p + Vector3.new(0, h / 2, 0),
					Vector3.new(body * 0.8, h, body * 0.8),
					dark,
					material
				)
			end
			p += Vector3.new(0, h, 0)
			local t = Kit.ball(
				parent,
				"Target" .. i,
				p + Vector3.new(0, body * 0.5, 0),
				body * 0.7,
				Color3.fromRGB(255, 80, 80),
				Enum.Material.Neon
			)
			t.CanCollide = false
			Kit.tag(t, "ChallengeTarget", { ChallengeId = def.Id, Index = i })
			table.insert(data.Targets, p + Vector3.new(0, body * 0.5, 0))
		elseif kind == "HiddenObject" then
			-- Clutter around each hidden object makes it a search.
			for j = 1, 4 do
				local q = p + Vector3.new(rng:NextNumber(-2, 2) * body, 0, rng:NextNumber(-2, 2) * body)
				Kit.block(
					parent,
					"Clutter",
					q + Vector3.new(0, body * 0.4, 0),
					Vector3.new(body * 1.2, body * 0.8, body * 1.2),
					accent:Lerp(dark, rng:NextNumber()),
					Enum.Material.Wood
				)
			end
			local t = Kit.part(parent, {
				Name = "Hidden" .. i,
				Size = Vector3.new(body * 0.35, body * 0.5, body * 0.35),
				Position = p + Vector3.new(0, body * 0.25, 0),
				Color = Color3.fromRGB(220, 60, 60),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
			Kit.tag(t, "ChallengeTarget", { ChallengeId = def.Id, Index = i, Hidden = true })
			table.insert(data.Targets, p + Vector3.new(0, body * 0.25, 0))
		else -- ResourceRush tokens
			local t = Kit.part(parent, {
				Name = "Token" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(body * 0.12, body * 0.6, body * 0.6),
				Position = p + Vector3.new(0, body * 0.5, 0),
				Color = Color3.fromRGB(255, 210, 60),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			Kit.tag(t, "ChallengeToken", { ChallengeId = def.Id, Index = i })
			table.insert(data.Tokens, p + Vector3.new(0, body * 0.5, 0))
		end
	end
	data.CheckpointRadius = body * 1.6
end

local function buildRunway(parent: Instance, def: ChallengeConfig.ChallengeDef, origin: Vector3, data: CourseData)
	local body = ChallengeConfig.physics(def.RequiredTier)
	local accent, dark, material = themeFor(def.Zone)
	local width = def.Course.Width * body
	local runLength = body * 14
	local thickness = math.max(0.3, body * 0.3)
	local dir = Vector3.new(1, 0, 0)
	platform(parent, "Runway", origin + dir * runLength / 2, Vector3.new(runLength, thickness, width), dark, material)
	local edge = origin + dir * runLength
	Kit.block(
		parent,
		"TakeoffLine",
		edge + Vector3.new(-body * 0.1, thickness * 0.05, 0),
		Vector3.new(body * 0.2, thickness * 0.1, width),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.Neon
	)
	-- Landing field slightly lower so the jump is a clean arc.
	local fieldLength = body * 12
	local drop = body * 0.5
	platform(
		parent,
		"LandingField",
		edge + dir * fieldLength / 2 - Vector3.new(0, drop, 0),
		Vector3.new(fieldLength, thickness, width * 3),
		Color3.fromRGB(70, 140, 80),
		Enum.Material.Grass
	)
	for m = 1, 10 do
		local markPos = edge + dir * (m * body) - Vector3.new(0, drop - thickness * 0.05, 0)
		local color = if m % 2 == 0 then accent else Color3.fromRGB(255, 255, 255)
		Kit.block(
			parent,
			"Mark" .. m,
			markPos,
			Vector3.new(body * 0.08, thickness * 0.1, width * 3),
			color,
			Enum.Material.Neon
		)
	end
	data.Start = origin + dir * body * 1.5
	data.StartFacing = dir
	data.Takeoff = { Point = edge, Direction = dir }
	data.FloorY = origin.Y - drop
	data.FailY = origin.Y - drop - body * 6
	data.Bounds = runLength + fieldLength + body * 10
	data.CheckpointRadius = body
	-- Safety net under everything.
	local net = Kit.block(
		parent,
		"Net",
		edge - Vector3.new(0, drop + body * 2, 0),
		Vector3.new(math.min((runLength + fieldLength) * 2.2, 2048), thickness, math.min(width * 8, 2048)),
		dark,
		material
	)
	net.Transparency = 0.5
end

------------------------------------------------------------------ build all

function CourseBuilder.build(root: Instance)
	local folder = Kit.folder(root, "TrainingSimulations")
	local cursorX = -ROW_LIMIT
	local cursorZ = POCKET_Z
	local rowRadius = 0
	for _, def in ChallengeConfig.List do
		local radius = estimateRadius(def)
		if cursorX + radius * 2 > ROW_LIMIT then
			cursorX = -ROW_LIMIT
			cursorZ += rowRadius * 2 + 500
			rowRadius = 0
		end
		local origin = Vector3.new(cursorX + radius, POCKET_Y, cursorZ + radius)
		cursorX += radius * 2 + 400
		rowRadius = math.max(rowRadius, radius)

		local pocket = Kit.model(folder, def.Id)
		local body = ChallengeConfig.physics(def.RequiredTier)
		local data: CourseData = {
			Id = def.Id,
			Kind = def.Course.Kind,
			Body = body,
			Origin = origin,
			Start = origin,
			StartFacing = Vector3.new(1, 0, 0),
			Checkpoints = {},
			CheckpointRadius = body,
			Finish = nil,
			FinishRadius = body,
			Tokens = {},
			Targets = {},
			FloorY = origin.Y,
			FailY = origin.Y - body * 10,
			Hazard = nil,
			LavaY = nil,
			Takeoff = nil,
			Bounds = radius,
			Pad = def.Anchor,
		}
		local kind = def.Course.Kind
		if kind == "Sprint" then
			buildLinear(pocket, def, origin, data, false)
		elseif kind == "Stones" then
			buildLinear(pocket, def, origin, data, true)
		elseif kind == "Tower" then
			buildTower(pocket, def, origin, data, false)
		elseif kind == "Escape" then
			buildTower(pocket, def, origin, data, true)
		elseif kind == "Arena" then
			buildArena(pocket, def, origin, data)
		elseif kind == "Runway" then
			buildRunway(pocket, def, origin, data)
		end
		CourseBuilder.Registry[def.Id] = data
	end
end

-- World start pads (tag ChallengeStart) — built by WorldBuilder after regions.
function CourseBuilder.buildPads(root: Instance)
	local folder = Kit.folder(root, "ChallengePads")
	for _, def in ChallengeConfig.List do
		local body = ChallengeConfig.physics(def.RequiredTier)
		local zone = ZoneConfig.get(def.Zone)
		local color = if zone then zone.MapColor else Color3.new(1, 1, 1)
		local frame = Color3.fromRGB(44, 50, 70)
		local pad = Kit.pillar(
			folder,
			"ChallengePad_" .. def.Id,
			def.Anchor,
			math.max(0.08, body * 0.08),
			body * 3,
			frame,
			Enum.Material.Metal
		)
		local rim = Kit.pillar(
			folder,
			"ChallengeRim",
			def.Anchor - Vector3.new(0, body * 0.01, 0),
			math.max(0.08, body * 0.08),
			body * 3.15,
			color,
			Enum.Material.Neon
		)
		rim.CanCollide = false
		rim.CanQuery = false
		rim.CastShadow = false
		local inlay = Kit.pillar(
			folder,
			"ChallengeInlay",
			def.Anchor + Vector3.new(0, body * 0.06, 0),
			math.max(0.04, body * 0.04),
			body * 1.2,
			color,
			Enum.Material.Neon
		)
		inlay.CanCollide = false
		inlay.CanQuery = false
		inlay.Transparency = 0.3
		-- Beam landmark + a sign naming the challenge.
		Kit.lightBeam(pad, body * 12, body * 1.4, color)
		local post = Kit.block(
			folder,
			"ChallengeSignPost",
			def.Anchor + Vector3.new(body * 1.7, body * 0.75, 0),
			Vector3.new(body * 0.12, body * 1.5, body * 0.12),
			frame,
			Enum.Material.Metal
		)
		post.CanCollide = false
		local sign = Kit.block(
			folder,
			"ChallengeSign",
			def.Anchor + Vector3.new(body * 1.7, body * 1.75, 0),
			Vector3.new(body * 1.6, body * 0.9, body * 0.08),
			frame,
			Enum.Material.SmoothPlastic
		)
		sign.CanCollide = false
		Kit.screen(sign, def.Name, color, Enum.NormalId.Front)
		Kit.screen(sign, def.Name, color, Enum.NormalId.Back)
		Kit.tag(pad, "ChallengeStart", { ChallengeId = def.Id })
	end
end

return CourseBuilder
