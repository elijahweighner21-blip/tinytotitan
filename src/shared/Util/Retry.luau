--!strict
--[[
	Retry
	Exponential-backoff wrapper for Roblox web-service calls (DataStores,
	MarketplaceService, OrderedDataStores). Returns ok + results instead of
	throwing so callers decide how to degrade.
]]

local Retry = {}

function Retry.call<T...>(attempts: number, baseDelay: number, fn: () -> T...): (boolean, ...any)
	local lastError: any = nil
	for attempt = 1, attempts do
		local result = table.pack(pcall(fn))
		if result[1] then
			return table.unpack(result, 1, result.n)
		end
		lastError = result[2]
		if attempt < attempts then
			task.wait(baseDelay * 2 ^ (attempt - 1) + math.random() * 0.25)
		end
	end
	return false, lastError
end

return Retry
