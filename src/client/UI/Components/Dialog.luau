--!strict
--[[
	Dialog
	Modal confirmation (used for Ascension, respec, leaving challenges).
	Blocks clicks behind it, supports gamepad (selects the safe option first)
	and resolves exactly once.
]]

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Button = require(script.Parent.Button)

local Dialog = {}

export type Options = {
	Title: string,
	Body: string?,
	Lines: { { Text: string, Color: Color3? } }?,
	Confirm: string?,
	Cancel: string?,
	Danger: boolean?,
	Parent: Instance,
}

function Dialog.confirm(opts: Options, onResult: (confirmed: boolean) -> ())
	local resolved = false
	local blocker = Create("TextButton", {
		Name = "DialogBlocker",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = opts.Parent,
	}) :: TextButton
	local panel = Create("Frame", {
		Name = "Dialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 51,
		Parent = blocker,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.stroke(if opts.Danger then Theme.Colors.Danger else Theme.Colors.Accent, 0.4, 2),
			Create.padding(20),
			Create.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center),
			Create("UISizeConstraint", { MaxSize = Vector2.new(560, 640) }),
		},
	})
	Create.label(opts.Title, Theme.TextSize.Title, Theme.Colors.Text, Theme.Fonts.Display, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		ZIndex = 52,
		Parent = panel,
	})
	if opts.Body then
		Create.label(opts.Body, Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, {
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			ZIndex = 52,
			Parent = panel,
		})
	end
	local lines: { { Text: string, Color: Color3? } } = opts.Lines or {}
	for i, line in lines do
		Create.label(line.Text, Theme.TextSize.Small, line.Color or Theme.Colors.Text, Theme.Fonts.Body, {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2 + i,
			ZIndex = 52,
			Parent = panel,
		})
	end
	local buttons = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 100,
		Parent = panel,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) },
	})
	local function finish(result: boolean)
		if resolved then
			return
		end
		resolved = true
		GuiService.SelectedObject = nil
		blocker:Destroy()
		onResult(result)
	end
	local cancel = Button.new({ Text = opts.Cancel or "Cancel", Style = "Secondary", Size = UDim2.fromOffset(180, 44), Parent = buttons, LayoutOrder = 1, OnClick = function()
		finish(false)
	end })
	Button.new({ Text = opts.Confirm or "Confirm", Style = if opts.Danger then "Danger" else "Primary", Size = UDim2.fromOffset(180, 44), Parent = buttons, LayoutOrder = 2, OnClick = function()
		finish(true)
	end })
	TweenService:Create(blocker, Theme.Tween.Normal, { BackgroundTransparency = 0.45 }):Play()
	GuiService.SelectedObject = cancel.Instance
end

return Dialog
