--!strict
--[[
	WorldMarkerController
	Guides the player without a minimap clutter:

	  * a beacon over the tracked quest's current objective (resolved from
	    the objective's Marker, or its Target for talk/discover/boss/challenge
	    objectives) with distance in world feet
	  * an arrow at the screen edge when the target is off-screen
	  * temporary markers for world events (meteor sites, supply drops)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local GameConfig = require(Shared.Config.GameConfig)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local WorldIndex = require(Client.WorldIndex)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local DataController = require(script.Parent.DataController)
local MovementController = require(script.Parent.MovementController)

local WorldMarkerController = {}

type Marker = {
	Id: string,
	Position: Vector3,
	Label: string,
	Color: Color3,
	Icon: string,
	Expires: number?,
	Anchor: Part,
	Gui: BillboardGui,
	Distance: TextLabel,
	Arrow: Frame,
}

local markers: { [string]: Marker } = {}
local folder: Folder
local arrowLayer: Frame

local STUDS_PER_FOOT = GameConfig.StudsPerFoot

local function formatDistance(studs: number): string
	local feet = studs / STUDS_PER_FOOT
	if feet >= 5280 then
		return string.format("%.1f mi", feet / 5280)
	elseif feet >= 100 then
		return string.format("%d ft", math.floor(feet / 10 + 0.5) * 10)
	end
	return string.format("%d ft", math.floor(feet + 0.5))
end

local function remove(id: string)
	local m = markers[id]
	if m then
		m.Anchor:Destroy()
		m.Arrow:Destroy()
		markers[id] = nil
	end
end

local function place(id: string, position: Vector3, label: string, color: Color3, icon: string, expires: number?)
	local existing = markers[id]
	if existing and existing.Position == position and existing.Label == label then
		existing.Expires = expires
		return
	end
	remove(id)
	local anchor = Create("Part", {
		Name = "Marker_" .. id,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		Position = position,
		Parent = folder,
	})
	local gui = Create("BillboardGui", {
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(160, 70),
		Adornee = anchor,
		MaxDistance = math.huge,
		Parent = anchor,
		[Create.Children] = { Create.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center) },
	})
	local bubble = Create("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(34, 34),
		LayoutOrder = 1,
		Parent = gui,
		[Create.Children] = { Create.corner(Theme.RadiusPill), Create.stroke(Color3.new(1, 1, 1), 0.1, 2) },
	})
	Create.label(icon, 18, Color3.new(1, 1, 1), Theme.Fonts.Display, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = bubble,
	})
	Create.label(label, Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Title, {
		Size = UDim2.new(1, 0, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		Parent = gui,
	})
	local distance = Create.label("", Theme.TextSize.Tiny, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Size = UDim2.new(1, 0, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		LayoutOrder = 3,
		Parent = gui,
	})
	local arrow = Create("Frame", {
		Name = "Arrow_" .. id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(30, 30),
		Visible = false,
		Parent = arrowLayer,
		[Create.Children] = {
			Create.corner(Theme.RadiusPill),
			Create.stroke(Color3.new(1, 1, 1), 0.1, 2),
			Create.label("➤", 18, Color3.new(1, 1, 1), Theme.Fonts.Display, {
				Name = "Glyph",
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},
	})
	markers[id] = {
		Id = id,
		Position = position,
		Label = label,
		Color = color,
		Icon = icon,
		Expires = expires,
		Anchor = anchor,
		Gui = gui,
		Distance = distance,
		Arrow = arrow,
	}
end

-- Where the tracked quest wants the player to go next.
local function questTarget(): (Vector3?, string?)
	local data = DataController:Get()
	if not data then
		return nil, nil
	end
	local questId = data.Quests.Tracked
	local active = questId ~= "" and data.Quests.Active[questId]
	local def = if active then QuestConfig.get(questId) else nil
	if not def or not active then
		return nil, nil
	end
	for i, objective in def.Objectives do
		if (active.Progress[i] or 0) < objective.Count then
			local position: Vector3? = nil
			if objective.Marker then
				position = WorldIndex.find(objective.Marker)
			end
			if not position and objective.Target then
				local kind = if objective.Type == "TalkTo"
					then "NPC"
					elseif objective.Type == "Discover" then "Discovery"
					elseif objective.Type == "DefeatBoss" then "Boss"
					elseif objective.Type == "CompleteChallenge" then "Challenge"
					else nil
				if kind then
					position = WorldIndex.get(kind, objective.Target)
				end
			end
			if position then
				return position, objective.Text
			end
			return nil, nil
		end
	end
	-- All objectives done but not yet turned in: point at the giver.
	if def.Giver then
		return WorldIndex.get("NPC", def.Giver), "Return to " .. def.Giver
	end
	return nil, nil
end

local function refreshQuest()
	local position, text = questTarget()
	if position and text then
		place("Quest", position, text, Theme.Colors.Gold, "!")
	else
		remove("Quest")
	end
end

local function update()
	local camera = workspace.CurrentCamera
	local root = MovementController:GetRoot()
	if not camera or not root then
		return
	end
	local now = os.clock()
	local viewport = camera.ViewportSize
	local hideArrows = UIManager:IsMenuOpen()
	for id, m in markers do
		if m.Expires and now > m.Expires then
			remove(id)
			continue
		end
		local dist = (m.Position - root.Position).Magnitude
		m.Distance.Text = formatDistance(dist)
		-- Hide the beacon once the player is basically there.
		local near = dist < MovementController:GetHeight() * 2
		m.Gui.Enabled = not near
		local screen, onScreen = camera:WorldToViewportPoint(m.Position)
		if onScreen or near or hideArrows then
			m.Arrow.Visible = false
		else
			-- Project to the screen edge; flip when behind the camera.
			local center = viewport / 2
			local dir = Vector2.new(screen.X, screen.Y) - center
			if screen.Z < 0 then
				dir = -dir
			end
			if dir.Magnitude < 1 then
				dir = Vector2.new(0, -1)
			end
			local margin = 40
			local half = center - Vector2.new(margin, margin)
			local scale = math.min(math.abs(half.X / dir.X), math.abs(half.Y / dir.Y))
			local pos = center + dir * scale
			m.Arrow.Position = UDim2.fromOffset(pos.X, pos.Y)
			m.Arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
			m.Arrow.Visible = true
		end
	end
end

-- A player-chosen waypoint (e.g. "show me this challenge pad"). Replaces the
-- previous waypoint; disappears after a few minutes or on arrival.
function WorldMarkerController:SetWaypoint(position: Vector3, label: string)
	place("Waypoint", position, label, Theme.Colors.Accent, "➜", os.clock() + 300)
end

function WorldMarkerController:ClearWaypoint()
	remove("Waypoint")
end

function WorldMarkerController:Init()
	folder = Instance.new("Folder")
	folder.Name = "TT_Markers"
	folder.Parent = workspace
	arrowLayer = Create("Frame", {
		Name = "MarkerArrows",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = UIManager.Overlay,
	})
	DataController.Changed:Connect(function(key)
		if key == "Quests" then
			refreshQuest()
		end
	end)
	DataController.Loaded:Connect(refreshQuest)
	Net.onSignal("WorldEvent", function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.State == "Marker" and typeof(payload.Position) == "Vector3" then
			place("Event_" .. tostring(payload.Id), payload.Position, "World Event", Theme.Colors.Warning, "★", os.clock() + 120)
		elseif payload.State == "End" then
			remove("Event_" .. tostring(payload.Id))
		elseif payload.State == "Picked" then
			remove("Event_" .. tostring(payload.Id))
		end
	end)
end

function WorldMarkerController:Start()
	task.spawn(function()
		if WorldIndex.wait(60) then
			refreshQuest()
		end
	end)
	local last = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - last >= 0.05 then
			last = now
			update()
		end
	end)
end

return WorldMarkerController
