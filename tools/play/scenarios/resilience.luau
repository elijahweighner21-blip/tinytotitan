-- Things break in a live game; a player must still get in and move.
-- Here the Floor World (the first spawn) fails to build and the engine has
-- no LoadCharacterAsync (older Studio builds), at the same time.
local E = __E
E.classes.Player.methods.LoadCharacterAsync = function()
	error("LoadCharacterAsync is not a valid member of Player", 2)
end
E.serverModule("World.Regions.FloorWorld").build = function()
	error("simulated region failure")
end

E.startServer()
E.run(3)
local zara = E.addPlayer("Zara", { UserId = 4242, client = true })
E.startClient(zara)
local PDS = E.serverModule("Services.PlayerDataService")
E.waitFor(function()
	return PDS:IsLoaded(zara) and zara.Character ~= nil
end, 40, "spawn")
E.run(10)

print("== Broken spawn region + missing LoadCharacterAsync")
local root = E.root(zara)
E.check("player still gets a character (legacy LoadCharacter fallback)", root ~= nil)
E.check("character is not frozen", root and not root.Anchored)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = { zara.Character }
local below = root and E.workspace:Raycast(root.Position, Vector3.new(0, -20, 0), rp)
E.check("there is ground under the player (safety pad)", below ~= nil, root and tostring(root.Position))
local loading = zara.PlayerGui:FindFirstChild("TT_Loading")
E.check("loading screen dismissed", loading == nil or loading:FindFirstChild("Loading") == nil)
E.check("alive after 10s", zara.Character and zara.Character:FindFirstChildOfClass("Humanoid").Health > 0)

print("== Watchdog")
zara.Character:Destroy()
E.run(12)
E.check("a player who loses their body gets a new one", E.root(zara) ~= nil)
E.root(zara).Anchored = true
E.run(14)
E.check("a body left frozen is released", not E.root(zara).Anchored)

-- The failures above are deliberate; they must be reported, not hidden.
local reported = 0
for _, l in E.log do
	if string.find(l.Text, "simulated region failure", 1, true) or string.find(l.Text, "falling back", 1, true) then
		reported += 1
	end
end
E.check("the failures are reported in the output", reported >= 2, reported)
E.summary()
