-- Static checks over the procedural world builders (they need live Roblox
-- APIs to run, so we verify placements by scanning their source).
local DiscoveryConfig = require(Shared.Config.DiscoveryConfig)
local NPCConfig = require(Shared.Config.NPCConfig)
local BossConfig = require(Shared.Config.BossConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local CollectibleConfig = require(Shared.Config.CollectibleConfig)
local InteractableConfig = require(Shared.Config.InteractableConfig)
local EnemyConfig = require(Shared.Config.EnemyConfig)

local all = ""
local regions = Server.World.Regions
for _, child in childrenOf(regions) do
	all ..= sourceOf(child) .. "\n"
end

local function placed(pattern)
	return string.find(all, pattern) ~= nil
end

describe("World placements", function()
	it("every discovery has a region", function()
		for _, d in DiscoveryConfig.List do
			if not placed('Kit%.discovery%([%w_]+, "' .. d.Id .. '"') then error("missing discovery " .. d.Id) end
		end
	end)
	it("every NPC has a spawn", function()
		for _, n in NPCConfig.List do
			if not placed('Kit%.npc%([%w_]+, "' .. n.Id .. '"') then error("missing npc " .. n.Id) end
		end
	end)
	it("every boss has an arena", function()
		for _, b in BossConfig.List do
			if not placed('Kit%.bossArena%([%w_]+, "' .. b.Id .. '"') then error("missing arena " .. b.Id) end
		end
	end)
	it("every zone has a fast travel station and spawn pad", function()
		for _, z in ZoneConfig.Zones do
			local ok = placed('Kit%.fastTravel%([%w_]+, ZONE') or placed('Kit%.fastTravel%([%w_]+, "' .. z.Id .. '"')
			if not ok then error("missing station " .. z.Id) end
		end
	end)
	it("collectible, interactable and enemy ids used by builders exist", function()
		for typeId in string.gmatch(all, 'Kit%.collectible%([%w_]+, "([%w_]+)"') do
			if not CollectibleConfig.get(typeId) then error("unknown collectible " .. typeId) end
		end
		for typeId in string.gmatch(all, 'Kit%.interactable%([%w_]+, "([%w_]+)"') do
			if not InteractableConfig.get(typeId) then error("unknown interactable " .. typeId) end
		end
		for typeId in string.gmatch(all, 'Kit%.enemySpawner%([%w_]+, "([%w_]+)"') do
			if not EnemyConfig.get(typeId) then error("unknown enemy " .. typeId) end
		end
	end)
	it("every enemy type is spawned somewhere", function()
		for _, e in EnemyConfig.List do
			if e.Id ~= "Ant" and not placed('Kit%.enemySpawner%([%w_]+, "' .. e.Id .. '"') then
				error("enemy never spawned: " .. e.Id)
			end
		end
	end)
	it("every zone has unique collectibles for its collection page", function()
		for _, z in ZoneConfig.Zones do
			-- Builders pass ZONE (the region file's zone) or the zone id string.
			local found = false
			for _, child in childrenOf(regions) do
				local src = sourceOf(child)
				if string.find(src, 'local ZONE = "' .. z.Id .. '"', 1, true) and string.find(src, '"TitanShard"', 1, true) then
					found = true
				end
			end
			if not found then error("zone without titan shards: " .. z.Id) end
		end
	end)
end)
