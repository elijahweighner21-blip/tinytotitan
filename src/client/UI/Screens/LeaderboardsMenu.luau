--!strict
--[[
	LeaderboardsMenu
	Global boards (cached on the server; refreshed every few minutes). The
	board picker lists lifetime boards first, then every challenge board.
	Your own row is highlighted when you are on the page.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Client = UI.Parent
local Net = require(Client.Net)
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Scroll = require(UI.Components.Scroll)
local Bus = require(UI.Bus)

local LeaderboardsMenu = {}

local player = Players.LocalPlayer
local picker: ScrollingFrame
local rows: ScrollingFrame
local board = "TotalMass"
local loading = false

local function valueText(boardId: string, ascending: boolean, value: number): string
	if string.sub(boardId, 1, 10) == "Challenge_" then
		if ascending then
			return Format.raceTime(value / 1000)
		end
		return Format.abbreviate(value / 100, 2)
	end
	return Format.abbreviate(value)
end

local function render(menu: MenuBase.Menu, _tab: string)
	if loading then
		return
	end
	loading = true
	local result = Net.request("GetLeaderboard", { Board = board })
	loading = false
	Scroll.clear(rows)
	if not result.ok then
		Create.label(tostring(result.err or "Leaderboards are unavailable right now."), Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, { Size = UDim2.new(1, 0, 0, 40), Parent = rows })
		return
	end
	menu.Window:SetSubtitle(tostring(result.Name or board))
	-- Board picker.
	Scroll.clear(picker)
	local boards = if type(result.Boards) == "table" then result.Boards else {}
	table.sort(boards, function(a, b)
		local ca = string.sub(a.Id, 1, 10) == "Challenge_"
		local cb = string.sub(b.Id, 1, 10) == "Challenge_"
		if ca ~= cb then
			return not ca
		end
		return a.Name < b.Name
	end)
	for i, entry in boards do
		local selected = entry.Id == board
		local button = Create("TextButton", {
			Text = entry.Name,
			TextSize = Theme.TextSize.Small,
			FontFace = Theme.Fonts.Title,
			TextColor3 = if selected then Color3.fromRGB(10, 20, 30) else Theme.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			BackgroundColor3 = if selected then Theme.Colors.Accent else Theme.Colors.PanelLight,
			Size = UDim2.new(1, -8, 0, 30),
			LayoutOrder = i,
			Parent = picker,
			[Create.Children] = { Create.corner(Theme.RadiusSmall), Create.padding(4, 10) },
		}) :: TextButton
		button.Activated:Connect(function()
			board = entry.Id
			menu:Refresh()
		end)
	end
	local list = if type(result.Rows) == "table" then result.Rows else {}
	if #list == 0 then
		Create.label("No entries yet — be the first!", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, { Size = UDim2.new(1, 0, 0, 40), Parent = rows })
	end
	for i, row in list do
		local me = row.UserId == player.UserId
		local medal = if row.Rank == 1 then "🥇" elseif row.Rank == 2 then "🥈" elseif row.Rank == 3 then "🥉" else "#" .. tostring(row.Rank)
		local frame = Create("Frame", {
			BackgroundColor3 = if me then Theme.Colors.Accent:Lerp(Theme.Colors.PanelLight, 0.7) else Theme.Colors.PanelLight,
			Size = UDim2.new(1, -8, 0, 36),
			LayoutOrder = i,
			Parent = rows,
			[Create.Children] = { Create.corner(Theme.RadiusSmall), Create.padding(4, 12) },
		})
		Create.label(medal, Theme.TextSize.Body, Theme.Colors.Gold, Theme.Fonts.Display, { Size = UDim2.new(0, 50, 1, 0), Parent = frame })
		Create.label(tostring(row.Name), Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Title, { Position = UDim2.fromOffset(56, 0), Size = UDim2.new(0.6, -56, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
		Create.label(valueText(board, result.Ascending == true, tonumber(row.Value) or 0), Theme.TextSize.Body, Theme.Colors.Accent, Theme.Fonts.Mono, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.4, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		})
	end
end

function LeaderboardsMenu.mount()
	local menu = MenuBase.new({
		Name = "Leaderboards",
		Title = "Leaderboards",
		Icon = "📊",
		Accent = Theme.Colors.Gold,
		Render = render,
	})
	picker = Scroll.list(menu.Content, { Size = UDim2.new(0.3, 0, 1, 0), Gap = 4, Name = "Boards" })
	rows = Scroll.list(menu.Content, { Size = UDim2.new(0.68, 0, 1, 0), Position = UDim2.fromScale(0.32, 0), Gap = 4, Name = "Rows" })
	Bus.OpenMenu:Connect(function(name, context)
		if name == "Leaderboards" and type(context) == "table" and type(context.Board) == "string" then
			board = context.Board
		end
	end)
end

return LeaderboardsMenu
