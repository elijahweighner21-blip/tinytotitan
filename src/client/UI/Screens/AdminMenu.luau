--!strict
--[[
	AdminMenu
	Developer tools, visible only when the server marks the player IsAdmin
	(GameConfig.Admins / AdminGroup, or Studio). Every command is
	re-authorised on the server and logged; a non-admin sending Admin
	requests is flagged by anti-exploit. Target defaults to yourself.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local WorldEventConfig = require(Shared.Config.WorldEventConfig)
local BossConfig = require(Shared.Config.BossConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)

local UI = script.Parent.Parent
local Client = UI.Parent
local Net = require(Client.Net)
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local Scroll = require(UI.Components.Scroll)
local Bus = require(UI.Bus)
local UIManager = require(UI.UIManager)

local AdminMenu = {}

local player = Players.LocalPlayer
local list: ScrollingFrame
local output: TextLabel
local targetName = ""
local amount = "1000"

local function targetId(): number?
	if targetName == "" then
		return nil
	end
	for _, p in Players:GetPlayers() do
		if
			string.lower(p.Name) == string.lower(targetName)
			or string.lower(p.DisplayName) == string.lower(targetName)
		then
			return p.UserId
		end
	end
	return -1
end

local function run(cmd: string, args: { [string]: any }?)
	local target = targetId()
	if target == -1 then
		Bus.toast("No player named " .. targetName, "Warning")
		return
	end
	local result = Net.request("Admin", { Cmd = cmd, Target = target, Args = args or {} })
	local ok, json = pcall(function()
		return HttpService:JSONEncode(result)
	end)
	output.Text = cmd .. " → " .. (if ok then json else tostring(result.ok))
	Bus.toast(
		cmd .. (if result.ok then " ✔" else " failed: " .. tostring(result.err)),
		if result.ok then "Success" else "Warning"
	)
end

local function value(): number
	return tonumber(amount) or 0
end

local function textBox(label: string, initial: string, order: number, onChange: (string) -> ())
	local frame = Create("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 40),
		LayoutOrder = order,
		Parent = list,
		[Create.Children] = { Create.corner(Theme.RadiusSmall), Create.padding(4, 12) },
	})
	Create.label(
		label,
		Theme.TextSize.Small,
		Theme.Colors.Text,
		Theme.Fonts.Title,
		{ Size = UDim2.new(0.4, 0, 1, 0), Parent = frame }
	)
	local box = Create("TextBox", {
		Text = initial,
		PlaceholderText = label,
		ClearTextOnFocus = false,
		TextSize = Theme.TextSize.Body,
		FontFace = Theme.Fonts.Mono,
		TextColor3 = Theme.Colors.Text,
		BackgroundColor3 = Theme.Colors.Panel,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0.58, 0, 0, 30),
		Parent = frame,
		[Create.Children] = { Create.corner(Theme.RadiusSmall) },
	}) :: TextBox
	box.FocusLost:Connect(function()
		onChange(box.Text)
	end)
end

type Entry = { Text: string, Run: () -> () }

local function buttons(order: number, entries: { Entry })
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = list,
		[Create.Children] = { Create.grid(UDim2.fromOffset(170, 32), 6) },
	})
	for _, entry in entries do
		Button.new({
			Text = entry.Text,
			Style = "Secondary",
			TextSize = Theme.TextSize.Small,
			Parent = row,
			OnClick = entry.Run,
		})
	end
end

