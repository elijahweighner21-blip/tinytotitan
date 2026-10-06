--!strict
--[[
	ChallengeService
	Server-measured challenge runs. The client never reports a time, a
	checkpoint or a score — the server times the run with its own clock and
	detects checkpoints, finishes, tokens, hidden objects, target hits and
	long-jump landings from the character's real position.

	Run lifecycle
	  StartChallenge (must stand on the start pad) → stream + teleport into the
	  course pocket → 3 s frozen countdown → Running → Finished / Failed →
	  teleport back to the pad.

	Anti-cheat
	  * finish times faster than the course's plausible minimum (adjusted for
	    the player's own upgraded speed) are rejected and reported
	  * medals/leaderboards only while the player's CURRENT size is inside the
	    challenge's tier range ("Ranked"); bigger players can still play
	  * fast travel is blocked during runs; death / leaving fails the run
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChallengeConfig = require(Shared.Config.ChallengeConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local CombatMath = require(Shared.Formulas.CombatMath)
local Guard = require(Shared.Util.Guard)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local CourseBuilder = require(ServerRoot.World.CourseBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local RewardService = require(script.Parent.RewardService)
local StatisticsService = require(script.Parent.StatisticsService)
local StatService = require(script.Parent.StatService)
local ScaleService = require(script.Parent.ScaleService)
local CombatService = require(script.Parent.CombatService)
local FastTravelService = require(script.Parent.FastTravelService)
local AntiExploitService = require(script.Parent.AntiExploitService)

local ChallengeService = {}

type Run = {
	Def: ChallengeConfig.ChallengeDef,
	Course: CourseBuilder.CourseData,
	State: string, -- Countdown | Running | Done
	CountdownUntil: number,
	StartedAt: number,
	Next: number,
	Tokens: { [number]: boolean },
	Targets: { [number]: boolean },
	Found: number,
	Ranked: boolean,
	Airborne: boolean,
	BestDistance: number,
	PlayerBody: number,
}

local runs: { [Player]: Run } = {}
local cooldowns: { [Player]: { [string]: number } } = {}

-- Leaderboard hook (set by LeaderboardService to avoid a require cycle).
ChallengeService.SubmitRecord = nil :: ((player: Player, challengeId: string, score: number) -> ())?

local function tierForScale(scale: number): number
	local tier = 1
	for i, def in SizeConfig.Tiers do
		if scale >= def.Scale * 0.98 then
			tier = i
		end
	end
	return tier
end

local function signal(player: Player, payload: { [string]: any })
	Net.signal(player, "Challenge", payload)
end

function ChallengeService:IsInRun(player: Player): boolean
	return runs[player] ~= nil
end

local function returnToPad(player: Player, run: Run)
	local root = CharacterService:GetRoot(player)
	if root then
		root.Anchored = false
	end
	if CharacterService:IsAlive(player) then
		pcall(function()
			player:RequestStreamAroundAsync(run.Def.Anchor, 5)
		end)
		CharacterService:SafeTeleport(player, run.Def.Anchor + Vector3.new(0, 1, 0), "ChallengeEnd")
	end
end

local function fail(player: Player, reason: string)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	run.State = "Done"
	signal(player, { State = "Failed", Id = run.Def.Id, Reason = reason })
	returnToPad(player, run)
end

local function finish(player: Player, score: number)
	local run = runs[player]
	local data = PlayerDataService:Get(player)
	if not run or not data then
		return
	end
	runs[player] = nil
	run.State = "Done"
	local def = run.Def
	-- Plausibility for timed runs, adjusted to the player's real sprint speed.
	if def.LowerIsBetter and def.MinPlausibleTime then
		local _, baseSprint = ChallengeConfig.physics(def.RequiredTier)
		local derived = StatService:GetDerived(player)
		local speedRatio = math.max(1, derived.SprintSpeed / math.max(baseSprint, 0.01))
		local minimum = def.MinPlausibleTime / speedRatio * 0.8
		if score < minimum then
			AntiExploitService:Flag(
				player,
				string.format("impossible %s time %.2f (min %.2f)", def.Id, score, minimum),
				6
			)
			signal(player, { State = "Failed", Id = def.Id, Reason = "Run invalidated" })
			returnToPad(player, run)
			return
		end
	end
	local medal = if run.Ranked then ChallengeConfig.medalFor(def, score) else 0
	local record = data.Challenges[def.Id]
	if not record then
		record = { Best = 0, Medal = 0, Completions = 0, LastAt = 0 }
		data.Challenges[def.Id] = record
	end
	local previousMedal = record.Medal
	local newBest = false
	if run.Ranked then
		if
			record.Best == 0
			or (def.LowerIsBetter and score < record.Best)
			or (not def.LowerIsBetter and score > record.Best)
		then
			record.Best = math.floor(score * 100) / 100
			newBest = true
		end
		record.Medal = math.max(record.Medal, medal)
	end
	record.Completions += 1
	record.LastAt = os.time()
	PlayerDataService:Changed(player, "Challenges")

	local medalName = if medal > 0 then ChallengeConfig.Medals[medal] else nil
	local granted = nil
	if medalName then
		local reward = (def.Rewards :: any)[medalName]
		if medal <= previousMedal then
			reward = RewardService:Scale(reward, ChallengeConfig.RepeatRewardFraction)
		end
		granted = RewardService:Grant(
			player,
			reward,
			{ Source = "Challenge", SourceId = def.Id, Category = "Challenge", Notify = false }
		)
	elseif not run.Ranked then
		granted = RewardService:Grant(
			player,
			RewardService:Scale(def.Rewards.Bronze, 0.1),
			{ Source = "Challenge", SourceId = def.Id, Category = "Challenge", Notify = false }
		)
	end
	StatisticsService:Increment(player, "ChallengesCompleted")
	GameEvents.fire("ChallengeCompleted", player, def.Id, medal)
	if medal == 4 and previousMedal < 4 then
		GameEvents.fire("TitanMedal", player, def.Id)
	end
	if run.Ranked and newBest and def.Leaderboard and ChallengeService.SubmitRecord then
		task.spawn(ChallengeService.SubmitRecord, player, def.Id, score)
	end
	signal(player, {
		State = "Finished",
		Id = def.Id,
		Score = score,
		ScoreKind = def.Score,
		Medal = medal,
		Ranked = run.Ranked,
		NewBest = newBest,
		Best = record.Best,
		Mass = if granted then granted.Mass else 0,
		GrowthEnergy = if granted then granted.GrowthEnergy else 0,
		XP = if granted then granted.XP else 0,
		TitanShards = if granted then granted.TitanShards else 0,
	})
	returnToPad(player, run)
end

local function startRun(player: Player, challengeId: string): { [string]: any }
	local def = ChallengeConfig.get(challengeId)
	local course = CourseBuilder.Registry[challengeId]
	if not def or not course then
		return { ok = false, err = "Unknown challenge" }
	end
	if runs[player] then
		return { ok = false, err = "Already in a challenge" }
	end
	local root = CharacterService:GetRoot(player)
	if not root then
		return { ok = false, err = "You can't start right now" }
	end
	local scale = ScaleService:GetScale(player)
	local height = ScaleMath.height(scale)
	local padReach = course.Body * 2 + height * 2 + 6
	if (root.Position - def.Anchor).Magnitude > padReach + height then
		return { ok = false, err = "Stand on the challenge pad" }
	end
	local now = os.clock()
	local personal = cooldowns[player]
	if not personal then
		personal = {}
		cooldowns[player] = personal
	end
	if (personal[challengeId] or 0) > now then
		return { ok = false, err = string.format("Ready again in %ds", math.ceil(personal[challengeId] - now)) }
	end
	local effTier = tierForScale(scale)
	if effTier < def.RequiredTier then
		return { ok = false, err = "Requires " .. SizeConfig.getTier(def.RequiredTier).Name }
	end
	local ranked = effTier <= (def.MaxTier or 99)
	personal[challengeId] = now + def.Cooldown
	local run: Run = {
		Def = def,
		Course = course,
		State = "Countdown",
		CountdownUntil = now + ChallengeConfig.CountdownSeconds + 0.5,
		StartedAt = 0,
		Next = 1,
		Tokens = {},
		Targets = {},
		Found = 0,
		Ranked = ranked,
		Airborne = false,
		BestDistance = 0,
		PlayerBody = height,
	}
	runs[player] = run
	pcall(function()
		player:RequestStreamAroundAsync(course.Start, 8)
	end)
	CharacterService:SafeTeleport(player, course.Start + Vector3.new(0, 0.5, 0), "ChallengeStart", course.StartFacing)
	local newRoot = CharacterService:GetRoot(player)
	if newRoot then
		newRoot.Anchored = true
	end
	signal(player, {
		State = "Countdown",
		Id = def.Id,
		Seconds = ChallengeConfig.CountdownSeconds,
		Ranked = ranked,
		Kind = def.Type,
		ScoreKind = def.Score,
		TimeLimit = def.TimeLimit,
		Thresholds = def.Thresholds,
		Checkpoints = #course.Checkpoints,
		Tokens = #course.Tokens,
		Targets = #course.Targets,
		Hazard = course.Hazard,
		LowerIsBetter = def.LowerIsBetter,
	})
	return { ok = true, ranked = ranked }
end

------------------------------------------------------------------ monitoring

local function monitor(player: Player, run: Run, now: number)
	local root = CharacterService:GetRoot(player)
	if not root then
		fail(player, "You were knocked out")
		return
	end
	local course = run.Course
	local def = run.Def
	if run.State == "Countdown" then
		if now >= run.CountdownUntil then
			run.State = "Running"
			run.StartedAt = now
			root.Anchored = false
			signal(player, { State = "Running", Id = def.Id, ServerTime = workspace:GetServerTimeNow() })
		end
		return
	end
	local elapsed = now - run.StartedAt
	local pos = root.Position
	local feetY = pos.Y - run.PlayerBody * 0.5
	-- Failure conditions.
	local flat = Vector3.new(pos.X - course.Origin.X, 0, pos.Z - course.Origin.Z)
	if flat.Magnitude > course.Bounds or pos.Y < course.FailY then
		if def.LowerIsBetter or def.Score == "Time" then
			fail(player, "You fell out of the course")
		else
			finish(player, if def.Score == "Distance" then run.BestDistance else run.Found)
		end
		return
	end
	if course.LavaY and feetY < course.LavaY then
		fail(player, "The floor is lava!")
		return
	end
	if course.Hazard then
		local level = course.Hazard.BaseY + course.Hazard.Speed * math.max(0, elapsed - course.Hazard.Delay)
		if feetY < level then
			fail(player, "The water caught you!")
			return
		end
	end
	if elapsed > def.TimeLimit then
		if def.Score == "Time" then
			fail(player, "Out of time")
		else
			finish(player, if def.Score == "Distance" then run.BestDistance else run.Found)
		end
		return
	end
	local kind = course.Kind
	if kind == "Sprint" or kind == "Stones" or kind == "Tower" or kind == "Escape" then
		local cp = course.Checkpoints[run.Next]
		if cp and (pos - cp).Magnitude <= course.CheckpointRadius + run.PlayerBody then
			run.Next += 1
			signal(player, { State = "Checkpoint", Id = def.Id, Index = run.Next - 1, Total = #course.Checkpoints })
		end
		if
			run.Next > #course.Checkpoints
			and course.Finish
			and (pos - course.Finish).Magnitude <= course.FinishRadius + run.PlayerBody
		then
			finish(player, elapsed)
		end
	elseif kind == "Arena" then
		local reach = math.max(course.Body, run.PlayerBody) * 1.2 + StatService:GetDerived(player).CollectRange * 0.5
		if def.Type == "ResourceRush" then
			for i, token in course.Tokens do
				if not run.Tokens[i] and (pos - token).Magnitude <= reach then
					run.Tokens[i] = true
					run.Found += 1
					signal(player, { State = "Token", Id = def.Id, Index = i, Count = run.Found })
				end
			end
		elseif def.Type == "HiddenObject" then
			for i, target in course.Targets do
				if not run.Targets[i] and (pos - target).Magnitude <= reach then
					run.Targets[i] = true
					run.Found += 1
					signal(
						player,
						{ State = "Target", Id = def.Id, Index = i, Count = run.Found, Total = #course.Targets }
					)
				end
			end
			if run.Found >= #course.Targets then
				finish(player, elapsed)
			end
		end
	elseif kind == "Runway" then
		local takeoff = course.Takeoff
		if takeoff then
			local along = (pos - takeoff.Point):Dot(takeoff.Direction)
			local velocityY = root.AssemblyLinearVelocity.Y
			if along > 0 and feetY > course.FloorY + run.PlayerBody * 0.05 then
				run.Airborne = true
			elseif run.Airborne and along > 0 and math.abs(velocityY) < run.PlayerBody * 0.5 then
				run.Airborne = false
				local distance = along / run.PlayerBody
				run.BestDistance = math.max(run.BestDistance, math.floor(distance * 100) / 100)
				signal(player, { State = "Jump", Id = def.Id, Distance = distance, Best = run.BestDistance })
				finish(player, run.BestDistance)
			end
		end
	end
end

function ChallengeService:Init()
	Net.onRequest("StartChallenge", Guard.shape({ Id = Guard.id() }), function(player, payload)
		return startRun(player, payload.Id)
	end)
	Net.onRequest("LeaveChallenge", Guard.none(), function(player)
		if not runs[player] then
			return { ok = false }
		end
		fail(player, "Left the challenge")
		return { ok = true }
	end)
	FastTravelService:AddBlocker(function(player)
		if runs[player] then
			return "Finish or leave your challenge first"
		end
		return nil
	end)
end

function ChallengeService:Start()
	CombatService.AttackPerformed:Connect(function(player, origin, facing, range, arc)
		local run = runs[player]
		if not run or run.State ~= "Running" or run.Def.Type ~= "TargetBreak" then
			return
		end
		for i, target in run.Course.Targets do
			if not run.Targets[i] and CombatMath.inArc(origin, facing, target, range + run.Course.Body * 0.6, arc) then
				run.Targets[i] = true
				run.Found += 1
				signal(
					player,
					{ State = "Target", Id = run.Def.Id, Index = i, Count = run.Found, Total = #run.Course.Targets }
				)
			end
		end
		if run.Found >= #run.Course.Targets then
			finish(player, os.clock() - run.StartedAt)
		end
	end)
	CharacterService.Died:Connect(function(player)
		if runs[player] then
			runs[player] = nil
			signal(player, { State = "Failed", Reason = "You were knocked out" })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		cooldowns[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for player, run in runs do
				local ok, err = pcall(function()
					monitor(player, run, now)
				end)
				if not ok then
					Log.warn("Challenge", "monitor failed", err)
					fail(player, "Something went wrong")
				end
			end
		end
	end)
end

return ChallengeService
