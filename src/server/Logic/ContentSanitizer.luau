--!strict
--[[
	ContentSanitizer
	Validates a loaded save against the game's content configs (the schema
	sanitiser only knows types and ranges). Removes ids that no longer exist
	(retired upgrades, skills, quests, cosmetics, titles) and clamps upgrade
	levels to each upgrade's real maximum. Pure: returns what it changed so
	the caller can log it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local SkillConfig = require(Shared.Config.SkillConfig)
local QuestConfig = require(Shared.Config.QuestConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local TitleConfig = require(Shared.Config.TitleConfig)
local AscensionConfig = require(Shared.Config.AscensionConfig)

local ContentSanitizer = {}

function ContentSanitizer.apply(data: any): { string }
	local fixes: { string } = {}
	for id, level in data.Upgrades do
		local def = UpgradeConfig.get(id)
		if not def then
			data.Upgrades[id] = nil
			table.insert(fixes, "removed unknown upgrade " .. tostring(id))
		elseif type(level) ~= "number" or level < 0 then
			data.Upgrades[id] = nil
			table.insert(fixes, "removed invalid upgrade level " .. tostring(id))
		elseif level > def.MaxLevel then
			data.Upgrades[id] = def.MaxLevel
			table.insert(fixes, "clamped upgrade " .. id)
		end
	end
	for id in data.Skills do
		if not SkillConfig.get(id) then
			data.Skills[id] = nil
			table.insert(fixes, "removed unknown skill " .. tostring(id))
		end
	end
	for id in data.Quests.Active do
		if not QuestConfig.get(id) or data.Quests.Completed[id] then
			data.Quests.Active[id] = nil
			table.insert(fixes, "removed stale active quest " .. tostring(id))
		end
	end
	if data.Quests.Tracked ~= "" and not data.Quests.Active[data.Quests.Tracked] then
		data.Quests.Tracked = ""
	end
	for id in data.Cosmetics.Owned do
		if not CosmeticConfig.get(id) then
			data.Cosmetics.Owned[id] = nil
			table.insert(fixes, "removed unknown cosmetic " .. tostring(id))
		end
	end
	for category, list in data.Cosmetics.Equipped do
		for i = #list, 1, -1 do
			if not data.Cosmetics.Owned[list[i]] then
				table.remove(list, i)
			end
		end
		if #list == 0 then
			data.Cosmetics.Equipped[category] = nil
		end
	end
	for id in data.Titles.Owned do
		if not TitleConfig.get(id) then
			data.Titles.Owned[id] = nil
			table.insert(fixes, "removed unknown title " .. tostring(id))
		end
	end
	if data.Titles.Equipped ~= "" and not data.Titles.Owned[data.Titles.Equipped] then
		data.Titles.Equipped = ""
	end
	for id, rank in data.Ascension.Tree do
		local node = AscensionConfig.getNode(id)
		if not node then
			data.Ascension.Tree[id] = nil
			table.insert(fixes, "removed unknown ascension node " .. tostring(id))
		elseif rank > node.MaxRank then
			data.Ascension.Tree[id] = node.MaxRank
		end
	end
	return fixes
end

return ContentSanitizer
