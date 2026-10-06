--!strict
--[[
	QuestsMenu
	  Active      objectives with progress bars, Track (shown in the HUD
	              tracker + world marker) and Abandon (non-story only)
	  Available   quests you qualify for: accept here or from the giver
	  Completed   your quest log, story chapters first
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local NPCConfig = require(Shared.Config.NPCConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local Format = require(Shared.Util.Format)
local Types = require(Shared.Types)

local UI = script.Parent.Parent
local Client = UI.Parent
local Net = require(Client.Net)
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local ProgressBar = require(UI.Components.ProgressBar)
local Scroll = require(UI.Components.Scroll)
local Dialog = require(UI.Components.Dialog)
local UIManager = require(UI.UIManager)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local QuestsMenu = {}

local list: ScrollingFrame

local CATEGORY_ICONS: { [string]: string } = {
	Story = "★",
	Collection = "◆",
	Parkour = "🧗",
	Exploration = "🧭",
	Discovery = "📍",
	Combat = "⚔",
	Boss = "👑",
	Growth = "🌱",
}

local function giverName(def: Types.Quest): string
	local npc = def.Giver and NPCConfig.get(def.Giver)
	return if npc then npc.Name else "—"
end

local function availability(def: Types.Quest, data: any): (boolean, string?)
	if data.Quests.Active[def.Id] or data.Quests.Completed[def.Id] then
		return false, nil
	end
	local prereqs: { string } = def.Prerequisites or {}
	for _, pre in prereqs do
		if not data.Quests.Completed[pre] then
			return false, "hidden"
		end
	end
	if def.RequiredTier and DataController:GetTier() < def.RequiredTier then
		return false, "Requires " .. SizeConfig.getTier(def.RequiredTier).Name
	end
	if def.RequiredLevel and data.Progress.Level < def.RequiredLevel then
		return false, "Requires level " .. def.RequiredLevel
	end
	return true, nil
end

local function questPanel(def: Types.Quest, order: number): Frame
	local frame = Create("Frame", {
		Name = def.Id,
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = list,
		[Create.Children] = { Create.corner(Theme.Radius), Create.padding(12), Create.list(Enum.FillDirection.Vertical, 6) },
	})
	local story = def.Category == "Story"
	Create.label((CATEGORY_ICONS[def.Category] or "•") .. "  " .. def.Name, Theme.TextSize.Heading, if story then Theme.Colors.Gold else Theme.Colors.Text, Theme.Fonts.Title, { LayoutOrder = 1, Parent = frame })
	Create.label(def.Description, Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
	})
	return frame
end

local function buttonRow(parent: Instance, order: number): Frame
	return Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		Parent = parent,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) },
	})
end

local function renderActive(data: any)
	local ids = {}
	for id in data.Quests.Active do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local da, db = QuestConfig.get(a), QuestConfig.get(b)
		local sa = da and da.Category == "Story"
		local sb = db and db.Category == "Story"
		if sa ~= sb then
			return sa == true
		end
		return a < b
	end)
	if #ids == 0 then
		Create.label("No active quests. Check the Available tab or talk to the people you meet!", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, { Size = UDim2.new(1, 0, 0, 40), Parent = list })
	end
	for i, id in ids do
		local def = QuestConfig.get(id)
		local active = data.Quests.Active[id]
		if def and active then
			local frame = questPanel(def, i)
			for j, objective in def.Objectives do
				local progress = math.min(active.Progress[j] or 0, objective.Count)
				local bar = ProgressBar.new({
					Parent = frame,
					LayoutOrder = 2 + j,
					Size = UDim2.new(1, 0, 0, 20),
					Color = if progress >= objective.Count then Theme.Colors.Success else Theme.Colors.Gold,
					TextSize = Theme.TextSize.Tiny,
				})
				bar:Set(progress / math.max(objective.Count, 1), true)
				bar:SetText(string.format("%s   %s/%s", objective.Text, Format.abbreviate(progress), Format.abbreviate(objective.Count)))
			end
			Create.label("Rewards: " .. Common.rewardText(def.Rewards :: any), Theme.TextSize.Small, Theme.Colors.Accent, Theme.Fonts.Title, { LayoutOrder = 20, Parent = frame })
			local row = buttonRow(frame, 21)
			local tracked = data.Quests.Tracked == id
			Button.new({
				Text = if tracked then "Tracking ✔" else "Track",
				Style = if tracked then "Success" else "Secondary",
				Size = UDim2.fromOffset(120, 32),
				TextSize = Theme.TextSize.Small,
				Parent = row,
				OnClick = function()
					Net.action("TrackQuest", id)
				end,
			})
			if not QuestConfig.NonAbandonable[def.Category] then
				Button.new({
					Text = "Abandon",
					Style = "Ghost",
					Size = UDim2.fromOffset(110, 32),
					TextSize = Theme.TextSize.Small,
					Parent = row,
					OnClick = function()
						Dialog.confirm({ Title = "Abandon " .. def.Name .. "?", Body = "Progress on this quest will be lost. You can accept it again later.", Confirm = "Abandon", Danger = true, Parent = UIManager.Menus }, function(ok)
							if ok then
								Common.request("AbandonQuest", { Id = id })
							end
						end)
					end,
				})
			end
		end
	end
