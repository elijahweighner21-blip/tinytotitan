--!strict
--[[
	QuestTracker
	Compact tracker under the currencies: the tracked quest's name and each
	objective with live progress. Click to open the Quests menu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local DataController = require(Client.Controllers.DataController)

local QuestTracker = {}

local frame: TextButton
local title: TextLabel
local list: Frame

local function refresh()
	local data = DataController:Get()
	if not data then
		frame.Visible = false
		return
	end
	local id = data.Quests.Tracked
	local active = id ~= "" and data.Quests.Active[id]
	local def = if active then QuestConfig.get(id) else nil
	if not def or not active then
		frame.Visible = false
		return
	end
	frame.Visible = true
	title.Text = (if def.Category == "Story" then "★ " else "") .. def.Name
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, objective in def.Objectives do
		local progress = math.min(active.Progress[i] or 0, objective.Count)
		local done = progress >= objective.Count
		local count = if objective.Count > 1 then string.format("  %s/%s", Format.abbreviate(progress), Format.abbreviate(objective.Count)) else ""
		Create.label((if done then "✔ " else "• ") .. objective.Text .. count, Theme.TextSize.Small, if done then Theme.Colors.Success else Theme.Colors.TextDim, Theme.Fonts.Body, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = list,
		})
	end
end

function QuestTracker.mount()
	frame = Create("TextButton", {
		Name = "QuestTracker",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 130),
		Size = UDim2.fromOffset(290, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = UIManager.Hud,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.stroke(Theme.Colors.Gold, 0.7),
			Create.padding(10, 12),
			Create.list(Enum.FillDirection.Vertical, 4),
		},
	})
	title = Create.label("", Theme.TextSize.Body, Theme.Colors.Gold, Theme.Fonts.Title, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = frame,
	})
	list = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
		[Create.Children] = { Create.list(Enum.FillDirection.Vertical, 2) },
	})
	frame.Activated:Connect(function()
		UIManager:Open("Quests")
	end)
	DataController.Changed:Connect(function(key)
		if key == "Quests" then
			refresh()
		end
	end)
	DataController.Loaded:Connect(refresh)
	refresh()
end

return QuestTracker
