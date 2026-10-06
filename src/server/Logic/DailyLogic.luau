--!strict
--[[
	DailyLogic
	Deterministic daily/weekly objective selection and progress rules. The
	selection depends only on (UserId, day/week, highest tier), so a player
	sees the same objectives on every server and can never pick their own.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DailyConfig = require(Shared.Config.DailyConfig)
local TableUtil = require(Shared.Util.TableUtil)

local DailyLogic = {}

export type Slot = { Id: string, Progress: number, Claimed: boolean }

function DailyLogic.pick(pool: { DailyConfig.ObjectiveDef }, count: number, seed: number, highestTier: number): { Slot }
	local eligible = {}
	for _, def in pool do
		if def.MinTier <= highestTier then
			table.insert(eligible, def)
		end
	end
	table.sort(eligible, function(a, b)
		return a.Id < b.Id
	end)
	local shuffled = TableUtil.seededShuffle(eligible, seed)
	local out = {}
	for i = 1, math.min(count, #shuffled) do
		table.insert(out, { Id = shuffled[i].Id, Progress = 0, Claimed = false })
	end
	return out
end

function DailyLogic.dailySeed(userId: number, day: number): number
	return (userId * 7919 + day * 104729) % 2147483646 + 1
end

function DailyLogic.weeklySeed(userId: number, week: number): number
	return (userId * 6271 + week * 15485863) % 2147483646 + 1
end

-- Adds progress for an event; returns true if anything changed.
function DailyLogic.applyEvent(slots: { Slot }, eventName: string, amount: number): boolean
	local changed = false
	for _, slot in slots do
		local def = DailyConfig.findObjective(slot.Id)
		if def and def.Event == eventName and not slot.Claimed and slot.Progress < def.Target then
			slot.Progress = math.min(def.Target, slot.Progress + amount)
			changed = true
		end
	end
	return changed
end

function DailyLogic.canClaim(slot: Slot?): boolean
	if not slot or slot.Claimed then
		return false
	end
	local def = DailyConfig.findObjective(slot.Id)
	return def ~= nil and slot.Progress >= def.Target
end

return DailyLogic
