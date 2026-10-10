--!strict
--[[
	ModelSkins
	Swaps a creature's generated block body for its real 3D model (built in
	tools/models, uploaded with tools/models/upload.mjs). Only the welded
	visual parts change: the Root and everything gameplay touches stay the
	same. A model with no asset id, or one still loading, keeps its blocks.

	The importer may pick different axes and units than Blender, so every
	loaded model is oriented by matching its parts' bounding-box centres to
	the manifest (ModelLibrary), trying the 24 axis-aligned rotations.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelLibrary = require(Shared.Config.ModelLibrary)
local ModelAssets = require(Shared.Config.ModelAssets)

local ModelSkins = {}

-- One part of a loaded model, in the manifest's frame: height 1, standing
-- on y = 0, facing -Z.
type Piece = { Part: BasePart, Role: string, Offset: CFrame, Size: Vector3 }

local templates: { [string]: { Piece } } = {}
local loading: { [string]: boolean } = {}

local ROTATIONS: { CFrame } = {}
do
	local axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis, -Vector3.xAxis, -Vector3.yAxis, -Vector3.zAxis }
	for _, x in axes do
		for _, y in axes do
			if math.abs(x:Dot(y)) < 0.5 then
				table.insert(ROTATIONS, CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y)))
			end
		end
	end
end

local function roleOf(part: BasePart): string
	-- Importers may suffix duplicate names ("Wing.001", "Wing_2").
	return string.match(part.Name, "^[A-Za-z]+") or part.Name
end

-- Orient and normalise a loaded model's parts. Returns nil when the parts
-- don't match the manifest well enough to place them confidently.
function ModelSkins.solve(name: string, parts: { BasePart }): { Piece }?
	local def = ModelLibrary[name]
	if not def then
		return nil
	end
	local actual: { Vector3 } = {}
	local expected: { Vector3 } = {}
	for _, part in parts do
		local spec = def.Parts[roleOf(part)]
		if spec then
			table.insert(actual, part.Position)
			table.insert(expected, spec.Center)
		end
	end
	if #actual < 3 then
		return nil
	end
	local aMean, eMean = Vector3.zero, Vector3.zero
	for i = 1, #actual do
		aMean += actual[i]
		eMean += expected[i]
	end
	aMean /= #actual
	eMean /= #expected
	local aSpread, eSpread = 0, 0
	for i = 1, #actual do
		aSpread += (actual[i] - aMean).Magnitude ^ 2
		eSpread += (expected[i] - eMean).Magnitude ^ 2
	end
	if aSpread <= 0 or eSpread <= 0 then
		return nil
	end
	-- Imported units per manifest unit.
	local k = math.sqrt(aSpread / eSpread)
	local best, bestErr = ROTATIONS[1], math.huge
	for _, r in ROTATIONS do
		local err = 0
		for i = 1, #actual do
			err += (r:VectorToWorldSpace((actual[i] - aMean) / k) - (expected[i] - eMean)).Magnitude ^ 2
		end
		if err < bestErr then
			best, bestErr = r, err
		end
	end
	-- Mean placement error must be small next to the model (height 1).
	if math.sqrt(bestErr / #actual) > 0.08 then
		return nil
	end
	local pieces: { Piece } = {}
	for _, part in parts do
		local role = roleOf(part)
		if def.Parts[role] then
			local position = best:VectorToWorldSpace((part.Position - aMean) / k) + eMean
			table.insert(pieces, {
				Part = part,
				Role = role,
				Offset = CFrame.new(position) * best * part.CFrame.Rotation,
				Size = part.Size / k,
			})
		end
	end
	return pieces
end

local function load(name: string, assetId: number)
	loading[name] = true
	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	loading[name] = nil
	if not ok or not container then
		warn(string.format("[ModelSkins] %s (asset %d) did not load: %s", name, assetId, tostring(container)))
		return
	end
	local parts: { BasePart } = {}
	for _, inst in (container :: Instance):GetDescendants() do
		if inst:IsA("BasePart") then
			table.insert(parts, inst)
		end
	end
	local pieces = ModelSkins.solve(name, parts)
	if pieces then
		templates[name] = pieces
	else
		warn(string.format("[ModelSkins] %s (asset %d) doesn't match its manifest; keeping blocks", name, assetId))
	end
end

-- Start loading every uploaded model (non-blocking).
function ModelSkins.preload()
	for name, assetId in ModelAssets do
		if ModelLibrary[name] and not templates[name] and not loading[name] then
			task.spawn(load, name, assetId)
		end
	end
end

function ModelSkins.isReady(name: string): boolean
	return templates[name] ~= nil
end

local function tinted(color: Color3, mode: string?, fixed: Color3): Color3
	if mode == "Tint" then
		return color
	elseif mode == "TintDark" then
		return color:Lerp(Color3.new(0, 0, 0), 0.4)
	elseif mode == "TintLight" then
		return color:Lerp(Color3.new(1, 1, 1), 0.35)
	end
	return fixed
end

-- Bounds of the generated visual parts in the root's space.
local function bodyBounds(model: Model, root: BasePart): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			local cf = root.CFrame:ToObjectSpace(part.CFrame)
			local half = part.Size / 2
			local r = cf.Rotation
			local extent = Vector3.new(
				math.abs(r.XVector.X) * half.X + math.abs(r.YVector.X) * half.Y + math.abs(r.ZVector.X) * half.Z,
				math.abs(r.XVector.Y) * half.X + math.abs(r.YVector.Y) * half.Y + math.abs(r.ZVector.Y) * half.Z,
				math.abs(r.XVector.Z) * half.X + math.abs(r.YVector.Z) * half.Y + math.abs(r.ZVector.Z) * half.Z
			)
			lo = lo:Min(cf.Position - extent)
			hi = hi:Max(cf.Position + extent)
		end
	end
	return lo, hi
end

-- Replace the block body of a freshly built creature with its 3D model.
-- Returns false (leaving the blocks) when the model isn't available.
function ModelSkins.apply(model: Model, root: BasePart, name: string, color: Color3): boolean
	local pieces = templates[name]
	local def = ModelLibrary[name]
	if not pieces or not def then
		return false
	end
	local lo, hi = bodyBounds(model, root)
	if lo.X > hi.X then
		lo, hi = -root.Size / 2, root.Size / 2
	end
	local box = hi - lo
	-- Fit inside the generated body, standing where it stood.
	local s = math.min(box.Y * 1.1, math.max(box.X, box.Z) * 1.05 / math.max(def.Size.X, def.Size.Z, 0.01))
	local base = root.CFrame * CFrame.new(0, lo.Y, (lo.Z + hi.Z) / 2)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			part:Destroy()
		end
	end
	for _, piece in pieces do
		local spec = def.Parts[piece.Role]
		local part = piece.Part:Clone()
		part.Size = piece.Size * s
		part.CFrame = base * CFrame.new(piece.Offset.Position * s) * piece.Offset.Rotation
		part.Color = tinted(color, spec.Tint, spec.Color)
		part.Material = spec.Material
		part.Transparency = if spec.Material == Enum.Material.Glass then 0.45 else 0
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = spec.Material ~= Enum.Material.Glass and spec.Material ~= Enum.Material.Neon
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	model:SetAttribute("Skin", name)
	return true
end

return ModelSkins
