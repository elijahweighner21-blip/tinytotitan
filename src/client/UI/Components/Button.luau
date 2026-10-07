--!strict
--[[
	Button
	The one button used everywhere. Hover lifts and brightens, press squashes,
	disabled states dim; gamepad selection shows the same highlight as hover.
	Styles: Primary, Secondary, Ghost, Danger, Gold, Robux, Success, Owned.
]]

local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Sound = require(UI.Sound)

export type Options = {
	Text: string?,
	Icon: string?,
	Style: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
	Parent: Instance?,
	Name: string?,
}

export type Button = {
	Instance: TextButton,
	Label: TextLabel,
	SetText: (self: Button, text: string) -> (),
	SetEnabled: (self: Button, enabled: boolean) -> (),
	SetStyle: (self: Button, style: string) -> (),
	Flash: (self: Button, color: Color3?) -> (),
	Destroy: (self: Button) -> (),
}

local STYLES: { [string]: { Fill: Color3, Text: Color3, Stroke: number } } = {
	Primary = { Fill = Theme.Colors.Accent, Text = Color3.fromRGB(10, 20, 30), Stroke = 1 },
	Secondary = { Fill = Theme.Colors.PanelLighter, Text = Theme.Colors.Text, Stroke = 0.8 },
	Ghost = { Fill = Theme.Colors.PanelLight, Text = Theme.Colors.TextDim, Stroke = 0.9 },
	Danger = { Fill = Theme.Colors.Danger, Text = Color3.fromRGB(255, 255, 255), Stroke = 1 },
	Gold = { Fill = Theme.Colors.Gold, Text = Color3.fromRGB(40, 25, 0), Stroke = 1 },
	Robux = { Fill = Theme.Colors.Robux, Text = Color3.fromRGB(5, 30, 10), Stroke = 1 },
	Success = { Fill = Theme.Colors.Success, Text = Color3.fromRGB(5, 30, 10), Stroke = 1 },
	-- Already bought / equipped: calm, clearly not a call to action.
	Owned = { Fill = Color3.fromRGB(34, 74, 52), Text = Theme.Colors.Success, Stroke = 0.6 },
}

local Button = {}
Button.__index = Button

function Button.new(opts: Options): Button
	local style = STYLES[opts.Style or "Secondary"] or STYLES.Secondary
	local text = opts.Text or ""
	local icon = opts.Icon
	local scale = Create("UIScale", { Scale = 1 })
	local label = Create.label(
		if icon and text ~= "" then icon .. "  " .. text elseif icon then icon else text,
		opts.TextSize or Theme.TextSize.Body,
		style.Text,
		Theme.Fonts.Title,
		{
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		}
	)
	local stroke = Create.stroke(Color3.new(1, 1, 1), style.Stroke, 1.5)
	local instance = Create("TextButton", {
		Name = opts.Name or ("Button_" .. text),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = style.Fill,
		Size = opts.Size or UDim2.fromOffset(160, 44),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
		Selectable = true,
		[Create.Children] = {
			Create.corner(Theme.RadiusSmall),
			stroke,
			scale,
			-- Lit from above: reads as a pressable surface, not a flat box.
			Create.gradient(Color3.new(1, 1, 1), Color3.fromRGB(196, 200, 210), 90),
			Create.padding(4, 10),
			label,
		},
	}) :: TextButton
	local self = setmetatable({
		Instance = instance,
		Label = label,
		_style = style,
		_enabled = true,
		_scale = scale,
		_stroke = stroke,
		_onClick = opts.OnClick,
		_connections = {} :: { RBXScriptConnection },
	}, Button)

	local function hover(on: boolean)
		if not self._enabled then
			return
		end
		TweenService:Create(scale, Theme.Tween.Fast, { Scale = if on then 1.04 else 1 }):Play()
		TweenService:Create(stroke, Theme.Tween.Fast, { Transparency = if on then 0.2 else self._style.Stroke }):Play()
		if on then
			Sound.play("Hover")
		end
	end
	table.insert(
		self._connections,
		instance.MouseEnter:Connect(function()
			hover(true)
		end)
	)
	table.insert(
		self._connections,
		instance.MouseLeave:Connect(function()
			hover(false)
		end)
	)
	table.insert(
		self._connections,
		instance.SelectionGained:Connect(function()
			hover(true)
		end)
	)
	table.insert(
		self._connections,
		instance.SelectionLost:Connect(function()
			hover(false)
		end)
	)
	table.insert(
		self._connections,
		instance.MouseButton1Down:Connect(function()
			if self._enabled then
				TweenService:Create(scale, Theme.Tween.Fast, { Scale = 0.95 }):Play()
			end
		end)
	)
	table.insert(
		self._connections,
		instance.Activated:Connect(function()
			if not self._enabled then
				Sound.play("Error")
				return
			end
			TweenService:Create(scale, Theme.Tween.Bounce, { Scale = 1 }):Play()
			Sound.play("Click")
			if self._onClick then
				self._onClick()
			end
		end)
	)
	if opts.Parent then
		instance.Parent = opts.Parent
	end
	return (self :: any) :: Button
end

function Button.SetText(self: any, text: string)
	self.Label.Text = text
end

function Button.SetEnabled(self: any, enabled: boolean)
	self._enabled = enabled
	self.Instance.BackgroundColor3 = if enabled then self._style.Fill else Theme.Colors.Locked
	self.Label.TextColor3 = if enabled then self._style.Text else Theme.Colors.TextFaint
end

function Button.SetStyle(self: any, styleName: string)
	local style = STYLES[styleName]
	if style then
		self._style = style
		self:SetEnabled(self._enabled)
	end
end

function Button.Flash(self: any, color: Color3?)
	local original = self.Instance.BackgroundColor3
	self.Instance.BackgroundColor3 = color or Theme.Colors.Success
	TweenService:Create(self.Instance, Theme.Tween.Slow, { BackgroundColor3 = original }):Play()
	self._scale.Scale = 1.12
	TweenService:Create(self._scale, Theme.Tween.Bounce, { Scale = 1 }):Play()
end

function Button.Destroy(self: any)
	for _, c in self._connections do
		c:Disconnect()
	end
	self.Instance:Destroy()
end

return Button
