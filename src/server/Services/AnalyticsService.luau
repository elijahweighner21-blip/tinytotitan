--!strict
--[[
	AnalyticsService
	Modular, privacy-conscious analytics hooks. Records aggregate counters
	(funnel steps, shop views, purchases, economy flow) keyed only by event
	name — no personal data is stored. If Roblox's AnalyticsService is
	available, custom/economy events are forwarded to it (pcall-wrapped so
	analytics can never break gameplay).

	Client UI may report a small whitelist of view events (Analytics action);
	these are counted but never grant anything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guard = require(Shared.Util.Guard)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local CurrencyService = require(script.Parent.CurrencyService)

local AnalyticsService = {}

local counters: { [string]: number } = {}
local robloxAnalytics: any = nil

local CLIENT_EVENTS = {
	ShopOpened = true,
	ShopCategory = true,
	ProductViewed = true,
	MenuOpened = true,
	TutorialHint = true,
	WelcomeShown = true,
} :: { [string]: boolean }

function AnalyticsService:Track(player: Player?, event: string, value: number?, detail: string?)
	local key = if detail then event .. ":" .. detail else event
	counters[key] = (counters[key] or 0) + (value or 1)
	if robloxAnalytics and player then
		pcall(function()
			robloxAnalytics:LogCustomEvent(player, event, value or 1)
		end)
	end
end

function AnalyticsService:Snapshot(): { [string]: number }
	return table.clone(counters)
end

function AnalyticsService:Init()
	local ok, service = pcall(function()
		return game:GetService("AnalyticsService")
	end)
	if ok then
		robloxAnalytics = service
	end
	Net.onAction(
		"Analytics",
		Guard.shape({ Event = Guard.id(32), Detail = Guard.optional(Guard.id(48)) }),
		function(player, payload)
			if CLIENT_EVENTS[payload.Event] then
				AnalyticsService:Track(player, payload.Event, 1, payload.Detail)
			end
		end
	)
end

function AnalyticsService:Start()
	CurrencyService.Transaction:Connect(function(player, currency, delta, source)
		AnalyticsService:Track(nil, if delta >= 0 then "Source" else "Sink", math.abs(delta), currency .. ":" .. source)
		if robloxAnalytics and (currency == "GrowthEnergy" or currency == "TitanShards") then
			pcall(function()
				robloxAnalytics:LogEconomyEvent(
					player,
					if delta >= 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
					currency,
					math.abs(delta),
					CurrencyService:Get(player, currency),
					source
				)
			end)
		end
	end)
	Players.PlayerAdded:Connect(function()
		AnalyticsService:Track(nil, "Join")
	end)
	-- Periodic compact summary in Studio for balancing sessions.
	task.spawn(function()
		while true do
			task.wait(600)
			if Log.isDebug() then
				local n = 0
				for _ in counters do
					n += 1
				end
				Log.debug("Analytics", n, "distinct counters tracked")
			end
		end
	end)
end

return AnalyticsService
