--!strict
--[[
	DialogueBox
	NPC conversation panel (bottom of screen). Shows the NPC's size-relative
	line, quests they offer (Accept → DialogueChoice, which re-checks
	distance on the server), and their station menu if they run one.
	Closes when the player walks away.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)

local Client = script.Parent.Parent.Parent
local Net = require(Client.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local Button = require(Client.UI.Components.Button)
local Bus = require(Client.UI.Bus)
local WorldIndex = require(Client.WorldIndex)
local MovementController = require(Client.Controllers.MovementController)

local DialogueBox = {}

local frame: Frame
local nameLabel: TextLabel
local roleLabel: TextLabel
local lineLabel: TextLabel
local options: Frame
local npcId: string? = nil
local typing = 0

local function close()
	frame.Visible = false
	npcId = nil
end

-- Typewriter reveal (skippable by clicking the panel).
local function typeLine(text: string)
	typing += 1
	local token = typing
	lineLabel.Text = text
	lineLabel.MaxVisibleGraphemes = 0
	task.spawn(function()
		local n = utf8.len(text) or #text
		for i = 1, n, 2 do
			if typing ~= token then
				return
			end
			lineLabel.MaxVisibleGraphemes = i
			task.wait(0.015)
		end
		lineLabel.MaxVisibleGraphemes = -1
	end)
end

local function option(text: string, style: string, order: number, onClick: () -> ())
	Button.new({
		Text = text,
		Style = style,
		Size = UDim2.new(0, 0, 0, 36),
		TextSize = Theme.TextSize.Small,
		LayoutOrder = order,
		Parent = options,
		OnClick = onClick,
	}).Instance.AutomaticSize = Enum.AutomaticSize.X
end

local function show(p: { [string]: any })
	npcId = p.Npc
	nameLabel.Text = tostring(p.Name)
	roleLabel.Text = tostring(p.Role or "")
	typeLine(tostring(p.Line or "..."))
	for _, child in options:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local order = 0
	if type(p.Quests) == "table" then
		for _, entry in p.Quests do
			local questId = if type(entry) == "table" then entry.Id else nil
			local def = if type(questId) == "string" then QuestConfig.get(questId) else nil
			if def and entry.State == "Available" then
				order += 1
				local quest = def
				option("❗ " .. quest.Name, "Gold", order, function()
					local result = Net.request("DialogueChoice", { Npc = npcId, Quest = quest.Id })
					if result.ok then
						Bus.toast("Quest accepted: " .. quest.Name, "Quest")
						close()
					else
						Bus.toast(result.err or "Can't take that quest yet", "Warning")
					end
				end)
			elseif def and entry.State == "Locked" and type(entry.Reason) == "string" then
				order += 1
				option("🔒 " .. def.Name, "Ghost", order, function()
					Bus.toast(entry.Reason, "Info")
				end)
			end
		end
	end
	if type(p.Menu) == "string" and p.Menu ~= "" then
		order += 1
		local menu = p.Menu
		option("Open " .. menu, "Primary", order, function()
			close()
			UIManager:Open(menu)
		end)
	end
	order += 1
	option("Goodbye", "Ghost", order, close)
	frame.Visible = true
end

function DialogueBox.mount()
	frame = Create("TextButton", {
		Name = "Dialogue",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(640, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = UIManager.Overlay,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.stroke(Theme.Colors.Accent, 0.4, 2),
			Create.padding(14, 18),
			Create.list(Enum.FillDirection.Vertical, 6),
		},
	}) :: any
	nameLabel = Create.label("", Theme.TextSize.Heading, Theme.Colors.Accent, Theme.Fonts.Display, { LayoutOrder = 1, Parent = frame })
	roleLabel = Create.label("", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, { LayoutOrder = 2, Parent = frame })
	lineLabel = Create.label("", Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Body, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = frame,
	})
	options = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = frame,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8), Create("UIPadding", { PaddingTop = UDim.new(0, 6) }) },
	})
	;(frame :: any).Activated:Connect(function()
		typing += 1
		lineLabel.MaxVisibleGraphemes = -1
	end)
	Bus.Dialogue:Connect(show)
	UIManager.MenuOpened:Connect(close)
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if not npcId or now - last < 0.5 then
			return
		end
		last = now
		local root = MovementController:GetRoot()
		local position = WorldIndex.get("NPC", npcId :: string)
		if root and position and (root.Position - position).Magnitude > MovementController:GetHeight() * 8 + 60 then
			close()
		end
	end)
end

return DialogueBox
