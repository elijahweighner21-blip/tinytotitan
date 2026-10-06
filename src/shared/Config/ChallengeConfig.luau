--!strict
--[[
	ChallengeConfig
	Repeatable challenges with Bronze / Silver / Gold / Titan medals.

	Each challenge has a START PAD in the world (`Anchor`) and a course built in
	its own "training simulation" pocket (server/World/CourseBuilder) far from
	the playable map, so courses never collide with furniture or arenas.

	Course geometry is expressed relative to the intended tier's REAL movement
	capabilities: `Gap` is a fraction of the max running-jump distance and
	`Rise` a fraction of max jump height. The same numbers drive the medal
	times, so every course is feasible and its medals stay consistent if
	movement is re-tuned.

	Medal eligibility (and leaderboards) only apply while the player's tier is
	within [RequiredTier, MaxTier] — a titan sprinting through an ant course
	does not get a record. Shrink Mode can bring a player back into range.
]]

local Types = require(script.Parent.Parent.Types)
local RewardConfig = require(script.Parent.RewardConfig)
local SizeConfig = require(script.Parent.SizeConfig)
local ScaleMath = require(script.Parent.Parent.Formulas.ScaleMath)

type Reward = Types.Reward

export type Course = {
	Kind: string, -- Sprint | Tower | Stones | Arena | Runway | Escape
	Segments: number, -- platforms (or tokens/targets for arena kinds)
	Gap: number, -- fraction of the max running-jump distance between platforms
	Rise: number, -- fraction of max jump height gained per segment
	Width: number, -- platform / arena size in body lengths
	Targets: number?,
	Seed: number,
}

export type ChallengeDef = {
	Id: string,
	Name: string,
	Type: string,
	Zone: string,
	Description: string,
	RequiredTier: number,
	MaxTier: number,
	TimeLimit: number,
	Thresholds: { Bronze: number, Silver: number, Gold: number, Titan: number },
	LowerIsBetter: boolean,
	MinPlausibleTime: number?,
	Rewards: { Bronze: Reward, Silver: Reward, Gold: Reward, Titan: Reward },
	Leaderboard: boolean,
	Cooldown: number,
	Course: Course,
	Anchor: Vector3,
	Score: string, -- Time | Count | Distance
}

local R = RewardConfig.zone

local function medalRewards(zone: string, weight: number): { Bronze: Reward, Silver: Reward, Gold: Reward, Titan: Reward }
	return {
		Bronze = R(zone, weight),
		Silver = R(zone, weight * 1.6),
		Gold = R(zone, weight * 2.4, { TitanShards = 2 }),
		Titan = R(zone, weight * 3.5, { TitanShards = 5 }),
	}
end

-- Physical numbers for the intended tier (no upgrades).
local function physics(tier: number)
	local scale = SizeConfig.getTier(tier).Scale
	local body = ScaleMath.height(scale)
	local sprint = ScaleMath.walkSpeed(scale) * ScaleMath.sprintMultiplier(scale)
	local airtime = ScaleMath.airTime(scale)
	local jumpDistance = sprint * airtime
	return body, sprint, airtime, jumpDistance, ScaleMath.jumpHeight(scale)
end

-- Ideal completion time for a course at the intended tier.
local function idealTime(tier: number, course: Course): number
	local body, sprint, airtime, jumpDistance = physics(tier)
	if course.Kind == "Tower" or course.Kind == "Escape" then
		return course.Segments * airtime * 1.05 + 1
	elseif course.Kind == "Arena" then
		local count = course.Targets or course.Segments
		return count * (course.Width * body * 0.35 / sprint + 0.6) + 1
	end
	local perSegment = (course.Gap * jumpDistance + course.Width * body) / sprint
	return course.Segments * math.max(perSegment, airtime * 0.9) + 1
end

