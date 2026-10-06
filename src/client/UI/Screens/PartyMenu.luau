--!strict
--[[
	PartyMenu
	Up to four players can team up. Party members near each other get a
	small shared reward bonus (RewardConfig.PartyPerMember) and Titan Roar
	buffs allies. Invites expire; anyone can leave at any time; the leader
	can remove members.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SizeConfig = require(Shared.Config.SizeConfig)

local UI = script.Parent.Parent
local Client = UI.Parent
local Net = require(Client.Net)
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local Scroll = require(UI.Components.Scroll)
local Common = require(script.Parent.Common)

local PartyMenu = {}

local player = Players.LocalPlayer
local list: ScrollingFrame
local members: { { UserId: number, Name: string, Leader: boolean? } } = {}
local invite: { UserId: number, Name: string, At: number }? = nil
local menuRef: MenuBase.Menu

local INVITE_SHOWN_FOR = 60

local function row(order: number, text: string, sub: string?): Frame
	local frame = Create("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 48),
		LayoutOrder = order,
		Parent = list,
		[Create.Children] = { Create.corner(Theme.RadiusSmall), Create.padding(6, 12) },
	})
	Create.label(
		text,
		Theme.TextSize.Body,
		Theme.Colors.Text,
		Theme.Fonts.Title,
		{ Size = UDim2.new(0.6, 0, 0, 20), Parent = frame }
	)
	if sub then
		Create.label(
			sub,
			Theme.TextSize.Tiny,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(0.6, 0, 0, 16), Parent = frame }
		)
	end
	Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		Parent = frame,
		[Create.Children] = {
			Create.list(
				Enum.FillDirection.Horizontal,
				6,
				Enum.HorizontalAlignment.Right,
				Enum.VerticalAlignment.Center
			),
		},
	})
	return frame
end

local function small(parent: Instance, text: string, style: string, onClick: () -> ())
	Button.new({
		Text = text,
		Style = style,
		Size = UDim2.fromOffset(96, 32),
		TextSize = Theme.TextSize.Small,
		Parent = parent,
		OnClick = onClick,
	})
end

local function describe(p: Player): string
	local tier = (p:GetAttribute("Tier") :: number?) or 1
	local level = (p:GetAttribute("Level") :: number?) or 1
	return string.format("%s · Level %d", SizeConfig.getTier(tier).Name, level)
end

local function render(menu: MenuBase.Menu, _tab: string)
	Scroll.clear(list)
	local order = 0
	local inv = invite
	if inv and os.clock() - inv.At < INVITE_SHOWN_FOR then
		order += 1
		local frame = row(order, "📨 " .. inv.Name .. " invited you!", "Join their party?")
		local buttons = frame:FindFirstChild("Buttons") :: Frame
		small(buttons, "Accept", "Success", function()
			invite = nil
			Common.request("Party", { Op = "Accept" }, "Joined the party!")
			menuRef:Refresh()
		end)
		small(buttons, "Decline", "Ghost", function()
			invite = nil
			Net.request("Party", { Op = "Decline" })
			menuRef:Refresh()
		end)
	end
	order += 1
	Create.label(
		if #members > 0 then string.format("YOUR PARTY (%d/4)", #members) else "You're not in a party",
		Theme.TextSize.Heading,
		Theme.Colors.Accent,
		Theme.Fonts.Display,
		{
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = order,
			Parent = list,
		}
	)
	local inParty: { [number]: boolean } = {}
	local amLeader = false
	for _, m in members do
		inParty[m.UserId] = true
		if m.UserId == player.UserId and m.Leader then
			amLeader = true
		end
	end
	for _, m in members do
		order += 1
		local other = Players:GetPlayerByUserId(m.UserId)
		local frame = row(
			order,
			(if m.Leader then "👑 " else "") .. m.Name .. (if m.UserId == player.UserId then " (you)" else ""),
			if other then describe(other) else nil
		)
		local buttons = frame:FindFirstChild("Buttons") :: Frame
		if m.UserId == player.UserId then
			small(buttons, "Leave", "Danger", function()
				Common.request("Party", { Op = "Leave" })
			end)
		elseif amLeader then
			small(buttons, "Remove", "Ghost", function()
				Common.request("Party", { Op = "Kick", Target = m.UserId })
			end)
		end
	end
	order += 1
	Create.label("PLAYERS IN THIS SERVER", Theme.TextSize.Heading, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = order,
		Parent = list,
	})
	local any = false
	for _, other in Players:GetPlayers() do
		if other ~= player and not inParty[other.UserId] then
			any = true
			order += 1
			local frame = row(order, other.DisplayName, describe(other))
			small(frame:FindFirstChild("Buttons") :: Frame, "Invite", "Primary", function()
				Common.request(
					"Party",
					{ Op = "Invite", Target = other.UserId },
					"Invite sent to " .. other.DisplayName
				)
			end)
		end
	end
	if not any then
		order += 1
		Create.label(
			"Nobody else is here yet.",
			Theme.TextSize.Small,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order, Parent = list }
		)
	end
	menu.Window:SetSubtitle("Party members nearby share a bonus on rewards")
end

function PartyMenu.mount()
	menuRef = MenuBase.new({
		Name = "Party",
		Title = "Party",
		Icon = "👥",
		Accent = Theme.Colors.Accent,
		Render = render,
	})
	list = Scroll.list(menuRef.Content, { Gap = 6 })
	Net.onSignal("Party", function(p)
		if type(p) ~= "table" then
			return
		end
		if type(p.Invite) == "table" then
			invite = { UserId = tonumber(p.Invite.UserId) or 0, Name = tostring(p.Invite.Name), At = os.clock() }
		end
		if type(p.Members) == "table" then
			members = p.Members
		end
		menuRef:Refresh()
	end)
	Players.PlayerAdded:Connect(function()
		menuRef:Refresh()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			menuRef:Refresh()
		end)
	end)
end

return PartyMenu
