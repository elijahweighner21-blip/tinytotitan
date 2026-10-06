--!strict
--[[
	ShopService
	The shop catalog (Robux items from MonetizationService + cosmetics) and
	purchases of cosmetics with gameplay currency. The rotating daily shop is
	deterministic (Formulas/ShopRotation) and limited-time items vanish
	automatically outside their configured window — the client never chooses
	what is for sale, and every purchase is re-validated on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local DailyConfig = require(Shared.Config.DailyConfig)
local GameConfig = require(Shared.Config.GameConfig)
local ShopRotation = require(Shared.Formulas.ShopRotation)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local MonetizationService = require(script.Parent.MonetizationService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ShopService = {}

local function today(): number
	return DailyConfig.dayNumber(os.time(), GameConfig.DailyResetHourUtc)
end

local function secondsUntilReset(): number
	local now = os.time()
	local day = today()
	local nextReset = (day + 1) * 86400 + GameConfig.DailyResetHourUtc * 3600
	return math.max(0, nextReset - now)
end

function ShopService:Init()
	Net.onRequest("ShopCatalog", Guard.none(), function(player)
		local now = os.time()
		local limited = {}
		for _, c in CosmeticConfig.List do
			if c.Limited and CosmeticConfig.isAvailable(c, now) then
				table.insert(limited, { Id = c.Id, Ends = c.Limited.End, Event = c.Limited.Event })
			end
		end
		local catalog = MonetizationService:GetCatalog(player)
		catalog.Cosmetics = {
			Permanent = ShopRotation.permanent(now),
			Daily = ShopRotation.daily(today()),
			Limited = limited,
			ResetsIn = secondsUntilReset(),
		}
		return { ok = true, Catalog = catalog }
	end)

	Net.onRequest("ShopPurchase", Guard.shape({ Id = Guard.id() }), function(player, payload)
		local def = CosmeticConfig.get(payload.Id)
		local data = PlayerDataService:Get(player)
		if not def or not data or not def.Price then
			return { ok = false, err = "Not for sale" }
		end
		if data.Cosmetics.Owned[def.Id] then
			return { ok = false, err = "Already owned" }
		end
		if not ShopRotation.isPurchasable(def.Id, today(), os.time()) then
			return { ok = false, err = "Not in the shop right now" }
		end
		if not CurrencyService:Remove(player, def.Price.Currency, def.Price.Amount, "Shop:" .. def.Id) then
			return { ok = false, err = "Not enough " .. (if def.Price.Currency == "TitanShards" then "Titan Shards" else "Growth Energy") }
		end
		InventoryService:GrantCosmetic(player, def.Id)
		AnalyticsService:Track(player, "ShopPurchase", 1, def.Id)
		return { ok = true }
	end)
end

return ShopService
