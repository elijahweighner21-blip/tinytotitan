--!strict
--[[
	Trove
	Tracks anything that needs cleaning up (connections, instances, threads,
	callbacks, nested troves) so controllers can release everything in one call
	when a character dies, a menu closes or a player leaves. This is the main
	defence against duplicated listeners after respawn.
]]

export type Trove = {
	Add: <T>(self: Trove, item: T, cleanupMethod: string?) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Extend: (self: Trove) -> Trove,
	Remove: (self: Trove, item: any) -> (),
	Destroy: (self: Trove) -> (),
}

local Trove = {}
Trove.__index = Trove

local function cleanupItem(item: any, method: string?)
	local kind = typeof(item)
	if method then
		local fn = item[method]
		if typeof(fn) == "function" then
			fn(item)
		end
	elseif kind == "function" then
		item()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if typeof(item.Destroy) == "function" then
			item:Destroy()
		elseif typeof(item.Disconnect) == "function" then
			item:Disconnect()
		elseif typeof(item.Clean) == "function" then
			item:Clean()
		end
	end
end

function Trove.new(): Trove
	local self = setmetatable({ _items = {} :: { { any } }, _cleaning = false }, Trove)
	return (self :: any) :: Trove
end

function Trove.Add(self: any, item: any, cleanupMethod: string?): any
	if self._cleaning then
		-- Adding during cleanup would leak; clean immediately instead.
		cleanupItem(item, cleanupMethod)
		return item
	end
	table.insert(self._items, { item, cleanupMethod })
	return item
end

function Trove.Connect(self: any, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(fn)
	self:Add(connection)
	return connection
end

function Trove.Extend(self: any): Trove
	local child = Trove.new()
	self:Add(child)
	return child
end

function Trove.Remove(self: any, item: any)
	for index, entry in self._items do
		if entry[1] == item then
			table.remove(self._items, index)
			cleanupItem(entry[1], entry[2])
			return
		end
	end
end

function Trove.Clean(self: any)
	if self._cleaning then
		return
	end
	self._cleaning = true
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local entry = items[i]
		local ok, err = pcall(function()
			cleanupItem(entry[1], entry[2])
		end)
		if not ok then
			warn("[Trove] cleanup failed:", err)
		end
	end
	self._cleaning = false
end

function Trove.Destroy(self: any)
	self:Clean()
end

return Trove
