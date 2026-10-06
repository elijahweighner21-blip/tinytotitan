--!strict
--[[
	Create
	Declarative instance builder:
	  Create("Frame", { Size = ..., [Create.Children] = { ... } })
	Also helpers for the decorations every element uses (corner, stroke,
	padding, list/grid layouts, gradients).
]]

local Theme = require(script.Parent.Theme)

local Create = {}
Create.Children = newproxy(false)

local function create(className: string, props: { [any]: any }?): any
	local instance = Instance.new(className)
	local children = nil
	local parent = nil
	if props then
		for key, value in props do
			if key == Create.Children then
				children = value
			elseif key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			if child then
				child.Parent = instance
			end
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

setmetatable(Create, {
	__call = function(_, className: string, props: { [any]: any }?)
		return create(className, props)
	end,
})

function Create.corner(radius: UDim?): any
	return create("UICorner", { CornerRadius = radius or Theme.Radius })
end

function Create.stroke(color: Color3?, transparency: number?, thickness: number?): any
	return create("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Transparency = transparency or Theme.StrokeTransparency,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.padding(all: number?, horizontal: number?): any
	local p = UDim.new(0, all or Theme.Padding)
	local h = UDim.new(0, horizontal or all or Theme.Padding)
	return create("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = h, PaddingRight = h })
end

function Create.list(
	direction: Enum.FillDirection?,
	gap: number?,
	align: Enum.HorizontalAlignment?,
	valign: Enum.VerticalAlignment?
): any
	return create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or Theme.Gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end

function Create.grid(cell: UDim2, gap: number?): any
	return create("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(gap or Theme.Gap, gap or Theme.Gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Create.gradient(top: Color3, bottom: Color3, rotation: number?): any
	return create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function Create.label(text: string, size: number?, color: Color3?, font: Font?, props: { [any]: any }?): any
	local base: { [any]: any } = {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size or Theme.TextSize.Body,
		TextColor3 = color or Theme.Colors.Text,
		FontFace = font or Theme.Fonts.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, (size or Theme.TextSize.Body) + 6),
		AutomaticSize = Enum.AutomaticSize.None,
	}
	if props then
		for k, v in props do
			base[k] = v
		end
	end
	return create("TextLabel", base)
end

return Create
