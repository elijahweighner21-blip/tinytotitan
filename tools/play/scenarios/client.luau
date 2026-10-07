-- Boots server + one real client (all LocalScripts) and exercises the UI.
local E = __E
E.startServer()
E.run(3)
local bob = E.addPlayer("Bob", { UserId = 777, client = true })
E.startClient(bob)
local PDS = E.serverModule("Services.PlayerDataService")
E.waitFor(function()
	return PDS:IsLoaded(bob) and bob.Character ~= nil
end, 30, "load")
E.run(8)
print("== Client boot")
E.check("no errors during client boot", E.countLog("error") == 0, E.countLog("error"))
local gui = bob:FindFirstChild("PlayerGui")
local function guiNamed(n)
	return gui and gui:FindFirstChild(n)
end
E.check("HUD ScreenGui exists", guiNamed("TT_HUD") ~= nil)
local loading = guiNamed("TT_Loading")
local loadingFrame = loading and loading:FindFirstChild("Loading")
E.check("loading screen dismissed", loadingFrame == nil)
local function client(path)
	local node = bob:FindFirstChild("PlayerScripts"):FindFirstChild("Client")
	for part in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(part)
	end
	return E.require(node, "client")
end
local DataController = client("Controllers.DataController")
E.check("client received its data", DataController:IsLoaded())

print("== Every menu opens and closes cleanly")
local UIManager = client("UI.UIManager")
local mark = #E.log
for _, name in { "Upgrades", "Skills", "Quests", "Map", "Challenges", "Collections", "Inventory", "Daily", "Achievements", "Ascension", "Leaderboards", "Party", "Shop", "Settings", "Admin" } do
	task.spawn(function()
		UIManager:Open(name)
	end)
	E.run(1.5)
	local opened = UIManager:Current() == name
	local errs = E.errorsSince(mark)
	E.check("menu " .. name .. " renders", opened and #errs == 0, table.concat(errs, "\n"))
	mark = #E.log
	task.spawn(function()
		UIManager:Close(name)
	end)
	E.run(0.3)
end

print("== Every tab of every menu renders")
mark = #E.log
local tabCount = 0
local menus = gui:FindFirstChild("TT_Menus")
for _, window in menus:GetChildren() do
	if window:IsA("Frame") then
		task.spawn(function()
			UIManager:Open(window.Name)
		end)
		E.run(0.5)
		local bar = window:FindFirstChild("TabBar", true)
		for _, tab in (bar and bar:GetChildren() or {}) do
			if tab:IsA("TextButton") then
				E.click(tab)
				E.run(0.6)
				tabCount += 1
			end
		end
		task.spawn(function()
			UIManager:Close(window.Name)
		end)
		E.run(0.2)
	end
end
local tabErrs = E.errorsSince(mark)
E.check(tabCount .. " tabs render without errors", #tabErrs == 0, table.concat(tabErrs, "\n"))

print("== Gameplay input")
mark = #E.log
for _, key in { Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.Q, Enum.KeyCode.C, Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.One, Enum.KeyCode.Two } do
	E.tap(key, 0.3)
	E.run(0.3)
end
E.clickMouse(true)
E.run(0.2)
E.clickMouse(false)
E.run(1)
local inputErrs = E.errorsSince(mark)
E.check("movement/combat/ability keys run without errors", #inputErrs == 0, table.concat(inputErrs, "\n"))
E.check("still alive after pressing everything", bob.Character and bob.Character:FindFirstChildOfClass("Humanoid").Health > 0)

print("== Buy an upgrade through the UI")
local rewards = E.serverModule("Services.RewardService")
rewards:Grant(bob, { GrowthEnergy = 200 }, { Source = "Quest" })
E.run(1)
task.spawn(function()
	UIManager:Open("Upgrades")
end)
E.run(1)
local growthTab = menus:FindFirstChild("Upgrades"):FindFirstChild("Tab_Growth", true)
if growthTab then
	E.click(growthTab)
	E.run(0.5)
end
local bought = false
for _, d in menus:GetDescendants() do
	if d:IsA("TextButton") and d.Parent and d.Parent.Name == "Footer" and d:IsDescendantOf(menus:FindFirstChild("Upgrades")) then
		local label = d:FindFirstChildWhichIsA("TextLabel")
		if label and string.find(label.Text, "⚡") then
			E.click(d)
			E.run(1)
			bought = true
			break
		end
	end
end
local level = E.data(bob).Upgrades.MassGain or 0
E.check("clicking the price button buys the upgrade", bought and level == 1, "MassGain level " .. level)
task.spawn(function()
	UIManager:Close("Upgrades")
end)
E.run(0.5)

print("== Respawn does not leak connections")
local RS = E.game:GetService("RunService")
local function conns()
	local n = 0
	for _, name in { "Heartbeat", "RenderStepped", "PreSimulation", "Stepped" } do
		n += E.sig(RS, name):Count()
	end
	return n
end
local base = conns()
for i = 1, 3 do
	bob.Character:FindFirstChildOfClass("Humanoid").Health = 0
	E.run(7)
end
local after = conns()
E.check("per-frame connections stable across 3 respawns", after <= base + 2, base .. " -> " .. after)
E.check("character back after respawns", bob.Character and bob.Character:FindFirstChildOfClass("Humanoid").Health > 0)
E.check("no errors across respawns", #E.errorsSince(mark) == 0, table.concat(E.errorsSince(mark), "\n"))
local ui = 0
for _ in gui:GetDescendants() do
	ui += 1
end
print("   UI instances after respawns: " .. ui)
print("   tweens/sec: " .. string.format("%.1f", E.tweensCreated / E.now) .. ", tweens created: " .. E.tweensCreated .. ", sounds played: " .. tostring(E.soundsPlayed) .. ", raycasts: " .. tostring(E.raycasts))
local traffic = {}
for k, v in E.remoteTraffic do
	table.insert(traffic, k .. "=" .. v)
end
table.sort(traffic)
print("   remote traffic: " .. table.concat(traffic, " "))
E.showUnknown = true
E.summary()
