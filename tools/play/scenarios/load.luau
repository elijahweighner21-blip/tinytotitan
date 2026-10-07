-- Server load: 12 players of different sizes moving around for 60s.
local E = __E
E.startServer()
E.run(3)
local PDS = E.serverModule("Services.PlayerDataService")
local Admin = E.serverModule("Services.ProgressionService")
local ZoneConfig = E.sharedModule("Config.ZoneConfig")
local SizeConfig = E.sharedModule("Config.SizeConfig")
local players = {}
for i = 1, 12 do
	local p = E.addPlayer("P" .. i, { UserId = 2000 + i })
	table.insert(players, p)
end
E.waitFor(function()
	for _, p in players do
		if not PDS:IsLoaded(p) or not p.Character then
			return false
		end
	end
	return true
end, 60, "all loaded")
-- Spread sizes: tiny, human, titan...
for i, p in players do
	local tier = ((i - 1) % 15) + 1
	Admin:SetMass(p, SizeConfig.getTier(tier).MassRequired + 1, "Admin")
end
local damage = {}
E.serverModule("Services.CombatService").PlayerDamaged:Connect(function(player, amount, source)
	local key = tostring(source) .. " -> tier " .. tostring(player:GetAttribute("Tier")) .. " (" .. tostring(player:GetAttribute("Zone")) .. ")"
	damage[key] = (damage[key] or 0) + amount
end)
E.run(8)
E.profiling = true
local rays0 = E.raycasts or 0
local t0 = E.now
local real0 = E.realClock()
for step = 1, 60 * 10 do
	for i, p in players do
		local root = E.root(p)
		if root then
			local zone = ZoneConfig.highestUnlocked(p:GetAttribute("Tier") or 1)
			local a = step / 60 + i
			local h = 5 * (p:GetAttribute("Scale") or 1)
			local pos = zone.Spawn + Vector3.new(math.cos(a) * h * 6, h * 0.55 + 1, math.sin(a) * h * 6)
			p.Character:PivotTo(CFrame.new(pos))
			root.AssemblyLinearVelocity = Vector3.new(-math.sin(a), 0, math.cos(a)) * h
		end
	end
	E.step(1 / 10)
end
E.profiling = false
local simulated = E.now - t0
print("== Server load: 12 players, " .. simulated .. "s simulated")
E.profileReport(18, simulated)
print(string.format("   wall time %.2fs", E.realClock() - real0))
print(string.format("   raycasts: %.0f per simulated second, enemies alive: %d", ((E.raycasts or 0) - rays0) / simulated, E.serverModule("Services.EnemyService"):Count()))
local alive = 0
for _, p in players do
	if p.Character and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
		alive += 1
	end
end
E.check("no server errors under load", E.countLog("error") == 0, E.countLog("error"))
print("   alive: " .. alive .. "/12, deaths: " .. #(E.deaths or {}))
for _, d in E.deaths or {} do
	print("     death: " .. d.Who .. " at " .. string.format("%.1f", d.At))
end
local keys = {}
for k, v in damage do
	table.insert(keys, string.format("%6.0f dmg  %s", v, k))
end
table.sort(keys)
for _, k in keys do
	print("   " .. k)
end
for _, l in E.log do
	if l.Kind == "warn" then
		print("   WARN " .. string.sub(l.Text, 1, 160))
	end
end
E.summary()
