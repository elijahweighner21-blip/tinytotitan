--!strict
--[[
	Guard
	Tiny runtime validators for remote payloads. Every client->server request
	is described by a Guard so malformed data (wrong types, NaN, huge strings,
	nested tables) is rejected before any handler runs.
]]

local MathUtil = require(script.Parent.MathUtil)

export type Check = (value: any) -> (boolean, string?)

local Guard = {}

function Guard.string(maxLength: number?): Check
	local limit = maxLength or 64
	return function(v)
		if type(v) ~= "string" then
			return false, "expected string"
		end
		if #v > limit then
			return false, "string too long"
		end
		if not utf8.len(v) then
			return false, "invalid utf8"
		end
		return true
	end
end

-- Identifier-like strings: config ids, product keys, etc.
function Guard.id(maxLength: number?): Check
	local limit = maxLength or 48
	return function(v)
		if type(v) ~= "string" or #v == 0 or #v > limit then
			return false, "bad id"
		end
		if string.find(v, "[^%w_%-]") then
			return false, "bad id characters"
		end
		return true
	end
end

function Guard.number(lo: number, hi: number): Check
	return function(v)
		if not MathUtil.isFinite(v) then
			return false, "expected finite number"
		end
		if v < lo or v > hi then
			return false, "number out of range"
		end
		return true
	end
end

function Guard.integer(lo: number, hi: number): Check
	return function(v)
		if not MathUtil.isFinite(v) or math.floor(v) ~= v then
			return false, "expected integer"
		end
		if v < lo or v > hi then
			return false, "integer out of range"
		end
		return true
	end
end

function Guard.boolean(): Check
	return function(v)
		return type(v) == "boolean", "expected boolean"
	end
end

function Guard.vector3(maxMagnitude: number?): Check
	local limit = maxMagnitude or 1e6
	return function(v)
		if typeof(v) ~= "Vector3" then
			return false, "expected Vector3"
		end
		if not (MathUtil.isFinite(v.X) and MathUtil.isFinite(v.Y) and MathUtil.isFinite(v.Z)) then
			return false, "non-finite vector"
		end
		if v.Magnitude > limit then
			return false, "vector too large"
		end
		return true
	end
end

function Guard.oneOf(options: { any }): Check
	local set = {}
	for _, o in options do
		set[o] = true
	end
	return function(v)
		return set[v] == true, "unexpected value"
	end
end

function Guard.optional(check: Check): Check
	return function(v)
		if v == nil then
			return true
		end
		return check(v)
	end
end

-- Validates a dictionary with exactly the given keys (extra keys rejected).
function Guard.shape(fields: { [string]: Check }): Check
	return function(v)
		if type(v) ~= "table" then
			return false, "expected table"
		end
		for key in v do
			if type(key) ~= "string" or fields[key] == nil then
				return false, "unexpected key " .. tostring(key)
			end
		end
		for key, check in fields do
			local ok, err = check(v[key])
			if not ok then
				return false, key .. ": " .. (err or "invalid")
			end
		end
		return true
	end
end

function Guard.array(check: Check, maxLength: number): Check
	return function(v)
		if type(v) ~= "table" then
			return false, "expected array"
		end
		local n = 0
		for key in v do
			n += 1
			if type(key) ~= "number" or key ~= math.floor(key) or key < 1 then
				return false, "not an array"
			end
		end
		if n > maxLength or n ~= #v then
			return false, "array too long or sparse"
		end
		for _, item in v do
			local ok, err = check(item)
			if not ok then
				return false, err
			end
		end
		return true
	end
end

function Guard.none(): Check
	return function(v)
		return v == nil, "expected no payload"
	end
end

function Guard.any(): Check
	return function()
		return true
	end
end

return Guard
