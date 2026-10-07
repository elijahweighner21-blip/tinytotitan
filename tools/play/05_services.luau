-- Services and the DataModel for the headless engine.
local E = __E
local class, classes, new, sig, isInst = E.class, E.classes, E.new, E.sig, E.isInst

------------------------------------------------------------------ DataModel
class("ServiceProvider", "Instance")
class("DataModel", "ServiceProvider", { defaults = { PlaceId = 0, GameId = 0, JobId = "emulated-job-1", PlaceVersion = 1, CreatorId = 0 } })
local game = new("DataModel")
rawset(game, "__name", "Game")
E.game = game
local services = {}
local function service(className, name)
	local c = classes[className] or class(className, "Instance")
	local s = new(c.Name)
	rawset(s, "__name", name or className)
	rawset(s, "__parent", game)
	table.insert(rawget(game, "__children"), s)
	services[name or className] = s
	return s
end
E.services = services
classes.DataModel.methods.GetService = function(_, name)
	local s = services[name]
	if not s then
		s = service(name)
	end
	return s
end
classes.DataModel.methods.FindService = function(_, name)
	return services[name]
end
classes.DataModel.methods.BindToClose = function(_, fn)
	E.closeHandlers = E.closeHandlers or {}
	table.insert(E.closeHandlers, fn)
end
classes.DataModel.methods.IsLoaded = function()
	return true
end
classes.DataModel.signals.Loaded = true
classes.DataModel.signals.Close = true

