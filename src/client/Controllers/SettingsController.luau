--!strict
--[[
	SettingsController
	Local, instantly-applied player settings. Values start from the saved
	settings (replicated data) and are persisted with a debounced
	SaveSettings request. Every other controller reads settings from here and
	listens to `Changed` so toggles apply immediately.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataSchema = require(Shared.Data.DataSchema)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)

local Net = require(script.Parent.Parent.Net)
local DataController = require(script.Parent.DataController)

local SettingsController = {}

SettingsController.Changed = Signal.new() :: Signal.Signal<string, any>

local settings: { [string]: any } = TableUtil.deepCopy(DataSchema.Defaults.Settings :: any)
local dirty: { [string]: any } = {}
local saveScheduled = false
local receivedServer = false

function SettingsController:Get(key: string): any
	return settings[key]
end

function SettingsController:All(): { [string]: any }
	return settings
end

function SettingsController:Set(key: string, value: any)
	if settings[key] == value or (DataSchema.Defaults.Settings :: any)[key] == nil then
		return
	end
	settings[key] = value
	dirty[key] = value
	SettingsController.Changed:Fire(key, value)
	if not saveScheduled then
		saveScheduled = true
		task.delay(2, function()
			saveScheduled = false
			local payload = dirty
			dirty = {}
			if next(payload) then
				Net.request("SaveSettings", payload)
			end
		end)
	end
end

function SettingsController:Init()
	DataController.Changed:Connect(function(key)
		if key ~= "Settings" or receivedServer then
			return
		end
		-- Adopt the saved settings once; afterwards the client is the source
		-- of truth for its own toggles (server only validates/stores them).
		receivedServer = true
		local saved = (DataController:Get() :: any).Settings
		for k, v in saved do
			if settings[k] ~= v then
				settings[k] = v
				SettingsController.Changed:Fire(k, v)
			end
		end
	end)
end

return SettingsController