end

local function renderAvailable(data: any)
	local n = 0
	for _, def in QuestConfig.List do
		local ok, reason = availability(def, data)
		if ok or (reason and reason ~= "hidden") then
			n += 1
			local frame = questPanel(def, n)
			Create.label("Given by " .. giverName(def) .. "   ·   Rewards: " .. Common.rewardText(def.Rewards :: any), Theme.TextSize.Small, Theme.Colors.Accent, Theme.Fonts.Title, { LayoutOrder = 3, Parent = frame })
			local row = buttonRow(frame, 4)
			if ok then
				Button.new({
					Text = "Accept",
					Style = "Gold",
					Size = UDim2.fromOffset(120, 32),
					TextSize = Theme.TextSize.Small,
					Parent = row,
					OnClick = function()
						Common.request("AcceptQuest", { Id = def.Id }, "Quest accepted: " .. def.Name)
					end,
				})
			else
				Create.label("🔒 " .. tostring(reason), Theme.TextSize.Small, Theme.Colors.Danger, Theme.Fonts.Title, {
					Size = UDim2.fromOffset(260, 32),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = row,
				})
			end
		end
	end
	if n == 0 then
		Create.label("Nothing new right now — finish your active quests to unlock more.", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, { Size = UDim2.new(1, 0, 0, 40), Parent = list })
	end
end

local function renderCompleted(data: any)
	local done = {}
	for id, at in data.Quests.Completed do
		local def = QuestConfig.get(id)
		if def then
			table.insert(done, { def = def, at = at })
		end
	end
	table.sort(done, function(a, b)
		local sa, sb = a.def.Category == "Story", b.def.Category == "Story"
		if sa ~= sb then
			return sa
		end
		return a.at > b.at
	end)
	for i, entry in done do
		local frame = questPanel(entry.def, i)
		if entry.def.Story then
			Create.label("“" .. entry.def.Story .. "”", Theme.TextSize.Small, Theme.Colors.Gold, Theme.Fonts.Light, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				Parent = frame,
			})
		end
	end
	if #done == 0 then
		Create.label("Your quest log is empty — for now.", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, { Size = UDim2.new(1, 0, 0, 40), Parent = list })
	end
end

local function render(menu: MenuBase.Menu, tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	local active = 0
	for _ in data.Quests.Active do
		active += 1
	end
	local completed = 0
	for _ in data.Quests.Completed do
		completed += 1
	end
	menu.Window:SetSubtitle(string.format("%d active · %d completed of %d", active, completed, #QuestConfig.List))
	Scroll.clear(list)
	if tab == "Active" then
		renderActive(data)
	elseif tab == "Available" then
		renderAvailable(data)
	else
		renderCompleted(data)
	end
end

function QuestsMenu.mount()
	local menu = MenuBase.new({
		Name = "Quests",
		Title = "Quests",
		Icon = "!",
		Accent = Theme.Colors.Gold,
		Tabs = {
			{ Id = "Active", Text = "Active" },
			{ Id = "Available", Text = "Available" },
			{ Id = "Completed", Text = "Completed" },
		},
		Watch = { "Quests", "Progress" },
		Render = render,
	})
	list = Scroll.list(menu.Content, { Gap = 10 })
end

return QuestsMenu