local function timed(def: {
	Id: string,
	Name: string,
	Type: string,
	Zone: string,
	Description: string,
	RequiredTier: number,
	Course: Course,
	Anchor: Vector3,
	Weight: number,
}): ChallengeDef
	local ideal = idealTime(def.RequiredTier, def.Course)
	return {
		Id = def.Id,
		Name = def.Name,
		Type = def.Type,
		Zone = def.Zone,
		Description = def.Description,
		RequiredTier = def.RequiredTier,
		MaxTier = def.RequiredTier + 2,
		TimeLimit = math.ceil(ideal * 6 + 20),
		Thresholds = {
			Titan = math.floor(ideal * 1.25 * 10) / 10,
			Gold = math.floor(ideal * 1.6 * 10) / 10,
			Silver = math.floor(ideal * 2.2 * 10) / 10,
			Bronze = math.floor(ideal * 3.4 * 10) / 10,
		},
		LowerIsBetter = true,
		MinPlausibleTime = ideal * 0.35,
		Rewards = medalRewards(def.Zone, def.Weight),
		Leaderboard = true,
		Cooldown = 20,
		Course = def.Course,
		Anchor = def.Anchor,
		Score = "Time",
	}
end

local function scored(def: {
	Id: string,
	Name: string,
	Type: string,
	Zone: string,
	Description: string,
	RequiredTier: number,
	Course: Course,
	Anchor: Vector3,
	Weight: number,
	TimeLimit: number,
	Thresholds: { Bronze: number, Silver: number, Gold: number, Titan: number },
	Score: string,
}): ChallengeDef
	return {
		Id = def.Id,
		Name = def.Name,
		Type = def.Type,
		Zone = def.Zone,
		Description = def.Description,
		RequiredTier = def.RequiredTier,
		MaxTier = def.RequiredTier + 2,
		TimeLimit = def.TimeLimit,
		Thresholds = def.Thresholds,
		LowerIsBetter = false,
		MinPlausibleTime = nil,
		Rewards = medalRewards(def.Zone, def.Weight),
		Leaderboard = true,
		Cooldown = 20,
		Course = def.Course,
		Anchor = def.Anchor,
		Score = def.Score,
	}
end

