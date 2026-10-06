--!strict
--[[
	Format
	The single place numbers and times are turned into strings. Every UI and
	notification uses these so "1.2K" style abbreviations are consistent and
	giant late-game values never print as 123456789012.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

-- 950 -> "950", 1234 -> "1.2K", 15800 -> "15.8K", 2400000 -> "2.4M"
function Format.abbreviate(n: number, decimals: number?): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "∞"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local whole = if n == math.floor(n) then tostring(math.floor(n)) else trimZeros(string.format("%.1f", n))
		return (if negative then "-" else "") .. whole
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local places = decimals or (if scaled < 100 then 1 else 0)
	-- Avoid "1000K": roll over to the next suffix after rounding.
	local text = string.format("%." .. places .. "f", math.floor(scaled * 10 ^ places) / 10 ^ places)
	if tonumber(text) and (tonumber(text) :: number) >= 1000 and tier < #SUFFIXES - 1 then
		tier += 1
		scaled = n / 10 ^ (tier * 3)
		text = string.format("%." .. places .. "f", math.floor(scaled * 10 ^ places) / 10 ^ places)
	end
	return (if negative then "-" else "") .. trimZeros(text) .. SUFFIXES[tier + 1]
end

-- 1234567 -> "1,234,567" (used only in detailed statistics views)
function Format.commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local formatted = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return (if n < 0 then "-" else "") .. formatted
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- Precise race timer: 63.456 -> "1:03.45"
function Format.raceTime(seconds: number): string
	seconds = math.max(0, seconds)
	local m = math.floor(seconds / 60)
	local s = seconds - m * 60
	return string.format("%d:%05.2f", m, s)
end

-- 90061 -> "1d 1h", 3700 -> "1h 1m", 59 -> "59s"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

function Format.percent(fraction: number, decimals: number?): string
	return trimZeros(string.format("%." .. (decimals or 0) .. "f", fraction * 100)) .. "%"
end

function Format.multiplier(m: number): string
	return trimZeros(string.format("%.2f", m)) .. "×"
end

-- "+500 Mass" style deltas
function Format.delta(n: number, label: string?): string
	local sign = if n >= 0 then "+" else ""
	return sign .. Format.abbreviate(n) .. (if label then " " .. label else "")
end

-- Distance in studs shown with a human-friendly unit for the HUD.
function Format.studs(n: number): string
	return Format.abbreviate(n) .. " st"
end

function Format.ordinal(n: number): string
	local last2 = n % 100
	local last = n % 10
	if last2 >= 11 and last2 <= 13 then
		return n .. "th"
	elseif last == 1 then
		return n .. "st"
	elseif last == 2 then
		return n .. "nd"
	elseif last == 3 then
		return n .. "rd"
	end
	return n .. "th"
end

return Format
