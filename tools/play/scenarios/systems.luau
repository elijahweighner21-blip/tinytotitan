-- A brand-new player's first session through real remotes, then the
-- bigger systems (skills, fast travel, daily, challenge, boss, ascension).
local E = __E
E.startServer()
E.run(3)
local CS = E.game:GetService("CollectionService")
local PDS = E.serverModule("Services.PlayerDataService")
local Rewards = E.serverModule("Services.RewardService")
local Progression = E.serverModule("Services.ProgressionService")
local WorldIndex = E.game:GetService("ReplicatedStorage"):FindFirstChild("WorldIndex")
local cara = E.addPlayer("Cara", { UserId = 31 })
E.waitFor(function()
	return PDS:IsLoaded(cara) and E.root(cara) ~= nil and not E.root(cara).Anchored
end, 30, "load")
E.run(2)
local function d()
	return E.data(cara)
end
local function step()
	return d().Tutorial.Step
end

print("== Tutorial")
E.check("starts at step 0", step() == 0, step())
E.walkTo(cara, E.root(cara).Position + Vector3.new(8, 0, 0), 4)
E.run(3)
E.check("walking completes 'Move'", step() >= 1, step())
E.action(cara, "Ability", { Id = "Jump" })
E.run(1)
E.check("jumping completes 'Jump'", step() >= 2, step())
local orbs = {}
for _, part in CS:GetTagged("Collectible") do
	if part:GetAttribute("Type") == "GrowthOrb" and part:GetAttribute("Zone") == "FloorWorld" then
		table.insert(orbs, part)
	end
end
table.sort(orbs, function(a, b)
	return (a.Position - E.root(cara).Position).Magnitude < (b.Position - E.root(cara).Position).Magnitude
end)
local function collect(n)
	local got = 0
	for _, orb in orbs do
		if got >= n then
			break
		end
		if not orb:GetAttribute("Taken") then
			E.walkTo(cara, orb.Position + Vector3.new(0, 0.6, 0), 20)
			local before = d().Currencies.Mass
			E.action(cara, "Collect", orb:GetAttribute("CollectibleId"))
			E.run(0.2)
			if d().Currencies.Mass > before then
				got += 1
				orb:SetAttribute("Taken", true)
			end
		end
	end
	return got
end
collect(3)
E.check("collecting an orb completes 'Orb'", step() >= 3, step())
local quest = d().Quests.Active.FirstSteps
E.check("story quest FirstSteps auto-started", quest ~= nil)
E.check("FirstSteps counts orbs", quest and (quest.Progress[1] or 0) >= 3, quest and quest.Progress[1])
-- Discovery: step into Rug Edge.
local rug = WorldIndex:GetAttribute("Discovery_RugEdge")
E.walkTo(cara, rug + Vector3.new(0, 0.6, 0), 20)
E.run(1.5)
E.check("Rug Cliffs discovered", d().Discoveries.RugEdge ~= nil)
E.check("discovery completes 'Parkour'", step() >= 4, step())
local discMass = d().Currencies.Mass
E.walkTo(cara, rug + Vector3.new(1, 0.6, 0), 20)
E.run(1.5)
E.check("discovery rewards only once", d().Currencies.Mass == discMass)
collect(4)
E.run(1)
E.check("earning Mass completes 'Mass'", step() >= 5, step())
-- Upgrade: earn energy by playing, then buy.
collect(14)
local ge = d().Currencies.GrowthEnergy
print("   Growth Energy after ~20 orbs + discovery: " .. ge)
local r = E.request(cara, "BuyUpgrade", { Id = "MassGain" })
E.check("first upgrade affordable from early play", r.ok == true, tostring(r.err) .. " (GE " .. ge .. ")")
E.check("buying completes 'Upgrade'", step() >= 6, step())
-- Talk to Mote to finish FirstSteps.
local mote = WorldIndex:GetAttribute("NPC_Mote")
E.walkTo(cara, mote + Vector3.new(1, 0.6, 1), 20)
local talk = E.request(cara, "Talk", { Npc = "Mote" })
E.check("can talk to Professor Mote", talk.ok == true, tostring(talk.err))
E.run(1)
E.check("FirstSteps completed", d().Quests.Completed.FirstSteps ~= nil)
E.check("next story quest started", d().Quests.Active.OrbHunter ~= nil)
-- Grow to Dust-Sized by playing.
local orbsForTier = 0
while (cara:GetAttribute("Tier") or 1) < 2 and orbsForTier < 60 do
	orbsForTier += collect(1)
	if orbsForTier == 0 then
		break
	end
