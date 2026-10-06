--!strict
--[[
	AscensionLogic
	Applies an Ascension to a player data table — pure, so the test suite can
	prove it resets exactly what AscensionConfig.Resets promises and keeps
	everything in AscensionConfig.Keeps (purchases, cosmetics, achievements…).

	Returns a summary used for the confirmation result.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AscensionConfig = require(Shared.Config.AscensionConfig)
local SkillConfig = require(Shared.Config.SkillConfig)
local QuestConfig = require(Shared.Config.QuestConfig)

local AscensionLogic = {}

export type Summary = {
	Points: number,
	RefundedSkillPoints: number,
	Count: number,
	StartEnergy: number,
	StartSkills: { string },
}

function AscensionLogic.canAscend(data: any): (boolean, string?)
	if data.Progress.Tier < AscensionConfig.RequiredTier then
		return false, "Reach Titan size to Ascend"
	end
	if data.Ascension.Count >= AscensionConfig.MaxAscensions then
		return false, "Maximum Ascensions reached"
	end
	return true, nil
end

-- Skill points that were spent on currently learned skills.
function AscensionLogic.spentSkillPoints(skills: { [string]: boolean }): number
	local total = 0
	for id, owned in skills do
		local def = SkillConfig.get(id)
		if owned and def then
			total += def.Cost.SkillPoints or 0
		end
	end
	return total
end

-- Mutates `data`. `startEnergy` / `startSkills` come from Ascension-tree stats.
function AscensionLogic.apply(data: any, now: number, startEnergy: number, startSkills: boolean): Summary
	local points = AscensionConfig.pointsFor(data.Progress.Tier, data.Progress.RunMass)
	local refund = AscensionLogic.spentSkillPoints(data.Skills)

	-- RESETS (must match AscensionConfig.Resets / ResetPaths exactly)
	data.Currencies.Mass = 0
	data.Currencies.GrowthEnergy = math.max(0, startEnergy)
	data.Upgrades = {}
	for resource in data.Resources do
		data.Resources[resource] = 0
	end
	data.Skills = {}
	data.Currencies.SkillPoints += refund
	data.Progress.RunMass = 0
	data.Progress.Tier = 1
	data.Progress.ShrinkTier = 0
	for questId in data.Quests.Active do
		local def = QuestConfig.get(questId)
		if not def or def.Category ~= "Story" then
			data.Quests.Active[questId] = nil
		end
	end

	-- GRANTS
	data.Currencies.AscensionPoints += points
	data.Ascension.Count += 1
	data.Ascension.TotalPoints += points
	data.Ascension.LastAscendedAt = now
	local granted = {}
	if startSkills then
		for _, id in { "DoubleJump", "Slide" } do
			data.Skills[id] = true
			table.insert(granted, id)
		end
	end
	return {
		Points = points,
		RefundedSkillPoints = refund,
		Count = data.Ascension.Count,
		StartEnergy = startEnergy,
		StartSkills = granted,
	}
end

return AscensionLogic
