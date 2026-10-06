--!strict
--[[
	AnimationController
	Animation layer for parkour and combat moves on top of Roblox's default
	Animate script (which keeps handling idle/walk/run/jump/fall/climb).

	For each move:
	  * if AnimationConfig.Ids has an uploaded animation, it is loaded once
	    per character and played while the move is active
	  * otherwise a procedural pose is blended onto the root joint (lean into
	    slides, tilt off walls, tuck into a flip on double jump, a twist on
	    attacks). Poses are applied to Motor6D.Transform after the animator
	    runs each frame, so they compose with walking/running animations and
	    survive character scaling.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimationConfig = require(Shared.Config.AnimationConfig)
local MathUtil = require(Shared.Util.MathUtil)
local Trove = require(Shared.Util.Trove)

local Client = script.Parent.Parent
local Bus = require(Client.UI.Bus)
local MovementController = require(script.Parent.MovementController)
local CombatController = require(script.Parent.CombatController)

local AnimationController = {}

type Pose = { Pitch: number, Roll: number, Yaw: number, Drop: number }

local player = Players.LocalPlayer
local trove = Trove.new()
local rootMotor: Motor6D? = nil
local animator: Animator? = nil
local tracks: { [string]: AnimationTrack } = {}
local playing: string? = nil
local carrying = false

local pose: Pose = { Pitch = 0, Roll = 0, Yaw = 0, Drop = 0 }
local flipUntil = 0
local flipStart = 0
local FLIP_TIME = 0.38
local swingUntil = 0
local swingStart = 0
local swingDir = 1
local swingStrength = 1
local lightCombo = 0

local function hasAnimation(name: string): boolean
	local id = AnimationConfig.Ids[name]
	return type(id) == "string" and id ~= ""
end

local function track(name: string): AnimationTrack?
	if tracks[name] then
		return tracks[name]
	end
	local a = animator
	if not a or not hasAnimation(name) then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = AnimationConfig.Ids[name]
	local ok, loaded = pcall(function()
		return a:LoadAnimation(anim)
	end)
	if not ok or not loaded then
		warn("[AnimationController] failed to load", name)
		AnimationConfig.Ids[name] = "" -- fall back to procedural from now on
		return nil
	end
	loaded.Priority = Enum.AnimationPriority.Action
	tracks[name] = loaded
	return loaded
end

-- Plays a one-shot animation if uploaded. Returns true if it played.
function AnimationController:PlayOnce(name: string, speed: number?): boolean
	local t = track(name)
	if not t then
		return false
	end
	t:Play(0.08, 1, speed or 1)
	return true
end

-- Which looping move is active for the current movement state.
local function moveFor(state: string): string?
	if state == "Slide" then
		return "Slide"
	elseif state == "WallRun" then
		return if MovementController:GetWallSide() < 0 then "WallRunLeft" else "WallRunRight"
	elseif state == "Dash" then
		return if MovementController:IsGrounded() then "Dash" else "AirDash"
	elseif state == "Glide" then
		return "Glide"
	elseif state == "GroundPound" then
		return "GroundPound"
	elseif state == "LedgeHang" then
		return "LedgeHang"
	elseif state == "Charge" then
		return "ChargeCrouch"
	elseif carrying then
		return "Carry"
	end
	return nil
end

local function setLoop(name: string?)
	if name == playing then
		return
	end
	if playing and tracks[playing] then
		tracks[playing]:Stop(0.15)
	end
	playing = name
	if name then
		local t = track(name)
		if t then
			t.Looped = true
			t:Play(0.12)
		end
	end
end

local function targetPose(now: number): Pose
	local target: Pose = { Pitch = 0, Roll = 0, Yaw = 0, Drop = 0 }
	local name = playing
	if name and not hasAnimation(name) then
		local p = AnimationConfig.Procedural[name]
		if p then
			target.Pitch = p.Pitch
			target.Roll = p.Roll
			target.Drop = p.Drop
		end
	end
	if name == "ChargeCrouch" then
		local charge = MovementController:GetCharge()
		target.Drop *= charge
		target.Pitch *= charge
	end
	-- Attack twist (procedural only).
	if now < swingUntil then
		local t = (now - swingStart) / (swingUntil - swingStart)
		target.Yaw += math.sin(t * math.pi) * 35 * swingDir * swingStrength
		target.Pitch += math.sin(t * math.pi) * 10 * swingStrength
	end
	return target
end

local function step(dt: number)
	local motor = rootMotor
	if not motor or not motor.Parent then
		return
	end
	local now = os.clock()
	setLoop(moveFor(MovementController:GetState()))
	local target = targetPose(now)
	local alpha = 1 - math.exp(-dt * 14)
	pose.Pitch = MathUtil.lerp(pose.Pitch, target.Pitch, alpha)
	pose.Roll = MathUtil.lerp(pose.Roll, target.Roll, alpha)
	pose.Yaw = MathUtil.lerp(pose.Yaw, target.Yaw, alpha)
	pose.Drop = MathUtil.lerp(pose.Drop, target.Drop, alpha)
	local pitch = pose.Pitch
	if now < flipUntil and not hasAnimation("DoubleJump") then
		-- Front flip: full rotation eased over FLIP_TIME.
		local t = (now - flipStart) / FLIP_TIME
		pitch += -360 * MathUtil.easeInOutQuad(math.clamp(t, 0, 1))
	end
	if math.abs(pitch) < 0.01 and math.abs(pose.Roll) < 0.01 and math.abs(pose.Yaw) < 0.01 and pose.Drop < 0.001 then
		return
	end
	local h = MovementController:GetHeight()
	local offset = CFrame.new(0, -pose.Drop * h, 0)
		* CFrame.Angles(math.rad(-pitch), math.rad(pose.Yaw), math.rad(pose.Roll))
	motor.Transform = motor.Transform * offset
end

local function onCharacter(character: Model)
	trove:Clean()
	table.clear(tracks)
	playing = nil
	rootMotor = nil
	animator = nil
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	animator = humanoid:WaitForChild("Animator", 10) :: Animator?
	-- R15: LowerTorso.Root ; R6: HumanoidRootPart.RootJoint
	local lower = character:WaitForChild("LowerTorso", 2)
	local motor = (lower and lower:FindFirstChild("Root"))
		or (
			character:FindFirstChild("HumanoidRootPart")
			and (character :: any).HumanoidRootPart:FindFirstChild("RootJoint")
		)
	if motor and motor:IsA("Motor6D") then
		rootMotor = motor
	end
	trove:Connect(humanoid.Died, function()
		setLoop(nil)
	end)
end

function AnimationController:Init()
	MovementController.Jumped:Connect(function(kind)
		if kind == "DoubleJump" then
			if not AnimationController:PlayOnce("DoubleJump") then
				flipStart = os.clock()
				flipUntil = flipStart + FLIP_TIME
			end
		end
	end)
	MovementController.AbilityUsed:Connect(function(id)
		if id == "Mantle" then
			AnimationController:PlayOnce("Mantle")
		elseif id == "Vault" then
			AnimationController:PlayOnce("Vault")
		elseif id == "TitanStomp" then
			AnimationController:PlayOnce("TitanStomp")
		elseif id == "TitanRoar" then
			AnimationController:PlayOnce("Roar")
		end
	end)
	CombatController.Swing:Connect(function(kind)
		local name = if kind == "Light"
			then (if lightCombo % 2 == 0 then "LightAttack1" else "LightAttack2")
			elseif kind == "Heavy" then "HeavyAttack"
			elseif kind == "Charged" then "ChargedAttack"
			else "DashAttack"
		if kind == "Light" then
			lightCombo += 1
		end
		if not AnimationController:PlayOnce(name) then
			swingStart = os.clock()
			swingStrength = if kind == "Light" then 1 elseif kind == "Dash" then 0.8 else 1.6
			swingUntil = swingStart + (if kind == "Light" then 0.22 else 0.4)
			swingDir = if lightCombo % 2 == 0 then -1 else 1
		end
	end)
	Bus.Carrying:Connect(function(id)
		local was = carrying
		carrying = id ~= nil
		if was and not carrying then
			AnimationController:PlayOnce("Throw")
		end
	end)
end

function AnimationController:Start()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	-- After the animator has written this frame's Transforms.
	RunService.PreSimulation:Connect(step)
end

return AnimationController
