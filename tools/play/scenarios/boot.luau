-- Boots the server, builds the world and checks for runtime errors.
local E = __E
print("== Boot: server start + world build")
local t0 = os.clock()
E.startServer()
E.run(5)
E.check("server booted without errors", E.countLog("error") == 0, E.countLog("error") .. " errors")
local world = E.workspace:FindFirstChild("World")
E.check("world folder exists in Workspace", world ~= nil)
local parts = 0
for _, d in E.workspace:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
print(string.format("   parts in workspace: %d (indexed %d, oversized %d)", parts, E.indexStats.parts, E.indexStats.big))
print("   clamped part sizes: " .. tostring(E.clampedSizes or 0))
for _, ex in E.clampedExamples or {} do
	print("     e.g. " .. ex.Part:GetFullName() .. " requested " .. tostring(ex.Size))
end
E.showUnknown = true

print("== Zone spawns: ground below, room to stand")
local ZoneConfig = E.sharedModule("Config.ZoneConfig")
local SizeConfig = E.sharedModule("Config.SizeConfig")
local ScaleMath = E.sharedModule("Formulas.ScaleMath")
local solid = RaycastParams.new()
solid.RespectCanCollide = true
local box = OverlapParams.new()
box.RespectCanCollide = true
for _, zone in ZoneConfig.Zones do
	local h = ScaleMath.height(SizeConfig.getTier(zone.RequiredTier).Scale)
	local hit = E.workspace:Raycast(zone.Spawn + Vector3.new(0, h * 0.5, 0), Vector3.new(0, -h * 3, 0), solid)
	local groundY = hit and hit.Position.Y
	E.check(zone.Id .. " spawn has ground", groundY ~= nil and math.abs(groundY - zone.Spawn.Y) < math.max(0.5, h * 0.1), if hit then string.format("spawn y=%.1f ground y=%.2f (%s)", zone.Spawn.Y, groundY, hit.Instance:GetFullName()) else "no ground below spawn")
	local standing = zone.Spawn + Vector3.new(0, h * 0.55 + 1, 0)
	local inside = E.workspace:GetPartBoundsInBox(CFrame.new(standing), Vector3.new(h * 0.4, h * 0.8, h * 0.4), box)
	local names = {}
	for _, p in inside do
		table.insert(names, p:GetFullName())
	end
	E.check(zone.Id .. " spawn is clear (no solid parts where the player stands)", #inside == 0, table.concat(names, ", "))
end

print("== Stations and travel pads are not buried in geometry")
local CS = E.game:GetService("CollectionService")
for _, tag in { "Station", "FastTravelStation" } do
	for _, part in CS:GetTagged(tag) do
		local top = part.Position + Vector3.new(0, part.Size.X / 2, 0)
		local probeCf = CFrame.new(top + Vector3.new(0, part.Size.Y * 0.25, 0))
		local probeSize = Vector3.new(part.Size.Y * 0.5, part.Size.Y * 0.4, part.Size.Y * 0.5)
		local clearance = E.workspace:GetPartBoundsInBox(probeCf, probeSize, box)
		local names = {}
		for _, p in clearance do
			-- Only the station's own model is exempt; everything else that
			-- really intersects the space above the pad blocks it.
			if p ~= part and not p:IsDescendantOf(part.Parent) and E.boxesOverlap(probeCf, probeSize, p.CFrame, p.Size) then
				table.insert(names, p:GetFullName())
			end
		end
		E.check(tag .. " " .. part:GetFullName() .. " is reachable", #names == 0, table.concat(names, ", "))
	end
end
E.summary()
