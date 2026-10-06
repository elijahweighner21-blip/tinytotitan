--!strict
--[[
	Tabs
	Pill tab strip that lives in a Window's TabBar. Selecting a tab calls
	OnSelect(id) and highlights it; works with mouse, touch and gamepad.
]]

local TweenService = game:GetService("TweenService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local Sound = require(UI.Sound)

export type TabDef = { Id: string, Text: string, Icon: string? }
export type Tabs = {
	Select: (self: Tabs, id: string) -> (),
	Selected: string,
	Buttons: { [string]: TextButton },
}

local Tabs = {}
Tabs.__index = Tabs

function Tabs.new(parent: Instance, defs: { TabDef }, accent: Color3?, onSelect: (id: string) -> ()): Tabs
	local self = setmetatable({ Selected = "", Buttons = {}, _accent = accent or Theme.Colors.Accent, _onSelect = onSelect }, Tabs)
	for i, def in defs do
		local text = if def.Icon then def.Icon .. " " .. def.Text else def.Text
		local button = Create("TextButton", {
			Name = "Tab_" .. def.Id,
			AutoButtonColor = false,
			Text = text,
			FontFace = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextDim,
			BackgroundColor3 = Theme.Colors.PanelLight,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			LayoutOrder = i,
			Selectable = true,
			Parent = parent,
			[Create.Children] = { Create.corner(Theme.RadiusPill), Create.padding(4, 14) },
		}) :: TextButton
		button.Activated:Connect(function()
			Sound.play("Click")
			self:Select(def.Id)
		end)
		self.Buttons[def.Id] = button
	end
	return (self :: any) :: Tabs
end

function Tabs.Select(self: any, id: string)
	self.Selected = id
	for tabId, button in self.Buttons do
		local active = tabId == id
		TweenService:Create(button, Theme.Tween.Fast, {
			BackgroundColor3 = if active then self._accent else Theme.Colors.PanelLight,
			TextColor3 = if active then Color3.fromRGB(10, 20, 30) else Theme.Colors.TextDim,
		}):Play()
	end
	self._onSelect(id)
end

return Tabs
