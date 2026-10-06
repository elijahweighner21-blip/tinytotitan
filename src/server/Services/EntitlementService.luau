--!strict
--[[
	EntitlementService
	Game Pass ownership, checked on the server only. Ownership is fetched with
	UserOwnsGamePassAsync (with retries) when the player joins and updated by
	PromptGamePassPurchaseFinished, so permanent purchases are recognised in
	every server, after rejoining and after respawning.

	Studio: admins can toggle simulated ownership (SetTestOwnership) to test
	pass perks. That path is refused outside Studio.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Signal = require(Shared.Util.Signal)
local Retry = require(Shared.Util.Retry)
local Log = require(Shared.Util.Log)

local EntitlementService = {}

-- (player, passKey, owned)
EntitlementService.OwnershipChanged = Signal.new() :: Signal.Signal<Player, string, boolean>

local owned: { [Player]: { [string]: boolean } } = {}
local checked: { [Player]: boolean } = {}

local function setOwned(player: Player, key: string, value: boolean)
	local map = owned[player]
	if not map then
		map = {}
		owned[player] = map
	end
	if map[key] == value then
		return
	end
	map[key] = value
	player:SetAttribute("Pass_" .. key, value)
	EntitlementService.OwnershipChanged:Fire(player, key, value)
end

local function checkAll(player: Player)
	for key, pass in MonetizationConfig.GamePasses do
		if pass.PassId ~= 0 then
			local ok, result = Retry.call(3, 1, function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.PassId)
			end)
			if ok then
				setOwned(player, key, result == true)
			else
				Log.warn("Entitlement", "ownership check failed", key, player.UserId, result)
			end
		end
	end
	checked[player] = true
	player:SetAttribute("PassesChecked", true)
end

function EntitlementService:Owns(player: Player, key: string): boolean
	local map = owned[player]
	return map ~= nil and map[key] == true
end

function EntitlementService:IsChecked(player: Player): boolean
	return checked[player] == true
end

function EntitlementService:OwnedList(player: Player): { [string]: boolean }
	return table.clone(owned[player] or {})
end

function EntitlementService:SetTestOwnership(player: Player, key: string, value: boolean): boolean
	if not RunService:IsStudio() or not MonetizationConfig.GamePasses[key] then
		return false
	end
	setOwned(player, key, value)
	return true
end

function EntitlementService:Start()
	Players.PlayerAdded:Connect(function(player)
		checkAll(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkAll, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		checked[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = MonetizationConfig.passByRobloxId(passId)
		if not pass then
			Log.warn("Entitlement", "purchase of unknown pass id", passId)
			return
		end
		-- Re-verify with Roblox rather than trusting the event alone.
		local ok, result = Retry.call(3, 1, function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		setOwned(player, pass.Key, if ok then result == true else true)
	end)
end

return EntitlementService
