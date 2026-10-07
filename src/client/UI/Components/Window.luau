--!strict
--[[
	Window
	Standard menu window: glass panel with title, optional subtitle, close
	button, tab strip slot and a content area. Open/close animate with a
	scale + fade. Windows are created hidden and registered with UIManager.
]]

local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Button = require(script.Parent.Button)

export type Window = {
	Root: Frame,
	Body: Frame,
	Content: Frame,
	TabBar: Frame,
	Title: TextLabel,
	Subtitle: TextLabel,
	CloseButton: any,
	Open: (self: Window) -> (),
	Close: (self: Window) -> (),
	IsOpen: (self: Window) -> boolean,
	SetSubtitle: (self: Window, text: string) -> (),
	OnClose: (() -> ())?,
}

local Window = {}
Window.__index = Window

function Window.new(props: {
	Name: string,
	Title: string,
	Icon: string?,
	Accent: Color3?,
	Size: UDim2?,
	Parent: Instance,
	Tabs: boolean?,
}): Window
	local accent = props.Accent or Theme.Colors.Accent
	local scale = Create("UIScale", { Scale = 0.9 })
	local title = Create.label(
		(if props.Icon then props.Icon .. "  " else "") .. string.upper(props.Title),
		Theme.TextSize.Title,
		Theme.Colors.Text,
		Theme.Fonts.Display,
		{
			Size = UDim2.new(1, -60, 0, 32),
			Position = UDim2.fromOffset(0, 0),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}
	)
	local subtitle = Create.label("", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Size = UDim2.new(1, -60, 0, 18),
		Position = UDim2.fromOffset(0, 32),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local accentBar = Create("Frame", {
		Name = "AccentBar",
		BackgroundColor3 = accent,
		Size = UDim2.new(0, 56, 0, 4),
		Position = UDim2.fromOffset(0, 54),
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	local tabBar = Create("Frame", {
		Name = "TabBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if props.Tabs then 38 else 0),
		Position = UDim2.fromOffset(0, 66),
		Visible = props.Tabs == true,
		[Create.Children] = {
			Create.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		},
	})
	local contentTop = if props.Tabs then 112 else 70
	local content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -contentTop),
		Position = UDim2.fromOffset(0, contentTop),
		ClipsDescendants = true,
	})
	local body = Create("Frame", {
		Name = "Body",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		Size = UDim2.fromScale(1, 1),
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.stroke(accent, 0.65, 2),
			Create.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 210, 230), 90),
			Create.padding(18, 20),
			title,
			subtitle,
			accentBar,
			tabBar,
			content,
		},
	})
	local root = Create("Frame", {
		Name = props.Name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromOffset(900, 560),
		Visible = false,
		[Create.Children] = { scale, body, Create("UISizeConstraint", { MaxSize = Vector2.new(1100, 700) }) },
		Parent = props.Parent,
	}) :: Frame
	local self = setmetatable({
		Root = root,
		Body = body,
		Content = content,
		TabBar = tabBar,
		Title = title,
		Subtitle = subtitle,
		_scale = scale,
		_open = false,
		OnClose = nil,
	}, Window)
	self.CloseButton = Button.new({
		Text = "✕",
		Style = "Ghost",
		Size = UDim2.fromOffset(40, 40),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Name = "Close",
		OnClick = function()
			if self.OnClose then
				self.OnClose()
			end
		end,
		Parent = body,
	})
	return (self :: any) :: Window
end

function Window.Open(self: any)
	if self._open then
		return
	end
	self._open = true
	self.Root.Visible = true
	self._scale.Scale = 0.92
	self.Body.BackgroundTransparency = 0.6
	self.Root.Position = UDim2.new(0.5, 0, 0.5, 18)
	TweenService:Create(self._scale, Theme.Tween.Bounce, { Scale = 1 }):Play()
	TweenService:Create(self.Root, Theme.Tween.Normal, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	TweenService:Create(self.Body, Theme.Tween.Normal, { BackgroundTransparency = Theme.PanelTransparency }):Play()
end

function Window.Close(self: any)
	if not self._open then
		return
	end
	self._open = false
	local tween = TweenService:Create(self._scale, Theme.Tween.Fast, { Scale = 0.94 })
	tween:Play()
	tween.Completed:Once(function()
		if not self._open then
			self.Root.Visible = false
		end
	end)
end

function Window.IsOpen(self: any): boolean
	return self._open
end

function Window.SetSubtitle(self: any, text: string)
	self.Subtitle.Text = text
end

return Window
