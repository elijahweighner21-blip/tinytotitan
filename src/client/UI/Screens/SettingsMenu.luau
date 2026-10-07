--!strict
--[[
	SettingsMenu
	Every option from SettingsConfig grouped by section (audio, graphics,
	comfort, interface, controls), applied instantly and saved to the
	server (debounced). Also: the Shrink Mode target size, tutorial skip,
	and a controls reference for keyboard / gamepad / touch.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsConfig = require(Shared.Config.SettingsConfig)
local SizeConfig = require(Shared.Config.SizeConfig)

local UI = script.Parent.Parent
local Client = UI.Parent
local Net = require(Client.Net)
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Controls = require(UI.Components.Controls)
local Button = require(UI.Components.Button)
local Scroll = require(UI.Components.Scroll)
local Bus = require(UI.Bus)
local SettingsController = require(Client.Controllers.SettingsController)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local SettingsMenu = {}

local list: ScrollingFrame

local CONTROLS = {
	{ "Move", "WASD", "Left stick", "Thumbstick" },
	{ "Jump / Double jump / Glide (hold)", "Space", "A", "⤒" },
	{ "Sprint", "Shift", "L3", "🏃" },
	{ "Crouch / Slide / Ground pound / Charge", "C / Ctrl", "B", "⤓" },
	{ "Dash", "Q", "R1", "💨" },
	{ "Attack (hold to charge)", "Left click", "R2", "👊" },
	{ "Heavy attack", "F", "Y", "—" },
	{ "Interact / Carry / Throw", "E", "X", "✋" },
	{ "Abilities", "1 – 6", "LB / LT / D-pad", "Ability row" },
	{ "Menus", "U K J M B I O L G H Y P", "D-pad / Start / Select", "Left dock" },
}

local function heading(text: string, order: number)
	Create.label(text, Theme.TextSize.Heading, Theme.Colors.Accent, Theme.Fonts.Display, {
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		Parent = list,
	})
end

local function renderSection(section: string, start: number): number
	local order = start
	for _, def in SettingsConfig.Settings do
		if def.Section == section then
			order += 1
			local value = SettingsController:Get(def.Key)
			if def.Kind == "Toggle" then
				Controls.toggle(list, def.Label, value == true, order, function(v)
					SettingsController:Set(def.Key, v)
				end)
			elseif def.Kind == "Slider" then
				Controls.slider(
					list,
					def.Label,
					tonumber(value) or (def.Min or 0),
					def.Min or 0,
					def.Max or 1,
					def.Step or 0.1,
					order,
					function(v)
						SettingsController:Set(def.Key, v)
					end
				)
			elseif def.Kind == "Choice" and def.Choices then
				Controls.choice(list, def.Label, tostring(value), def.Choices, order, function(v)
					SettingsController:Set(def.Key, v)
				end)
			end
			if def.Hint then
				order += 1
				Create.label(def.Hint, Theme.TextSize.Tiny, Theme.Colors.TextFaint, Theme.Fonts.Body, {
					Size = UDim2.new(1, 0, 0, 16),
					LayoutOrder = order,
					Parent = list,
				})
			end
		end
	end
	return order
end

local function render(menu: MenuBase.Menu, tab: string)
	Scroll.clear(list)
	menu.Window:SetSubtitle("Changes apply instantly and are saved to your account")
	local order = 0
	if tab == "Controls" then
		order = renderSection("Controls", order)
		for _, entry in CONTROLS do
			order += 1
			local frame = Create("Frame", {
				BackgroundColor3 = Theme.Colors.PanelLight,
				Size = UDim2.new(1, -8, 0, 34),
				LayoutOrder = order,
				Parent = list,
				[Create.Children] = { Create.corner(Theme.RadiusSmall), Create.padding(4, 12) },
			})
			Create.label(
				entry[1],
				Theme.TextSize.Small,
				Theme.Colors.Text,
				Theme.Fonts.Title,
				{ Size = UDim2.new(0.4, 0, 1, 0), Parent = frame }
			)
			for i = 2, 4 do
				Create.label(entry[i], Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Mono, {
					Position = UDim2.fromScale(0.4 + (i - 2) * 0.2, 0),
					Size = UDim2.new(0.2, 0, 1, 0),
					Parent = frame,
				})
			end
		end
		order += 1
		local data = DataController:Get()
		if data and not data.Tutorial.Done then
			Button.new({
				Text = "Skip Tutorial",
				Style = "Ghost",
				Size = UDim2.fromOffset(180, 36),
				LayoutOrder = order,
				Parent = list,
				OnClick = function()
					Net.action("Tutorial", { Skip = true })
					Bus.toast("Tutorial hints turned off", "Info")
				end,
			})
		end
		return
	end
	if tab == "Gameplay" then
		heading("Shrink Mode", 1)
		local tier = DataController:GetTier()
		local data = DataController:Get()
		local current = if data then data.Progress.ShrinkTier else 0
		local choices = { "Auto (4 sizes smaller)" }
		local byName: { [string]: number } = { ["Auto (4 sizes smaller)"] = 0 }
		for i = 1, tier - 1 do
			local name = SizeConfig.getTier(i).Name
			table.insert(choices, name)
			byName[name] = i
		end
		local currentName = if current > 0 and current < tier then SizeConfig.getTier(current).Name else choices[1]
		Controls.choice(list, "Shrink to", currentName, choices, 2, function(value)
			Common.request("ToggleShrink", { Tier = byName[value] or 0 }, "Shrink Mode target: " .. value)
		end)
		Create.label(
			"Shrink Mode (skill, key 2) temporarily returns you to a smaller size so you can revisit places you've outgrown. Your Mass is never lost.",
			Theme.TextSize.Small,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 3,
				Parent = list,
			}
		)
		return
	end
	renderSection(tab, order)
end

function SettingsMenu.mount()
	local tabs = {}
	for _, section in SettingsConfig.Sections do
		if section ~= "Controls" then
			table.insert(tabs, { Id = section, Text = section })
		end
	end
	table.insert(tabs, { Id = "Gameplay", Text = "Gameplay" })
	table.insert(tabs, { Id = "Controls", Text = "Controls" })
	local menu = MenuBase.new({
		Name = "Settings",
		Title = "Settings",
		Icon = Theme.Icons.Settings,
		Accent = Theme.Colors.Accent,
		Tabs = tabs,
		Watch = { "Progress", "Tutorial" },
		Render = render,
	})
	list = Scroll.list(menu.Content, { Gap = 8 })
end

return SettingsMenu
