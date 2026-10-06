--!strict
--[[
	GameEvents
	Server-side gameplay event bus. Systems that DO things fire events; systems
	that TRACK things (quests, daily objectives, achievements, tutorial,
	analytics) listen. This keeps tracking logic in one place per system and
	avoids circular requires between gameplay services.

	Event catalogue (all receive `player` first):
	  Collected(type, id, zone)        OrbCollected(zone)       Discovered(id, zone)
	  TierUp(newTier, oldTier)         LevelUp(level)           MassEarned(amount, scaledAmount)
	  EnemyDefeated(enemyId, zone)     BossDefeated(bossId)     ChallengeCompleted(id, medal)
	  QuestCompleted(questId)          UpgradeBought(id, level) SkillUnlocked(id)
	  AbilityUsed(abilityId)           ObjectBroken(objectId)   ObjectMoved(verb, objectId)
	  ZoneEntered(zoneId)              ResourceGathered(resource, amount)
	  EventJoined(eventId)             FastTraveled(stationId)  Ascended(count)
	  TalkedTo(npcId)                  Jumped()                 Dashed()
	  Sprinted()                       Moved()                  TitanMedal(challengeId)
	  Achievement(id)                  Purchase(productKey)
]]

local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.Signal)

local GameEvents = {}

local signals: { [string]: Signal.Signal<...any> } = {}
local anySignal = Signal.new()

local function get(name: string): Signal.Signal<...any>
	local s = signals[name]
	if not s then
		s = Signal.new()
		signals[name] = s
	end
	return s
end

function GameEvents.fire(name: string, player: Player, ...: any)
	get(name):Fire(player, ...)
	anySignal:Fire(name, player, ...)
end

function GameEvents.on(name: string, fn: (player: Player, ...any) -> ()): Signal.Connection
	return get(name):Connect(fn)
end

-- Listen to every event (used by daily objectives / achievements / tutorial).
function GameEvents.onAny(fn: (name: string, player: Player, ...any) -> ()): Signal.Connection
	return anySignal:Connect(fn)
end

return GameEvents
