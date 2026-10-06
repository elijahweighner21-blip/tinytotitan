--!strict
--[[
	CollectionsMenu
	  Zones        unique collectibles per region (coins, shards, relics,
	               toys, fragments, secret stars) with milestone rewards to
	               claim at 50% and 100%
	  Discoveries  every named place; undiscovered ones show "???" and hidden
	               ones stay secret until found
	  Journal      lore unlocked so far, by chapter — the story of the Titan
	               Engine told in fragments
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local CollectibleConfig = require(Shared.Config.CollectibleConfig)
local DiscoveryConfig = require(Shared.Config.DiscoveryConfig)
local LoreConfig = require(Shared.Config.LoreConfig)

local UI = script.Parent.Parent
local Client = UI.Parent
local Net = require(Client.Net)
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local ProgressBar = require(UI.Components.ProgressBar)
local Scroll = require(UI.Components.Scroll)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local CollectionsMenu = {}

local list: ScrollingFrame
local totals: { [string]: { Total: number, ByType: { [string]: number } } } = {}

local function section(title: string, order: number): Frame
	local frame = Create("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = list,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.padding(12),
			Create.list(Enum.FillDirection.Vertical, 6),
		},
	})
	Create.label(
		title,
		Theme.TextSize.Heading,
		Theme.Colors.Text,
		Theme.Fonts.Title,
		{ LayoutOrder = 0, Parent = frame }
	)
	return frame
end

local function renderZones(data: any)
	local owned: { [string]: { [string]: number } } = {}
	for id in data.Collectibles do
		local zone, typeId = string.match(id, "^([^_]+)_([^_]+)_")
		if zone and typeId then
			owned[zone] = owned[zone] or {}
			owned[zone][typeId] = (owned[zone][typeId] or 0) + 1
		end
	end
	for i, zone in ZoneConfig.Zones do
		local t = totals[zone.Id]
		if t and t.Total > 0 then
			local frame = section(zone.Name, i)
			local mine: { [string]: number } = owned[zone.Id] or {}
			local count = 0
			for _, n in mine do
				count += n
			end
			local bar = ProgressBar.new({
				Parent = frame,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 20),
				Color = zone.MapColor,
				TextSize = Theme.TextSize.Tiny,
			})
			bar:Set(count / t.Total, true)
			bar:SetText(string.format("%d / %d collected", count, t.Total))
			local parts = {}
			for _, def in CollectibleConfig.Types do
				local total = t.ByType[def.Id]
				if total then
					local have = mine[def.Id] or 0
					local hidden = def.Hidden and have == 0
					table.insert(parts, string.format("%s %d/%d", if hidden then "❔ ???" else def.Name, have, total))
				end
			end
			Create.label(
				table.concat(parts, "   ·   "),
				Theme.TextSize.Small,
				Theme.Colors.TextDim,
				Theme.Fonts.Body,
				{
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
					Parent = frame,
				}
			)
			local row = Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 32),
				LayoutOrder = 3,
				Parent = frame,
				[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) },
			})
			for m, milestone in CollectibleConfig.CollectionMilestones do
				local key = zone.Id .. ":" .. m
				local claimed = data.CollectionClaims[key] == true
				local ready = count / t.Total >= milestone.Fraction
				local button = Button.new({
					Text = string.format(
						"%d%%: %s",
						math.floor(milestone.Fraction * 100),
						if claimed then "Claimed ✔" else Common.rewardText(milestone.Reward :: any)
					),
					Style = if claimed then "Ghost" elseif ready then "Gold" else "Secondary",
					Size = UDim2.fromOffset(230, 32),
					TextSize = Theme.TextSize.Small,
					Parent = row,
					OnClick = function()
						Common.request(
							"ClaimCollection",
							{ Zone = zone.Id, Milestone = m },
							"Collection reward claimed!"
						)
					end,
				})
				button:SetEnabled(ready and not claimed)
			end
		end
	end
end

local function renderDiscoveries(data: any)
	for i, zone in ZoneConfig.Zones do
		local entries = {}
		local found = 0
		local total = 0
		for _, d in DiscoveryConfig.List do
			if d.Zone == zone.Id then
				local has = data.Discoveries[d.Id] ~= nil
				if not d.Hidden then
					total += 1
				end
				if has then
					found += 1
					table.insert(entries, "📍 " .. d.Name .. (if d.Hidden then "  ✨ secret" else ""))
				elseif not d.Hidden then
					table.insert(entries, "❔ ???")
				end
			end
		end
		if #entries > 0 then
			local frame = section(string.format("%s   (%d/%d)", zone.Name, found, total), i)
			Create.label(table.concat(entries, "\n"), Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
				Parent = frame,
			})
		end
	end
end

local function renderJournal(data: any)
	local chapters: { [number]: { LoreConfig.LoreEntry } } = {}
	local maxChapter = 0
	local unlocked = 0
	for _, entry in LoreConfig.Entries do
		maxChapter = math.max(maxChapter, entry.Chapter)
		if data.Inventory.Lore[entry.Id] then
			unlocked += 1
			chapters[entry.Chapter] = chapters[entry.Chapter] or {}
			table.insert(chapters[entry.Chapter], entry)
		end
	end
	if unlocked == 0 then
		Create.label(
			"Your journal is empty. Explore, find Memory Fragments and secret places to piece together what happened here.",
			Theme.TextSize.Body,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{
				Size = UDim2.new(1, 0, 0, 60),
				Parent = list,
			}
		)
		return
	end
	for chapter = 1, maxChapter do
		local entries = chapters[chapter]
		if entries then
			local frame = section("Chapter " .. chapter, chapter)
			for j, entry in entries do
				Create.label(
					entry.Title,
					Theme.TextSize.Body,
					Theme.Colors.Gold,
					Theme.Fonts.Title,
					{ LayoutOrder = j * 2, Parent = frame }
				)
				Create.label(entry.Text, Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Light, {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = j * 2 + 1,
					Parent = frame,
				})
			end
		end
	end
end

local function render(menu: MenuBase.Menu, tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	local discovered = 0
	for _ in data.Discoveries do
		discovered += 1
	end
	local collected = 0
	for _ in data.Collectibles do
		collected += 1
	end
	menu.Window:SetSubtitle(string.format("%d collectibles · %d discoveries", collected, discovered))
	Scroll.clear(list)
	if tab == "Zones" then
		renderZones(data)
	elseif tab == "Discoveries" then
		renderDiscoveries(data)
	else
		renderJournal(data)
	end
end

function CollectionsMenu.mount()
	local menu = MenuBase.new({
		Name = "Collections",
		Title = "Collections",
		Icon = "◆",
		Accent = Theme.Colors.Shards,
		Tabs = {
			{ Id = "Zones", Text = "Collectibles" },
			{ Id = "Discoveries", Text = "Discoveries" },
			{ Id = "Journal", Text = "Journal" },
		},
		Watch = { "Collectibles", "CollectionClaims", "Discoveries", "Inventory" },
		Render = render,
	})
	list = Scroll.list(menu.Content, { Gap = 10 })
	Net.onSignal("WorldInfo", function(p)
		if type(p) == "table" and type(p.Collections) == "table" then
			totals = p.Collections
			menu:Refresh()
		end
	end)
end

return CollectionsMenu