local function build()
	textBox("Target player (blank = you)", "", 1, function(text)
		targetName = text
	end)
	textBox("Amount / value", amount, 2, function(text)
		amount = text
	end)
	buttons(3, {
		{
			Text = "Add Mass",
			Run = function()
				run("AddMass", { Value = value() })
			end,
		},
		{
			Text = "Set Mass",
			Run = function()
				run("SetMass", { Value = value() })
			end,
		},
		{
			Text = "Set Tier",
			Run = function()
				run("SetTier", { Value = value() })
			end,
		},
		{
			Text = "Set Level",
			Run = function()
				run("SetLevel", { Value = value() })
			end,
		},
		{
			Text = "Give Energy",
			Run = function()
				run("GiveCurrency", { Currency = "GrowthEnergy", Value = value() })
			end,
		},
		{
			Text = "Give Shards",
			Run = function()
				run("GiveCurrency", { Currency = "TitanShards", Value = value() })
			end,
		},
		{
			Text = "Give Skill Pts",
			Run = function()
				run("GiveCurrency", { Currency = "SkillPoints", Value = value() })
			end,
		},
		{
			Text = "Give Asc. Pts",
			Run = function()
				run("GiveCurrency", { Currency = "AscensionPoints", Value = value() })
			end,
		},
		{
			Text = "Heal",
			Run = function()
				run("Heal")
			end,
		},
		{
			Text = "Server Stats",
			Run = function()
				run("Stats")
			end,
		},
		{
			Text = "Print Data",
			Run = function()
				run("PrintData")
			end,
		},
		{
			Text = "Debug Overlay",
			Run = function()
				run("Debug", { Value = player:GetAttribute("DebugMode") ~= true })
			end,
		},
	})
	local zones: { Entry } = {}
	for _, z in ZoneConfig.Zones do
		table.insert(zones, {
			Text = "→ " .. z.Name,
			Run = function()
				run("Teleport", { Zone = z.Id })
			end,
		})
	end
	buttons(4, zones)
	local events: { Entry } = {}
	for _, e in WorldEventConfig.List do
		table.insert(events, {
			Text = "Event: " .. e.Name,
			Run = function()
				run("StartEvent", { Id = e.Id })
			end,
		})
	end
	for _, b in BossConfig.List do
		table.insert(events, {
			Text = "Boss: " .. b.Name,
			Run = function()
				run("SpawnBoss", { Id = b.Id })
			end,
		})
	end
	buttons(5, events)
	local boosts: { Entry } = {}
	for id, b in MonetizationConfig.Boosts do
		table.insert(boosts, {
			Text = b.Icon .. " " .. b.Name .. " 10m",
			Run = function()
				run("GiveBoost", { Boost = id, Value = 600 })
			end,
		})
	end
	buttons(6, boosts)
	Create.label(
		"STUDIO PURCHASE TESTING (runs the real receipt pipeline)",
		Theme.TextSize.Small,
		Theme.Colors.Gold,
		Theme.Fonts.Title,
		{ LayoutOrder = 7, Parent = list }
	)
	local purchases: { Entry } = {}
	for key, product in MonetizationConfig.DeveloperProducts do
		table.insert(purchases, {
			Text = "Buy " .. product.Name,
			Run = function()
				run("TestPurchase", { Product = key })
			end,
		})
	end
	for key, pass in MonetizationConfig.GamePasses do
		table.insert(purchases, {
			Text = "Pass: " .. pass.Name,
			Run = function()
				run("SetPass", { Key = key, Value = player:GetAttribute("Pass_" .. key) ~= true })
			end,
		})
	end
	table.sort(purchases, function(a, b)
		return a.Text < b.Text
	end)
	buttons(8, purchases)
	buttons(9, {
		{
			Text = "⚠ Reset My Data",
			Run = function()
				run("ResetData")
			end,
		},
	})
	output = Create.label("", Theme.TextSize.Tiny, Theme.Colors.TextDim, Theme.Fonts.Mono, {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 10,
		Parent = list,
	})
end

function AdminMenu.mount()
	local menu = MenuBase.new({
		Name = "Admin",
		Title = "Admin",
		Icon = "🛠",
		Accent = Theme.Colors.Danger,
		Render = function(m)
			m.Window:SetSubtitle("Every command is verified and logged by the server")
		end,
	})
	list = Scroll.list(menu.Content, { Gap = 8 })
	build()
	-- F2 toggles the panel for admins.
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 and player:GetAttribute("IsAdmin") == true then
			UIManager:Toggle("Admin")
		end
	end)
end

return AdminMenu
