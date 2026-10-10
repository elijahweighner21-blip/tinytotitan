-- 3D model skins: an uploaded model (faked here, imported with other axes
-- and units than Blender's) replaces a creature's block body, oriented,
-- sized and tinted correctly; a failing asset keeps the blocks.
local E = __E
E.startServer()
E.run(3)
local ModelSkins = E.serverModule("World.ModelSkins")
local ModelAssets = E.sharedModule("Config.ModelAssets")
local ModelLibrary = E.sharedModule("Config.ModelLibrary")
local EnemyConfig = E.sharedModule("Config.EnemyConfig")
local EnemyService = E.serverModule("Services.EnemyService")

-- The importer turned the model Z-up, half-turned it and used 37 units per
-- model height: the loader must undo all of that.
local IMPORT = CFrame.Angles(math.rad(-90), math.rad(180), 0)
local UNITS = 37
local function fakeImport(name)
	return function()
		local model = E.new("Model")
		model.Name = name
		for role, spec in ModelLibrary[name].Parts do
			local part = E.new("MeshPart")
			part.Name = role .. ".001"
			part.Size = spec.Extent * UNITS
			part.CFrame = CFrame.new(Vector3.new(500, 20, -300) + IMPORT:VectorToWorldSpace(spec.Center * UNITS)) * IMPORT
			part.Parent = model
		end
		return model
	end
end

print("== Loading")
ModelAssets.Wasp = 9001
ModelAssets.Beetle = 9002 -- not available: must fall back to blocks
E.insertAssets[9001] = fakeImport("Wasp")
ModelSkins.preload()
E.run(2)
E.check("uploaded model loads", ModelSkins.isReady("Wasp"))
E.check("missing asset keeps blocks", not ModelSkins.isReady("Beetle"))

print("== A wasp wears its model")
local function enemyId(shape)
	for _, def in EnemyConfig.List do
		if def.Shape == shape then
			return def.Id, def
		end
	end
	return nil, nil
end
local waspId, waspDef = enemyId("Wasp")
local wasp = EnemyService:Spawn(waspId, Vector3.new(0, 30, 0))
E.check("wasp spawned", wasp ~= nil)
E.run(0.5)
local model, root = wasp.Model, wasp.Root
E.check("model marked as skinned", model:GetAttribute("Skin") == "Wasp")
local head = model:FindFirstChild("Head.001")
local stinger = model:FindFirstChild("Stinger.001")
local body = model:FindFirstChild("Body.001")
E.check("parts present", head ~= nil and stinger ~= nil and body ~= nil)
local look = root.CFrame.LookVector
local headAhead = (head.Position - root.Position):Dot(look)
local stingerAhead = (stinger.Position - root.Position):Dot(look)
E.check("faces forward (head in front of stinger)", headAhead > stingerAhead, string.format("%.2f vs %.2f", headAhead, stingerAhead))
local up = root.CFrame.UpVector
E.check("upright (wings above legs)", (model:FindFirstChild("Wing.001").Position - model:FindFirstChild("Leg.001").Position):Dot(up) > 0)
E.check("tinted with the enemy colour", body.Color == waspDef.Color, tostring(body.Color))
E.check("fixed colours kept", model:FindFirstChild("Stripe.001").Color == ModelLibrary.Wasp.Parts.Stripe.Color)
E.check("glass wings see-through", model:FindFirstChild("Wing.001").Transparency > 0.3)
local lo, hi = math.huge, -math.huge
for _, p in model:GetDescendants() do
	if p:IsA("BasePart") and p ~= root then
		E.check("visual part " .. p.Name .. " is cosmetic", not p.CanCollide and not p.CanQuery and p.Massless)
		local y = (p.Position - root.Position):Dot(up)
		lo, hi = math.min(lo, y - p.Size.Magnitude * 0.25), math.max(hi, y + p.Size.Magnitude * 0.25)
	end
end
E.check("about the creature's size", hi - lo > wasp.H * 0.4 and hi - lo < wasp.H * 1.6, string.format("%.1f vs H %.1f", hi - lo, wasp.H))
E.check("no blocks left behind", model:FindFirstChild("Thorax") == nil)

print("== Other creatures keep their blocks")
local beetleId = enemyId("Beetle")
local beetle = EnemyService:Spawn(beetleId, Vector3.new(60, 30, 0))
E.run(0.5)
E.check("beetle uses blocks", beetle ~= nil and beetle.Model:GetAttribute("Skin") == nil and beetle.Model:FindFirstChild("Shell") ~= nil)

print("== A mismatched model is rejected")
local wrong = fakeImport("Spider")()
local parts = {}
for _, p in wrong:GetDescendants() do
	if p:IsA("BasePart") then
		table.insert(parts, p)
	end
end
E.check("spider parts don't pass as a wasp", ModelSkins.solve("Wasp", parts) == nil)
E.check("every library model solves its own import", (function()
	for name in ModelLibrary do
		local m = fakeImport(name)()
		local list = {}
		for _, p in m:GetDescendants() do
			table.insert(list, p)
		end
		if not ModelSkins.solve(name, list) then
			print("   could not solve " .. name)
			return false
		end
	end
	return true
end)())
E.summary()
