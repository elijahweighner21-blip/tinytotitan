--!strict
--[[
	SkillService
	Skill tree unlocks and respecs. Requirements (size tier, level,
	achievement, boss victory) and costs (Skill Points, Titan Shards, zone
	resources) are all checked server-side; prerequisites must be owned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillConfig = require(Shared.Config.SkillConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local BossConfig = require(Shared.Config.BossConfig)
local AchievementConfig = require(Shared.Config.AchievementConfig)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local AscensionLogic = require(ServerRoot.Logic.AscensionLogic)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local StatService = require(script.Parent.StatService)
local ProgressionService = require(script.Parent.ProgressionService)

local SkillService = {}

function SkillService:CanUnlock(player: Player, skillId: string): (boolean, string?)
	local def = SkillConfig.get(skillId)
	local data = PlayerDataService:Get(player)
	if not def or not data then
		return false, "Unknown skill"
	end
	if data.Skills[skillId] then
		return false, "Already learned"
	end
	for _, pre in def.Prerequisites do
		if not data.Skills[pre] then
			local preDef = SkillConfig.get(pre)
			return false, "Requires " .. (if preDef then preDef.Name else pre)
		end
	end
	local req = def.Requirements
	if req.Tier and ProgressionService:GetTier(player) < req.Tier then
		return false, "Requires " .. SizeConfig.getTier(req.Tier).Name
	end
	if req.Level and data.Progress.Level < req.Level then
		return false, "Requires level " .. req.Level
	end
	if req.Achievement and not data.Achievements[req.Achievement] then
		local ach = AchievementConfig.get(req.Achievement)
		return false, "Requires achievement " .. (if ach then ach.Name else req.Achievement)
	end
	if req.Boss then
		local record = data.Bosses[req.Boss]
		if not record or record.Kills <= 0 then
			local boss = BossConfig.get(req.Boss)
			return false, "Defeat " .. (if boss then boss.Name else req.Boss) .. " first"
		end
	end
	return true, nil
end

function SkillService:Unlock(player: Player, skillId: string): { [string]: any }
	local ok, reason = SkillService:CanUnlock(player, skillId)
	if not ok then
		return { ok = false, err = reason }
	end
	local def = SkillConfig.get(skillId)
	local data = PlayerDataService:Get(player)
	if not data or not def then
		return { ok = false }
	end
	local costs: { [string]: number } = {}
	if def.Cost.SkillPoints and def.Cost.SkillPoints > 0 then
		costs.SkillPoints = def.Cost.SkillPoints
	end
	if def.Cost.TitanShards and def.Cost.TitanShards > 0 then
		costs.TitanShards = def.Cost.TitanShards
	end
	local resources = def.Cost.Resources
	if resources then
		for resource, amount in resources do
			costs["Resource:" .. resource] = amount
		end
	end
	if not CurrencyService:Spend(player, costs, "Skill:" .. skillId) then
		return { ok = false, err = "Not enough Skill Points or materials" }
	end
	data.Skills[skillId] = true
	PlayerDataService:Changed(player, "Skills")
	StatService:Invalidate(player)
	GameEvents.fire("SkillUnlocked", player, skillId)
	local allMobility = true
	for _, s in SkillConfig.List do
		if s.Branch == "Mobility" and not data.Skills[s.Id] then
			allMobility = false
			break
		end
	end
	if allMobility then
		GameEvents.fire("MobilityComplete", player)
	end
	return { ok = true }
end

function SkillService:Respec(player: Player): { [string]: any }
	local data = PlayerDataService:Get(player)
	if not data then
		return { ok = false }
	end
	local refund = AscensionLogic.spentSkillPoints(data.Skills)
	if refund <= 0 then
		return { ok = false, err = "No skills to reset" }
	end
	if not CurrencyService:Remove(player, "TitanShards", SkillConfig.RespecCost, "Respec") then
		return { ok = false, err = "Respec costs " .. SkillConfig.RespecCost .. " Titan Shards" }
	end
	data.Skills = {}
	PlayerDataService:Changed(player, "Skills")
	CurrencyService:Add(player, "SkillPoints", refund, "Respec")
	StatService:Invalidate(player)
	return { ok = true, refunded = refund }
end

function SkillService:Init()
	Net.onRequest("UnlockSkill", Guard.shape({ Id = Guard.id() }), function(player, payload)
		return SkillService:Unlock(player, payload.Id)
	end)
	Net.onRequest("RespecSkills", Guard.none(), function(player)
		return SkillService:Respec(player)
	end)
end

return SkillService
