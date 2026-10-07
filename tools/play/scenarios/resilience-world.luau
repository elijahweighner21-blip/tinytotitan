-- Even if building the world fails outright, the game systems still start:
-- saves load, the player spawns (on a safety pad) and can play once fixed.
local E = __E
E.serverModule("World.WorldBuilder").build = function()
	error("simulated world build failure")
end
E.startServer()
E.run(3)
local yuki = E.addPlayer("Yuki", { UserId = 5151, client = true })
E.startClient(yuki)
local PDS = E.serverModule("Services.PlayerDataService")
E.waitFor(function()
	return PDS:IsLoaded(yuki) and yuki.Character ~= nil
end, 60, "spawn")
E.run(10)
print("== World build failed")
E.check("services still started and the save loaded", PDS:IsLoaded(yuki))
local root = E.root(yuki)
E.check("player spawned and is not frozen", root ~= nil and not root.Anchored)
local loading = yuki.PlayerGui:FindFirstChild("TT_Loading")
E.check("loading screen dismissed", loading == nil or loading:FindFirstChild("Loading") == nil)
local reported = false
for _, l in E.log do
	if string.find(l.Text, "world build failed", 1, true) then
		reported = true
	end
end
E.check("the failure is reported in the output", reported)
E.summary()
