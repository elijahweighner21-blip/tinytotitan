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
local RunService = game:GetService("RunService")
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

local TIPS = {
	"Collect glowing orbs to gain Mass — Mass makes you grow.",
	"Every size changes the world: today's mountain is tomorrow's pebble.",
	"Hold Shift to sprint. Jump again in the air to double jump once you learn it.",
	"Upgrade at a Growth Pod to gain Mass faster.",
	"Hidden collectibles hide where only tiny players can reach.",
	"Bosses only notice players big enough to challenge them.",
	"Fast-travel gateways remember every zone you've reached.",
	"Daily rewards grow with your login streak.",
}

local anim: RBXScriptConnection? = nil

function LoadingScreen.show()
	pcall(function()
		ReplicatedFirst:RemoveDefaultLoadingScreen()
	end)
	root = Create("Frame", {
		Name = "Loading",
		-- White base: the gradient below supplies the colour (gradients multiply).
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		Parent = UIManager.Loading,
		[Create.Children] = { Create.gradient(Color3.fromRGB(34, 46, 84), Color3.fromRGB(9, 11, 20)) },
	})
	Create("UIScale", { Scale = 1, Parent = root })
	-- Growth rings: a dot growing into a giant circle, gently breathing.
	local rings: { Frame } = {}
	for i = 1, 5 do
		local d = 30 * (2.1 ^ i)
		local ring = Create("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(d, d),
			Parent = root,
			[Create.Children] = {
				Create.corner(Theme.RadiusPill),
				Create.stroke(Theme.Colors.Mass:Lerp(Theme.Colors.Gold, i / 5), 0.82 + i * 0.025, 2),
			},
		}) :: Frame
		table.insert(rings, ring)
	end
	-- Drifting dust motes.
	local motes: { { Frame: Frame, Speed: number, X: number } } = {}
	local rng = Random.new()
	for _ = 1, 26 do
		local size = rng:NextNumber(2, 6)
		local mote = Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 240, 210),
			BackgroundTransparency = rng:NextNumber(0.4, 0.8),
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber()),
			Parent = root,
			[Create.Children] = { Create.corner(Theme.RadiusPill) },
		}) :: Frame
		table.insert(motes, { Frame = mote, Speed = rng:NextNumber(0.01, 0.035), X = rng:NextNumber() })
	end
	-- Title: "tiny" small, "TITAN" huge — the game's promise in one line.
	local title = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(0, 110),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = root,
		[Create.Children] = {
			Create.list(
				Enum.FillDirection.Horizontal,
				18,
				Enum.HorizontalAlignment.Center,
				Enum.VerticalAlignment.Bottom
			),
		},
	})
	Create.label("tiny", 30, Theme.Colors.Mass, Theme.Fonts.Display, {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		LayoutOrder = 1,
		Parent = title,
	})
	Create.label("→", 40, Theme.Colors.TextDim, Theme.Fonts.Display, {
		Size = UDim2.fromOffset(0, 54),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		LayoutOrder = 2,
		Parent = title,
	})
	Create.label("TITAN", 96, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.fromOffset(0, 110),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		LayoutOrder = 3,
		Parent = title,
		[Create.Children] = {
			Create.gradient(Theme.Colors.Gold, Color3.fromRGB(255, 140, 70), 90),
			Create.textStroke(Color3.fromRGB(60, 30, 10), 0.4, 3),
		},
	})
	Create.label(
		"Start as a speck of dust. End as a giant.",
		Theme.TextSize.Heading,
		Theme.Colors.TextDim,
		Theme.Fonts.Body,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(700, 26),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = root,
		}
	)
	local track = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 12, 22),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(440, 12),
		Parent = root,
		[Create.Children] = { Create.corner(Theme.RadiusPill), Create.stroke(nil, 0.8, 1.5) },
	})
	bar = Create("Frame", {
		BackgroundColor3 = Theme.Colors.Mass,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
		[Create.Children] = {
			Create.corner(Theme.RadiusPill),
			Create.gradient(Theme.Colors.Mass, Theme.Colors.Gold, 0),
		},
	})
	status = Create.label("Loading World...", Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Title, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.64, 22),
		Size = UDim2.fromOffset(440, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
	local tip = Create.label("", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -36),
		Size = UDim2.fromOffset(760, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	}) :: TextLabel
	local tipIndex = rng:NextInteger(1, #TIPS)
	local nextTip = 0
	local t = 0
	anim = RunService.RenderStepped:Connect(function(dt)
		t += dt
		for i, ring in rings do
			local d = 30 * (2.1 ^ i) * (1 + 0.04 * math.sin(t * 1.3 + i * 0.8))
			ring.Size = UDim2.fromOffset(d, d)
		end
		for _, m in motes do
			local p = m.Frame.Position
			local y = p.Y.Scale - m.Speed * dt
			if y < -0.02 then
				y = 1.02
			end
			m.Frame.Position = UDim2.fromScale(m.X + 0.01 * math.sin(t * 0.7 + m.X * 10), y)
		end
		if t >= nextTip then
			nextTip = t + 4.5
			tipIndex = tipIndex % #TIPS + 1
			tip.Text = "TIP  ·  " .. TIPS[tipIndex]
			tip.TextTransparency = 1
			TweenService:Create(tip, Theme.Tween.Slow, { TextTransparency = 0 }):Play()
		end
	end)
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
		-- The server kicks with an explanation if the save truly can't load,
		-- so this only ends early if something else went wrong.
		while not DataController:IsLoaded() and os.clock() - started < 120 do
			task.wait(0.25)
		end
	end
	setStep("Preparing Character...", 0.8)
	local waitedFrom = os.clock()
	while not player.Character and os.clock() - waitedFrom < 25 do
		task.wait(0.1)
	end
	local character = player.Character
	if character then
		character:WaitForChild("HumanoidRootPart", 10)
	else
		warn("[Client] no character after 25s; showing the game anyway")
	end
	setStep("Ready!", 1)
	task.wait(0.35)
end

function LoadingScreen.hide()
	if finished then
		return
	end
	finished = true
	-- Push in slightly while fading, as if the camera flies into the world.
	local zoom = root:FindFirstChildOfClass("UIScale")
	if zoom then
		TweenService:Create(zoom, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1.12 })
			:Play()
	end
	local fade = TweenService:Create(root, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end
	fade:Play()
	fade.Completed:Once(function()
		if anim then
			anim:Disconnect()
			anim = nil
		end
		root:Destroy()
	end)
end

return LoadingScreen
