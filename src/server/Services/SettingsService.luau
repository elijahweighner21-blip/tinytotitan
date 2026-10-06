--!strict
--[[
	SettingsService
	Persists client settings. Every key is validated against the schema
	defaults (type) and clamped by DataSchema.sanitize, so a client can't
	store junk, huge strings or unknown keys in its save.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataSchema = require(Shared.Data.DataSchema)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SettingsService = {}

local defaults = DataSchema.Defaults.Settings :: { [string]: any }

local function validate(payload: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "expected table"
	end
	local count = 0
	for key, value in payload do
		count += 1
		if count > 30 or type(key) ~= "string" or defaults[key] == nil then
			return false, "unknown setting"
		end
		if type(value) ~= type(defaults[key]) then
			return false, "wrong type for " .. key
		end
		if type(value) == "string" and #value > 16 then
			return false, "string too long"
		end
	end
	return true, nil
end

function SettingsService:Init()
	Net.onRequest("SaveSettings", validate, function(player, payload)
		local data = PlayerDataService:Get(player)
		if not data then
			return { ok = false }
		end
		local settings = data.Settings :: any
		for key, value in payload do
			settings[key] = value
		end
		-- Clamp ranges / enums through the shared sanitiser.
		DataSchema.sanitize(data :: any)
		PlayerDataService:Changed(player, "Settings")
		return { ok = true }
	end)
end

return SettingsService