end
print("   orbs to reach Dust-Sized: about " .. orbsForTier + 20)
E.run(4)
E.check("reached Dust-Sized", (cara:GetAttribute("Tier") or 1) >= 2, cara:GetAttribute("Tier"))
E.check("growing completes 'Grow'", step() >= 7, step())
E.action(cara, "Sprint", true)
E.root(cara).AssemblyLinearVelocity = Vector3.new(20, 0, 0)
E.run(2)
E.action(cara, "Sprint", false)
E.run(1)
E.check("sprinting completes the tutorial", d().Tutorial.Done == true, step())

print("== Skills")
local sp = d().Currencies.SkillPoints
print("   skill points at level " .. d().Progress.Level .. ": " .. sp)
local sk = E.request(cara, "UnlockSkill", { Id = "Slide" })
E.check("can unlock a first skill", sk.ok == true, tostring(sk.err))
local bad = E.request(cara, "UnlockSkill", { Id = "TitanRoar" })
E.check("cannot unlock a locked late skill", bad.ok == false)

print("== Fast travel rules")
local ft = E.request(cara, "FastTravel", { Station = "TitanCity" })
E.check("cannot travel to an unvisited/locked zone", ft.ok == false, tostring(ft.err))

print("== Daily")
local login = E.request(cara, "ClaimDaily", { Kind = "Login" })
E.check("login reward claimable", login.ok == true, tostring(login.err))
local again = E.request(cara, "ClaimDaily", { Kind = "Login" })
E.check("login reward not claimable twice", again.ok == false)

print("== Ascension keeps what it promises")
Progression:SetMass(cara, E.sharedModule("Config.SizeConfig").getTier(12).MassRequired + 10, "Admin")
E.run(6)
Rewards:Grant(cara, { TitanShards = 77 }, { Source = "Purchase", Multipliers = false })
d().Cosmetics.Owned.GlowAura = true
local before = { Shards = d().Currencies.TitanShards, Level = d().Progress.Level, Disc = d().Discoveries.RugEdge, Cos = d().Cosmetics.Owned.GlowAura }
local noConfirm = E.request(cara, "Ascend", {})
E.check("ascend refused without confirmation", noConfirm.ok == false)
local asc = E.request(cara, "Ascend", { Confirm = "ASCEND" })
E.check("ascend succeeds at Titan", asc.ok == true, tostring(asc.err))
E.run(5)
E.check("Mass reset", d().Currencies.Mass == 0, d().Currencies.Mass)
E.check("Titan Shards kept", d().Currencies.TitanShards >= before.Shards, before.Shards .. " -> " .. d().Currencies.TitanShards)
E.check("level kept", d().Progress.Level >= before.Level, before.Level .. " -> " .. d().Progress.Level)
E.check("discoveries kept", d().Discoveries.RugEdge == before.Disc)
E.check("cosmetics kept", d().Cosmetics.Owned.GlowAura == true)
E.check("ascension points granted", d().Currencies.AscensionPoints > 0, d().Currencies.AscensionPoints)
E.check("shrunk back to Microscopic", cara.Character:GetScale() < 0.3, cara.Character:GetScale())
E.check("alive after ascending", cara.Character:FindFirstChildOfClass("Humanoid").Health > 0)
E.summary()
