--!strict
--[[
	Net (server)
	Creates the six remotes and dispatches client messages to handlers.

	Every inbound message passes, in order:
	  1. name lookup (unknown names are dropped and counted as suspicious)
	  2. per-player, per-name token-bucket rate limit (Shared/Net limits)
	  3. "data loaded" gate (nothing is processed before the profile loads)
	  4. payload Guard validation (shape/type/range)
	  5. the handler, wrapped in pcall so one bad request cannot break others

	Requests always return a table { ok = boolean, err = string?, ... }.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetDefs = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local Guard = require(Shared.Util.Guard)
local Log = require(Shared.Util.Log)

export type Result = { [string]: any }
type Handler = (player: Player, payload: any) -> ...any

local Net = {}

local folder: Folder
local remotes: { [string]: Instance } = {}
local actionHandlers: { [string]: { guard: Guard.Check, fn: Handler } } = {}
local requestHandlers: { [string]: { guard: Guard.Check, fn: Handler } } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}
local readyCheck: ((player: Player) -> boolean)? = nil
local suspiciousHook: ((player: Player, reason: string) -> ())? = nil

local function limiterFor(name: string, def: NetDefs.Limit): RateLimiter.RateLimiter
	local limiter = limiters[name]
	if not limiter then
		limiter = RateLimiter.new(def.Rate, def.Burst)
		limiters[name] = limiter
	end
	return limiter
end

local function flag(player: Player, reason: string)
	if suspiciousHook then
		suspiciousHook(player, reason)
	end
end

local function admit(player: Player, name: any, payload: any, defs: { [string]: NetDefs.Limit }, handlers: any): (Handler?, any)
	if type(name) ~= "string" or #name > 40 then
		flag(player, "malformed remote name")
		return nil, "bad request"
	end
	local def = defs[name]
	local entry = handlers[name]
	if not def or not entry then
		flag(player, "unknown remote " .. name)
		return nil, "unknown request"
	end
	if not limiterFor(name, def):Check(player) then
		-- Silently drop: over-limit traffic is usually lag bursts or spam.
		return nil, "rate limited"
	end
	if readyCheck and name ~= "ClientReady" and not readyCheck(player) then
		return nil, "loading"
	end
	local ok, err = entry.guard(payload)
	if not ok then
		flag(player, string.format("invalid payload for %s: %s", name, tostring(err)))
		return nil, "invalid payload"
	end
	return entry.fn, nil
end

function Net.init()
	folder = Instance.new("Folder")
	folder.Name = NetDefs.FolderName
	for name, className in NetDefs.Remotes do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage

	local action = remotes.Action :: RemoteEvent
	action.OnServerEvent:Connect(function(player: Player, name: any, payload: any)
		local fn = admit(player, name, payload, NetDefs.Actions, actionHandlers)
		if fn then
			local ok, err = pcall(fn, player, payload)
			if not ok then
				Log.error("Net", "action", name, "failed:", err)
			end
		end
	end)

	local request = remotes.Request :: RemoteFunction
	request.OnServerInvoke = function(player: Player, name: any, payload: any): Result
		local fn, reason = admit(player, name, payload, NetDefs.Requests, requestHandlers)
		if not fn then
			return { ok = false, err = reason }
		end
		local ok, result = pcall(fn, player, payload)
		if not ok then
			Log.error("Net", "request", name, "failed:", result)
			return { ok = false, err = "server error" }
		end
		if type(result) ~= "table" then
			return { ok = result == true }
		end
		return result
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Reset(player)
		end
	end)
end

function Net.setReadyCheck(fn: (player: Player) -> boolean)
	readyCheck = fn
end

function Net.setSuspiciousHook(fn: (player: Player, reason: string) -> ())
	suspiciousHook = fn
end

function Net.onAction(name: string, guard: Guard.Check?, fn: Handler)
	assert(NetDefs.Actions[name], "action not declared in Shared/Net: " .. name)
	assert(not actionHandlers[name], "duplicate action handler " .. name)
	actionHandlers[name] = { guard = guard or Guard.any(), fn = fn }
end

function Net.onRequest(name: string, guard: Guard.Check?, fn: Handler)
	assert(NetDefs.Requests[name], "request not declared in Shared/Net: " .. name)
	assert(not requestHandlers[name], "duplicate request handler " .. name)
	requestHandlers[name] = { guard = guard or Guard.any(), fn = fn }
end

function Net.signal(player: Player, name: string, payload: any?)
	if not NetDefs.Signals[name] then
		Log.warn("Net", "undeclared signal", name)
	end
	if player.Parent then
		(remotes.Signal :: RemoteEvent):FireClient(player, name, payload)
	end
end

function Net.signalAll(name: string, payload: any?)
	(remotes.Signal :: RemoteEvent):FireAllClients(name, payload)
end

function Net.state(player: Player, kind: string, payload: any)
	if player.Parent then
		(remotes.State :: RemoteEvent):FireClient(player, kind, payload)
	end
end

-- Cosmetic effect broadcast (unreliable). Clients filter by distance/settings.
function Net.fx(name: string, payload: { [string]: any })
	(remotes.Fx :: UnreliableRemoteEvent):FireAllClients(name, payload)
end

function Net.fxTo(player: Player, name: string, payload: { [string]: any })
	if player.Parent then
		(remotes.Fx :: UnreliableRemoteEvent):FireClient(player, name, payload)
	end
end

function Net.energy(player: Player, payload: { [string]: any })
	if player.Parent then
		(remotes.Energy :: UnreliableRemoteEvent):FireClient(player, payload)
	end
end

-- For the remote audit tooling / debug panel.
function Net.registeredHandlers(): { actions: { string }, requests: { string } }
	local a, r = {}, {}
	for name in actionHandlers do
		table.insert(a, name)
	end
	for name in requestHandlers do
		table.insert(r, name)
	end
	table.sort(a)
	table.sort(r)
	return { actions = a, requests = r }
end

return Net
