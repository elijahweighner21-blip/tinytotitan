--!strict
--[[
	CameraController
	Enhances the default Roblox camera (which keeps working on PC, mobile and
	console) instead of replacing it:
	  * zoom limits follow the character's size with a smooth transition, so
	    a speck gets a close camera and a titan a distant one
	  * speed FOV while sprinting / dashing (toggleable)
	  * trauma-based shake for landings, stomps, bosses (scaled by the Camera
	    Shake setting; 0 disables it completely)
	  * cinematic pull-back during the growth sequence
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ScaleMath = require(Shared.Formulas.ScaleMath)
local MathUtil = require(Shared.Util.MathUtil)

local DataController = require(script.Parent.DataController)
local SettingsController = require(script.Parent.SettingsController)
local MovementController = require(script.Parent.MovementController)

local CameraController = {}

local player = Players.LocalPlayer
local trauma = 0
local shakeTime = 0
local pullBack = 0 -- 0..1 extra distance for cinematic moments
local pullBackTarget = 0
local currentMin, currentMax = 0.5, 400
local fovBoost = 0

function CameraController:Shake(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

-- Shake scaled by distance from the camera (world events / bosses).
function CameraController:ShakeAt(position: Vector3, amount: number, radius: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local d = (camera.CFrame.Position - position).Magnitude
	if d < radius then
		CameraController:Shake(amount * (1 - d / radius))
	end
end

function CameraController:PullBack(amount: number, seconds: number)
	pullBackTarget = math.clamp(amount, 0, 1.5)
	task.delay(seconds, function()
		pullBackTarget = 0
	end)
end

local function updateZoom(dt: number)
	local scale = DataController:GetScale()
	local minZoom, maxZoom = ScaleMath.cameraZoomLimits(scale)
	local default = ScaleMath.cameraDistance(scale)
	pullBack = MathUtil.damp(pullBack, pullBackTarget, 3, dt)
	local cinematic = default * (1 + pullBack * 1.5)
	-- Smoothly move limits; the default camera clamps its zoom into them,
	-- which produces a natural zoom-out as the player grows.
	currentMin = MathUtil.damp(currentMin, math.max(minZoom, if pullBack > 0.05 then cinematic else 0), 2.5, dt)
	currentMax = MathUtil.damp(currentMax, math.max(maxZoom, cinematic), 2.5, dt)
	player.CameraMinZoomDistance = math.clamp(currentMin, 0.5, 1e5)
	player.CameraMaxZoomDistance = math.clamp(math.max(currentMax, currentMin + 1), 1, 1e5)
end

local function onRender(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	updateZoom(dt)
	-- FOV.
	local baseFov = SettingsController:Get("FieldOfView") or 70
	local state = MovementController:GetState()
	local targetBoost = 0
	if SettingsController:Get("FovEffects") then
		if state == "Dash" then
			targetBoost = 12
		elseif MovementController:IsSprinting() then
			targetBoost = 6
		elseif state == "Glide" then
			targetBoost = 4
		end
	end
	fovBoost = MathUtil.damp(fovBoost, targetBoost, 6, dt)
	camera.FieldOfView = baseFov + fovBoost
	-- Shake: applied after the default camera has positioned itself.
	local intensity = SettingsController:Get("CameraShake") or 1
	trauma = math.max(0, trauma - dt * 1.4)
	if trauma > 0 and intensity > 0 then
		shakeTime += dt * 25
		local s = trauma * trauma * intensity
		local pitch = math.noise(shakeTime, 0.3) * s * 0.06
		local yaw = math.noise(shakeTime, 7.1) * s * 0.06
		local roll = math.noise(shakeTime, 13.7) * s * 0.03
		camera.CFrame = camera.CFrame * CFrame.Angles(pitch, yaw, roll)
	end
end

function CameraController:Start()
	RunService:BindToRenderStep("TT_Camera", Enum.RenderPriority.Camera.Value + 1, onRender)
	MovementController.Landed:Connect(function(bodies, pound)
		if pound then
			CameraController:Shake(0.55)
		elseif bodies > 1.5 then
			CameraController:Shake(math.clamp((bodies - 1.5) * 0.12, 0, 0.45))
		end
	end)
	player.CharacterAdded:Connect(function()
		trauma = 0
		pullBack = 0
		pullBackTarget = 0
	end)
end

return CameraController
