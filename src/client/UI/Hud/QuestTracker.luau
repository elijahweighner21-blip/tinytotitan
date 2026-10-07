--!strict
--[[
	QuestTracker
	Compact tracker under the currencies: the tracked quest's name and each
	objective with live progress. Click to open the Quests menu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local DataController = require(Client.Controllers.DataController)
local Hud = require(script.Parent.Hud)

local QuestTracker = {}

local frame: TextButton
local caption: TextLabel
local percent: TextLabel
local title: TextLabel
local list: Frame
local border: UIStroke
local lastSignature = ""

local function objectiveRow(text: string, progress: number, count: number, order: number)
	local done = progress >= count
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = list,
		[Create.Children] = { Create.list(Enum.FillDirection.Vertical, 3) },
	})
	local suffix = if count > 1
		then string.format("  %s/%s", Format.abbreviate(progress), Format.abbreviate(count))
		else ""
	Create.label(
		(if done then "✔  " else "") .. text .. suffix,
		Theme.TextSize.Small,
		if done then Theme.Colors.Success else Theme.Colors.Text,
		Theme.Fonts.Body,
		{
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = row,
		}
	)
	local track = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 12, 20),
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, 4),
		LayoutOrder = 2,
		Parent = row,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	Create("Frame", {
		BackgroundColor3 = if done then Theme.Colors.Success else Theme.Colors.Gold,
		Size = UDim2.fromScale(math.clamp(progress / math.max(count, 1), 0, 1), 1),
		Parent = track,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
end

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
	caption.Text = Theme.Icons.Quests .. "  " .. (if def.Category == "Story" then "STORY QUEST" else "QUEST")
	title.Text = string.upper(def.Name)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local total, sum = 0, 0
	local signature = id
	for i, objective in def.Objectives do
		local progress = math.min(active.Progress[i] or 0, objective.Count)
		total += 1
		sum += progress / math.max(objective.Count, 1)
		signature ..= ":" .. progress
		objectiveRow(objective.Text, progress, objective.Count, i)
	end
	percent.Text = string.format("%d%%", math.floor(sum / math.max(total, 1) * 100))
	-- Progress made: flash the border.
	if lastSignature ~= "" and signature ~= lastSignature and string.sub(lastSignature, 1, #id) == id then
		border.Transparency = 0
		border.Thickness = 3
		TweenService:Create(border, Theme.Tween.Slow, { Transparency = 0.6, Thickness = 1.5 }):Play()
	end
	lastSignature = signature
end

function QuestTracker.mount()
	border = Create.stroke(Theme.Colors.Gold, 0.6, 1.5)
	frame = Create("TextButton", {
		Name = "QuestTracker",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.18,
		Size = UDim2.fromOffset(290, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Visible = false,
		-- Stacks under the currencies/boosts so they can never overlap.
		Parent = Hud.rightColumn or UIManager.Hud,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			border,
			Create.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 195, 215), 90),
			Create.padding(10, 12),
			Create.list(Enum.FillDirection.Vertical, 6),
		},
	})
	local header = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 1,
		Parent = frame,
	})
	caption = Create.label("", Theme.TextSize.Tiny, Theme.Colors.Gold, Theme.Fonts.Display, {
		Size = UDim2.fromScale(0.7, 1),
		Parent = header,
	})
	percent = Create.label("", Theme.TextSize.Tiny, Theme.Colors.Gold, Theme.Fonts.Display, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.3, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	title = Create.label("", Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
	})
	list = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = frame,
		[Create.Children] = { Create.list(Enum.FillDirection.Vertical, 6) },
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
