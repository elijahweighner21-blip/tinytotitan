--!strict
--[[
	WorldIndex
	Positions of named world targets (discoveries, NPCs, challenge pads,
	boss arenas, fast-travel stations) published by the server's
	WorldBuilder in ReplicatedStorage.WorldIndex. Unlike the parts
	themselves these are always available, even when streamed out.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldIndex = {}

local KINDS = { "Discovery", "NPC", "Challenge", "Boss", "Station" }

local folder: Instance? = nil

local function getFolder(): Instance?
	if folder and folder.Parent then
		return folder
	end
	folder = ReplicatedStorage:FindFirstChild("WorldIndex")
	return folder
end

function WorldIndex.wait(timeout: number?): boolean
	if getFolder() then
		return true
	end
	folder = ReplicatedStorage:WaitForChild("WorldIndex", timeout or 30)
	return folder ~= nil
end

function WorldIndex.get(kind: string, id: string): Vector3?
	local f = getFolder()
	if not f then
		return nil
	end
	local value = f:GetAttribute(kind .. "_" .. id)
	return if typeof(value) == "Vector3" then value else nil
end

-- Resolves a quest marker id of unknown kind.
function WorldIndex.find(id: string): (Vector3?, string?)
	for _, kind in KINDS do
		local p = WorldIndex.get(kind, id)
		if p then
			return p, kind
		end
	end
	return nil, nil
end

function WorldIndex.all(kind: string): { [string]: Vector3 }
	local out = {}
	local f = getFolder()
	if not f then
		return out
	end
	local prefix = kind .. "_"
	for name, value in f:GetAttributes() do
		if string.sub(name, 1, #prefix) == prefix and typeof(value) == "Vector3" then
			out[string.sub(name, #prefix + 1)] = value
		end
	end
	return out
end

return WorldIndex
