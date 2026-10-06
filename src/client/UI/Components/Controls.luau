--!strict
--[[
	Controls
	Settings widgets: Toggle, Slider and Choice. All are gamepad-selectable
	(Slider responds to left/right while selected) and touch friendly.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Sound = require(UI.Sound)

local Controls = {}

local function row(label: string, layoutOrder: number, parent: Instance): (Frame, Frame)
	local holder = Create("Frame", {
		Name = "Row_" .. label,
		BackgroundColor3 = Theme.Colors.PanelLight,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, -8, 0, 46),
		LayoutOrder = layoutOrder,
		Parent = parent,
		[Create.Children] = {
			Create.corner(Theme.RadiusSmall),
			Create.padding(6, 12),
			Create.label(
				label,
				Theme.TextSize.Body,
				Theme.Colors.Text,
				Theme.Fonts.Body,
				{ Size = UDim2.new(0.55, 0, 1, 0), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd }
			),
		},
	})
	local right = Create("Frame", {
		Name = "Control",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0.42, 0, 1, 0),
		Parent = holder,
	})
	return holder, right
end

function Controls.toggle(
	parent: Instance,
	label: string,
	value: boolean,
	layoutOrder: number,
	onChange: (boolean) -> ()
): (boolean) -> ()
	local _, right = row(label, layoutOrder, parent)
	local knob = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	local track = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(54, 28),
		BackgroundColor3 = Theme.Colors.Locked,
		Selectable = true,
		Parent = right,
		[Create.Children] = { Create.corner(Theme.RadiusPill), knob },
	}) :: TextButton
	local state = value
	local function render()
		TweenService:Create(
			track,
			Theme.Tween.Fast,
			{ BackgroundColor3 = if state then Theme.Colors.Success else Theme.Colors.Locked }
		):Play()
		TweenService:Create(
			knob,
			Theme.Tween.Fast,
			{ Position = if state then UDim2.new(1, -25, 0.5, 0) else UDim2.new(0, 3, 0.5, 0) }
		):Play()
	end
	track.Activated:Connect(function()
		state = not state
		Sound.play("Click")
		render()
		onChange(state)
	end)
	render()
	return function(v: boolean)
		state = v
		render()
	end
end

function Controls.slider(
	parent: Instance,
	label: string,
	value: number,
	min: number,
	max: number,
	step: number,
	layoutOrder: number,
	onChange: (number) -> ()
): (number) -> ()
	local _, right = row(label, layoutOrder, parent)
	local valueLabel = Create.label("", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Mono, {
		Size = UDim2.new(0, 44, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = right,
	})
	local fill = Create("Frame", {
		BackgroundColor3 = Theme.Colors.Accent,
		Size = UDim2.fromScale(0, 1),
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	local bar = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Background,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(1, -52, 0, 10),
		Selectable = true,
		Parent = right,
		[Create.Children] = { Create.corner(Theme.RadiusPill), fill },
	}) :: TextButton
	local current = value
	local function render()
		local t = (current - min) / math.max(max - min, 1e-6)
		fill.Size = UDim2.fromScale(math.clamp(t, 0, 1), 1)
		valueLabel.Text = if max <= 1
			then string.format("%d%%", math.floor(current * 100 + 0.5))
			else tostring(math.floor(current * 100 + 0.5) / 100)
	end
	local function setFromFraction(t: number)
		local raw = min + (max - min) * math.clamp(t, 0, 1)
		local snapped = math.floor(raw / step + 0.5) * step
		if snapped ~= current then
			current = snapped
			render()
			onChange(current)
		end
	end
	local dragging = false
	bar.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFromFraction((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFromFraction((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	-- Gamepad: left/right while selected.
	UserInputService.InputBegan:Connect(function(input)
		if game:GetService("GuiService").SelectedObject ~= bar then
			return
		end
		if input.KeyCode == Enum.KeyCode.DPadRight or input.KeyCode == Enum.KeyCode.Right then
			setFromFraction((current + step - min) / (max - min))
		elseif input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.Left then
			setFromFraction((current - step - min) / (max - min))
		end
	end)
	render()
	return function(v: number)
		current = v
		render()
	end
end

function Controls.choice(
	parent: Instance,
	label: string,
	value: string,
	choices: { string },
	layoutOrder: number,
	onChange: (string) -> ()
): (string) -> ()
	local _, right = row(label, layoutOrder, parent)
	local button = Create("TextButton", {
		AutoButtonColor = false,
		Text = value,
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Colors.Text,
		BackgroundColor3 = Theme.Colors.PanelLighter,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(1, 0, 0, 32),
		Selectable = true,
		Parent = right,
		[Create.Children] = { Create.corner(Theme.RadiusSmall) },
	}) :: TextButton
	local current = value
	button.Activated:Connect(function()
		local index = table.find(choices, current) or 0
		current = choices[index % #choices + 1]
		button.Text = "◀  " .. current .. "  ▶"
		Sound.play("Click")
		onChange(current)
	end)
	button.Text = "◀  " .. current .. "  ▶"
	return function(v: string)
		current = v
		button.Text = "◀  " .. current .. "  ▶"
	end
end

return Controls
