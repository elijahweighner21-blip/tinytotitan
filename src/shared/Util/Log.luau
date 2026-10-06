--!strict
--[[
	Log
	Tagged, throttled logging. Identical messages within a short window are
	collapsed so a failing loop cannot flood the Output.
]]

local RunService = game:GetService("RunService")

local Log = {}

local DEDUPE_WINDOW = 10
local lastEmitted: { [string]: number } = {}
local suppressed: { [string]: number } = {}
local debugEnabled = RunService:IsStudio()

local function shouldEmit(key: string): boolean
	local now = os.clock()
	local last = lastEmitted[key]
	if last and now - last < DEDUPE_WINDOW then
		suppressed[key] = (suppressed[key] or 0) + 1
		return false
	end
	lastEmitted[key] = now
	return true
end

local function compose(tag: string, ...: any): string
	local parts = table.create(select("#", ...))
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	return string.format("[%s] %s", tag, table.concat(parts, " "))
end

local function withSuppressed(key: string, message: string): string
	local count = suppressed[key]
	if count and count > 0 then
		suppressed[key] = 0
		return message .. string.format(" (+%d repeats)", count)
	end
	return message
end

function Log.setDebug(enabled: boolean)
	debugEnabled = enabled
end

function Log.isDebug(): boolean
	return debugEnabled
end

function Log.debug(tag: string, ...: any)
	if debugEnabled then
		print(compose(tag, ...))
	end
end

function Log.info(tag: string, ...: any)
	print(compose(tag, ...))
end

function Log.warn(tag: string, ...: any)
	local message = compose(tag, ...)
	if shouldEmit(message) then
		warn(withSuppressed(message, message))
	end
end

function Log.error(tag: string, ...: any)
	local message = compose(tag, ...)
	if shouldEmit(message) then
		-- Use warn with a marker rather than error() so logging never throws.
		warn("‼ " .. withSuppressed(message, message))
	end
end

return Log
