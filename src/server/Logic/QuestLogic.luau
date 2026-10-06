--!strict
--[[
	QuestLogic
	Pure quest rules (no Roblox services) so they are unit-tested:
	  * availability (prerequisites, tier, level, active limit)
	  * matching gameplay events to objectives
	  * applying progress and detecting completion
	QuestService wires these to GameEvents, data and rewards.
]]

local QuestConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.QuestConfig)

local QuestLogic = {}

export type Active = { Progress: { number }, StartedAt: number }
export type QuestData = {
	Active: { [string]: Active },
	Completed: { [string]: number },
	Tracked: string,
}

-- Event name -> objective type it can advance, and how to read the event.
-- Each entry returns (target, amount) from the event arguments.
QuestLogic.EventMap = {
	Collected = {
		Type = "Collect",
		Read = function(typeId: any)
			return typeId, 1
		end,
	},
	Discovered = {
		Type = "Discover",
		Read = function(id: any)
			return id, 1
		end,
	},
	EnemyDefeated = {
		Type = "DefeatEnemy",
		Read = function(id: any)
			return id, 1
		end,
	},
	BossDefeated = {
		Type = "DefeatBoss",
		Read = function(id: any)
			return id, 1
		end,
	},
	ChallengeCompleted = {
		Type = "CompleteChallenge",
		Read = function(id: any)
			return id, 1
		end,
	},
	TalkedTo = {
		Type = "TalkTo",
		Read = function(id: any)
			return id, 1
		end,
	},
	UpgradeBought = {
		Type = "BuyUpgrade",
		Read = function(id: any)
			return id, 1
		end,
	},
	SkillUnlocked = {
		Type = "UnlockSkill",
		Read = function(id: any)
			return id, 1
		end,
	},
	AbilityUsed = {
		Type = "UseAbility",
		Read = function(id: any)
			return id, 1
		end,
	},
	ObjectBroken = {
		Type = "BreakObject",
		Read = function(id: any)
			return id, 1
		end,
	},
	ObjectMoved = {
		Type = "MoveObject",
		Read = function(verb: any)
			return verb, 1
		end,
	},
	ZoneEntered = {
		Type = "EnterZone",
		Read = function(id: any)
			return id, 1
		end,
	},
	ResourceGathered = {
		Type = "GatherResource",
		Read = function(resource: any, amount: any)
			return resource, amount
		end,
	},
	MassEarned = {
		Type = "EarnMass",
		Read = function(amount: any)
			return nil, amount
		end,
	},
	EventJoined = {
		Type = "JoinEvent",
		Read = function(id: any)
			return id, 1
		end,
	},
	FastTraveled = {
		Type = "FastTravel",
		Read = function()
			return nil, 1
		end,
	},
	Ascended = {
		Type = "Ascend",
		Read = function()
			return nil, 1
		end,
	},
} :: { [string]: { Type: string, Read: (...any) -> (string?, number) } }

-- Objectives whose progress reflects current STATE rather than counted events.
QuestLogic.StateObjectives = { ReachTier = true, ReachLevel = true } :: { [string]: boolean }

export type Context = {
	Tier: number,
	Level: number,
	Discoveries: { [string]: number },
	Zone: string?,
}

function QuestLogic.isAvailable(questId: string, quests: QuestData, ctx: Context): (boolean, string?)
	local def = QuestConfig.get(questId)
	if not def then
		return false, "Unknown quest"
	end
	if quests.Active[questId] then
		return false, "Already active"
	end
	if quests.Completed[questId] then
		return false, "Already completed"
	end
	local prereqs: { string } = def.Prerequisites or {}
	for _, pre in prereqs do
		if not quests.Completed[pre] then
			local preDef = QuestConfig.get(pre)
			return false, 'Complete "' .. (if preDef then preDef.Name else pre) .. '" first'
		end
	end
	if def.RequiredTier and ctx.Tier < def.RequiredTier then
		return false, "Requires a bigger size"
	end
	if def.RequiredLevel and ctx.Level < def.RequiredLevel then
		return false, "Requires level " .. def.RequiredLevel
	end
	return true, nil
end

function QuestLogic.activeCount(quests: QuestData): number
	local n = 0
	for _ in quests.Active do
		n += 1
	end
	return n
end

-- Creates progress for a newly accepted quest, crediting state objectives
-- and discoveries the player already made (otherwise they'd be stuck).
function QuestLogic.newProgress(questId: string, ctx: Context, now: number): Active
	local def = QuestConfig.get(questId)
	local progress = {}
	if def then
		for i, objective in def.Objectives do
			local value = 0
			if objective.Type == "ReachTier" then
				value = if ctx.Tier >= objective.Count then objective.Count else 0
			elseif objective.Type == "ReachLevel" then
				value = if ctx.Level >= objective.Count then objective.Count else 0
			elseif
				objective.Type == "Discover"
				and objective.Target
				and objective.Target ~= "Any"
				and ctx.Discoveries[objective.Target]
			then
				value = objective.Count
			elseif objective.Type == "EnterZone" and ctx.Zone == objective.Target then
				value = objective.Count
			end
			progress[i] = value
		end
	end
	return { Progress = progress, StartedAt = now }
end

-- Applies one event to an active quest. Returns true if progress changed.
function QuestLogic.applyEvent(questId: string, active: Active, eventName: string, ...: any): boolean
	local def = QuestConfig.get(questId)
	local mapping = QuestLogic.EventMap[eventName]
	if not def or not mapping then
		return false
	end
	local target, amount = mapping.Read(...)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	local changed = false
	for i, objective in def.Objectives do
		if objective.Type == mapping.Type then
			local matches = objective.Target == nil or objective.Target == "Any" or objective.Target == target
			local current = active.Progress[i] or 0
			if matches and current < objective.Count then
				active.Progress[i] = math.min(objective.Count, current + amount)
				changed = true
			end
		end
	end
	return changed
end

-- Re-evaluates state objectives (tier / level).
function QuestLogic.applyState(questId: string, active: Active, ctx: Context): boolean
	local def = QuestConfig.get(questId)
	if not def then
		return false
	end
	local changed = false
	for i, objective in def.Objectives do
		local current = active.Progress[i] or 0
		if objective.Type == "ReachTier" and ctx.Tier >= objective.Count and current < objective.Count then
			active.Progress[i] = objective.Count
			changed = true
		elseif objective.Type == "ReachLevel" and ctx.Level >= objective.Count and current < objective.Count then
			active.Progress[i] = objective.Count
			changed = true
		end
	end
	return changed
end

function QuestLogic.isComplete(questId: string, active: Active): boolean
	local def = QuestConfig.get(questId)
	if not def then
		return false
	end
	for i, objective in def.Objectives do
		if (active.Progress[i] or 0) < objective.Count then
			return false
		end
	end
	return true
end

-- Quests that should auto-start for this player right now.
function QuestLogic.autoStartable(quests: QuestData, ctx: Context): { string }
	local out = {}
	for _, def in QuestConfig.List do
		if def.AutoStart and QuestLogic.isAvailable(def.Id, quests, ctx) then
			table.insert(out, def.Id)
		end
	end
	return out
end

return QuestLogic
