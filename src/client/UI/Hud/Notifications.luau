--!strict
--[[
	Notifications
	Everything that pops up, in three lanes so nothing piles on top of
	anything else:

	  toasts        right side, max 4, short one-liners (info/warnings,
	                quest started, purchases). Duplicates within a second are
	                merged instead of stacked.
	  reward feed   just above the size bar: "+12 Mass  +6 ⚡". Rapid rewards
	                (orb chains) merge into one growing line.
	  cards         centre-top, one at a time: discoveries (with lore),
	                achievements, quest complete, level ups, world events.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local Net = require(Client.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local Bus = require(Client.UI.Bus)
local AudioController = require(Client.Controllers.AudioController)
local Hud = require(script.Parent.Hud)

local Notifications = {}

local KIND_COLORS: { [string]: Color3 } = {
	Info = Theme.Colors.Accent,
	Success = Theme.Colors.Success,
	Warning = Theme.Colors.Warning,
	Error = Theme.Colors.Danger,
	Level = Theme.Colors.XP,
	Ascension = Theme.Colors.Gold,
	Quest = Theme.Colors.Gold,
	Purchase = Theme.Colors.Robux,
}

local toastLane: Frame
local rewardLabel: TextLabel
local cardFrame: Frame
local cardTitle: TextLabel
local cardHeading: TextLabel
local cardBody: TextLabel
local cardIcon: TextLabel
local cardStroke: UIStroke

local recent: { [string]: { Frame: Frame, Count: number, Label: TextLabel, Text: string } } = {}
local cardQueue: { { Icon: string, Heading: string, Title: string, Body: string, Color: Color3, Sound: string? } } = {}
local cardShowing = false

local rewardTotals: { [string]: number } = {}
local rewardToken = 0

------------------------------------------------------------------ toasts

function Notifications.toast(text: string, kind: string?)
	local k = kind or "Info"
	local existing = recent[text]
	if existing and existing.Frame.Parent then
		existing.Count += 1
		existing.Label.Text = string.format("%s  ×%d", text, existing.Count)
		return
	end
	local color = KIND_COLORS[k] or Theme.Colors.Accent
	local frame = Create("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastLane,
		[Create.Children] = {
			Create.corner(Theme.RadiusSmall),
			Create.stroke(color, 0.4, 1.5),
			Create.padding(8, 12),
			Create("Frame", {
				BackgroundColor3 = color,
				Size = UDim2.new(0, 4, 1, 0),
				Position = UDim2.fromOffset(-8, 0),
				[Create.Children] = { Create.corner(Theme.RadiusPill) },
			}),
		},
	})
	local label = Create.label(text, Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Title, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})
	recent[text] = { Frame = frame, Count = 1, Label = label, Text = text }
	-- Keep at most 4 toasts.
	local toasts = {}
	for _, child in toastLane:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	if k == "Warning" or k == "Error" then
		AudioController:Play("Error")
	else
		AudioController:Play("Notify")
	end
	task.delay(if k == "Warning" or k == "Error" then 4.5 else 3.5, function()
		if recent[text] and recent[text].Frame == frame then
			recent[text] = nil
		end
		if frame.Parent then
			local t = TweenService:Create(frame, Theme.Tween.Normal, { BackgroundTransparency = 1 })
			TweenService:Create(label, Theme.Tween.Normal, { TextTransparency = 1 }):Play()
			t:Play()
			t.Completed:Once(function()
				frame:Destroy()
			end)
		end
	end)
end

------------------------------------------------------------------ reward feed

local REWARD_ORDER = {
	{ Key = "Mass", Icon = "", Suffix = " Mass", Color = Theme.Colors.Mass },
	{ Key = "GrowthEnergy", Icon = "⚡", Suffix = "", Color = Theme.Colors.Energy },
	{ Key = "TitanShards", Icon = "🔷", Suffix = "", Color = Theme.Colors.Shards },
	{ Key = "XP", Icon = "", Suffix = " XP", Color = Theme.Colors.XP },
	{ Key = "SkillPoints", Icon = "✦", Suffix = " SP", Color = Theme.Colors.Gold },
}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

function Notifications.reward(amounts: { [string]: any })
	local any = false
	for _, entry in REWARD_ORDER do
		local n = tonumber(amounts[entry.Key])
		if n and n > 0 then
			rewardTotals[entry.Key] = (rewardTotals[entry.Key] or 0) + n
			any = true
		end
	end
	if not any then
		return
	end
	local parts = {}
	for _, entry in REWARD_ORDER do
		local n = rewardTotals[entry.Key]
		if n and n > 0 then
			table.insert(
				parts,
				string.format(
					'<font color="%s">+%s%s%s</font>',
					hex(entry.Color),
					entry.Icon,
					Format.abbreviate(n),
					entry.Suffix
				)
			)
		end
	end
	rewardLabel.Text = table.concat(parts, "   ")
	rewardLabel.TextTransparency = 0
	rewardLabel.TextStrokeTransparency = 0.4
	rewardLabel.Visible = true
	rewardToken += 1
	local token = rewardToken
	task.delay(1.6, function()
		if token ~= rewardToken then
			return
		end
		table.clear(rewardTotals)
		local t =
			TweenService:Create(rewardLabel, Theme.Tween.Slow, { TextTransparency = 1, TextStrokeTransparency = 1 })
		t:Play()
	end)
end

------------------------------------------------------------------ cards

local function showNextCard()
	if cardShowing then
		return
	end
	local card = table.remove(cardQueue, 1)
	if not card then
		return
	end
	cardShowing = true
	cardIcon.Text = card.Icon
	cardHeading.Text = card.Heading
	cardHeading.TextColor3 = card.Color
	cardTitle.Text = card.Title
	cardBody.Text = card.Body
	cardBody.Visible = card.Body ~= ""
	cardStroke.Color = card.Color
	cardFrame.Visible = true
	cardFrame.Position = UDim2.new(0.5, 0, 0, -140)
	-- Over an open menu, stop at the top edge instead of covering its title.
	local restY = if UIManager:IsMenuOpen() then 8 else 110
	TweenService:Create(cardFrame, Theme.Tween.Bounce, { Position = UDim2.new(0.5, 0, 0, restY) }):Play()
	if card.Sound then
		AudioController:Play(card.Sound)
	end
	local duration = 3.2 + math.min(#card.Body / 60, 3)
	task.delay(duration, function()
		local t = TweenService:Create(cardFrame, Theme.Tween.Normal, { Position = UDim2.new(0.5, 0, 0, -140) })
		t:Play()
		t.Completed:Once(function()
			cardFrame.Visible = false
			cardShowing = false
			showNextCard()
		end)
	end)
end

function Notifications.card(icon: string, heading: string, title: string, body: string?, color: Color3?, sound: string?)
	-- Cards wait while a menu is open would hide them; they still queue.
	table.insert(cardQueue, {
		Icon = icon,
		Heading = heading,
		Title = title,
		Body = body or "",
		Color = color or Theme.Colors.Accent,
		Sound = sound,
	})
	if #cardQueue > 6 then
		table.remove(cardQueue, 1)
	end
	showNextCard()
end

local function rewardLine(p: { [string]: any }): string
	local parts = {}
	for _, entry in REWARD_ORDER do
		local n = tonumber(p[entry.Key])
		if n and n > 0 then
			table.insert(parts, "+" .. entry.Icon .. Format.abbreviate(n) .. entry.Suffix)
		end
	end
	return table.concat(parts, "  ")
end

------------------------------------------------------------------ build + wiring

local function build()
	local root = UIManager.Overlay
	toastLane = Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 150),
		Size = UDim2.fromOffset(320, 400),
		Parent = root,
		[Create.Children] = {
			Create.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right),
			Create("UIPadding", { PaddingTop = UDim.new(0, 0) }),
		},
	})
	rewardLabel = Create.label("", Theme.TextSize.Heading, Theme.Colors.Text, Theme.Fonts.Display, {
		Name = "RewardFeed",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(600, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = true,
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = root,
	})
	cardFrame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -140),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
		[Create.Children] = { Create.corner(Theme.Radius), Create.padding(14, 18) },
	})
	cardStroke = Create.stroke(Theme.Colors.Accent, 0.2, 2)
	cardStroke.Parent = cardFrame
	cardIcon = Create.label("", 34, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.fromOffset(48, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = cardFrame,
	})
	local text = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(1, -60, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = cardFrame,
		[Create.Children] = { Create.list(Enum.FillDirection.Vertical, 2) },
	})
	cardHeading = Create.label(
		"",
		Theme.TextSize.Small,
		Theme.Colors.Accent,
		Theme.Fonts.Title,
		{ LayoutOrder = 1, Parent = text }
	)
	cardTitle = Create.label(
		"",
		Theme.TextSize.Title,
		Theme.Colors.Text,
		Theme.Fonts.Display,
		{ LayoutOrder = 2, Parent = text }
	)
	cardBody = Create.label("", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = text,
	})