local List: { ChallengeDef } = {
	-- Floor World -----------------------------------------------------------
	timed({ Id = "CrumbSprint", Name = "Crumb Sprint", Type = "TimeTrial", Zone = "FloorWorld", Description = "Race across the crumbs from start to finish.", RequiredTier = 2, Weight = 2,
		Course = { Kind = "Sprint", Segments = 12, Gap = 0.55, Rise = 0.15, Width = 2.2, Seed = 11 }, Anchor = Vector3.new(215, 0, 290) }),
	timed({ Id = "FiberClimb", Name = "Fiber Climb", Type = "Climb", Zone = "FloorWorld", Description = "Climb a tower of thread spools and buttons.", RequiredTier = 3, Weight = 2.5,
		Course = { Kind = "Tower", Segments = 12, Gap = 0.35, Rise = 0.55, Width = 1.8, Seed = 12 }, Anchor = Vector3.new(290, 0, 40) }),
	scored({ Id = "CoinRush", Name = "Coin Rush", Type = "ResourceRush", Zone = "FloorWorld", Description = "Grab as many spinning tokens as you can in 45 seconds.", RequiredTier = 2, Weight = 2,
		Course = { Kind = "Arena", Segments = 24, Gap = 0, Rise = 0, Width = 22, Seed = 13 }, Anchor = Vector3.new(60, 0, 45),
		TimeLimit = 45, Thresholds = { Bronze = 8, Silver = 13, Gold = 18, Titan = 22 }, Score = "Count" }),
	-- Bedroom -------------------------------------------------------------------
	timed({ Id = "DeskDash", Name = "Desk Dash", Type = "TimeTrial", Zone = "Bedroom", Description = "An obstacle course of pencils, erasers and sticky notes.", RequiredTier = 4, Weight = 2.5,
		Course = { Kind = "Sprint", Segments = 14, Gap = 0.6, Rise = 0.2, Width = 2, Seed = 21 }, Anchor = Vector3.new(-230, 0, -60) }),
	timed({ Id = "BookshelfAscent", Name = "Bookshelf Ascent", Type = "Climb", Zone = "Bedroom", Description = "Climb book spines to the top shelf.", RequiredTier = 5, Weight = 3,
		Course = { Kind = "Tower", Segments = 14, Gap = 0.35, Rise = 0.6, Width = 1.6, Seed = 22 }, Anchor = Vector3.new(-150, 0, -60) }),
	timed({ Id = "LavaRug", Name = "The Floor Is Lava", Type = "FloorIsLava", Zone = "Bedroom", Description = "Cross the rug on stepping stones. Touch the floor and you're out.", RequiredTier = 4, Weight = 3,
		Course = { Kind = "Stones", Segments = 16, Gap = 0.5, Rise = 0.05, Width = 1.4, Seed = 23 }, Anchor = Vector3.new(-70, 0, -60) }),
	-- Kitchen -------------------------------------------------------------------
	timed({ Id = "CounterRun", Name = "Counter Run", Type = "TimeTrial", Zone = "Kitchen", Description = "Sprint the full length of the counters.", RequiredTier = 6, Weight = 2.5,
		Course = { Kind = "Sprint", Segments = 14, Gap = 0.6, Rise = 0.2, Width = 2, Seed = 31 }, Anchor = Vector3.new(255, 0, -60) }),
	scored({ Id = "SpoonLeap", Name = "Spoon Leap", Type = "DistanceJump", Zone = "Kitchen", Description = "Launch off the spoon and land as far as you can.", RequiredTier = 6, Weight = 2,
		Course = { Kind = "Runway", Segments = 1, Gap = 0, Rise = 0, Width = 4, Seed = 32 }, Anchor = Vector3.new(255, 0, -105),
		TimeLimit = 30, Thresholds = { Bronze = 2, Silver = 3, Gold = 4.5, Titan = 6 }, Score = "Distance" }),
	timed({ Id = "CupSmash", Name = "Cup Smash", Type = "TargetBreak", Zone = "Kitchen", Description = "Smash all 10 paper cups as fast as possible.", RequiredTier = 6, Weight = 2.5,
		Course = { Kind = "Arena", Segments = 10, Gap = 0, Rise = 0.3, Width = 12, Targets = 10, Seed = 33 }, Anchor = Vector3.new(255, 0, -240) }),
	-- Backyard ------------------------------------------------------------------
	timed({ Id = "GnomeHunt", Name = "Gnome Hunt", Type = "HiddenObject", Zone = "Backyard", Description = "Find all 6 tiny gnomes hidden in the garden.", RequiredTier = 7, Weight = 3,
		Course = { Kind = "Arena", Segments = 6, Gap = 0, Rise = 0, Width = 16, Targets = 6, Seed = 41 }, Anchor = Vector3.new(-200, 0, -700) }),
	timed({ Id = "FenceRun", Name = "Fence Run", Type = "TimeTrial", Zone = "Backyard", Description = "Run along the fence posts without falling.", RequiredTier = 8, Weight = 3,
		Course = { Kind = "Sprint", Segments = 16, Gap = 0.6, Rise = 0.2, Width = 1.6, Seed = 42 }, Anchor = Vector3.new(500, 0, -1000) }),
	-- Neighborhood ----------------------------------------------------------------
	timed({ Id = "RooftopRush", Name = "Rooftop Rush", Type = "TimeTrial", Zone = "Neighborhood", Description = "Leap across the neighborhood rooftops.", RequiredTier = 9, Weight = 3,
		Course = { Kind = "Sprint", Segments = 14, Gap = 0.65, Rise = 0.3, Width = 2.2, Seed = 51 }, Anchor = Vector3.new(-1200, 0, -2000) }),
	timed({ Id = "DrainEscape", Name = "Drain Escape", Type = "Escape", Zone = "Neighborhood", Description = "The water is rising. Climb out of the drain!", RequiredTier = 9, Weight = 3.5,
		Course = { Kind = "Escape", Segments = 14, Gap = 0.3, Rise = 0.6, Width = 1.6, Seed = 52 }, Anchor = Vector3.new(1600, 0, -2400) }),
	-- Downtown ------------------------------------------------------------------
	timed({ Id = "SkyscraperClimb", Name = "Skyscraper Climb", Type = "Climb", Zone = "Downtown", Description = "Scale the side of a skyscraper, ledge by ledge.", RequiredTier = 10, Weight = 3.5,
		Course = { Kind = "Tower", Segments = 18, Gap = 0.35, Rise = 0.65, Width = 1.8, Seed = 61 }, Anchor = Vector3.new(-1500, 0, 4200) }),
	timed({ Id = "TowerTargets", Name = "Tower Targets", Type = "TargetBreak", Zone = "Downtown", Description = "Break 12 drone beacons across the rooftops.", RequiredTier = 11, Weight = 3,
		Course = { Kind = "Arena", Segments = 12, Gap = 0, Rise = 0.5, Width = 12, Targets = 12, Seed = 62 }, Anchor = Vector3.new(1800, 0, 6600) }),
	-- Titan City / Wilderness -------------------------------------------------------
	timed({ Id = "TitanGauntlet", Name = "Titan Gauntlet", Type = "TimeTrial", Zone = "TitanCity", Description = "The Titans' own obstacle course.", RequiredTier = 12, Weight = 3.5,
		Course = { Kind = "Sprint", Segments = 16, Gap = 0.6, Rise = 0.3, Width = 2, Seed = 71 }, Anchor = Vector3.new(6200, 0, 6000) }),
	scored({ Id = "TitanLongJump", Name = "Titan Long Jump", Type = "DistanceJump", Zone = "TitanCity", Description = "How far can a Titan fly?", RequiredTier = 12, Weight = 2.5,
		Course = { Kind = "Runway", Segments = 1, Gap = 0, Rise = 0, Width = 4, Seed = 72 }, Anchor = Vector3.new(9800, 0, -1500),
		TimeLimit = 30, Thresholds = { Bronze = 2, Silver = 3, Gold = 4.5, Titan = 6 }, Score = "Distance" }),
	timed({ Id = "PeakAscent", Name = "Peak Ascent", Type = "Climb", Zone = "TitanWilderness", Description = "Race up the floating stones beside Sky Falls.", RequiredTier = 13, Weight = 4,
		Course = { Kind = "Tower", Segments = 16, Gap = 0.35, Rise = 0.65, Width = 1.8, Seed = 81 }, Anchor = Vector3.new(-9000, 0, -2500) }),
}

