--!strict
--[[
	TableUtil
	Deep copy / reconcile / freeze helpers. `reconcile` is what fills in new
	fields when the save schema grows, so old saves never miss data.
]]

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[TableUtil.deepCopy(k)] = TableUtil.deepCopy(v)
	end
	return (copy :: any) :: T
end

-- Adds any keys present in `template` but missing in `target` (recursively).
-- Never overwrites existing values. Type mismatches are replaced by the default
-- because a wrong-typed field is always corruption.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, default in template do
		local existing = target[key]
		if existing == nil then
			target[key] = TableUtil.deepCopy(default)
		elseif type(default) == "table" then
			if type(existing) ~= "table" then
				target[key] = TableUtil.deepCopy(default)
			else
				TableUtil.reconcile(existing, default)
			end
		elseif type(existing) ~= type(default) then
			target[key] = default
		end
	end
	return target
end

function TableUtil.deepFreeze<T>(t: T): T
	if type(t) == "table" then
		for _, v in t :: any do
			if type(v) == "table" and not table.isfrozen(v) then
				TableUtil.deepFreeze(v)
			end
		end
		if not table.isfrozen(t :: any) then
			table.freeze(t :: any)
		end
	end
	return t
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function TableUtil.keys<K>(t: { [K]: any }): { K }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	return out
end

function TableUtil.map<T, U>(list: { T }, fn: (T, number) -> U): { U }
	local out = table.create(#list)
	for i, v in list do
		out[i] = fn(v, i)
	end
	return out
end

function TableUtil.filter<T>(list: { T }, fn: (T) -> boolean): { T }
	local out = {}
	for _, v in list do
		if fn(v) then
			table.insert(out, v)
		end
	end
	return out
end

function TableUtil.find<T>(list: { T }, fn: (T) -> boolean): T?
	for _, v in list do
		if fn(v) then
			return v
		end
	end
	return nil
end

function TableUtil.shallowEqual(a: { [any]: any }, b: { [any]: any }): boolean
	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end
	for k, v in b do
		if a[k] ~= v then
			return false
		end
	end
	return true
end

-- Weighted pick: entries are { weight = number, ... }. `rng` returns [0,1).
function TableUtil.weightedPick<T>(entries: { T }, getWeight: (T) -> number, rng: () -> number): T?
	local total = 0
	for _, e in entries do
		total += math.max(0, getWeight(e))
	end
	if total <= 0 then
		return nil
	end
	local roll = rng() * total
	for _, e in entries do
		roll -= math.max(0, getWeight(e))
		if roll < 0 then
			return e
		end
	end
	return entries[#entries]
end

-- Deterministic shuffle using a seeded Random so every server agrees.
function TableUtil.seededShuffle<T>(list: { T }, seed: number): { T }
	local out = table.clone(list)
	local rng = Random.new(seed)
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

return TableUtil
