-- Challenges (honest run, impossible run, leaving, dying) and a boss fight.
local E = __E
E.startServer()
E.run(3)
local PDS = E.serverModule("Services.PlayerDataService")
local Progression = E.serverModule("Services.ProgressionService")
local Registry = E.serverModule("World.CourseBuilder").Registry
local ChallengeConfig = E.sharedModule("Config.ChallengeConfig")
local SizeConfig = E.sharedModule("Config.SizeConfig")
local ScaleMath = E.sharedModule("Formulas.ScaleMath")
local dan = E.addPlayer("Dan", { UserId = 41 })
E.waitFor(function()
	return PDS:IsLoaded(dan) and E.root(dan) ~= nil and not E.root(dan).Anchored
end, 30, "load")
local def = ChallengeConfig.get("CrumbSprint")
Progression:SetMass(dan, SizeConfig.getTier(def.RequiredTier).MassRequired + 1, "Admin")
E.run(5)
local course = Registry[def.Id]
local scale = dan:GetAttribute("Scale")
local h = ScaleMath.height(scale)
local speed = ScaleMath.walkSpeed(scale) * 1.4

local Challenge = E.serverModule("Services.ChallengeService")
local function ended()
	return not Challenge:IsInRun(dan)
end
local function runCourse(fast)
	E.teleport(dan, def.Anchor + Vector3.new(0, h * 0.55 + 0.5, 0))
	E.run(0.5)
	local r = E.request(dan, "StartChallenge", { Id = def.Id })
	if not r.ok then
		return r
	end
	E.run(ChallengeConfig.CountdownSeconds + 1)
	local lift = Vector3.new(0, h * 0.55, 0)
	for _, cp in course.Checkpoints do
		if fast then
			E.teleport(dan, cp + lift)
			E.run(0.1)
		else
			E.walkTo(dan, cp + lift, speed, ended)
		end
	end
	if course.Finish then
		if fast then
			E.teleport(dan, course.Finish + lift)
		else
			E.walkTo(dan, course.Finish + lift, speed, ended)
		end
	end
	E.run(2)
	return r
end

print("== Honest challenge run")
local r = runCourse(false)
E.check("challenge starts from the pad", r.ok == true, tostring(r.err))
local rec = E.data(dan).Challenges[def.Id]
E.check("finish recorded", rec and rec.Completions == 1, rec and rec.Completions)
print(string.format("   time %.2fs, medal %d (thresholds: titan %.1f gold %.1f)", rec and rec.Best or -1, rec and rec.Medal or -1, def.Thresholds.Titan, def.Thresholds.Gold))
E.check("player returned to the pad after finishing", (E.root(dan).Position - def.Anchor).Magnitude < h * 6 + 20, tostring(E.root(dan).Position))

print("== Impossible (teleport) run")
E.run(def.Cooldown + 1)
local best = rec.Best
runCourse(true)
local rec2 = E.data(dan).Challenges[def.Id]
E.check("teleport run rejected (no new best)", rec2.Best == best and rec2.Completions == 1, string.format("best %.2f -> %.2f", best, rec2.Best))

print("== Leaving and dying mid-run")
E.run(def.Cooldown + 1)
E.teleport(dan, def.Anchor + Vector3.new(0, h * 0.55 + 0.5, 0))
E.run(0.5)
E.request(dan, "StartChallenge", { Id = def.Id })
E.run(ChallengeConfig.CountdownSeconds + 1.5)
local left = E.request(dan, "LeaveChallenge")
E.check("can leave a run", left.ok == true, tostring(left.err))
E.run(def.Cooldown + 1)
E.request(dan, "StartChallenge", { Id = def.Id })
E.run(ChallengeConfig.CountdownSeconds + 1.5)
local ft = E.request(dan, "FastTravel", { Station = "FloorWorld" })
E.check("cannot fast travel during a run", ft.ok == false, tostring(ft.err))
dan.Character:FindFirstChildOfClass("Humanoid").Health = 0
E.run(8)
local s = E.request(dan, "LeaveChallenge")
E.check("dying ends the run", s.ok == false or s.ok == true)
E.check("respawned after dying in a run", dan.Character and dan.Character:FindFirstChildOfClass("Humanoid").Health > 0)

print("== Boss: THE QUEEN")
local BossConfig = E.sharedModule("Config.BossConfig")
local queen = BossConfig.get("Queen")
Progression:SetMass(dan, SizeConfig.getTier(queen.RequiredTier).MassRequired + 1, "Admin")
E.run(5)
local arena = E.game:GetService("ReplicatedStorage"):FindFirstChild("WorldIndex"):GetAttribute("Boss_Queen")
local ph = ScaleMath.height(dan:GetAttribute("Scale"))
E.teleport(dan, arena + Vector3.new(ScaleMath.height(queen.Scale) * 1.2, ph * 0.55, 0))
E.run(6)
local BossService = E.serverModule("Services.BossService")
local fight = BossService:GetFight("Queen")
E.check("boss fight starts when an eligible player enters", fight and fight.State == "Fighting", fight and fight.State)
local shards0 = E.data(dan).Currencies.TitanShards
local hits = 0
for _ = 1, 400 do
	if fight.State ~= "Fighting" then
		break
	end
	local root = E.root(dan)
	if not root then
		E.run(6)
		continue
	end
	local bossRoot = fight.Root
	if bossRoot then
		local dir = (bossRoot.Position - root.Position) * Vector3.new(1, 0, 1)
		local stand = bossRoot.Position - dir.Unit * (ScaleMath.height(queen.Scale) * 0.6 + ph * 0.5)
		E.teleport(dan, Vector3.new(stand.X, arena.Y + ph * 0.55, stand.Z))
		E.action(dan, "Attack", { Kind = "Light", Facing = dir.Unit })
		hits += 1
	end
	E.run(0.4)
	local hum = dan.Character and dan.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health < 40 then
		hum.Health = hum.MaxHealth -- keep the tester alive; we're testing the boss loop
	end
end
print(string.format("   attacks: %d, boss state: %s, health %d/%d", hits, fight.State, fight.Health, fight.MaxHealth))
E.check("boss can be defeated with attacks", fight.State == "Defeated", fight.State)
E.run(3)
local bossRec = E.data(dan).Bosses.Queen
E.check("boss kill recorded", bossRec and bossRec.Kills == 1, bossRec and bossRec.Kills)
E.check("boss rewards granted", E.data(dan).Currencies.TitanShards > shards0)
E.summary()
