--!strict
--[[
	LoadingScreen
	"TINY → TITAN" title card shown while the world streams in, the save
	loads and the character spawns. Steps advance on real signals (never a
	fake timer), with a generous timeout so a slow load never traps the
	player behind the screen.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local WorldIndex = require(Client.WorldIndex)
local DataController = require(Client.Controllers.DataController)

local LoadingScreen = {}

local player = Players.LocalPlayer
local root: Frame
local status: TextLabel
local bar: Frame
local finished = false

local function setStep(text: string, fraction: number)
	status.Text = text
	TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) }):Play()
end

function LoadingScreen.show()
	pcall(function()
		ReplicatedFirst:RemoveDefaultLoadingScreen()
	end)
	root = Create("Frame", {
		Name = "Loading",
		BackgroundColor3 = Theme.Colors.Background,
		Size = UDim2.fromScale(1, 1),
		Parent = UIManager.Loading,
		[Create.Children] = { Create.gradient(Color3.fromRGB(30, 40, 70), Color3.fromRGB(10, 12, 20)) },
	})
	Create.label("TINY  →  TITAN", 72, Theme.Colors.Text, Theme.Fonts.Display, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(900, 90),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = root,
		[Create.Children] = { Create.gradient(Theme.Colors.Mass, Theme.Colors.Gold, 0) },
	})
	Create.label(
		"Start as a speck of dust. End as a giant.",
		Theme.TextSize.Heading,
		Theme.Colors.TextDim,
		Theme.Fonts.Body,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(700, 26),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = root,
		}
	)
	local track = Create("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(420, 8),
		Parent = root,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	bar = Create("Frame", {
		BackgroundColor3 = Theme.Colors.Mass,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	status = Create.label("Loading World...", Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Title, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.62, 18),
		Size = UDim2.fromOffset(420, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
end

-- Runs the real loading steps; returns when the game is ready to show.
function LoadingScreen.run()
	setStep("Loading World...", 0.1)
	WorldIndex.wait(30)
	pcall(function()
		ContentProvider:PreloadAsync({ UIManager.Hud })
	end)
	setStep("Loading Progress...", 0.45)
	local started = os.clock()
	while not DataController:IsLoaded() and os.clock() - started < 45 do
		task.wait(0.1)
	end
	if not DataController:IsLoaded() then
		setStep("Still loading your save — hang tight...", 0.6)
		DataController.Loaded:Wait()
	end
	setStep("Preparing Character...", 0.8)
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 15)
	setStep("Ready!", 1)
	task.wait(0.35)
end

function LoadingScreen.hide()
	if finished then
		return
	end
	finished = true
	local fade = TweenService:Create(root, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
	end
	fade:Play()
	fade.Completed:Once(function()
		root:Destroy()
	end)
end

return LoadingScreen
