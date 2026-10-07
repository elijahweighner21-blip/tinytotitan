-- Full server-side player lifecycle with real services and DataStores.
local E = __E
local Monet = E.sharedModule("Config.MonetizationConfig")
Monet.DeveloperProducts.Shards100.ProductId = 9001
Monet.DeveloperProducts.MassBoost30.ProductId = 9002
Monet.DeveloperProducts.StarterPack.ProductId = 9003

E.startServer()
E.run(3)
local CS = E.game:GetService("CollectionService")
local Progression = E.sharedModule("Formulas.Progression")
local PDS = E.serverModule("Services.PlayerDataService")
local GameConfig = E.sharedModule("Config.GameConfig")

print("== Join and spawn")
local alice = E.addPlayer("Alice", { UserId = 501 })
E.waitFor(function()
	return PDS:IsLoaded(alice) and alice.Character ~= nil and E.root(alice) ~= nil and not E.root(alice).Anchored
end, 30, "spawn")
E.check("data loaded", PDS:IsLoaded(alice))
E.check("character spawned", alice.Character ~= nil)
E.run(10)
E.check("character still alive 10s after spawn", alice.Character and alice.Character:FindFirstChildOfClass("Humanoid").Health > 0, #(E.deaths or {}) .. " deaths")
local root = E.root(alice)
local scale = alice:GetAttribute("Scale")
E.check("starts Microscopic (scale 0.2)", scale and math.abs(scale - 0.2) < 1e-6, tostring(scale))
E.check("model actually scaled to 0.2", alice.Character:GetScale() < 0.21, tostring(alice.Character:GetScale()))
local spawn = E.sharedModule("Config.ZoneConfig").get("FloorWorld").Spawn
E.check("spawned at the Floor World spawn", root and (root.Position - spawn).Magnitude < 10, root and tostring(root.Position))
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = { alice.Character }
local below = E.workspace:Raycast(root.Position, Vector3.new(0, -50, 0), rp)
E.check("there is ground under the spawn", below ~= nil, "nothing below " .. tostring(root.Position))
if below then
	print("   ground: " .. below.Instance:GetFullName() .. " at y=" .. string.format("%.2f", below.Position.Y) .. ", feet clearance " .. string.format("%.2f", root.Position.Y - root.Size.Y / 2 - below.Position.Y - alice.Character:FindFirstChildOfClass("Humanoid").HipHeight))
end

print("== Collect orbs")
local data = E.data(alice)
local mass0 = data.Currencies.Mass
local orbs = {}
for _, part in CS:GetTagged("Collectible") do
	if part:GetAttribute("Type") == "GrowthOrb" and part:GetAttribute("Zone") == "FloorWorld" then
		table.insert(orbs, part)
	end
end
table.sort(orbs, function(a, b)
	return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
end)
E.check("Floor World has growth orbs", #orbs >= 10, #orbs)
local collected = 0
for i = 1, math.min(12, #orbs) do
	local orb = orbs[i]
	E.walkTo(alice, orb.Position + Vector3.new(0, 0.6, 0), 25)
	local before = E.data(alice).Currencies.Mass
	E.action(alice, "Collect", orb:GetAttribute("CollectibleId"))
	E.run(0.2)
	if E.data(alice).Currencies.Mass > before then
		collected += 1
	end
end
E.check("collecting orbs grants Mass", collected >= 10, collected .. " of 12")
print(string.format("   Mass %d -> %d", mass0, E.data(alice).Currencies.Mass))
local again = E.data(alice).Currencies.Mass
E.action(alice, "Collect", orbs[1]:GetAttribute("CollectibleId"))
E.run(0.2)
E.check("same orb can't be collected again during its respawn", E.data(alice).Currencies.Mass == again)

print("== Exploit attempts")
local far = orbs[#orbs]
local m1 = E.data(alice).Currencies.Mass
E.action(alice, "Collect", far:GetAttribute("CollectibleId"))
E.run(0.2)
E.check("far-away orb rejected", E.data(alice).Currencies.Mass == m1)
local markErr = #E.log
for _, bad in { 42, {}, string.rep("x", 500), nil } do
	E.action(alice, "Collect", bad)
end
E.action(alice, "NotARealAction", { give = 1e9 })
local r = E.request(alice, "BuyUpgrade", { Id = "MassGain", Level = 99 })
E.check("malformed/unknown remote traffic raises no server errors", #E.errorsSince(markErr) == 0, table.concat(E.errorsSince(markErr), "\n"))
E.check("upgrade without enough Growth Energy is refused", r.ok == false, tostring(r.err))
local ge = E.data(alice).Currencies.GrowthEnergy
for _ = 1, 40 do
	E.request(alice, "BuyUpgrade", { Id = "WalkSpeed" })
end
E.check("currency never goes negative", E.data(alice).Currencies.GrowthEnergy >= 0, E.data(alice).Currencies.GrowthEnergy)

print("== Earn energy, buy an upgrade")
E.run(5) -- let the request rate limiter refill after the spam above
E.data(alice).Currencies.GrowthEnergy += 0 -- untouched; earn legitimately below
local rewards = E.serverModule("Services.RewardService")
rewards:Grant(alice, { GrowthEnergy = 500 }, { Source = "Quest" })
local before = E.data(alice).Upgrades.MassGain or 0
local res = E.request(alice, "BuyUpgrade", { Id = "MassGain" })
E.check("upgrade purchase succeeds", res.ok == true, tostring(res.err))
E.check("upgrade level increased by exactly one", (E.data(alice).Upgrades.MassGain or 0) == before + 1)

print("== Grow a tier")
local tier0 = alice:GetAttribute("Tier")
rewards:Grant(alice, { Mass = 300 }, { Source = "Quest" })
E.run(4)
E.check("tier increased", alice:GetAttribute("Tier") > tier0, tostring(tier0) .. " -> " .. tostring(alice:GetAttribute("Tier")))
E.check("character grew", alice.Character:GetScale() > 0.21, tostring(alice.Character:GetScale()))
E.check("still alive after growing", alice.Character:FindFirstChildOfClass("Humanoid").Health > 0)

print("== Save, leave, rejoin")
local snapshot = { Mass = E.data(alice).Currencies.Mass, GE = E.data(alice).Currencies.GrowthEnergy, Up = E.data(alice).Upgrades.MassGain, Collectibles = 0 }
E.removePlayer(alice)
E.run(5)
local stored
for key, store in E.dataStores do
	if string.find(key, GameConfig.DataStoreName, 1, true) then
		stored = store[GameConfig.DataKeyPrefix .. "501"]
	end
end
E.check("save record written", stored ~= nil)
E.check("session lock released on leave", stored and stored.Session == nil, stored and stored.Session and stored.Session.JobId)
E.check("saved Mass matches", stored and stored.Data.Currencies.Mass == snapshot.Mass, stored and stored.Data.Currencies.Mass)
local alice2 = E.addPlayer("Alice", { UserId = 501 })
E.waitFor(function()
	return PDS:IsLoaded(alice2)
end, 30, "rejoin load")
local d2 = E.data(alice2)
E.check("Mass restored", d2 and d2.Currencies.Mass == snapshot.Mass)
E.check("Growth Energy restored", d2 and d2.Currencies.GrowthEnergy == snapshot.GE)
E.check("upgrade restored", d2 and d2.Upgrades.MassGain == snapshot.Up)
E.run(3)
E.check("rejoined character spawned at saved size", alice2.Character and alice2.Character:GetScale() > 0.21)

print("== Respawn")
local loads = E.characterLoads
alice2.Character:FindFirstChildOfClass("Humanoid").Health = 0
E.run(GameConfig.RespawnTime + 2)
E.check("respawned after death", E.characterLoads == loads + 1 and alice2.Character and alice2.Character:FindFirstChildOfClass("Humanoid").Health > 0)
E.check("scale restored after respawn", alice2.Character:GetScale() > 0.21)

print("== Purchases")
local shards0 = E.data(alice2).Currencies.TitanShards
local decision = E.deliverReceipt(alice2, 9001, "P-1", 1)
E.check("receipt granted", decision == Enum.ProductPurchaseDecision.PurchaseGranted, tostring(decision))
E.check("100 shards added", E.data(alice2).Currencies.TitanShards == shards0 + 100, E.data(alice2).Currencies.TitanShards - shards0)
E.deliverReceipt(alice2, 9001, "P-1", 1)
E.deliverReceipt(alice2, 9001, "P-1", 1)
E.check("duplicate receipt delivery never grants twice", E.data(alice2).Currencies.TitanShards == shards0 + 100)
-- Save outage during a purchase: must not report granted until saved.
E.dsFailNext = 6
local d1 = E.deliverReceipt(alice2, 9001, "P-2", 1)
E.check("receipt not confirmed while saving fails", d1 == Enum.ProductPurchaseDecision.NotProcessedYet, tostring(d1))
local afterFail = E.data(alice2).Currencies.TitanShards
E.dsFailNext = 0
local d2r = E.deliverReceipt(alice2, 9001, "P-2", 3)
E.check("retry after outage confirms", d2r == Enum.ProductPurchaseDecision.PurchaseGranted, tostring(d2r))
E.check("outage + retry granted exactly once", E.data(alice2).Currencies.TitanShards == shards0 + 200, E.data(alice2).Currencies.TitanShards - shards0)
local _ = afterFail
local starter = E.deliverReceipt(alice2, 9003, "P-3", 1)
E.check("starter pack granted", starter == Enum.ProductPurchaseDecision.PurchaseGranted)
local unknown = E.deliverReceipt(alice2, 123456, "P-4", 1)
E.check("unknown product not granted", unknown == Enum.ProductPurchaseDecision.NotProcessedYet)

print("== Shutdown")
local shardsBefore = E.data(alice2).Currencies.TitanShards
local ok = E.shutdown()
E.check("BindToClose finished", ok)
for key, store in E.dataStores do
	if string.find(key, GameConfig.DataStoreName, 1, true) then
		stored = store[GameConfig.DataKeyPrefix .. "501"]
	end
end
E.check("purchases persisted at shutdown", stored and stored.Data.Currencies.TitanShards == shardsBefore)
print(string.format("   DataStore calls: %d get, %d update, %d set · last save %d bytes", E.dsCalls.Get, E.dsCalls.Update, E.dsCalls.Set, E.lastSaveBytes or 0))
E.summary()
