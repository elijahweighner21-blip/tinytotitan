--!strict
--[[
	OverheadController
	Name tags above other players: display name (in their equipped name
	color), equipped title (if "Show Titles" is on) and size tier. The tag
	floats above the head at any scale and fades with distance relative to
	that player's size, so a titan's name is readable from far away while an
	ant's isn't cluttering the screen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SizeConfig = require(Shared.Config.SizeConfig)
local TitleConfig = require(Shared.Config.TitleConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Trove = require(Shared.Util.Trove)

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local SettingsController = require(script.Parent.SettingsController)
local CosmeticsController = require(script.Parent.CosmeticsController)

local OverheadController = {}

local localPlayer = Players.LocalPlayer
local troves: { [Player]: Trove.Trove } = {}
local refreshers: { [Player]: () -> () } = {}

local function build(player: Player, character: Model)
	local old = troves[player]
	if old then
		old:Destroy()
	end
	local trove = Trove.new()
	troves[player] = trove
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not humanoid or not head or not character.Parent then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local gui = trove:Add(Create("BillboardGui", {
		Name = "TT_Overhead",
		Adornee = head,
		AlwaysOnTop = false,
		LightInfluence = 0,
		Size = UDim2.fromOffset(220, 64),
		ResetOnSpawn = false,
		Parent = localPlayer:WaitForChild("PlayerGui"),
		[Create.Children] = {
			Create.list(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
		},
	})) :: BillboardGui
	local title = Create.label("", Theme.TextSize.Small, Theme.Colors.Gold, Theme.Fonts.Title, {
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		LayoutOrder = 1,
		Parent = gui,
	})
	local name = Create.label(player.DisplayName, Theme.TextSize.Heading, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		LayoutOrder = 2,
		Parent = gui,
	})
	local tier = Create.label("", Theme.TextSize.Tiny, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		LayoutOrder = 3,
		Parent = gui,
	})

	local function refresh()
		local scale = (player:GetAttribute("Scale") :: number?) or 1
		local h = ScaleMath.height(scale)
		gui.StudsOffsetWorldSpace = Vector3.new(0, h * 0.18 + 0.5, 0)
		gui.MaxDistance = math.max(120, h * 60)
		local tierIndex = (player:GetAttribute("Tier") :: number?) or 1
		local level = (player:GetAttribute("Level") :: number?) or 1
		local tierDef = SizeConfig.getTier(tierIndex)
		tier.Text = string.format("%s · Lv %d", tierDef.Name, level)
		tier.TextColor3 = tierDef.Color
		local titleId = player:GetAttribute("Title")
		local titleDef = if type(titleId) == "string" and titleId ~= "" then TitleConfig.get(titleId) else nil
		title.Visible = titleDef ~= nil and SettingsController:Get("ShowTitles") ~= false
		if titleDef then
			title.Text = "« " .. titleDef.Text .. " »"
			title.TextColor3 = titleDef.Color
		end
		local nameColor = CosmeticsController:GetEquipped(player, "NameColor")
		name.TextColor3 = if nameColor then nameColor.Colors[1] else Theme.Colors.Text
	end
	refreshers[player] = refresh
	refresh()
	for _, attribute in { "Scale", "Tier", "Level", "Title", "Cosmetics" } do
		trove:Connect(player:GetAttributeChangedSignal(attribute), refresh)
	end
	trove:Connect(character.AncestryChanged, function()
		if not character.Parent then
			trove:Destroy()
		end
	end)
end

local function watch(player: Player)
	if player == localPlayer then
		return
	end
	if player.Character then
		task.spawn(build, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		build(player, character)
	end)
end

function OverheadController:Init()
	SettingsController.Changed:Connect(function(key)
		if key == "ShowTitles" then
			for _, refresh in refreshers do
				refresh()
			end
		end
	end)
end

function OverheadController:Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local trove = troves[player]
		if trove then
			trove:Destroy()
		end
		troves[player] = nil
		refreshers[player] = nil
	end)
end

return OverheadController
