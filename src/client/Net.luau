--!strict
--[[
	Net (client)
	Thin wrapper over the six remotes defined in Shared/Net.

	  Net.action(name, payload)            fire-and-forget (validated server-side)
	  Net.request(name, payload) -> table  never throws; { ok = false, err } on failure
	  Net.onSignal(name, fn)               server notifications (buffered until a
	                                       handler exists, so nothing sent during
	                                       loading is lost)
	  Net.onState(fn), Net.onFx(name, fn), Net.onEnergy(fn)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetDefs = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local Net = {}

local folder = ReplicatedStorage:WaitForChild(NetDefs.FolderName)
local Action = folder:WaitForChild("Action") :: RemoteEvent
local Request = folder:WaitForChild("Request") :: RemoteFunction
local State = folder:WaitForChild("State") :: RemoteEvent
local SignalRemote = folder:WaitForChild("Signal") :: RemoteEvent
local Fx = folder:WaitForChild("Fx") :: UnreliableRemoteEvent
local Energy = folder:WaitForChild("Energy") :: UnreliableRemoteEvent

local signalHandlers: { [string]: Signal.Signal<any> } = {}
local buffered: { [string]: { { payload: any, at: number } } } = {}
local fxHandlers: { [string]: Signal.Signal<any> } = {}

local BUFFER_SECONDS = 15

function Net.action(name: string, payload: any?)
	if not NetDefs.Actions[name] then
		warn("[Net] undeclared action", name)
		return
	end
	Action:FireServer(name, payload)
end

function Net.request(name: string, payload: any?): { [string]: any }
	if not NetDefs.Requests[name] then
		warn("[Net] undeclared request", name)
		return { ok = false, err = "invalid request" }
	end
	local ok, result = pcall(function()
		return Request:InvokeServer(name, payload)
	end)
	if not ok or type(result) ~= "table" then
		return { ok = false, err = "Connection problem, please try again" }
	end
	return result
end

function Net.onSignal(name: string, fn: (payload: any) -> ()): Signal.Connection
	local s = signalHandlers[name]
	if not s then
		s = Signal.new()
		signalHandlers[name] = s
	end
	local connection = s:Connect(fn)
	local pending = buffered[name]
	if pending then
		buffered[name] = nil
		local now = os.clock()
		for _, entry in pending do
			if now - entry.at <= BUFFER_SECONDS then
				task.spawn(fn, entry.payload)
			end
		end
	end
	return connection
end

function Net.onState(fn: (kind: string, payload: any) -> ()): RBXScriptConnection
	return State.OnClientEvent:Connect(fn)
end

function Net.onFx(name: string, fn: (payload: any) -> ()): Signal.Connection
	local s = fxHandlers[name]
	if not s then
		s = Signal.new()
		fxHandlers[name] = s
	end
	return s:Connect(fn)
end

function Net.onEnergy(fn: (payload: any) -> ()): RBXScriptConnection
	return Energy.OnClientEvent:Connect(fn)
end

SignalRemote.OnClientEvent:Connect(function(name: string, payload: any)
	local s = signalHandlers[name]
	if s then
		s:Fire(payload)
	else
		local list = buffered[name] or {}
		buffered[name] = list
		table.insert(list, { payload = payload, at = os.clock() })
		if #list > 20 then
			table.remove(list, 1)
		end
	end
end)

Fx.OnClientEvent:Connect(function(name: string, payload: any)
	local s = fxHandlers[name]
	if s then
		s:Fire(payload)
	end
end)

return Net
