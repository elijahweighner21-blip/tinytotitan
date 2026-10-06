--!strict
--[[
	GrowthSequence
	The tier-up moment — the most important feedback in the game:
	  1. the camera eases back while the server tweens the character larger
	  2. a light spiral (or the equipped Growth cosmetic) rises around you
	  3. "YOU GREW!" + the new size name + what it unlocks
	  4. a ground ring and a short screen flash
	Shrinking back (Ascension, Shrink Mode ending) gets a softer version.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SizeConfig = require(Shared.Config.SizeConfig)

local Client = script.Parent.Parent.Parent
local Net = require(Client.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local MovementController = require(Client.Controllers.MovementController)
local CameraController = require(Client.Controllers.CameraController)
local AudioController = require(Client.Controllers.AudioController)
local EffectsController = require(Client.Controllers.EffectsController)
local CosmeticsController = require(Client.Controllers.CosmeticsController)

local GrowthSequence = {}

local frame: Frame
local heading: TextLabel
local tierName: TextLabel
local flavor: TextLabel
local unlocks: TextLabel
local token = 0

local function fade(label: TextLabel, to: number, time: number)
	TweenService:Create(label, TweenInfo.new(time, Enum.EasingStyle.Quad), { TextTransparency = to, TextStrokeTransparency = if to >= 1 then 1 else 0.3 }):Play()
end

function GrowthSequence.play(newTier: number, oldTier: number, unlockList: { string }?)
	token += 1
	local myToken = token
	local def = SizeConfig.getTier(newTier)
	local grew = newTier > oldTier
	heading.Text = if grew then "YOU GREW!" else "SIZE CHANGED"
	tierName.Text = string.upper(def.Name)
	tierName.TextColor3 = def.Color
	flavor.Text = def.Flavor
	if unlockList and #unlockList > 0 and grew then
		unlocks.Text = "Unlocked:  " .. table.concat(unlockList, "  •  ")
		unlocks.Visible = true
	else
		unlocks.Visible = false
	end
	frame.Visible = true
	for _, label in { heading, tierName, flavor, unlocks } do
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
	end
	local root = MovementController:GetRoot()
	local h = MovementController:GetHeight()
	if grew then
		CameraController:PullBack(1, 2.6)
		AudioController:Play("GrowthRise")
		if root then
			local feet = root.Position - Vector3.new(0, h * 0.5, 0)
			if not CosmeticsController:PlayGrowth(feet, h) then
				EffectsController:Spiral(feet, def.Color, h * 2.2, 1.6)
			end
			task.delay(1.4, function()
				local r = MovementController:GetRoot()
				if r then
					local hh = MovementController:GetHeight()
					local f = r.Position - Vector3.new(0, hh * 0.5, 0)
					EffectsController:Ring(f, def.Color, hh * 4, 0.8)
					EffectsController:Burst(r.Position, def.Color, hh * 0.6, 30)
					CameraController:Shake(0.35)
				end
				EffectsController:Flash(def.Color, 0.25)
			end)
		end
	else
		CameraController:PullBack(0.3, 1.2)
		AudioController:Play("Shrink")
	end
	fade(heading, 0, 0.4)
	task.delay(0.25, function()
		fade(tierName, 0, 0.5)
	end)
	task.delay(0.6, function()
		fade(flavor, 0, 0.5)
		fade(unlocks, 0, 0.5)
	end)
	task.delay(if grew then 4.5 else 2.5, function()
		if token ~= myToken then
			return
		end
		for _, label in { heading, tierName, flavor, unlocks } do
			fade(label, 1, 0.6)
		end
		task.delay(0.7, function()
			if token == myToken then
				frame.Visible = false
			end
		end)
	end)
end

function GrowthSequence.mount()
	frame = Create("Frame", {
		Name = "Growth",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(800, 180),
		Visible = false,
		Parent = UIManager.Overlay,
		[Create.Children] = { Create.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center) },
	})
	local function line(text: string, size: number, color: Color3, font: Font, order: number): TextLabel
		return Create.label(text, size, color, font, {
			Size = UDim2.new(1, 0, 0, size + 8),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.3,
			LayoutOrder = order,
			Parent = frame,
		})
	end
	heading = line("YOU GREW!", Theme.TextSize.Title, Theme.Colors.Text, Theme.Fonts.Title, 1)
	tierName = line("", 60, Theme.Colors.Mass, Theme.Fonts.Display, 2)
	flavor = line("", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, 3)
	unlocks = line("", Theme.TextSize.Body, Theme.Colors.Gold, Theme.Fonts.Title, 4)
	Net.onSignal("TierUp", function(p)
		if type(p) == "table" and type(p.Tier) == "number" then
			GrowthSequence.play(p.Tier, tonumber(p.OldTier) or (p.Tier - 1), if type(p.Unlocks) == "table" then p.Unlocks else nil)
		end
	end)
end

return GrowthSequence