end

function Notifications.mount()
	build()
	Bus.Toast:Connect(Notifications.toast)
	Net.onSignal("Notify", function(p)
		if type(p) ~= "table" or p.Kind == "Collect" then
			return
		end
		if type(p.Text) == "string" then
			if p.Kind == "Level" or p.Kind == "Ascension" then
				Notifications.card(
					if p.Kind == "Level" then "⭐" else "∞",
					string.upper(p.Kind),
					p.Text,
					nil,
					KIND_COLORS[p.Kind],
					"LevelUp"
				)
			else
				Notifications.toast(p.Text, p.Kind)
			end
		end
	end)
	Net.onSignal("Reward", function(p)
		if type(p) == "table" then
			Notifications.reward(p)
		end
	end)
	Net.onSignal("Discovery", function(p)
		if type(p) ~= "table" then
			return
		end
		local body = rewardLine(p)
		if type(p.Lore) == "string" and p.Lore ~= "" then
			body = p.Lore .. "\n" .. body
		end
		Notifications.card(
			if p.Hidden then "✨" else "📍",
			if p.Hidden then "SECRET DISCOVERED" else "DISCOVERED",
			tostring(p.Name),
			body,
			if p.Hidden then Theme.Colors.Gold else Theme.Colors.Accent,
			"Discovery"
		)
	end)
	Net.onSignal("Achievement", function(p)
		if type(p) == "table" then
			Notifications.card(
				"🏆",
				"ACHIEVEMENT UNLOCKED",
				tostring(p.Name),
				tostring(p.Description or ""),
				Theme.Colors.Gold,
				"Achievement"
			)
		end
	end)
	Net.onSignal("QuestUpdate", function(p)
		if type(p) == "table" and p.Started then
			Notifications.toast("New quest: " .. tostring(p.Name), "Quest")
		end
	end)
	Net.onSignal("QuestComplete", function(p)
		if type(p) == "table" then
			local body = rewardLine(p)
			if type(p.Story) == "string" and p.Story ~= "" then
				body = p.Story .. "\n" .. body
			end
			Notifications.card("✔", "QUEST COMPLETE", tostring(p.Name), body, Theme.Colors.Success, "Achievement")
		end
	end)
	Net.onSignal("LevelUp", function(p)
		if type(p) == "table" then
			Hud.levelUp()
			local points = tonumber(p.SkillPoints) or 0
			Notifications.card(
				"⭐",
				"LEVEL UP",
				"Level " .. tostring(p.Level),
				if points > 0
					then string.format(
						"+%d Skill Point%s — spend them in the Skill Tree (K)",
						points,
						if points == 1 then "" else "s"
					)
					else "",
				Theme.Colors.XP,
				"LevelUp"
			)
		end
	end)
	Net.onSignal("WorldEvent", function(p)
		if type(p) ~= "table" then
			return
		end
		if p.State == "Start" then
			local color = if typeof(p.Color) == "Color3" then p.Color else Theme.Colors.Warning
			Notifications.card(
				tostring(p.Icon or "🌐"),
				"WORLD EVENT",
				tostring(p.Name),
				tostring(p.Description or ""),
				color,
				"EventHorn"
			)
		elseif p.State == "End" then
			Notifications.toast(tostring(p.Name) .. " has ended", "Info")
		end
	end)
	Net.onSignal("PurchaseResult", function(p)
		if type(p) ~= "table" then
			return
		end
		if p.Ok then
			Notifications.card(
				"🎉",
				"THANK YOU!",
				tostring(p.Name or "Purchase complete"),
				"Your items have been delivered.",
				Theme.Colors.Robux,
				"Purchase"
			)
		elseif not p.Cancelled then
			Notifications.toast("Purchase failed — you were not charged. Please try again.", "Error")
		end
	end)
	Net.onSignal("Damage", function()
		Hud.hurt()
		AudioController:Play("Hurt")
	end)
	Net.onSignal("Teleported", function()
		AudioController:Play("Teleport")
	end)
	Net.onSignal("Party", function(p)
		if type(p) == "table" and type(p.Invite) == "table" then
			Notifications.toast(tostring(p.Invite.Name) .. " invited you to a party — open Party to accept", "Info")
		end
	end)
end

return Notifications