local byId: { [string]: ChallengeDef } = {}
for _, def in List do
	assert(byId[def.Id] == nil, "duplicate challenge " .. def.Id)
	byId[def.Id] = def
end

local ChallengeConfig = {
	List = List,
	Medals = { "Bronze", "Silver", "Gold", "Titan" },
	MedalColors = {
		Bronze = Color3.fromRGB(205, 127, 50),
		Silver = Color3.fromRGB(200, 205, 215),
		Gold = Color3.fromRGB(255, 205, 60),
		Titan = Color3.fromRGB(120, 220, 255),
	},
	-- Repeat completions at an already-earned medal pay this fraction.
	RepeatRewardFraction = 0.3,
	-- Leaving the course area further than this many course radii fails the run.
	LeaveRadiusMultiplier = 1.6,
	CountdownSeconds = 3,
	idealTime = idealTime,
	physics = physics,
}

function ChallengeConfig.get(id: string): ChallengeDef?
	return byId[id]
end

-- 0 = none, 1 Bronze, 2 Silver, 3 Gold, 4 Titan
function ChallengeConfig.medalFor(def: ChallengeDef, score: number): number
	local t = def.Thresholds
	local order = { t.Bronze, t.Silver, t.Gold, t.Titan }
	local medal = 0
	for i, threshold in order do
		local ok = if def.LowerIsBetter then score <= threshold else score >= threshold
		if ok then
			medal = i
		end
	end
	return medal
end

return ChallengeConfig