------------------------------------------------------------------ Workspace + spatial index
class("WorldRoot", "Model")
class("Workspace", "WorldRoot", {
	defaults = { Gravity = 196.2, StreamingEnabled = true, FallenPartsDestroyHeight = -500, DistributedGameTime = 0 },
	get = {
		DistributedGameTime = function()
			return E.now
		end,
	},
})
local workspace = service("Workspace")
E.workspace = workspace
local camera = new("Camera")
camera.Parent = workspace
rawget(workspace, "__props").CurrentCamera = camera
local terrain = new("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace

local CELL = 64
local BIG = 512
local grid = {} -- key -> set of parts
local bigParts = {} -- set
local indexed = {} -- part -> { keys = {...} } or "big"
E.indexStats = { parts = 0, big = 0 }

local function aabb(p)
	local cf, s = p.CFrame, p.Size / 2
	local ex = math.abs(cf[1]) * s.X + math.abs(cf[2]) * s.Y + math.abs(cf[3]) * s.Z
	local ey = math.abs(cf[4]) * s.X + math.abs(cf[5]) * s.Y + math.abs(cf[6]) * s.Z
	local ez = math.abs(cf[7]) * s.X + math.abs(cf[8]) * s.Y + math.abs(cf[9]) * s.Z
	return Vector3.new(cf.X - ex, cf.Y - ey, cf.Z - ez), Vector3.new(cf.X + ex, cf.Y + ey, cf.Z + ez)
end
E.aabb = aabb

local function unindex(p)
	local entry = indexed[p]
	if not entry then
		return
	end
	if entry == "big" then
		bigParts[p] = nil
		E.indexStats.big -= 1
	else
		for _, key in entry do
			local set = grid[key]
			if set then
				set[p] = nil
			end
		end
	end
	indexed[p] = nil
	E.indexStats.parts -= 1
end
local function index(p)
	unindex(p)
	local mn, mx = aabb(p)
	E.indexStats.parts += 1
	if mx.X - mn.X > BIG or mx.Z - mn.Z > BIG then
		bigParts[p] = true
		indexed[p] = "big"
		E.indexStats.big += 1
		return
	end
	local keys = {}
	for cx = math.floor(mn.X / CELL), math.floor(mx.X / CELL) do
		for cz = math.floor(mn.Z / CELL), math.floor(mx.Z / CELL) do
			local key = cx * 100003 + cz
			local set = grid[key]
			if not set then
				set = {}
				grid[key] = set
			end
			set[p] = true
			table.insert(keys, key)
		end
	end
	indexed[p] = keys
end
E.onPartMoved = function(p)
	if indexed[p] then
		index(p)
	end
end
E.onDestroy = function(o)
	if indexed[o] then
		unindex(o)
	end
end

local tagged = {} -- tag -> set of instances (any membership)
E.onMembership = function(d, wasInGame, nowInGame, wasWS, nowWS)
	if d:IsA("BasePart") then
		if nowWS and not wasWS then
			index(d)
		elseif wasWS and not nowWS then
			unindex(d)
		end
	end
	if wasInGame ~= nowInGame then
		for tag in rawget(d, "__tags") do
			local s = rawget(E.collection, "__signals")[(if nowInGame then "Added:" else "Removed:") .. tag]
			if s then
				s:Fire(d)
			end
		end
	end
end

local function candidatesInBox(mn, mx)
	local out = {}
	for p in bigParts do
		out[p] = true
	end
	local x0, x1 = math.floor(mn.X / CELL), math.floor(mx.X / CELL)
	local z0, z1 = math.floor(mn.Z / CELL), math.floor(mx.Z / CELL)
	if (x1 - x0 + 1) * (z1 - z0 + 1) > 40000 then
		for p in indexed do
			out[p] = true
		end
		return out
	end
	for cx = x0, x1 do
		for cz = z0, z1 do
			local set = grid[cx * 100003 + cz]
			if set then
				for p in set do
					out[p] = true
				end
			end
		end
	end
	return out
end

local function filtered(p, params)
	if not params then
		return true
	end
	local list = params.FilterDescendantsInstances or {}
	local hit = false
	for _, f in list do
		if p == f or p:IsDescendantOf(f) then
			hit = true
			break
		end
	end
	local include = params.FilterType == Enum.RaycastFilterType.Include or params.FilterType == Enum.RaycastFilterType.Whitelist
	if include then
		return hit
	end
	return not hit
end

local function rayOBB(origin, dir, p)
	local inv = p.CFrame:Inverse()
	local o = inv * origin
	local d = inv.Rotation * dir
	local h = p.Size / 2
	local tmin, tmax = 0, 1
	local nAxis, nSign = 0, 0
	for axis = 1, 3 do
		local oa = if axis == 1 then o.X elseif axis == 2 then o.Y else o.Z
		local da = if axis == 1 then d.X elseif axis == 2 then d.Y else d.Z
		local ha = if axis == 1 then h.X elseif axis == 2 then h.Y else h.Z
		if math.abs(da) < 1e-12 then
			if oa < -ha or oa > ha then
				return nil
			end
		else
			local t1, t2 = (-ha - oa) / da, (ha - oa) / da
			local s = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				s = 1
			end
			if t1 > tmin then
				tmin = t1
				nAxis, nSign = axis, s
			end
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	if nAxis == 0 then
		return nil -- origin inside the box: Roblox ignores the containing part
	end
	local localNormal = Vector3.new(if nAxis == 1 then nSign else 0, if nAxis == 2 then nSign else 0, if nAxis == 3 then nSign else 0)
	return tmin, p.CFrame.Rotation * localNormal
end

local wm = classes.WorldRoot.methods
function wm.Raycast(_, origin, direction, params)
	assert(typeof(origin) == "Vector3" and typeof(direction) == "Vector3", "Raycast expects Vector3s")
	E.raycasts = (E.raycasts or 0) + 1
	local finish = origin + direction
	local cands = candidatesInBox(origin:Min(finish), origin:Max(finish))
	local respect = params and params.RespectCanCollide
	local bestT, bestPart, bestN = math.huge, nil, nil
	for p in cands do
		if (if respect then p.CanCollide else p.CanQuery) and filtered(p, params) then
			local t, n = rayOBB(origin, direction, p)
			if t and t < bestT then
				bestT, bestPart, bestN = t, p, n
			end
		end
	end
	if not bestPart then
		return nil
	end
	local pos = origin + direction * bestT
	return { Instance = bestPart, Position = pos, Normal = bestN, Distance = direction.Magnitude * bestT, Material = bestPart.Material, __type = "RaycastResult" }
end
function wm.Blockcast(w, cf, size, dir, params)
	return wm.Raycast(w, cf.Position, dir, params)
end
function wm.Spherecast(w, pos, radius, dir, params)
	return wm.Raycast(w, pos, dir, params)
end
function wm.Shapecast(w, part, dir, params)
	return wm.Raycast(w, part.Position, dir, params)
end
local function boxQuery(mn, mx, params)
	local out = {}
	for p in candidatesInBox(mn, mx) do
		local a, b = aabb(p)
		if a.X <= mx.X and b.X >= mn.X and a.Y <= mx.Y and b.Y >= mn.Y and a.Z <= mx.Z and b.Z >= mn.Z then
			local ok = if params and params.RespectCanCollide then p.CanCollide else p.CanQuery
			if ok and filtered(p, params) then
				table.insert(out, p)
			end
		end
	end
	return out
end
function wm.GetPartBoundsInBox(_, cf, size, params)
	local h = size / 2
	local probe = { CFrame = cf, Size = size }
	local mn, mx = aabb(probe)
	local _ = h
	return boxQuery(mn, mx, params)
end
function wm.GetPartBoundsInRadius(_, pos, r, params)
	local v = Vector3.new(r, r, r)
	return boxQuery(pos - v, pos + v, params)
end
function wm.GetPartsInPart(_, part, params)
	local mn, mx = aabb(part)
	local out = {}
	for _, p in boxQuery(mn, mx, params) do
		if p ~= part then
			table.insert(out, p)
		end
	end
	return out
end
function wm.BulkMoveTo(_, parts, cfs)
	for i, p in parts do
		p.CFrame = cfs[i]
	end
end
classes.Workspace.methods.GetServerTimeNow = function()
	return E.epoch + E.now
end
classes.Workspace.methods.GetRealPhysicsFPS = function()
	return 60
end
-- Streaming: the emulator has the whole world, so these succeed.
classes.Workspace.methods.RequestStreamAroundAsync = function() end

------------------------------------------------------------------ Players
class("Player", "Instance", {
	defaults = {
		UserId = 1,
		DisplayName = "Player",
		AccountAge = 30,
		MembershipType = function()
			return Enum.MembershipType.None
		end,
		LocaleId = "en-us",
		CameraMinZoomDistance = 0.5,
		CameraMaxZoomDistance = 400,
		CameraMode = function()
			return Enum.CameraMode.Classic
		end,
		DevComputerMovementMode = function()
			return Enum.DevComputerMovementMode.UserChoice
		end,
		ReplicationFocus = false,
		RespawnLocation = false,
	},
	signals = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled", "OnTeleport" },
})
local pm = classes.Player.methods
function pm.LoadCharacterAsync(p)
	if not p.Parent then
		error("LoadCharacterAsync: player has left", 2)
	end
	local old = rawget(p, "__props").Character
	if old then
		sig(p, "CharacterRemoving"):Fire(old)
		old:Destroy()
	end
	local rig = E.buildRig(p.Name)
	-- Default spawn when there is no SpawnLocation: above the origin.
	rig:PivotTo(CFrame.new(0, 100, 0))
	rawget(p, "__props").Character = rig
	rig.Parent = workspace
	E.characterLoads = (E.characterLoads or 0) + 1
	sig(p, "CharacterAdded"):Fire(rig)
	task.delay(0.2, function()
		if rig.Parent then
			rawset(p, "__appearanceLoaded", true)
			sig(p, "CharacterAppearanceLoaded"):Fire(rig)
		end
	end)
end
pm.LoadCharacter = pm.LoadCharacterAsync
function pm.HasAppearanceLoaded(p)
	return rawget(p, "__appearanceLoaded") == true
end
function pm.Kick(p, message)
	E.record("print", "KICK " .. p.Name .. ": " .. tostring(message))
	E.kicks = E.kicks or {}
	table.insert(E.kicks, { Player = p.Name, Message = message })
	E.removePlayer(p)
end
function pm.GetMouse()
	return { Hit = CFrame.new(), Target = nil, X = 0, Y = 0, Icon = "" }
end
function pm.IsInGroupAsync()
	return false
end
function pm.GetRankInGroupAsync()
	return 0
end
function pm.GetFriendsOnline()
	return {}
end
function pm.IsFriendsWith()
	return false
end
function pm.GetNetworkPing()
	return 0.05
end
function pm.RequestStreamAroundAsync() end
classes.Player.set.Character = function(p, v)
	rawget(p, "__props").Character = v
end

class("Players", "Instance", { defaults = { MaxPlayers = 30, RespawnTime = 5, CharacterAutoLoads = true }, signals = { "PlayerAdded", "PlayerRemoving" } })
local Players = service("Players")
local plm = classes.Players.methods
function plm.GetPlayers(s)
	local out = {}
	for _, c in rawget(s, "__children") do
		if c:IsA("Player") then
			table.insert(out, c)
		end
	end
	return out
end
function plm.GetPlayerByUserId(s, id)
	for _, p in plm.GetPlayers(s) do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
function plm.GetPlayerFromCharacter(s, character)
	if not character then
		return nil
	end
	for _, p in plm.GetPlayers(s) do
		if rawget(p, "__props").Character == character then
			return p
		end
	end
	return nil
end
function plm.GetNameFromUserIdAsync(_, id)
	return "Player" .. tostring(id)
end
function plm.GetUserIdFromNameAsync()
	return 1
end
function plm.GetHumanoidDescriptionFromUserId()
	return new("HumanoidDescription")
end
function plm.CreateHumanoidModelFromDescription(_, desc, rigType)
	return E.buildRig("NPC")
end
function plm.GetUserThumbnailAsync()
	return "rbxasset://textures/ui/GuiImagePlaceholder.png", true
end
classes.Players.get.LocalPlayer = function()
	return E.localPlayer
end

------------------------------------------------------------------ CollectionService
class("CollectionService", "Instance")
local CS = service("CollectionService")
E.collection = CS
local csm = classes.CollectionService.methods
function csm.AddTag(_, o, tag)
	local tags = rawget(o, "__tags")
	if tags[tag] then
		return
	end
	tags[tag] = true
	tagged[tag] = tagged[tag] or setmetatable({}, { __mode = "k" })
	tagged[tag][o] = true
	if E.inGame(o) then
		local s = rawget(CS, "__signals")["Added:" .. tag]
		if s then
			s:Fire(o)
		end
	end
end
function csm.RemoveTag(_, o, tag)
	local tags = rawget(o, "__tags")
	if not tags[tag] then
		return
	end
	tags[tag] = nil
	if tagged[tag] then
		tagged[tag][o] = nil
	end
	if E.inGame(o) then
		local s = rawget(CS, "__signals")["Removed:" .. tag]
		if s then
			s:Fire(o)
		end
	end
end
function csm.HasTag(_, o, tag)
	return rawget(o, "__tags")[tag] == true
end
function csm.GetTags(_, o)
	return o:GetTags()
end
function csm.GetTagged(_, tag)
	local out = {}
	for o in tagged[tag] or {} do
		if not rawget(o, "__destroyed") and E.inGame(o) then
			table.insert(out, o)
		end
	end
	return out
end
function csm.GetAllTags()
	local out = {}
	for t in tagged do
		table.insert(out, t)
	end
	return out
end
function csm.GetInstanceAddedSignal(_, tag)
	return sig(CS, "Added:" .. tag)
end
function csm.GetInstanceRemovedSignal(_, tag)
	return sig(CS, "Removed:" .. tag)
end

------------------------------------------------------------------ RunService
class("RunService", "Instance", { signals = { "Heartbeat", "Stepped", "RenderStepped", "PreSimulation", "PostSimulation", "PreRender", "PreAnimation" } })
local RS = service("RunService")
E.isStudio = true
local rsm = classes.RunService.methods
function rsm.IsStudio()
	return E.isStudio
end
function rsm.IsServer()
	return true
end
function rsm.IsClient()
	return true
end
function rsm.IsRunning()
	return true
end
function rsm.IsRunMode()
	return false
end
function rsm.BindToRenderStep(_, name, priority, fn)
	E.renderBindings[name] = { priority = priority, fn = fn }
end
function rsm.UnbindFromRenderStep(_, name)
	E.renderBindings[name] = nil
end
E.stepSignals = {
	{ signal = sig(RS, "PreAnimation") },
	{ signal = sig(RS, "Stepped"), withTime = true },
	{ signal = sig(RS, "PreSimulation") },
	{ signal = sig(RS, "PostSimulation") },
	{ signal = sig(RS, "Heartbeat") },
	{ signal = sig(RS, "PreRender") },
	{ signal = sig(RS, "RenderStepped") },
}

------------------------------------------------------------------ DataStores
-- In-memory stores shared across emulated "servers" (E.dataStores survives
-- E.restartServer). Supports failure injection and budget accounting.
E.dataStores = E.dataStores or {}
E.dsCalls = { Get = 0, Update = 0, Set = 0, Remove = 0, Ordered = 0 }
E.dsFailNext = 0 -- number of upcoming DataStore calls that should error
local function maybeFail(op)
	if E.dsFailNext > 0 then
		E.dsFailNext -= 1
		error("DataStore request failed (emulated outage): " .. op, 0)
	end
	task.wait(0.05) -- requests yield like the real thing
end
local function deep(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deep(x)
	end
	return out
end
local function checkStorable(v, path)
	local t = type(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			error("DataStore: cannot store NaN/inf at " .. path, 0)
		end
	elseif t == "table" then
		if rawget(v, "__type") or isInst(v) then
			error("DataStore: cannot store " .. typeof(v) .. " at " .. path, 0)
		end
		for k, x in v do
			if type(k) ~= "string" and type(k) ~= "number" then
				error("DataStore: invalid key at " .. path, 0)
			end
			checkStorable(x, path .. "." .. tostring(k))
		end
	elseif t ~= "string" and t ~= "boolean" and t ~= "nil" then
		error("DataStore: cannot store " .. t .. " at " .. path, 0)
	end
end
class("GlobalDataStore", "Instance")
class("DataStore", "GlobalDataStore")
class("OrderedDataStore", "GlobalDataStore")
local function storeFor(kind, name, scope)
	local key = kind .. ":" .. name .. ":" .. (scope or "global")
	local s = E.dataStores[key]
	if not s then
		s = {}
		E.dataStores[key] = s
	end
	return s
end
local dsm = classes.GlobalDataStore.methods
function dsm.GetAsync(o, key)
	E.dsCalls.Get += 1
	maybeFail("GetAsync")
	return deep(rawget(o, "__data")[key]), { Version = "1", CreatedTime = 0, UpdatedTime = 0, GetMetadata = function()
		return {}
	end, GetUserIds = function()
		return {}
	end }
end
function dsm.SetAsync(o, key, value)
	E.dsCalls.Set += 1
	maybeFail("SetAsync")
	checkStorable(value, key)
	local json = E.JSON.encode(value)
	if #json > 4 * 1024 * 1024 then
		error("DataStore: value too large (" .. #json .. " bytes)", 0)
	end
	rawget(o, "__data")[key] = deep(value)
	return "1"
end
function dsm.UpdateAsync(o, key, fn)
	E.dsCalls.Update += 1
	maybeFail("UpdateAsync")
	local data = rawget(o, "__data")
	local current = deep(data[key])
	local result = fn(current, { Version = "1", GetMetadata = function()
		return {}
	end, GetUserIds = function()
		return {}
	end })
	if result == nil then
		return deep(data[key])
	end
	checkStorable(result, key)
	local json = E.JSON.encode(result)
	E.lastSaveBytes = #json
	if #json > 4 * 1024 * 1024 then
		error("DataStore: value too large (" .. #json .. " bytes)", 0)
	end
	data[key] = deep(result)
	return deep(result)
end
function dsm.RemoveAsync(o, key)
	E.dsCalls.Remove += 1
	maybeFail("RemoveAsync")
	local data = rawget(o, "__data")
	local old = data[key]
	data[key] = nil
	return old
end
function dsm.IncrementAsync(o, key, delta)
	return dsm.UpdateAsync(o, key, function(v)
		return (v or 0) + (delta or 1)
	end)
end
function dsm.GetSortedAsync(o, ascending, pageSize)
	E.dsCalls.Ordered += 1
	maybeFail("GetSortedAsync")
	local rows = {}
	for k, v in rawget(o, "__data") do
		table.insert(rows, { key = k, value = v })
	end
	table.sort(rows, function(a, b)
		if ascending then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	local page = {}
	for i = 1, math.min(pageSize or 50, #rows) do
		page[i] = rows[i]
	end
	return {
		IsFinished = true,
		GetCurrentPage = function()
			return page
		end,
		AdvanceToNextPageAsync = function() end,
	}
end
class("DataStoreService", "Instance")
local DSS = service("DataStoreService")
classes.DataStoreService.methods.GetDataStore = function(_, name, scope)
	if E.dataStoreAccessDenied then
		error("You must publish this place to the web to access DataStore.", 2)
	end
	local s = new("DataStore")
	rawset(s, "__data", storeFor("ds", name, scope))
	return s
end
classes.DataStoreService.methods.GetOrderedDataStore = function(_, name, scope)
	if E.dataStoreAccessDenied then
		error("You must publish this place to the web to access DataStore.", 2)
	end
	local s = new("OrderedDataStore")
	rawset(s, "__data", storeFor("ods", name, scope))
	return s
end
classes.DataStoreService.methods.GetRequestBudgetForRequestType = function()
	return 100
end
classes.DataStoreService.methods.GetGlobalDataStore = function(self)
	return classes.DataStoreService.methods.GetDataStore(self, "global")
end

------------------------------------------------------------------ MarketplaceService
class("MarketplaceService", "Instance", { signals = { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "PromptPurchaseFinished", "PromptBundlePurchaseFinished" } })
local MPS = service("MarketplaceService")
E.ownedPasses = {} -- [userId][passId] = true
E.prompts = {}
local mpm = classes.MarketplaceService.methods
function mpm.UserOwnsGamePassAsync(_, userId, passId)
	task.wait(0.05)
	return (E.ownedPasses[userId] or {})[passId] == true
end
function mpm.PlayerOwnsAsset()
	return false
end
function mpm.GetProductInfo(_, id, infoType)
	task.wait(0.05)
	return { PriceInRobux = 99, Name = "Product " .. tostring(id), IsForSale = true }
end
function mpm.PromptProductPurchase(_, player, id)
	table.insert(E.prompts, { Kind = "Product", Player = player, Id = id, At = E.now })
end
function mpm.PromptGamePassPurchase(_, player, id)
	table.insert(E.prompts, { Kind = "Pass", Player = player, Id = id, At = E.now })
end
function mpm.PromptPurchase(_, player, id)
	table.insert(E.prompts, { Kind = "Asset", Player = player, Id = id, At = E.now })
end
-- Roblox-side receipt delivery: calls ProcessReceipt like Roblox would,
-- retrying while it returns NotProcessedYet (up to `retries`).
function E.deliverReceipt(player, productId, purchaseId, retries)
	local handler = rawget(MPS, "__props").ProcessReceipt
	assert(handler, "ProcessReceipt not set")
	local receipt = {
		PlayerId = player.UserId,
		ProductId = productId,
		PurchaseId = purchaseId,
		CurrencySpent = 99,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = 0,
	}
	local results = {}
	for _ = 1, (retries or 1) do
		local ok, decision = E.call(handler, table.clone(receipt))
		if not ok then
			E.record("error", "ProcessReceipt threw: " .. tostring(decision))
			decision = Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(results, decision)
		if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
			break
		end
		E.run(1)
	end
	return results[#results], results
end

------------------------------------------------------------------ misc services
class("HttpService", "Instance", { defaults = { HttpEnabled = false } })
local HS = service("HttpService")
local guid = 0
classes.HttpService.methods.GenerateGUID = function(_, braces)
	guid += 1
	local s = string.format("%08X-0000-4000-8000-%012X", guid, guid * 7919)
	return if braces == false then s else "{" .. s .. "}"
end
classes.HttpService.methods.JSONEncode = function(_, v)
	return E.JSON.encode(v)
end
classes.HttpService.methods.JSONDecode = function(_, s)
	return E.JSON.decode(s)
end
classes.HttpService.methods.UrlEncode = function(_, s)
	return s
end

class("TweenBase", "Instance", { defaults = { PlaybackState = function()
	return Enum.PlaybackState.Begin
end }, signals = { "Completed" } })
class("Tween", "TweenBase")
class("TweenService", "Instance")
local TS = service("TweenService")
E.tweensCreated = 0
local function applyGoals(inst, goals)
	for k, v in goals do
		if not rawget(inst, "__destroyed") then
			inst[k] = v
		end
	end
end
classes.TweenService.methods.Create = function(_, inst, info, goals)
	assert(isInst(inst), "TweenService:Create expects an Instance")
	assert(type(goals) == "table", "TweenService:Create expects a goal table")
	E.tweensCreated += 1
	local t = new("Tween")
	rawset(t, "__target", inst)
	rawset(t, "__info", info)
	rawset(t, "__goals", goals)
	return t
end
classes.TweenService.methods.GetValue = function(_, alpha)
	return alpha
end
classes.TweenService.methods.SmoothDamp = function(_, cur, target)
	return target, 0
end
local tm = classes.Tween.methods
function tm.Play(t)
	local inst, info, goals = rawget(t, "__target"), rawget(t, "__info"), rawget(t, "__goals")
	local token = {}
	rawset(t, "__token", token)
	rawget(t, "__props").PlaybackState = Enum.PlaybackState.Playing
	local duration = (info.Time or 1) + (info.DelayTime or 0)
	if (info.RepeatCount or 0) < 0 then
		applyGoals(inst, goals)
		return
	end
	task.delay(duration, function()
		if rawget(t, "__token") ~= token then
			return
		end
		applyGoals(inst, goals)
		rawget(t, "__props").PlaybackState = Enum.PlaybackState.Completed
		sig(t, "Completed"):Fire(Enum.PlaybackState.Completed)
	end)
end
function tm.Cancel(t)
	rawset(t, "__token", nil)
	rawget(t, "__props").PlaybackState = Enum.PlaybackState.Cancelled
	sig(t, "Completed"):Fire(Enum.PlaybackState.Cancelled)
end
tm.Pause = tm.Cancel

class("Debris", "Instance")
service("Debris")
classes.Debris.methods.AddItem = function(_, inst, t)
	task.delay(t or 10, function()
		if not rawget(inst, "__destroyed") then
			inst:Destroy()
		end
	end)
end

class("Lighting", "Instance", {
	defaults = {
		Brightness = 2,
		ClockTime = 14,
		Ambient = Color3.new(0.3, 0.3, 0.3),
		OutdoorAmbient = Color3.new(0.5, 0.5, 0.5),
		ExposureCompensation = 0,
		GlobalShadows = true,
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
		FogEnd = 100000,
		FogStart = 0,
		Technology = function()
			return Enum.Technology.Future
		end,
	},
})
service("Lighting")
class("SoundService", "Instance", { defaults = { RespectFilteringEnabled = true, AmbientReverb = function()
	return Enum.ReverbType.NoReverb
end } })
service("SoundService")
classes.SoundService.methods.PlayLocalSound = function(_, s)
	s:Play()
end

class("PhysicsService", "Instance")
service("PhysicsService")
E.collisionGroups = { Default = true }
classes.PhysicsService.methods.RegisterCollisionGroup = function(_, name)
	E.collisionGroups[name] = true
end
classes.PhysicsService.methods.IsCollisionGroupRegistered = function(_, name)
	return E.collisionGroups[name] == true
end
classes.PhysicsService.methods.CollisionGroupSetCollidable = function(_, a, b)
	if not E.collisionGroups[a] or not E.collisionGroups[b] then
		error("CollisionGroupSetCollidable: unregistered group " .. tostring(a) .. "/" .. tostring(b), 2)
	end
end
classes.PhysicsService.methods.GetRegisteredCollisionGroups = function()
	local out = {}
	for n in E.collisionGroups do
		table.insert(out, { name = n })
	end
	return out
end

class("MessagingService", "Instance")
service("MessagingService")
classes.MessagingService.methods.PublishAsync = function() end
classes.MessagingService.methods.SubscribeAsync = function()
	return { Disconnect = function() end }
end

class("GroupService", "Instance")
service("GroupService")
classes.GroupService.methods.GetGroupsAsync = function()
	return {}
end

class("AnalyticsService", "Instance")
service("AnalyticsService")
classes.AnalyticsService.methods.LogCustomEvent = function() end
classes.AnalyticsService.methods.LogEconomyEvent = function() end
classes.AnalyticsService.methods.LogProgressionEvent = function() end
classes.AnalyticsService.methods.LogOnboardingFunnelStepEvent = function() end

class("Stats", "Instance", { defaults = { InstanceCount = 0 } })
local stats = service("Stats")
classes.Stats.methods.GetTotalMemoryUsageMb = function()
	return collectgarbage("count") / 1024
end
local network = new("Folder")
network.Name = "Network"
network.Parent = stats
local ssi = new("Folder")
ssi.Name = "ServerStatsItem"
ssi.Parent = network

class("ContentProvider", "Instance")
service("ContentProvider")
classes.ContentProvider.methods.PreloadAsync = function() end

class("ReplicatedFirst", "Instance")
service("ReplicatedFirst")
classes.ReplicatedFirst.methods.RemoveDefaultLoadingScreen = function() end

class("UserInputService", "Instance", {
	defaults = {
		TouchEnabled = false,
		KeyboardEnabled = true,
		MouseEnabled = true,
		GamepadEnabled = false,
		VREnabled = false,
		MouseBehavior = function()
			return Enum.MouseBehavior.Default
		end,
		MouseIconEnabled = true,
	},
	signals = { "InputBegan", "InputEnded", "InputChanged", "LastInputTypeChanged", "WindowFocusReleased", "WindowFocused", "TouchStarted", "TouchEnded", "JumpRequest", "GamepadConnected", "GamepadDisconnected" },
})
local UIS = service("UserInputService")
E.lastInputType = Enum.UserInputType.Keyboard
classes.UserInputService.methods.GetLastInputType = function()
	return E.lastInputType
end
classes.UserInputService.methods.IsKeyDown = function()
	return false
end
classes.UserInputService.methods.GetMouseLocation = function()
	return Vector2.new(640, 360)
end
classes.UserInputService.methods.GetConnectedGamepads = function()
	return {}
end
classes.UserInputService.methods.GetFocusedTextBox = function()
	return nil
end
classes.UserInputService.methods.GetGamepadConnected = function()
	return false
end

class("ContextActionService", "Instance")
local CAS = service("ContextActionService")
E.casBindings = {}
local casm = classes.ContextActionService.methods
function casm.BindAction(_, name, fn, touch, ...)
	E.casBindings[name] = { fn = fn, keys = { ... } }
end
function casm.BindActionAtPriority(_, name, fn, touch, priority, ...)
	E.casBindings[name] = { fn = fn, keys = { ... }, priority = priority }
end
function casm.UnbindAction(_, name)
	E.casBindings[name] = nil
end
function casm.SetTitle() end
function casm.SetImage() end
function casm.SetPosition() end
function casm.GetButton()
	return nil
end

-- Simulates a key/button press through UserInputService + ContextActionService.
function E.press(keyCode, down)
	local state = if down == false then Enum.UserInputState.End else Enum.UserInputState.Begin
	local input = { KeyCode = keyCode, UserInputType = if keyCode == Enum.KeyCode.Unknown then Enum.UserInputType.MouseButton1 else Enum.UserInputType.Keyboard, UserInputState = state, Position = Vector3.zero, Delta = Vector3.zero, __type = "InputObject" }
	for name, b in E.casBindings do
		for _, k in b.keys do
			if k == keyCode then
				task.spawn(b.fn, name, state, input)
				return
			end
		end
	end
	sig(UIS, if down == false then "InputEnded" else "InputBegan"):Fire(input, false)
end
function E.tap(keyCode, hold)
	E.press(keyCode, true)
	E.run(hold or 0.1)
	E.press(keyCode, false)
end
function E.clickMouse(down)
	local state = if down == false then Enum.UserInputState.End else Enum.UserInputState.Begin
	local input = { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.MouseButton1, UserInputState = state, Position = Vector3.zero, __type = "InputObject" }
	sig(UIS, if down == false then "InputEnded" else "InputBegan"):Fire(input, false)
end

class("GuiService", "Instance", { defaults = { SelectedObject = false, AutoSelectGuiEnabled = true, GuiNavigationEnabled = true, MenuIsOpen = false } })
service("GuiService")
classes.GuiService.methods.GetGuiInset = function()
	return Vector2.new(0, 58), Vector2.zero
end
classes.GuiService.methods.IsTenFootInterface = function()
	return false
end
classes.GuiService.set.SelectedObject = function(o, v)
	rawget(o, "__props").SelectedObject = v
end
classes.GuiService.get.SelectedObject = function(o)
	local v = rawget(o, "__props").SelectedObject
	return if v == false then nil else v
end

class("TextService", "Instance")
service("TextService")
classes.TextService.methods.GetTextSize = function(_, text, size)
	return Vector2.new(#text * size * 0.5, size)
end
class("TeleportService", "Instance")
service("TeleportService")
class("LocalizationService", "Instance", { defaults = { RobloxLocaleId = "en-us" } })
service("LocalizationService")
class("ProximityPromptService", "Instance")
service("ProximityPromptService")
class("TextChatService", "Instance")
service("TextChatService")
class("PathfindingService", "Instance")
service("PathfindingService")
class("ServerStorage", "Instance")
service("ServerStorage")
class("ServerScriptService", "Instance")
service("ServerScriptService")
class("ReplicatedStorage", "Instance")
service("ReplicatedStorage")
local starterGui = new("StarterGui")
rawset(starterGui, "__name", "StarterGui")
rawset(starterGui, "__parent", game)
table.insert(rawget(game, "__children"), starterGui)
services.StarterGui = starterGui
class("StarterPlayer", "Instance", { defaults = { CharacterUseJumpPower = true, LoadCharacterAppearance = true, AutoJumpEnabled = true, CameraMaxZoomDistance = 400, CameraMinZoomDistance = 0.5 } })
local starterPlayer = service("StarterPlayer")
local sps = new("Folder")
sps.Name = "StarterPlayerScripts"
sps.Parent = starterPlayer
local scs = new("Folder")
scs.Name = "StarterCharacterScripts"
scs.Parent = starterPlayer

E.workspace = workspace
E.Players = Players
E.MPS = MPS
E.UIS = UIS

------------------------------------------------------------------ players lifecycle
local nextUserId = 1000
function E.addPlayer(name, opts)
	opts = opts or {}
	nextUserId += 1
	local p = new("Player")
	rawset(p, "__name", name)
	rawget(p, "__props").UserId = opts.UserId or nextUserId
	rawget(p, "__props").DisplayName = name
	local gui = new("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = p
	local ps = new("PlayerScripts")
	ps.Name = "PlayerScripts"
	ps.Parent = p
	local bp = new("Backpack")
	bp.Name = "Backpack"
	bp.Parent = p
	p.Parent = Players
	if opts.client then
		E.localPlayer = p
	end
	sig(Players, "PlayerAdded"):Fire(p)
	if Players.CharacterAutoLoads then
		task.defer(function()
			if p.Parent then
				p:LoadCharacterAsync()
			end
		end)
	end
	return p
end
function E.removePlayer(p)
	if not p.Parent then
		return
	end
	sig(Players, "PlayerRemoving"):Fire(p)
	local character = rawget(p, "__props").Character
	if character then
		character:Destroy()
	end
	if p == E.localPlayer then
		E.clientRunning = false
	end
	p:Destroy()
end
