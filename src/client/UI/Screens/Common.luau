--!strict
--[[
	Common
	Small helpers shared by menu screens: server requests with consistent
	error feedback, cost formatting and affordability checks against the
	replicated data (the server re-checks everything).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CurrencyConfig = require(Shared.Config.CurrencyConfig)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Client = UI.Parent
local Net = require(Client.Net)
local Bus = require(UI.Bus)
local Sound = require(UI.Sound)
local DataController = require(Client.Controllers.DataController)

local Common = {}

-- Sends a request; toasts the server's error on failure. Returns the result.
function Common.request(name: string, payload: any?, successText: string?): { [string]: any }
	local result = Net.request(name, payload)
	if result.ok then
		Sound.play("Purchase")
		if successText then
			Bus.toast(successText, "Success")
		end
	else
		Sound.play("Error")
		Bus.toast(tostring(result.err or "Something went wrong — please try again"), "Warning")
	end
	return result
end

function Common.balance(id: string): number
	local data = DataController:Get()
	if not data then
		return 0
	end
	return data.Currencies[id] or data.Resources[id] or 0
end

function Common.canAfford(costs: { [string]: number }): boolean
	for id, amount in costs do
		if Common.balance(id) < amount then
			return false
		end
	end
	return true
end

function Common.costText(id: string, amount: number): string
	local d = CurrencyConfig.display(id)
	return d.Icon .. " " .. Format.abbreviate(amount)
end

function Common.costsText(costs: { [string]: number }): string
	local parts = {}
	for id, amount in costs do
		if amount > 0 then
			table.insert(parts, Common.costText(id, amount))
		end
	end
	table.sort(parts)
	return table.concat(parts, "  +  ")
end

function Common.rewardText(reward: { [string]: any }?): string
	if not reward then
		return ""
	end
	local parts = {}
	for _, id in { "Mass", "GrowthEnergy", "TitanShards", "XP", "SkillPoints", "AscensionPoints", "ExplorationTokens" } do
		local n = tonumber(reward[id])
		if n and n > 0 then
			if id == "XP" then
				table.insert(parts, "+" .. Format.abbreviate(n) .. " XP")
			else
				table.insert(parts, "+" .. Common.costText(id, n))
			end
		end
	end
	if type(reward.Resources) == "table" then
		for id, n in reward.Resources do
			table.insert(parts, "+" .. Common.costText(id, n))
		end
	end
	return table.concat(parts, "   ")
end

return Common
