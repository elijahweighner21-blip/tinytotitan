--!strict
--[[
	MassBar
	The centrepiece of the HUD: how close you are to the next size.

	   [ ANT-SIZED ]                         NEXT SIZE ▸ BUG-SIZED
	   ████████████████████░░░░░░░░░░  1.9K MASS ·············  27%

	  * the fill shows progress *within* the current size, in the size's
	    colour, with a top shine and a shimmer sweep every few seconds
	  * gaining Mass pulses the bar (bigger gains pulse harder) and counts
	    the number up
	  * near the next size it glows and gives off sparkles; reaching it
	    flashes the whole bar
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Progression = require(Shared.Formulas.Progression)
local SizeConfig = require(Shared.Config.SizeConfig)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)

export type MassBar = {
	Instance: Frame,
	Update: (self: MassBar, mass: number, shrink: boolean?) -> (),
	Destroy: (self: MassBar) -> (),
}

local MassBar = {}
MassBar.__index = MassBar

local BAR_HEIGHT = 26

function MassBar.new(parent: Instance, width: number): MassBar
	local root = Create("Frame", {
		Name = "MassBar",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, 58),
		Parent = parent,
	}) :: Frame
	local scale = Create("UIScale", { Scale = 1, Parent = root }) :: UIScale

	-- Header row: current size pill (left), next size (right).
	local pill = Create("Frame", {
		Name = "SizePill",
		BackgroundColor3 = Theme.Colors.Mass,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = root,
		[Create.Children] = {
			Create.corner(Theme.RadiusPill),
			Create.padding(0, 12),
			Create.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205), 90),
		},
	}) :: Frame
	local sizeName =
		Create.label("MICROSCOPIC", Theme.TextSize.Small, Color3.fromRGB(16, 22, 30), Theme.Fonts.Display, {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			TextWrapped = false,
			Parent = pill,
		}) :: TextLabel
	local nextLabel = Create.label("", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Title, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.6, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		RichText = true,
		TextStrokeTransparency = 0.55,
		Parent = root,
	}) :: TextLabel

	-- Bar.
	local halo = Create("Frame", {
		Name = "Halo",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		Parent = root,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	}) :: Frame
	local haloStroke = Create.stroke(Theme.Colors.Mass, 1, 3)
	haloStroke.Parent = halo
	local track = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Color3.fromRGB(10, 13, 22),
		BackgroundTransparency = 0.15,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		ClipsDescendants = true,
		Parent = root,
		[Create.Children] = { Create.corner(Theme.RadiusPill), Create.stroke(nil, 0.8, 1.5) },
	}) :: Frame
	local fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Colors.Mass,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
		Parent = track,
		[Create.Children] = {
			Create.corner(Theme.RadiusPill),
			Create.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175), 90),
		},
	}) :: Frame
	Create("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 0.32, 0),
		ZIndex = 3,
		Parent = fill,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	local shimmer = Create("Frame", {
		Name = "Shimmer",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		Position = UDim2.fromScale(-0.3, 0),
		Size = UDim2.fromScale(0.18, 1),
		ZIndex = 3,
		Parent = fill,
		[Create.Children] = {
			Create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		},
	}) :: Frame
	-- Quarter ticks.
	for i = 1, 3 do
		Create("Frame", {
			Name = "Tick",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.82,
			Position = UDim2.new(i / 4, -1, 0.25, 0),
			Size = UDim2.new(0, 2, 0.5, 0),
			ZIndex = 4,
			Parent = track,
		})
	end
	local massLabel = Create.label("0 MASS", Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Display, {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		ZIndex = 5,
		TextStrokeTransparency = 0.45,
		Parent = track,
	}) :: TextLabel
	local percentLabel = Create.label("0%", Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Display, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.new(0.3, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
		TextStrokeTransparency = 0.45,
		Parent = track,
	}) :: TextLabel
	local sparkles = Create("Frame", {
		Name = "Sparkles",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		ZIndex = 6,
		Parent = root,
	}) :: Frame

	local self = setmetatable({
		Instance = root,
		_scale = scale,
		_pill = pill,
		_sizeName = sizeName,
		_next = nextLabel,
		_fill = fill,
		_shimmer = shimmer,
		_halo = haloStroke,
		_mass = massLabel,
		_percent = percentLabel,
		_sparkles = sparkles,
		_fraction = 0,
		_tier = 0,
		_shownMass = 0,
		_targetMass = 0,
		_near = false,
		_t = 0,
		_nextSpark = 0,
		_conn = nil :: RBXScriptConnection?,
	}, MassBar)
	self._conn = RunService.RenderStepped:Connect(function(dt)
		self:_step(dt)
	end)
	return (self :: any) :: MassBar
end

function MassBar._step(self: any, dt: number)
	self._t += dt
	-- Count the number toward its target.
	if self._shownMass ~= self._targetMass then
		local diff = self._targetMass - self._shownMass
		self._shownMass = if math.abs(diff) < 1 then self._targetMass else self._shownMass + diff * math.min(1, dt * 8)
		self._mass.Text = Format.abbreviate(math.floor(self._shownMass + 0.5)) .. " MASS"
	end
	-- Shimmer sweep every ~4 s.
	local cycle = self._t % 4
	self._shimmer.Position = UDim2.fromScale(-0.3 + math.clamp(cycle / 1.2, 0, 1) * 1.6, 0)
	-- Near the next size: breathing halo + sparkles.
	if self._near then
		self._halo.Transparency = 0.35 + 0.35 * (0.5 + 0.5 * math.cos(self._t * 4))
		if self._t >= self._nextSpark then
			self._nextSpark = self._t + 0.18
			self:_spark()
		end
	else
		self._halo.Transparency = 1
	end
end

function MassBar._spark(self: any)
	local x = math.random() * self._fraction
	local dot = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(x, 0, 0.5, 0),
		Size = UDim2.fromOffset(4, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 6,
		Parent = self._sparkles,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	local tween = TweenService:Create(dot, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(x, math.random(-10, 10), 0.5, -26 - math.random() * 14),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(2, 2),
	})
	tween.Completed:Once(function()
		dot:Destroy()
	end)
	tween:Play()
end

function MassBar._pulse(self: any, strength: number)
	self._scale.Scale = 1 + 0.035 * strength
	TweenService
		:Create(self._scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function MassBar.Update(self: any, mass: number, shrink: boolean?)
	local tier, fraction, nextReq = Progression.tierProgress(mass)
	local def = SizeConfig.getTier(tier)
	local color = def.Color:Lerp(Theme.Colors.Mass, 0.35)
	local gained = mass - self._targetMass
	self._targetMass = mass
	if self._tier == 0 then
		self._shownMass = mass
		self._mass.Text = Format.abbreviate(mass) .. " MASS"
	end
	self._sizeName.Text = string.upper(def.Name) .. (if shrink then "  ·  SHRUNK" else "")
	self._pill.BackgroundColor3 = color
	self._fill.BackgroundColor3 = color
	self._halo.Color = color
	if nextReq then
		local nextDef = SizeConfig.getTier(tier + 1)
		self._next.Text = string.format(
			'NEXT SIZE  ▸  <font color="#%s"><b>%s</b></font>',
			nextDef.Color:Lerp(Color3.new(1, 1, 1), 0.35):ToHex(),
			string.upper(nextDef.Name)
		)
		self._percent.Text = string.format("%d%%", math.floor(fraction * 100))
	else
		self._next.Text = "<b>MAXIMUM SIZE</b>"
		self._percent.Text = "MAX"
		fraction = 1
	end
	local tierUp = self._tier ~= 0 and tier > self._tier
	if tierUp then
		-- Fill to the end, flash, then restart from the new size's start.
		TweenService:Create(self._fill, Theme.Tween.Fast, { Size = UDim2.fromScale(1, 1) }):Play()
		self._fill.BackgroundColor3 = Color3.new(1, 1, 1)
		task.delay(0.25, function()
			self._fill.Size = UDim2.fromScale(0, 1)
			self._fill.BackgroundColor3 = color
			TweenService:Create(self._fill, Theme.Tween.Slow, { Size = UDim2.fromScale(fraction, 1) }):Play()
		end)
		self:_pulse(2)
	elseif math.abs(fraction - self._fraction) > 1e-4 then
		TweenService:Create(self._fill, Theme.Tween.Normal, { Size = UDim2.fromScale(fraction, 1) }):Play()
	end
	if gained > 0 and self._tier ~= 0 and not tierUp then
		-- Bigger gains (relative to the size's span) pulse harder.
		local span = if nextReq then math.max(nextReq - def.MassRequired, 1) else math.max(mass, 1)
		self:_pulse(math.clamp(gained / span * 20, 0.25, 1.5))
	end
	self._near = nextReq ~= nil and fraction >= 0.9
	self._fraction = fraction
	self._tier = tier
end

function MassBar.Destroy(self: any)
	if self._conn then
		self._conn:Disconnect()
	end
	self.Instance:Destroy()
end

return MassBar
