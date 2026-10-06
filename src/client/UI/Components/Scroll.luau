--!strict
--[[
	Scroll
	ScrollingFrame with automatic canvas sizing and a list or grid layout.
	Touch and gamepad scrolling work out of the box.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)

local Scroll = {}

function Scroll.list(parent: Instance, props: { Size: UDim2?, Position: UDim2?, Gap: number?, Direction: Enum.FillDirection?, Name: string? }): ScrollingFrame
	local direction = props.Direction or Enum.FillDirection.Vertical
	local horizontal = direction == Enum.FillDirection.Horizontal
	return Create("ScrollingFrame", {
		Name = props.Name or "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.TextFaint,
		Selectable = false,
		Parent = parent,
		[Create.Children] = {
			Create.list(direction, props.Gap or Theme.Gap),
			Create.padding(4, 4),
		},
	}) :: ScrollingFrame
end

function Scroll.grid(parent: Instance, cell: UDim2, props: { Size: UDim2?, Position: UDim2?, Gap: number?, Name: string? }): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = props.Name or "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.TextFaint,
		Selectable = false,
		Parent = parent,
		[Create.Children] = {
			Create.grid(cell, props.Gap or 10),
			Create.padding(6, 6),
		},
	}) :: ScrollingFrame
end

function Scroll.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

return Scroll
