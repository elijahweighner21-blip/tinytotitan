--!strict
--[[
	InteractionController
	One context-sensitive Interact button for everything in the world:

	  Interactable       Carry / Push / Break (best verb your strength allows)
	  (while carrying)   Throw (or Drop if too weak to throw)
	  Station            opens the station's menu (Upgrades, Skills, …)
	  FastTravelStation  opens the map on its fast-travel page
	  ChallengeStart     starts the challenge
	  LockedDoor         tries your key items
	  NPC                talks (dialogue reacts to your size)

	The nearest valid target within a size-relative range gets a floating
	prompt with the device's button glyph; on touch the prompt itself is the
	button. All actions are re-validated by the server (reach, strength,
	ownership) — this controller only decides what to show.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InteractableConfig = require(Shared.Config.InteractableConfig)
local ChallengeConfig = require(Shared.Config.ChallengeConfig)
local NPCConfig = require(Shared.Config.NPCConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local Bus = require(Client.UI.Bus)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local DataController = require(script.Parent.DataController)

local InteractionController = {}

type Target = {
	Kind: string,
	Instance: Instance,
	Position: Vector3,
	Size: number,
	Verb: string,
	Label: string,
	Enabled: boolean,
	Run: () -> (),
}

local player = Players.LocalPlayer
local TAGS = { "Interactable", "Station", "FastTravelStation", "ChallengeStart", "LockedDoor", "NPC" }
local tracked: { [string]: { [Instance]: boolean } } = {}
local current: Target? = nil
local carryingId: string? = nil
local billboard: BillboardGui
local promptButton: TextButton
local keyLabel: TextLabel
local keyFrame: Frame
local verbLabel: TextLabel
local nameLabel: TextLabel
local highlight: Highlight
local lastScan = 0
local busyUntil = 0

-- Station "Menu" attributes that map to a differently named menu.
local MENU_ALIAS: { [string]: string } = {
	SkillTree = "Skills",
	Cosmetics = "Inventory",
}

local KEY_GLYPH: { [string]: string } = {
	Keyboard = "E",
	Gamepad = "X",
	Touch = "TAP",
}

local positionCache: { [Instance]: { Position: Vector3, Size: number, At: number } } = {}
setmetatable(positionCache :: any, { __mode = "k" })

local function positionOf(instance: Instance): (Vector3?, number)
	if instance:IsA("BasePart") then
		return instance.Position, instance.Size.Magnitude
	elseif instance:IsA("Model") then
		local ok, cf, size = pcall(function()
			local c, s = instance:GetBoundingBox()
			return c, s
		end)
		if ok then
			return (cf :: CFrame).Position, (size :: Vector3).Magnitude
		end
	end
	return nil, 0
end

local function interactableTarget(part: Instance, position: Vector3, size: number): Target?
	local typeId = part:GetAttribute("ObjectType")
	local id = part:GetAttribute("InteractId")
	local def = if type(typeId) == "string" then InteractableConfig.get(typeId) else nil
	if not def or type(id) ~= "string" or part:GetAttribute("Broken") then
		return nil
	end
	local derived = DataController:GetDerived()
	local verb: string? = nil
	local need = ""
	if def.Carry and derived.CarryStrength >= def.Carry then
		verb = "Carry"
	elseif def.Push and derived.PushStrength >= def.Push then
		verb = "Push"
	elseif def.Break and derived.BreakPower >= def.Break then
		verb = "Break"
	elseif def.Push then
		need = "Push needs " .. Format.abbreviate(def.Push) .. " strength"
	elseif def.Carry then
		need = "Carry needs " .. Format.abbreviate(def.Carry) .. " strength"
	elseif def.Break then
		need = "Break needs " .. Format.abbreviate(def.Break) .. " power"
	end
	local chosen = verb
	return {
		Kind = "Interactable",
		Instance = part,
		Position = position,
		Size = size,
		Verb = chosen or "Too heavy",
		Label = if chosen then def.Name else need,
		Enabled = chosen ~= nil,
		Run = function()
			if chosen then
				Net.action("Interact", { Id = id, Verb = chosen })
			end
		end,
	}
end

local function buildTarget(kind: string, instance: Instance): Target?
	local position, size = positionOf(instance)
	if not position then
		return nil
	end
	if kind == "Interactable" then
		return interactableTarget(instance, position, size)
	elseif kind == "Station" then
		local menu = instance:GetAttribute("Menu")
		local label = instance:GetAttribute("Label")
		if type(menu) ~= "string" then
			return nil
		end
		return {
			Kind = kind :: string,
			Instance = instance,
			Position = position,
			Size = size,
			Verb = "Open",
			Label = if type(label) == "string" then label else menu,
			Enabled = true,
			Run = function()
				if menu == "LeaveLounge" then
					local result = Net.request("VipLounge", { Enter = false })
					if not result.ok then
						Bus.toast(result.err or "Can't leave right now", "Warning")
					end
					return
				end
				UIManager:Open(MENU_ALIAS[menu] or menu)
			end,
		}
	elseif kind == "FastTravelStation" then
		local station = instance:GetAttribute("StationId")
		return {
			Kind = kind :: string,
			Instance = instance,
			Position = position,
			Size = size,
			Verb = "Fast Travel",
			Label = "Travel Station",
			Enabled = true,
			Run = function()
				Bus.OpenMenu:Fire("Map", { Station = station })
				UIManager:Open("Map")
			end,
		}
	elseif kind == "ChallengeStart" then
		local id = instance:GetAttribute("ChallengeId")
		local def = if type(id) == "string" then ChallengeConfig.get(id) else nil
		if not def then
			return nil
		end
		local record = DataController:Get() and DataController:Get().Challenges[def.Id]
		return {
			Kind = kind :: string,
			Instance = instance,
			Position = position,
			Size = size,
			Verb = "Start",
			Label = def.Name
				.. (
					if record and record.Medal and record.Medal > 0 then "  " .. string.rep("★", record.Medal) else ""
				),
			Enabled = true,
			Run = function()
				local result = Net.request("StartChallenge", { Id = def.Id })
				if not result.ok then
					Bus.toast(result.err or "Can't start that right now", "Warning")
				end
			end,
		}
	elseif kind == "LockedDoor" then
		local id = instance:GetAttribute("InteractId")
		local data = DataController:Get()
		if type(id) ~= "string" or (data and data.UnlockedDoors and data.UnlockedDoors[id]) then
			return nil
		end
		return {
			Kind = kind :: string,
			Instance = instance,
			Position = position,
			Size = size,
			Verb = "Unlock",
			Label = (instance:GetAttribute("Message") :: string?) or "Locked",
			Enabled = true,
			Run = function()
				local result = Net.request("UseKey", { Id = id })
				if result.ok then
					Bus.toast("Unlocked!", "Success")
				else
					Bus.toast(result.err or "Locked", "Warning")
				end
			end,
		}
	elseif kind == "NPC" then
		local npcId = instance:GetAttribute("NPCId")
		local def = if type(npcId) == "string" then NPCConfig.get(npcId) else nil
		if not def then
			return nil
		end
		return {
			Kind = kind :: string,
			Instance = instance,
			Position = position,
			Size = size,
			Verb = "Talk",
			Label = def.Name,
			Enabled = true,
			Run = function()
				local result = Net.request("Talk", { Npc = def.Id })
				if result.ok then
					Bus.Dialogue:Fire(result)
				else
					Bus.toast(result.err or "They can't hear you", "Info")
				end
			end,
		}
	end
	return nil
end

-- How far away a target of this kind can be used from.
local function reachFor(kind: string, instance: Instance, size: number, derived: any): number
	local myHeight = derived.Height
	if kind == "Interactable" or kind == "LockedDoor" then
		return derived.InteractRange + size * 0.6
	elseif kind == "NPC" then
		local npcScale = (instance:GetAttribute("Scale") :: number?) or 1
		return math.max(myHeight, ScaleMath.height(npcScale)) * NPCConfig.TalkRangeMultiplier + 6
	else
		return math.max(derived.InteractRange, myHeight * 2) + size * 0.5
	end
end

local function carryTarget(root: BasePart): Target
	return {
		Kind = "Carry",
		Instance = root,
		Position = root.Position,
		Size = 0,
		Verb = "Throw",
		Label = "Hold Crouch + Interact to drop",
		Enabled = true,
		Run = function()
			if InputController:IsHeld("Crouch") then
				Net.action("Interact", { Id = "drop", Verb = "Drop" })
				return
			end
			local camera = workspace.CurrentCamera
			local look = if camera then camera.CFrame.LookVector else root.CFrame.LookVector
			Net.action("ThrowRelease", { Direction = look.Unit })
		end,
	}
end

local function scan(): Target?
	local root = MovementController:GetRoot()
	if not root or not DataController:IsLoaded() then
		return nil
	end
	if carryingId then
		return carryTarget(root)
	end
	local origin = root.Position
	local best: Target? = nil
	local bestScore = math.huge
	local look = root.CFrame.LookVector
	-- Stats once per scan (deriving them is not free), and cached positions
	-- for things that never move (stations, pads, NPCs, doors).
	local derived = DataController:GetDerived()
	local now = os.clock()
	for _, kind in TAGS do
		local static = kind ~= "Interactable"
		for instance in tracked[kind] do
			local position: Vector3?, size: number
			local cached = if static then positionCache[instance] else nil
			if cached and now - cached.At < 5 then
				position, size = cached.Position, cached.Size
			else
				position, size = positionOf(instance)
				if static and position then
					positionCache[instance] = { Position = position :: Vector3, Size = size, At = now }
				end
			end
			if position then
				local offset = position - origin
				local dist = offset.Magnitude
				local reach = reachFor(kind, instance, size, derived)
				if dist <= reach then
					-- Prefer things in front of the player.
					local facingBonus = if dist > 0.01 then 1 - 0.35 * offset.Unit:Dot(look) else 0.65
					local score = dist / reach * facingBonus
					if score < bestScore then
						local t = buildTarget(kind, instance)
						if t then
							best = t
							bestScore = score
						end
					end
				end
			end
		end
	end
	return best
end

local function showPrompt(target: Target?)
	current = target
	if not target or UIManager:IsMenuOpen() then
		billboard.Enabled = false
		highlight.Adornee = nil
		Bus.Prompt:Fire(nil)
		return
	end
	local device = InputController:GetDevice()
	keyLabel.Text = KEY_GLYPH[device] or "E"
	verbLabel.Text = target.Verb
	nameLabel.Text = target.Label
	verbLabel.TextColor3 = if target.Enabled then Theme.Colors.Text else Theme.Colors.Danger
	keyFrame.Visible = target.Enabled
	billboard.Adornee = if target.Instance:IsA("BasePart") or target.Instance:IsA("Model")
		then target.Instance :: any
		else nil
	local h = DataController:GetDerived().Height
	billboard.StudsOffsetWorldSpace = Vector3.new(0, math.max(target.Size * 0.4, h * 0.6), 0)
	billboard.Enabled = true
	highlight.Adornee = if target.Kind == "Interactable" and target.Enabled then target.Instance else nil
	Bus.Prompt:Fire({ Verb = target.Verb, Label = target.Label, Enabled = target.Enabled })
end

function InteractionController:Trigger()
	local target = current
	if not target or not target.Enabled or os.clock() < busyUntil or InputController:IsBlocked() then
		return
	end
	busyUntil = os.clock() + 0.25
	task.spawn(target.Run)
end

function InteractionController:GetTarget(): Target?
	return current
end

function InteractionController:IsCarrying(): boolean
	return carryingId ~= nil
end

local function buildPrompt()
	billboard = Create("BillboardGui", {
		Name = "TT_InteractPrompt",
		AlwaysOnTop = true,
		Active = true,
		Enabled = false,
		LightInfluence = 0,
		Size = UDim2.fromOffset(240, 56),
		MaxDistance = math.huge,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	promptButton = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Parent = billboard,
		[Create.Children] = {
			Create.corner(Theme.RadiusSmall),
			Create.stroke(Theme.Colors.Accent, 0.5),
			Create.padding(6, 8),
		},
	})
	keyFrame = Create("Frame", {
		Name = "Key",
		BackgroundColor3 = Theme.Colors.Accent,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = promptButton,
		[Create.Children] = { Create.corner(Theme.RadiusSmall) },
	})
	keyLabel = Create.label("E", Theme.TextSize.Heading, Color3.fromRGB(10, 20, 30), Theme.Fonts.Display, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = keyFrame,
	})
	verbLabel = Create.label("", Theme.TextSize.Heading, Theme.Colors.Text, Theme.Fonts.Title, {
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(1, -50, 0.55, 0),
		Parent = promptButton,
	})
	nameLabel = Create.label("", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Position = UDim2.new(0, 50, 0.55, 0),
		Size = UDim2.new(1, -50, 0.45, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = promptButton,
	})
	promptButton.Activated:Connect(function()
		InteractionController:Trigger()
	end)
	highlight = Instance.new("Highlight")
	highlight.Name = "TT_InteractHighlight"
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = Theme.Colors.Accent
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = billboard
end

local function track(kind: string)
	local set: { [Instance]: boolean } = {}
	tracked[kind] = set
	for _, instance in CollectionService:GetTagged(kind) do
		set[instance] = true
	end
	CollectionService:GetInstanceAddedSignal(kind):Connect(function(instance)
		set[instance] = true
	end)
	CollectionService:GetInstanceRemovedSignal(kind):Connect(function(instance)
		set[instance] = nil
	end)
end

function InteractionController:Init()
	for _, kind in TAGS do
		track(kind)
	end
	buildPrompt()
	InputController.Pressed:Connect(function(action)
		if action == "Interact" then
			InteractionController:Trigger()
		end
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		local value = player:GetAttribute("Carrying")
		carryingId = if type(value) == "string" then value else nil
		Bus.Carrying:Fire(carryingId)
		lastScan = 0
	end)
	UIManager.MenuOpened:Connect(function()
		showPrompt(nil)
	end)
end

function InteractionController:Start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastScan < 0.15 then
			return
		end
		lastScan = now
		local target = scan()
		local previous = current
		if
			target
			and previous
			and target.Instance == previous.Instance
			and target.Verb == previous.Verb
			and target.Label == previous.Label
		then
			current = target
			return
		end
		showPrompt(target)
	end)
end

return InteractionController
