--!strict
--[[
	BossBar
	Big health bar at the top of the screen while you are in a boss arena
	(the server only sends Boss updates to players near the fight). Shows
	the boss title, current phase and a damage-trail segment that lags
	behind the real health so big hits read clearly.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local Net = require(Client.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local AudioController = require(Client.Controllers.AudioController)

local BossBar = {}

local frame: Frame
local nameLabel: TextLabel
local phaseLabel: TextLabel
local fill: Frame
local trail: Frame
local hpLabel: TextLabel
local lastUpdate = 0
local current: string? = nil

local function hide()
	if frame.Visible then
		frame.Visible = false
		AudioController:SetBossMusic(false)
	end
	current = nil
end

function BossBar.mount()
	frame = Create("Frame", {
		Name = "BossBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(620, 70),
		Visible = false,
		Parent = UIManager.Overlay,
	})
	nameLabel = Create.label("", Theme.TextSize.Title, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		Parent = frame,
	})
	phaseLabel = Create.label("", Theme.TextSize.Small, Theme.Colors.Danger, Theme.Fonts.Title, {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Parent = frame,
	})
	local back = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 10, 15),
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = frame,
		[Create.Children] = { Create.corner(Theme.RadiusPill), Create.stroke(Theme.Colors.Danger, 0.4, 2) },
	})
	trail = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 230, 200),
		Size = UDim2.fromScale(1, 1),
		Parent = back,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	fill = Create("Frame", {
		BackgroundColor3 = Theme.Colors.Danger,
		Size = UDim2.fromScale(1, 1),
		Parent = back,
		[Create.Children] = {
			Create.corner(Theme.RadiusPill),
			Create.gradient(Color3.fromRGB(255, 140, 140), Color3.fromRGB(200, 40, 60)),
		},
	})
	hpLabel = Create.label("", Theme.TextSize.Tiny, Theme.Colors.Text, Theme.Fonts.Title, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
		Parent = back,
	})
	Net.onSignal("Boss", function(p)
		if type(p) ~= "table" then
			return
		end
		lastUpdate = os.clock()
		if p.State == "Defeated" or p.State == "Reset" or p.State == "Waiting" then
			hide()
			return
		end
		if current ~= p.Id then
			current = p.Id
			frame.Visible = true
			AudioController:SetBossMusic(true)
		end
		nameLabel.Text = tostring(p.Name)
			.. (if type(p.Title) == "string" and p.Title ~= "" then "  ·  " .. p.Title else "")
		phaseLabel.Text = if type(p.Phase) == "string" and p.Phase ~= "" then string.upper(p.Phase) else ""
		local max = math.max(tonumber(p.Max) or 1, 1)
		local hp = math.clamp(tonumber(p.Health) or 0, 0, max)
		local fraction = hp / max
		fill.Size = UDim2.fromScale(fraction, 1)
		TweenService:Create(
			trail,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35),
			{ Size = UDim2.fromScale(fraction, 1) }
		):Play()
		hpLabel.Text = string.format("%s / %s", Format.abbreviate(hp), Format.abbreviate(max))
	end)
	RunService.Heartbeat:Connect(function()
		-- Left the arena (updates stop) → hide.
		if current and os.clock() - lastUpdate > 4 then
			hide()
		end
	end)
end

return BossBar
