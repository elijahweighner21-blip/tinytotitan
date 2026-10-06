--!strict
--[[
	Probe
	Size-aware raycasts for parkour. Every distance is expressed in body
	heights so wall runs, ledge grabs and vaults behave identically for a
	1-stud speck and a 2000-stud titan. Characters, enemies, collectibles and
	other players are ignored (players never collide with each other).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Probe = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

local excluded: { Instance } = {}

function Probe.refresh()
	table.clear(excluded)
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(excluded, enemies)
	end
	for _, gate in CollectionService:GetTagged("Gate") do
		-- Gates the player can pass are non-collidable locally; treat them as air.
		if gate:IsA("BasePart") and not gate.CanCollide then
			table.insert(excluded, gate)
		end
	end
	params.FilterDescendantsInstances = excluded
end

function Probe.cast(origin: Vector3, direction: Vector3): RaycastResult?
	return workspace:Raycast(origin, direction, params)
end

-- Distance from feet to the ground below (nil if more than `maxBodies` away).
function Probe.groundDistance(feet: Vector3, height: number, maxBodies: number): number?
	local hit = Probe.cast(feet + Vector3.new(0, height * 0.1, 0), Vector3.new(0, -height * maxBodies, 0))
	if hit then
		return math.max(0, feet.Y - hit.Position.Y)
	end
	return nil
end

-- Wall directly ahead at chest height.
function Probe.wallAhead(root: BasePart, height: number, direction: Vector3, reachBodies: number): RaycastResult?
	local dir = Vector3.new(direction.X, 0, direction.Z)
	if dir.Magnitude < 1e-3 then
		return nil
	end
	local hit = Probe.cast(root.Position + Vector3.new(0, height * 0.1, 0), dir.Unit * height * reachBodies)
	if hit and math.abs(hit.Normal.Y) < 0.35 then
		return hit
	end
	return nil
end

-- Side walls for wall running: returns the hit and which side (-1 left, 1 right).
function Probe.sideWall(root: BasePart, height: number, reachBodies: number): (RaycastResult?, number)
	local right = root.CFrame.RightVector
	local origin = root.Position
	local hitR = Probe.cast(origin, right * height * reachBodies)
	if hitR and math.abs(hitR.Normal.Y) < 0.3 then
		return hitR, 1
	end
	local hitL = Probe.cast(origin, -right * height * reachBodies)
	if hitL and math.abs(hitL.Normal.Y) < 0.3 then
		return hitL, -1
	end
	return nil, 0
end

-- Finds a grabbable ledge in front: wall at chest height whose top surface is
-- between minBodies and maxBodies above the feet, with room to stand on it.
function Probe.ledge(root: BasePart, height: number, forward: Vector3, minBodies: number, maxBodies: number): (Vector3?, Vector3?)
	local wall = Probe.wallAhead(root, height, forward, 0.75)
	if not wall then
		return nil, nil
	end
	local feetY = root.Position.Y - height * 0.5
	local inward = -wall.Normal * height * 0.25
	local top = Vector3.new(wall.Position.X, feetY + height * maxBodies + height * 0.1, wall.Position.Z) + inward
	local down = Probe.cast(top, Vector3.new(0, -height * (maxBodies - minBodies + 0.2), 0))
	if not down or down.Normal.Y < 0.7 then
		return nil, nil
	end
	local ledgeHeight = down.Position.Y - feetY
	if ledgeHeight < height * minBodies or ledgeHeight > height * maxBodies then
		return nil, nil
	end
	-- Headroom check above the ledge.
	local clear = Probe.cast(down.Position + Vector3.new(0, height * 0.05, 0), Vector3.new(0, height * 0.9, 0))
	if clear then
		return nil, nil
	end
	return down.Position, wall.Normal
end

-- Low obstacle in front that can be vaulted (top between 0.2 and 0.75 bodies).
function Probe.vaultable(root: BasePart, height: number, forward: Vector3): number?
	local feet = root.Position - Vector3.new(0, height * 0.5, 0)
	local dir = Vector3.new(forward.X, 0, forward.Z)
	if dir.Magnitude < 1e-3 then
		return nil
	end
	dir = dir.Unit
	local low = Probe.cast(feet + Vector3.new(0, height * 0.25, 0), dir * height * 0.9)
	if not low then
		return nil
	end
	local high = Probe.cast(feet + Vector3.new(0, height * 0.8, 0), dir * height * 1.1)
	if high then
		return nil -- too tall: it's a wall, not a vault
	end
	local top = Probe.cast(low.Position + dir * height * 0.15 + Vector3.new(0, height * 0.8, 0), Vector3.new(0, -height * 0.8, 0))
	if not top then
		return nil
	end
	return top.Position.Y - feet.Y
end

return Probe
