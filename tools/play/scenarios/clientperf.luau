-- Client frame cost: a real client playing at 60 fps, first as a speck in
-- the Floor World (dense props, orbs, camp lights), then as a titan in
-- Titan City. Reports script time per frame and the most expensive handlers.
local E = __E
E.startServer()
E.run(3)
local p = E.addPlayer("Perf", { UserId = 4343, client = true })
E.startClient(p)
local PDS = E.serverModule("Services.PlayerDataService")
E.waitFor(function()
	return PDS:IsLoaded(p) and p.Character ~= nil
end, 40, "spawn")
E.run(6)

local function measure(label, seconds, move)
	table.clear(E.profile)
	E.profiling = true
	local frames = math.floor(seconds * 60)
	local start = E.root(p).Position
	for i = 1, frames do
		local root = E.root(p)
		if root and move then
			local t = i / 60
			p.Character:PivotTo(CFrame.new(start + move(t)))
			-- The real camera follows the player; the emulator's doesn't.
			local h = 5 * (p:GetAttribute("Scale") or 1)
			local eye = root.Position + Vector3.new(0, h * 0.6, h * 2.2)
			E.workspace.CurrentCamera.CFrame = CFrame.lookAt(eye, root.Position)
		end
		E.step(1 / 60)
	end
	E.profiling = false
	local total = 0
	for _, e in E.profile do
		total += e.time
	end
	local perFrame = total * 1000 / frames
	local node = p:FindFirstChild("PlayerScripts"):FindFirstChild("Client").Controllers.EnvironmentController
	print(string.format("== %s: %.2f ms script per frame (%d frames), %d ambient objects animated", label, perFrame, frames, E.require(node, "client").Animated))
	E.profileReport(10, seconds)
	return perFrame
end

local speck = measure("Floor World, Microscopic", 10, function(t)
	return Vector3.new(math.sin(t * 0.6) * 12, 0, -t * 1.5)
end)
local SizeConfig = E.sharedModule("Config.SizeConfig")
E.serverModule("Services.ProgressionService"):SetMass(p, SizeConfig.getTier(12).MassRequired + 1, "Admin")
E.run(6)
local ZoneConfig = E.sharedModule("Config.ZoneConfig")
local h = 5 * (p:GetAttribute("Scale") or 1)
E.teleport(p, ZoneConfig.get("TitanCity").Spawn + Vector3.new(0, h * 0.55 + 1, 0))
E.run(6)
local titan = measure("Titan City, Titan", 10, function(t)
	return Vector3.new(t * 80, 0, math.sin(t) * 200)
end)
-- Budget: a 60 fps frame is 16.7 ms; scripts should use a small slice.
E.check("client scripts stay under 4 ms/frame as a speck", speck < 4, string.format("%.2f", speck))
E.check("client scripts stay under 4 ms/frame as a titan", titan < 4, string.format("%.2f", titan))
E.check("no client errors", E.countLog("error") == 0, E.countLog("error"))
E.summary()
