--!strict
--[[
	ScreenFade
	Full-screen fades for transitions that would otherwise snap:
	  * dying fades to black; the new body fades back in
	  * fast travel covers the jump with a quick fade and an arrival flash
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local Client = script.Parent.Parent.Parent
local Net = require(Client.Net)
local Create = require(Client.UI.Create)

local ScreenFade = {}

local player = Players.LocalPlayer
local veil: Frame

local function tween(alpha: number, seconds: number, color: Color3?): Tween
	if color then
		veil.BackgroundColor3 = color
	end
	local t = TweenService:Create(
		veil,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ BackgroundTransparency = 1 - alpha }
	)
	t:Play()
	return t
end

-- Cover the screen (for a moment the player shouldn't see).
function ScreenFade.cover(seconds: number?, color: Color3?)
	tween(1, seconds or 0.2, color or Color3.fromRGB(8, 10, 18))
end

function ScreenFade.reveal(seconds: number?)
	tween(0, seconds or 0.4)
end

function ScreenFade.flash(color: Color3, strength: number?)
	veil.BackgroundColor3 = color
	veil.BackgroundTransparency = 1 - (strength or 0.6)
	tween(0, 0.45)
end

local function watch(character: Model)
	-- A new body: fade back in from wherever the death fade left us.
	ScreenFade.reveal(0.6)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			task.delay(math.max(GameConfig.RespawnTime - 0.9, 0.2), function()
				if player.Character == character then
					ScreenFade.cover(0.7)
				end
			end)
		end)
	end
end

function ScreenFade.mount()
	local gui = Create("ScreenGui", {
		Name = "TT_Fade",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	veil = Create("Frame", {
		Name = "Veil",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		Parent = gui,
	}) :: Frame
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
	Net.onSignal("Teleported", function(payload)
		if type(payload) == "table" and payload.Reason == "FastTravel" then
			ScreenFade.flash(Color3.fromRGB(190, 240, 255), 0.85)
		end
	end)
end

return ScreenFade
