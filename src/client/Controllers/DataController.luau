--!strict
--[[
	DataController
	Client mirror of the player's own save data (server-replicated through the
	State remote; server-only keys such as receipts are never sent). Purely a
	read model: changing it locally does nothing — every change goes through
	a validated request.

	  DataController:Get() -> data?          DataController.Changed:Connect(fn(key))
	  DataController:WaitForData() -> data   DataController.Loaded (Signal)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Stats = require(Shared.Formulas.Stats)
local Progression = require(Shared.Formulas.Progression)

local Net = require(script.Parent.Parent.Net)

local DataController = {}

DataController.Changed = Signal.new() :: Signal.Signal<string>
DataController.Loaded = Signal.new() :: Signal.Signal<any>
DataController.StatsChanged = Signal.new() :: Signal.Signal<>

local data: any = nil
local stats: Stats.StatTable = Stats.empty()
local player = Players.LocalPlayer

local STAT_KEYS = { Upgrades = true, Skills = true, Ascension = true }

local function recomputeStats()
	if not data then
		return
	end
	stats = Stats.compute({ Upgrades = data.Upgrades, Skills = data.Skills, AscensionTree = data.Ascension.Tree })
	DataController.StatsChanged:Fire()
end

function DataController:Get(): any
	return data
end

function DataController:IsLoaded(): boolean
	return data ~= nil
end

function DataController:WaitForData(): any
	while not data do
		DataController.Loaded:Wait()
	end
	return data
end

function DataController:GetStats(): Stats.StatTable
	return stats
end

-- Gameplay scale published by the server (includes Shrink/Overgrowth).
function DataController:GetScale(): number
	return (player:GetAttribute("Scale") :: number?) or 0.2
end

function DataController:GetDerived(): Stats.Derived
	return Stats.derive(stats, DataController:GetScale())
end

function DataController:GetTier(): number
	if data then
		return Progression.tierForMass(data.Currencies.Mass)
	end
	return 1
end

function DataController:Init()
	Net.onState(function(kind, payload)
		if type(payload) ~= "table" then
			return
		end
		if kind == "Full" then
			local first = data == nil
			data = payload
			recomputeStats()
			if first then
				DataController.Loaded:Fire(data)
			end
			for key in payload do
				DataController.Changed:Fire(key)
			end
		elseif kind == "Patch" and data then
			for key, value in payload do
				data[key] = value
				if STAT_KEYS[key] then
					recomputeStats()
				end
				DataController.Changed:Fire(key)
			end
		end
	end)
	player:GetAttributeChangedSignal("Scale"):Connect(function()
		DataController.StatsChanged:Fire()
	end)
end

function DataController:Start()
	-- Ask for the full snapshot once the server says our data is ready.
	local function ready()
		Net.action("ClientReady")
	end
	if player:GetAttribute("DataLoaded") then
		ready()
	else
		player:GetAttributeChangedSignal("DataLoaded"):Once(ready)
	end
	-- Keep asking until the snapshot arrives, in case a request raced the
	-- server's load or was dropped.
	task.spawn(function()
		while not data and player.Parent do
			task.wait(5)
			if not data and player:GetAttribute("DataLoaded") then
				ready()
			end
		end
	end)
end

return DataController
