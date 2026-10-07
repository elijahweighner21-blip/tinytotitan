--!strict
--[[
	MovementFxController
	Baseline movement visuals everyone gets (cosmetics layer on top):

	  * footsteps kick up dust tinted by the surface; titans' steps leave an
	    impact ring and a slight tremor
	  * landings scale with fall height and size; ground pounds shock outward
	  * a faint wind streak while sprinting, an energy streak on dashes
	  * small bursts for double jumps / wall jumps, sparks while wall running

	Everything goes through EffectsController, which caps particles per the
	graphics preset; the streaks are off on Low.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ScaleMath = require(Shared.Formulas.ScaleMath)

local MovementController = require(script.Parent.MovementController)
local EffectsController = require(script.Parent.EffectsController)
local CameraController = require(script.Parent.CameraController)
local EnvironmentController = require(script.Parent.EnvironmentController)

local MovementFxController = {}

local player = Players.LocalPlayer
local TITAN_SCALE = 40 -- from here on, steps shake the ground

-- Dust colour per surface (falls back to a warm grey).
local SURFACE: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(120, 170, 90),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(120, 170, 90),
	[Enum.Material.Sand] = Color3.fromRGB(225, 205, 160),
	[Enum.Material.Ground] = Color3.fromRGB(150, 120, 90),
	[Enum.Material.Mud] = Color3.fromRGB(110, 85, 60),
	[Enum.Material.Snow] = Color3.fromRGB(245, 248, 255),
	[Enum.Material.Fabric] = Color3.fromRGB(215, 205, 195),
	[Enum.Material.Wood] = Color3.fromRGB(215, 190, 150),
	[Enum.Material.WoodPlanks] = Color3.fromRGB(215, 190, 150),
	[Enum.Material.Concrete] = Color3.fromRGB(200, 200, 195),
	[Enum.Material.Asphalt] = Color3.fromRGB(150, 150, 150),
	[Enum.Material.Rock] = Color3.fromRGB(170, 165, 160),
	[Enum.Material.Slate] = Color3.fromRGB(160, 160, 165),
	[Enum.Material.Water] = Color3.fromRGB(170, 215, 255),
}

local trail: Trail? = nil
local scaleConn: RBXScriptConnection? = nil
local dashUntil = 0
local lastSpark = 0

local function dust(material: Enum.Material): Color3
	return SURFACE[material] or Color3.fromRGB(210, 205, 195)
end

local function feet(): (Vector3?, number)
	local root = MovementController:GetRoot()
	local h = MovementController:GetHeight()
	if not root then
		return nil, h
	end
	return root.Position - Vector3.new(0, h * 0.5, 0), h
end

local function buildTrail(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local h = ScaleMath.height((player:GetAttribute("Scale") :: number?) or 1)
	local a0 = Instance.new("Attachment")
	a0.Name = "TT_StreakTop"
	a0.Position = Vector3.new(0, h * 0.25, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TT_StreakBottom"
	a1.Position = Vector3.new(0, -h * 0.25, 0)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = "TT_Streak"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.FaceCamera = true
	t.LightEmission = 0.6
	t.Lifetime = 0.22
	t.MinLength = 0.05
	t.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 230, 255))
	t.Transparency = NumberSequence.new(0.8, 1)
	t.Enabled = false
	t.Parent = root
	trail = t
	-- Keep the streak sized to the character as it grows (one listener).
	if scaleConn then
		scaleConn:Disconnect()
	end
	scaleConn = player:GetAttributeChangedSignal("Scale"):Connect(function()
		local hh = ScaleMath.height((player:GetAttribute("Scale") :: number?) or 1)
		a0.Position = Vector3.new(0, hh * 0.25, 0)
		a1.Position = Vector3.new(0, -hh * 0.25, 0)
	end)
end

local function onFootstep(position: Vector3, scale: number, material: Enum.Material)
	local h = ScaleMath.height(scale)
	local sprinting = MovementController:IsSprinting()
	EffectsController:Burst(
		position,
		dust(material),
		h * (if sprinting then 0.1 else 0.07),
		if sprinting then 4 else 2,
		true
	)
	if scale >= TITAN_SCALE then
		-- The ground answers a titan's footstep.
		EffectsController:Ring(position, dust(material), h * 0.9, 0.35)
		CameraController:Shake(math.clamp(0.04 + scale / 4000, 0.04, 0.14))
	end
end

local function onLanded(bodies: number, pound: boolean)
	local position, h = feet()
	if not position then
		return
	end
	local scale = (player:GetAttribute("Scale") :: number?) or 1
	if pound then
		EffectsController:Ring(position, Color3.fromRGB(255, 210, 140), h * 3.2, 0.45)
		EffectsController:Burst(position, Color3.fromRGB(230, 215, 190), h * 0.45, 22, true)
	elseif bodies > 1.2 then
		local strength = math.clamp(bodies / 4, 0.3, 1.5)
		EffectsController:Burst(
			position,
			Color3.fromRGB(225, 215, 200),
			h * 0.25 * strength,
			math.floor(6 + 12 * strength),
			true
		)
		if bodies > 3 or scale >= TITAN_SCALE then
			EffectsController:Ring(position, Color3.fromRGB(240, 230, 210), h * (1.2 + strength), 0.4)
		end
		if scale >= TITAN_SCALE and bodies > 2 then
			EffectsController:Ring(position, Color3.fromRGB(255, 220, 170), h * 4 * strength, 0.6)
		end
	end
end

local function onAbility(id: string)
	local position, h = feet()
	if not position then
		return
	end
	if id == "DoubleJump" then
		EffectsController:Ring(position, Color3.fromRGB(200, 240, 255), h * 0.9, 0.3)
		EffectsController:Burst(position, Color3.fromRGB(230, 245, 255), h * 0.12, 8)
	elseif id == "WallJump" or id == "Vault" or id == "Mantle" then
		EffectsController:Burst(position + Vector3.new(0, h * 0.5, 0), Color3.fromRGB(240, 240, 240), h * 0.1, 6, true)
	elseif id == "AirDash" or id == "GroundDash" or id == "LongJump" then
		dashUntil = os.clock() + 0.3
		EffectsController:Burst(position + Vector3.new(0, h * 0.5, 0), Color3.fromRGB(120, 220, 255), h * 0.18, 10)
	elseif id == "Slide" then
		EffectsController:Burst(position, Color3.fromRGB(225, 215, 200), h * 0.15, 8, true)
	end
end

local function step()
	local t = trail
	if not t or not t.Parent then
		return
	end
	local now = os.clock()
	local low = EnvironmentController:GetPreset() == "Low"
	local dashing = now < dashUntil
	local sprinting = MovementController:IsSprinting()
	t.Enabled = not low and (dashing or sprinting)
	if dashing then
		t.Transparency = NumberSequence.new(0.25, 1)
		t.Color = ColorSequence.new(Color3.fromRGB(150, 235, 255), Color3.fromRGB(80, 160, 255))
		t.Lifetime = 0.3
	else
		t.Transparency = NumberSequence.new(0.82, 1)
		t.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 230, 255))
		t.Lifetime = 0.2
	end
	-- Sparks where the shoes meet the wall while wall running.
	if MovementController:GetState() == "WallRun" and now - lastSpark > 0.12 then
		lastSpark = now
		local position, h = feet()
		if position then
			EffectsController:Burst(position, Color3.fromRGB(255, 230, 170), h * 0.06, 3)
		end
	end
end

function MovementFxController:Start()
	MovementController.Footstep:Connect(onFootstep)
	MovementController.Landed:Connect(onLanded)
	MovementController.AbilityUsed:Connect(onAbility)
	player.CharacterAdded:Connect(buildTrail)
	if player.Character then
		task.spawn(buildTrail, player.Character)
	end
	RunService.RenderStepped:Connect(step)
end

return MovementFxController
