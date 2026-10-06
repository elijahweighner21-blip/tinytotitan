--!strict
--[[
	ShopRotation
	Deterministic daily cosmetic shop. The selection depends only on the day
	number, so every server shows the same items and the client can never
	choose its own inventory. Limited items appear only inside their window.
]]

local CosmeticConfig = require(script.Parent.Parent.Config.CosmeticConfig)
local DailyConfig = require(script.Parent.Parent.Config.DailyConfig)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local ShopRotation = {}

-- Items always purchasable (Source = "Shop" and currently available).
function ShopRotation.permanent(now: number): { string }
	local out = {}
	for _, c in CosmeticConfig.List do
		if c.Price and (c.Source == "Shop" or c.Source == "Event") and CosmeticConfig.isAvailable(c, now) then
			table.insert(out, c.Id)
		end
	end
	return out
end

-- Rotating items for a given day.
function ShopRotation.daily(day: number): { string }
	local pool = {}
	for _, c in CosmeticConfig.List do
		if c.Source == "Daily" and c.Price then
			table.insert(pool, c.Id)
		end
	end
	table.sort(pool)
	local shuffled = TableUtil.seededShuffle(pool, day * 7919 + 17)
	local out = {}
	for i = 1, math.min(DailyConfig.DailyShopSlots, #shuffled) do
		out[i] = shuffled[i]
	end
	return out
end

function ShopRotation.isPurchasable(cosmeticId: string, day: number, now: number): boolean
	local c = CosmeticConfig.get(cosmeticId)
	if not c or not c.Price or not CosmeticConfig.isAvailable(c, now) then
		return false
	end
	if c.Source == "Shop" or c.Source == "Event" then
		return true
	end
	if c.Source == "Daily" then
		return table.find(ShopRotation.daily(day), cosmeticId) ~= nil
	end
	return false
end

return ShopRotation
