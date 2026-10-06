--!strict
--[[
	MockDataStore
	In-memory stand-in used ONLY in Studio when DataStores are not reachable
	(e.g. "Enable Studio Access to API Services" is off). Mirrors the subset of
	the GlobalDataStore API the game uses, including UpdateAsync semantics
	(returning nil from the transform cancels the write).
]]

local MockDataStore = {}
MockDataStore.__index = MockDataStore

export type MockStore = {
	GetAsync: (self: MockStore, key: string) -> any,
	SetAsync: (self: MockStore, key: string, value: any) -> (),
	UpdateAsync: (self: MockStore, key: string, transform: (any) -> any) -> any,
	RemoveAsync: (self: MockStore, key: string) -> any,
}

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

function MockDataStore.new(): MockStore
	local self = setmetatable({ _data = {} :: { [string]: any } }, MockDataStore)
	return (self :: any) :: MockStore
end

function MockDataStore.GetAsync(self: any, key: string): any
	return deepCopy(self._data[key])
end

function MockDataStore.SetAsync(self: any, key: string, value: any)
	self._data[key] = deepCopy(value)
end

function MockDataStore.UpdateAsync(self: any, key: string, transform: (any) -> any): any
	local result = transform(deepCopy(self._data[key]))
	if result ~= nil then
		self._data[key] = deepCopy(result)
	end
	return deepCopy(result)
end

function MockDataStore.RemoveAsync(self: any, key: string): any
	local old = self._data[key]
	self._data[key] = nil
	return old
end

return MockDataStore
