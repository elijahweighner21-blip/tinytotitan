--!strict
--[[
	UpgradeService
	Buys stat upgrades with Growth Energy (plus zone resources on some
	levels). Every purchase is validated server-side: known upgrade, size
	requirement, level cap, price computed by the server (Pricing) with the
	player's own discount, and an atomic multi-currency spend.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local Pricing = require(Shared.Formulas.Pricing)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local StatService = require(script.Parent.StatService)
local StatisticsService = require(script.Parent.StatisticsService)
local ProgressionService = require(script.Parent.ProgressionService)

local UpgradeService = {}

-- Price of the next level for a player (server truth; UI shows the same).
function UpgradeService:GetPrice(player: Player, upgradeId: string): (number?, string?, number)
	local def = UpgradeConfig.get(upgradeId)
	local data = PlayerDataService:Get(player)
	if not def or not data then
		return nil, nil, 0
	end
	local level = data.Upgrades[upgradeId] or 0
	local discount = StatService:Get(player, "UpgradeDiscount")
	local cost = Pricing.upgradeCost(def, level, discount)
	local resource, amount = Pricing.resourceCost(def, level)
	return cost, resource, amount
end

function UpgradeService:Buy(player: Player, upgradeId: string): { [string]: any }
	local def = UpgradeConfig.get(upgradeId)
	local data = PlayerDataService:Get(player)
	if not def or not data then
		return { ok = false, err = "Unknown upgrade" }
	end
	local tier = ProgressionService:GetTier(player)
	if def.RequiredTier and tier < def.RequiredTier then
		return { ok = false, err = "Unlocks at " .. SizeConfig.getTier(def.RequiredTier).Name }
	end
	local level = data.Upgrades[upgradeId] or 0
	if level >= def.MaxLevel then
		return { ok = false, err = "Max level" }
	end
	local cost, resource, amount = UpgradeService:GetPrice(player, upgradeId)
	if not cost or cost == math.huge then
		return { ok = false, err = "Unavailable" }
	end
	local costs: { [string]: number } = { [def.Currency] = cost }
	if resource and amount > 0 then
		costs["Resource:" .. resource] = amount
	end
	if not CurrencyService:Spend(player, costs, "Upgrade:" .. upgradeId) then
		return { ok = false, err = "Not enough " .. (if resource and CurrencyService:GetResource(player, resource) < amount then resource else "Growth Energy") }
	end
	data.Upgrades[upgradeId] = level + 1
	PlayerDataService:Changed(player, "Upgrades")
	StatService:Invalidate(player)
	StatisticsService:Increment(player, "UpgradesBought")
	GameEvents.fire("UpgradeBought", player, upgradeId, level + 1)
	return { ok = true, level = level + 1 }
end

function UpgradeService:Init()
	Net.onRequest("BuyUpgrade", Guard.shape({ Id = Guard.id() }), function(player, payload)
		return UpgradeService:Buy(player, payload.Id)
	end)
end

return UpgradeService
