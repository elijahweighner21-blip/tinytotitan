--!strict
--[[
	ProgressBar
	Animated bar with optional label, glow and "near full" pulse. Used by the
	Mass bar, energy, XP, quests, boss health and loading.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)

export type ProgressBar = {
	Instance: Frame,
	Fill: Frame,
	Label: TextLabel,
	Set: (self: ProgressBar, fraction: number, instant: boolean?) -> (),
	SetText: (self: ProgressBar, text: string) -> (),
	SetColor: (self: ProgressBar, color: Color3) -> (),
	SetPulse: (self: ProgressBar, on: boolean) -> (),
	Destroy: (self: ProgressBar) -> (),
}

local ProgressBar = {}
ProgressBar.__index = ProgressBar

function ProgressBar.new(props: {
	Size: UDim2?,
	Color: Color3?,
	Background: Color3?,
	Text: string?,
	TextSize: number?,
	Parent: Instance?,
	LayoutOrder: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}): ProgressBar
	local color = props.Color or Theme.Colors.Accent
	local glow = Create("Frame", {
		Name = "Glow",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	local fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
		[Create.Children] = {
			Create.corner(Theme.RadiusPill),
			Create.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200), 90),
			glow,
		},
	})
	local label =
		Create.label(props.Text or "", props.TextSize or Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Title, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
			TextStrokeTransparency = 0.6,
		})
	local frame = Create("Frame", {
		Name = "ProgressBar",
		BackgroundColor3 = props.Background or Theme.Colors.Background,
		BackgroundTransparency = 0.2,
		Size = props.Size or UDim2.new(1, 0, 0, 14),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = true,
		[Create.Children] = { Create.corner(Theme.RadiusPill), Create.stroke(nil, 0.85, 1), fill, label },
	}) :: Frame
	local self = setmetatable({
		Instance = frame,
		Fill = fill,
		Label = label,
		_glow = glow,
		_fraction = 0,
		_pulse = nil :: RBXScriptConnection?,
	}, ProgressBar)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return (self :: any) :: ProgressBar
end

function ProgressBar.Set(self: any, fraction: number, instant: boolean?)
	local f = math.clamp(if fraction ~= fraction then 0 else fraction, 0, 1)
	-- Callers may update every frame; only animate actual changes.
	if self._set and math.abs(f - self._fraction) < 1e-4 then
		return
	end
	self._set = true
	local grew = f > self._fraction + 0.001
	self._fraction = f
	if instant then
		self.Fill.Size = UDim2.fromScale(f, 1)
		return
	end
	TweenService:Create(self.Fill, Theme.Tween.Normal, { Size = UDim2.fromScale(f, 1) }):Play()
	if grew then
		self._glow.BackgroundTransparency = 0.55
		TweenService:Create(self._glow, Theme.Tween.Slow, { BackgroundTransparency = 1 }):Play()
	end
end

function ProgressBar.SetText(self: any, text: string)
	self.Label.Text = text
end

function ProgressBar.SetColor(self: any, color: Color3)
	self.Fill.BackgroundColor3 = color
end

function ProgressBar.SetPulse(self: any, on: boolean)
	if on and not self._pulse then
		local t = 0
		self._pulse = RunService.RenderStepped:Connect(function(dt)
			t += dt
			self._glow.BackgroundTransparency = 0.6 + 0.35 * (0.5 + 0.5 * math.cos(t * 5))
		end)
	elseif not on and self._pulse then
		self._pulse:Disconnect()
		self._pulse = nil
		self._glow.BackgroundTransparency = 1
	end
end

function ProgressBar.Destroy(self: any)
	self:SetPulse(false)
	self.Instance:Destroy()
end

return ProgressBar
