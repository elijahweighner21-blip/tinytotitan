--!strict
--[[
	Card
	Item tile used by the shop, upgrades, cosmetics, collections and
	achievements: icon badge, title, description, optional tag ribbon and a
	footer slot for buttons/prices.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)

export type Card = {
	Instance: Frame,
	Icon: TextLabel,
	Title: TextLabel,
	Description: TextLabel,
	Footer: Frame,
	Tag: TextLabel,
	SetTag: (self: Card, text: string?, color: Color3?) -> (),
	SetDim: (self: Card, dim: boolean) -> (),
}

local Card = {}
Card.__index = Card

function Card.new(props: {
	Icon: string?,
	Title: string,
	Description: string?,
	Accent: Color3?,
	Size: UDim2?,
	LayoutOrder: number?,
	Parent: Instance?,
}): Card
	local accent = props.Accent or Theme.Colors.Accent
	local icon = Create.label(props.Icon or "", 30, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.fromOffset(52, 52),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.25,
		BackgroundColor3 = accent:Lerp(Theme.Colors.Background, 0.55),
		TextWrapped = false,
		[Create.Children] = { Create.corner(Theme.RadiusSmall), Create.stroke(accent, 0.5, 1.5) },
	})
	local title = Create.label(props.Title, Theme.TextSize.Heading, Theme.Colors.Text, Theme.Fonts.Title, {
		Size = UDim2.new(1, -62, 0, 24),
		Position = UDim2.fromOffset(62, 0),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local description =
		Create.label(props.Description or "", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, {
			Size = UDim2.new(1, -62, 0, 44),
			Position = UDim2.fromOffset(62, 26),
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	local footer = Create("Frame", {
		Name = "Footer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		[Create.Children] = {
			Create.list(
				Enum.FillDirection.Horizontal,
				6,
				Enum.HorizontalAlignment.Right,
				Enum.VerticalAlignment.Center
			),
		},
	})
	local tag = Create.label("", Theme.TextSize.Tiny, Color3.fromRGB(20, 20, 20), Theme.Fonts.Title, {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 4, 0, -6),
		BackgroundTransparency = 0,
		BackgroundColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Visible = false,
		ZIndex = 5,
		[Create.Children] = { Create.corner(Theme.RadiusPill), Create.padding(1, 8) },
	})
	local frame = Create("Frame", {
		Name = "Card_" .. props.Title,
		BackgroundColor3 = Theme.Colors.PanelLight,
		BackgroundTransparency = 0.05,
		Size = props.Size or UDim2.fromOffset(260, 150),
		LayoutOrder = props.LayoutOrder or 0,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.stroke(accent, 0.75, 1.5),
			Create.padding(12),
			icon,
			title,
			description,
			footer,
			tag,
		},
	}) :: Frame
	local self = setmetatable(
		{ Instance = frame, Icon = icon, Title = title, Description = description, Footer = footer, Tag = tag },
		Card
	)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return (self :: any) :: Card
end

function Card.SetTag(self: any, text: string?, color: Color3?)
	if text and text ~= "" then
		self.Tag.Text = text
		self.Tag.Visible = true
		if color then
			self.Tag.BackgroundColor3 = color
		end
	else
		self.Tag.Visible = false
	end
end

function Card.SetDim(self: any, dim: boolean)
	self.Instance.BackgroundTransparency = if dim then 0.45 else 0.05
	self.Title.TextColor3 = if dim then Theme.Colors.TextFaint else Theme.Colors.Text
end

return Card
