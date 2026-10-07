--!strict
--[[
	NPCService
	Spawns NPC rigs at their markers (scaled to their region) and answers
	Talk / DialogueChoice requests. Dialogue reacts to how big the player is
	relative to the NPC, and NPCs remember players they met while small:
	meet Professor Mote as a speck, come back as a titan, and they notice.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCConfig = require(Shared.Config.NPCConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Guard = require(Shared.Util.Guard)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local ProgressionService = require(script.Parent.ProgressionService)
local ScaleService = require(script.Parent.ScaleService)
local QuestService = require(script.Parent.QuestService)

local NPCService = {}

type Spawned = { Def: NPCConfig.NPC, Model: Model?, Position: Vector3 }
local npcs: { [string]: Spawned } = {}
local rng = Random.new()

local function buildFallbackRig(def: NPCConfig.NPC): Model
	-- Simple block figure used if the humanoid rig can't be created.
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = def.ShirtColor
	torso.Anchored = true
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Position = Vector3.new(0, 1.6, 0)
	head.Color = Color3.fromRGB(240, 200, 170)
	head.Anchored = true
	head.Parent = model
	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(2, 2, 1)
	legs.Position = Vector3.new(0, -2, 0)
	legs.Color = Color3.fromRGB(40, 50, 80)
	legs.Anchored = true
	legs.Parent = model
	model.PrimaryPart = root
	return model
end

local ROLE_COLORS: { [string]: Color3 } = {
	Guide = Color3.fromRGB(80, 220, 255),
	Merchant = Color3.fromRGB(255, 205, 60),
	Quest = Color3.fromRGB(110, 230, 140),
	Story = Color3.fromRGB(255, 190, 90),
	Upgrades = Color3.fromRGB(120, 255, 150),
	Skills = Color3.fromRGB(190, 150, 255),
	Shop = Color3.fromRGB(255, 205, 60),
}

-- Name + role floating above the NPC, sized for the screen (not the world)
-- so it stays readable whether the NPC is a speck or a titan.
local function nameplate(model: Model, def: NPCConfig.NPC, height: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local accent = ROLE_COLORS[def.Role] or Color3.fromRGB(200, 205, 215)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(240, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height * 0.72, 0)
	gui.MaxDistance = math.max(height * 30, 80)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = root
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 26)
	name.Text = def.Name
	name.TextColor3 = Color3.fromRGB(245, 248, 255)
	name.TextSize = 20
	name.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	name.TextStrokeTransparency = 0.45
	name.Parent = gui
	local chip = Instance.new("TextLabel")
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0, 28)
	chip.Size = UDim2.fromOffset(0, 18)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = accent
	chip.BackgroundTransparency = 0.1
	chip.Text = "  " .. string.upper(def.Role) .. "  "
	chip.TextColor3 = Color3.fromRGB(16, 20, 30)
	chip.TextSize = 12
	chip.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	chip.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = chip
end

-- Subtle life: the default idle animation. Only the root stays anchored so
-- the limbs can move; any failure leaves a still (but fine) NPC.
local IDLE_ANIMATION = "rbxassetid://507766666"
local function idle(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if not humanoid or not root then
		return
	end
	pcall(function()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= root then
				d.Anchored = false
			end
		end
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		local animation = Instance.new("Animation")
		animation.AnimationId = IDLE_ANIMATION
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play(0.3, 1, 0.9 + math.random() * 0.2)
	end)
end

local function spawnNpc(def: NPCConfig.NPC, marker: BasePart)
	local model: Model
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = Color3.fromRGB(240, 200, 170)
		description.TorsoColor = def.ShirtColor
		description.LeftArmColor = def.ShirtColor
		description.RightArmColor = def.ShirtColor
		description.LeftLegColor = Color3.fromRGB(40, 50, 80)
		description.RightLegColor = Color3.fromRGB(40, 50, 80)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		model = result :: Model
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	else
		Log.debug("NPC", "using fallback rig for", def.Id, result)
		model = buildFallbackRig(def)
	end
	model.Name = def.Name
	model:SetAttribute("NPCId", def.Id)
	model:SetAttribute("Role", def.Role)
	model:SetAttribute("Scale", def.Scale)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	pcall(function()
		model:ScaleTo(def.Scale)
	end)
	local height = ScaleMath.height(def.Scale)
	model:PivotTo(CFrame.new(marker.Position + Vector3.new(0, height * 0.5, 0)) * marker.CFrame.Rotation)
	nameplate(model, def, height)
	idle(model)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, "NPC")
	model.Parent = workspace:FindFirstChild("World") or workspace
	npcs[def.Id] = { Def = def, Model = model, Position = marker.Position + Vector3.new(0, height * 0.5, 0) }
end

local function pickLine(lines: { string }): string
	if #lines == 0 then
		return "..."
	end
	return lines[rng:NextInteger(1, #lines)]
end

function NPCService:GetPosition(npcId: string): Vector3?
	local npc = npcs[npcId]
	return npc and npc.Position
end

local function talk(player: Player, npcId: string): { [string]: any }
	local npc = npcs[npcId]
	local data = PlayerDataService:Get(player)
	local root = CharacterService:GetRoot(player)
	if not npc or not data or not root then
		return { ok = false, err = "Nobody's there" }
	end
	local def = npc.Def
	local scale = ScaleService:GetScale(player)
	local reach = math.max(ScaleMath.height(scale), ScaleMath.height(def.Scale)) * NPCConfig.TalkRangeMultiplier + 8
	if (root.Position - npc.Position).Magnitude > reach then
		return { ok = false, err = "Get closer to talk" }
	end
	local tier = ProgressionService:GetTier(player)
	local metAt = data.NPCs[def.Id]
	local line: string
	if metAt and tier - metAt >= 2 and #def.Remember > 0 and rng:NextNumber() < 0.6 then
		line = pickLine(def.Remember)
	else
		line = pickLine((def.Lines :: any)[NPCConfig.relativeSize(scale, def.Scale)])
	end
	if not metAt then
		data.NPCs[def.Id] = tier
		PlayerDataService:Changed(player, "NPCs")
	end
	GameEvents.fire("TalkedTo", player, def.Id)
	return {
		ok = true,
		Npc = def.Id,
		Name = def.Name,
		Role = def.Role,
		Line = line,
		Menu = def.Menu,
		Quests = QuestService:GetGiverQuests(player, def.Id),
	}
end

function NPCService:Init()
	Net.onRequest("Talk", Guard.shape({ Npc = Guard.id() }), function(player, payload)
		return talk(player, payload.Npc)
	end)
	Net.onRequest("DialogueChoice", Guard.shape({ Npc = Guard.id(), Quest = Guard.id() }), function(player, payload)
		local npc = npcs[payload.Npc]
		local root = CharacterService:GetRoot(player)
		if not npc or not root then
			return { ok = false }
		end
		-- Re-check proximity: dialogue choices are only valid face to face.
		local reach = math.max(ScaleMath.height(ScaleService:GetScale(player)), ScaleMath.height(npc.Def.Scale))
				* NPCConfig.TalkRangeMultiplier
			+ 12
		if (root.Position - npc.Position).Magnitude > reach then
			return { ok = false, err = "Get closer to talk" }
		end
		local ok, reason = QuestService:StartQuest(player, payload.Quest)
		return { ok = ok, err = reason }
	end)
end

function NPCService:Start()
	for _, marker in CollectionService:GetTagged("NPCSpawn") do
		local id = marker:GetAttribute("NPCId")
		local def = if type(id) == "string" then NPCConfig.get(id) else nil
		if def and marker:IsA("BasePart") then
			task.spawn(spawnNpc, def, marker)
		end
	end
end

return NPCService
