--!strict
--[[
	CurrencyService
	The ONLY code path allowed to change currency or resource balances.
	Every change is validated (finite, positive amount, known currency),
	clamped to GameConfig.MaxCurrency, replicated, and announced through
	`Transaction` so analytics and anti-exploit can audit the economy.

	  :Get(player, currency)              :Add(player, currency, amount, source)
	  :Remove(player, currency, amount, source)
	  :CanAfford(player, costs)           :Spend(player, costs, source)  (atomic)
	  Resources use the same API with `Resources.<Id>` semantics via the
	  *Resource variants.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local DataSchema = require(Shared.Data.DataSchema)
local MathUtil = require(Shared.Util.MathUtil)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Util.Log)

local PlayerDataService = require(script.Parent.PlayerDataService)

export type Costs = { [string]: number } -- currency or "Resource:<Id>" -> amount

local CurrencyService = {}

-- (player, currency, newValue, delta)
CurrencyService.Changed = Signal.new() :: Signal.Signal<Player, string, number, number>
-- (player, currency, delta, source) — fired for every successful change
CurrencyService.Transaction = Signal.new() :: Signal.Signal<Player, string, number, string>

local VALID_CURRENCY: { [string]: boolean } = {}
for key in DataSchema.Defaults.Currencies :: any do
	VALID_CURRENCY[key] = true
end
local VALID_RESOURCE: { [string]: boolean } = {}
for key in DataSchema.Defaults.Resources :: any do
	VALID_RESOURCE[key] = true
end

-- Single transactions above this many times the player's current balance
-- (and above an absolute floor) are logged for review. Never blocked.
local UNUSUAL_RATIO = 50
local UNUSUAL_FLOOR = 1e5

local function validAmount(amount: number): boolean
	return MathUtil.isFinite(amount) and amount > 0
end

function CurrencyService:IsCurrency(id: string): boolean
	return VALID_CURRENCY[id] == true
end

function CurrencyService:IsResource(id: string): boolean
	return VALID_RESOURCE[id] == true
end

function CurrencyService:Get(player: Player, currency: string): number
	local data = PlayerDataService:Get(player)
	if not data or not VALID_CURRENCY[currency] then
		return 0
	end
	return (data.Currencies :: any)[currency] or 0
end

function CurrencyService:GetResource(player: Player, resource: string): number
	local data = PlayerDataService:Get(player)
	if not data or not VALID_RESOURCE[resource] then
		return 0
	end
	return (data.Resources :: any)[resource] or 0
end

local function audit(player: Player, currency: string, before: number, delta: number, source: string)
	if math.abs(delta) > UNUSUAL_FLOOR and math.abs(delta) > math.max(before, 1) * UNUSUAL_RATIO then
		Log.warn(
			"Economy",
			string.format("unusual %s %+g for %d (balance %g) from %s", currency, delta, player.UserId, before, source)
		)
	end
end

local function apply(player: Player, bucket: string, id: string, delta: number, source: string): boolean
	local data = PlayerDataService:Get(player)
	if not data then
		return false
	end
	local map = (data :: any)[bucket]
	local before = map[id] or 0
	local after = math.clamp(before + delta, 0, GameConfig.MaxCurrency)
	if delta < 0 and before + delta < -1e-9 then
		return false
	end
	map[id] = after
	PlayerDataService:Changed(player, bucket)
	audit(player, id, before, delta, source)
	local label = if bucket == "Resources" then "Resource:" .. id else id
	CurrencyService.Changed:Fire(player, label, after, after - before)
	CurrencyService.Transaction:Fire(player, label, after - before, source)
	return true
end

function CurrencyService:Add(player: Player, currency: string, amount: number, source: string): boolean
	if not VALID_CURRENCY[currency] or not validAmount(amount) then
		Log.warn("Economy", "rejected Add", currency, amount, source)
		return false
	end
	return apply(player, "Currencies", currency, amount, source)
end

function CurrencyService:Remove(player: Player, currency: string, amount: number, source: string): boolean
	if not VALID_CURRENCY[currency] or not validAmount(amount) then
		return false
	end
	if CurrencyService:Get(player, currency) < amount then
		return false
	end
	return apply(player, "Currencies", currency, -amount, source)
end

-- Sets a currency directly (admin tools / ascension resets only).
function CurrencyService:Set(player: Player, currency: string, value: number, source: string): boolean
	if not VALID_CURRENCY[currency] or not MathUtil.isFinite(value) then
		return false
	end
	local current = CurrencyService:Get(player, currency)
	local target = math.clamp(value, 0, GameConfig.MaxCurrency)
	if target == current then
		return true
	end
	return apply(player, "Currencies", currency, target - current, source)
end

function CurrencyService:AddResource(player: Player, resource: string, amount: number, source: string): boolean
	if not VALID_RESOURCE[resource] or not validAmount(amount) then
		return false
	end
	return apply(player, "Resources", resource, math.floor(amount), source)
end

function CurrencyService:RemoveResource(player: Player, resource: string, amount: number, source: string): boolean
	if not VALID_RESOURCE[resource] or not validAmount(amount) then
		return false
	end
	if CurrencyService:GetResource(player, resource) < amount then
		return false
	end
	return apply(player, "Resources", resource, -amount, source)
end

local function parseCost(key: string): (string, string)
	if string.sub(key, 1, 9) == "Resource:" then
		return "Resources", string.sub(key, 10)
	end
	return "Currencies", key
end

function CurrencyService:CanAfford(player: Player, costs: Costs): boolean
	for key, amount in costs do
		if not MathUtil.isFinite(amount) or amount < 0 then
			return false
		end
		local bucket, id = parseCost(key)
		local have = if bucket == "Resources"
			then CurrencyService:GetResource(player, id)
			else CurrencyService:Get(player, id)
		if have < amount then
			return false
		end
	end
	return true
end

-- Deducts every cost or nothing. Returns false if unaffordable.
function CurrencyService:Spend(player: Player, costs: Costs, source: string): boolean
	if not CurrencyService:CanAfford(player, costs) then
		return false
	end
	for key, amount in costs do
		if amount > 0 then
			local bucket, id = parseCost(key)
			local ok = if bucket == "Resources"
				then CurrencyService:RemoveResource(player, id, amount, source)
				else CurrencyService:Remove(player, id, amount, source)
			if not ok then
				-- Cannot happen after CanAfford in a single-threaded frame;
				-- logged loudly if it ever does.
				Log.error("Economy", "partial spend detected", player.UserId, key, source)
				return false
			end
		end
	end
	return true
end

return CurrencyService
