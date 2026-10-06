--!strict
--[[
	CollectibleController
	Client half of collecting. The server owns rewards and per-player
	respawn timers; this controller:

	  * sends Collect when the player touches an available collectible
	    (one pending request per id, so walking through an orb never spams)
	  * hides collectibles locally while they are on this player's cooldown
	    (other players still see their own copy) and permanently for unique
	    ones already in the save
	  * keeps Secret Stars invisible until the player is close enough
	  * spins/bobs only the nearby ones (cheap even with thousands placed)
	  * flies a little copy of the item into the player on pickup
	  * shows Echo Scan results as pulsing beacons for a few seconds
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectibleConfig = require(Shared.Config.CollectibleConfig)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local MovementController = require(script.Parent.MovementController)
local DataController = require(script.Parent.DataController)
local AudioController = require(script.Parent.AudioController)
local EffectsController = require(script.Parent.EffectsController)

local CollectibleController = {}

type Entry = {
	Part: BasePart,
	Id: string,
	Type: string,
	Def: CollectibleConfig.CollectibleType,
	Home: CFrame,
	Radius: number,
	Phase: number,
}

local entries: { [BasePart]: Entry } = {}
local byId: { [string]: Entry } = {}
local hiddenUntil: { [string]: number } = {}
local pending: { [string]: number } = {}
local animated: { Entry } = {}
local lastCheck = 0
local lastAnimRefresh = 0
local beaconFolder: Folder

local MAX_ANIMATED = 80

local function isAvailable(e: Entry, now: number): boolean
	return (hiddenUntil[e.Id] or 0) <= now
end

local function setVisible(e: Entry, visible: boolean)
	e.Part.LocalTransparencyModifier = if visible then 0 else 1
end

local function register(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local id = instance:GetAttribute("CollectibleId")
	local typeId = instance:GetAttribute("Type")
	local def = if type(typeId) == "string" then CollectibleConfig.get(typeId) else nil
	if type(id) ~= "string" or not def then
		return
	end
	local e: Entry = {
		Part = instance,
		Id = id,
		Type = typeId :: string,
		Def = def,
		Home = instance.CFrame,
		Radius = instance.Size.Magnitude * 0.5,
		Phase = (#id % 17) / 17 * math.pi * 2,
	}
	entries[instance] = e
	byId[id] = e
	local data = DataController:Get()
	if def.Unique and data and data.Collectibles and data.Collectibles[id] then
		hiddenUntil[id] = math.huge
	end
	setVisible(e, isAvailable(e, os.clock()) and not def.Hidden)
end

local function unregister(instance: Instance)
	local e = entries[instance :: BasePart]
	if e then
		entries[instance :: BasePart] = nil
		if byId[e.Id] == e then
			byId[e.Id] = nil
		end
	end
end

local function flyToPlayer(e: Entry)
	local root = MovementController:GetRoot()
	if not root then
		return
	end
	local ghost = e.Part:Clone()
	ghost:ClearAllChildren()
	CollectionService:RemoveTag(ghost, "Collectible")
	ghost.Anchored = true
	ghost.LocalTransparencyModifier = 0
	ghost.Parent = beaconFolder
	local tween = TweenService:Create(ghost, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = root.Position,
		Size = ghost.Size * 0.3,
	})
	tween:Play()
	tween.Completed:Once(function()
		ghost:Destroy()
		EffectsController:Burst(root.Position, e.Def.Color, MovementController:GetHeight() * 0.25, if e.Def.Unique then 24 else 8)
	end)
end

-- Server confirmed a pickup.
local function onCollected(payload: { [string]: any })
	local id = payload.Collectible
	if type(id) ~= "string" then
		return
	end
	pending[id] = nil
	local respawn = payload.Respawn
	hiddenUntil[id] = if type(respawn) == "number" then os.clock() + respawn else math.huge
	local e = byId[id]
	if e then
		flyToPlayer(e)
		setVisible(e, false)
		local def = CollectibleConfig.get(payload.Type or e.Type)
		local rare = def ~= nil and (def.Unique or def.Rarity == "Rare")
		AudioController:Play(if rare then "RareCollect" else "Collect", { Position = e.Part.Position })
	end
end

local function revealRange(): number
	local stats = DataController:GetStats() :: any
	return MovementController:GetHeight() * CollectibleConfig.SecretRevealHeights * (1 + (stats.SecretFinder or 0))
end

local function check(now: number)
	local root = MovementController:GetRoot()
	if not root or not DataController:IsLoaded() then
		return
	end
	local origin = root.Position
	local derived = DataController:GetDerived()
	local reach = derived.CollectRange + derived.Height * 0.5
	local reveal = revealRange()
	for _, e in entries do
		local available = isAvailable(e, now)
		local dist = (e.Part.Position - origin).Magnitude
		if e.Def.Hidden then
			setVisible(e, available and dist <= reveal)
		elseif available and e.Part.LocalTransparencyModifier > 0 then
			setVisible(e, true)
		end
		if available and dist <= reach + e.Radius and (pending[e.Id] or 0) < now then
			pending[e.Id] = now + 1
			Net.action("Collect", e.Id)
		end
	end
end

-- Picks the closest visible collectibles to animate.
local function refreshAnimated(now: number)
	table.clear(animated)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	local range = math.max(MovementController:GetHeight() * 40, 120)
	local candidates: { { e: Entry, d: number } } = {}
	for _, e in entries do
		if isAvailable(e, now) then
			local d = (e.Part.Position - origin).Magnitude
			if d < range then
				table.insert(candidates, { e = e, d = d })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(#candidates, MAX_ANIMATED) do
		table.insert(animated, candidates[i].e)
	end
end

local function animate(now: number)
	for _, e in animated do
		if e.Part.Parent then
			local bob = math.sin(now * 2 + e.Phase) * e.Radius * 0.25
			local spin = CFrame.Angles(0, now * 1.6 + e.Phase, 0)
			e.Part.CFrame = CFrame.new(e.Home.Position + Vector3.new(0, bob, 0)) * spin * e.Home.Rotation
		end
	end
end

-- Echo Scan: beacons over every available collectible in range.
local function showScan(payload: { [string]: any })
	local items = payload.Items
	if type(items) ~= "table" then
		return
	end
	local h = MovementController:GetHeight()
	for _, item in items do
		if type(item) == "table" and typeof(item.P) == "Vector3" then
			local def = CollectibleConfig.get(item.T)
			local color = if def then def.Color else Theme.Colors.Accent
			local beam = Create("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Material = Enum.Material.Neon,
				Color = color,
				Transparency = 0.45,
				Size = Vector3.new(h * 0.15, h * 12, h * 0.15),
				Position = item.P + Vector3.new(0, h * 6, 0),
				Parent = beaconFolder,
			})
			Create("BillboardGui", {
				AlwaysOnTop = true,
				Size = UDim2.fromOffset(28, 28),
				LightInfluence = 0,
				Adornee = beam,
				StudsOffsetWorldSpace = Vector3.new(0, -h * 6, 0),
				Parent = beam,
				[Create.Children] = {
					Create("Frame", {
						BackgroundColor3 = color,
						Size = UDim2.fromScale(1, 1),
						[Create.Children] = { Create.corner(Theme.RadiusPill), Create.stroke(Color3.new(1, 1, 1), 0.2, 2) },
					}),
				},
			})
			if def and def.Hidden then
				local e = byId[item.Id]
				if e then
					setVisible(e, true)
				end
			end
			TweenService:Create(beam, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.8 }):Play()
			task.delay(10, function()
				beam:Destroy()
			end)
		end
	end
	AudioController:Play("Scan")
end

function CollectibleController:IsCollected(id: string): boolean
	return hiddenUntil[id] == math.huge
end

function CollectibleController:Init()
	beaconFolder = Instance.new("Folder")
	beaconFolder.Name = "TT_Collectibles"
	beaconFolder.Parent = workspace
	Net.onSignal("Notify", function(payload)
		if type(payload) == "table" and payload.Kind == "Collect" then
			onCollected(payload)
		end
	end)
	Net.onSignal("ScanResult", showScan)
	DataController.Loaded:Connect(function(data)
		for id in data.Collectibles or {} do
			hiddenUntil[id] = math.huge
			local e = byId[id]
			if e then
				setVisible(e, false)
			end
		end
	end)
end

function CollectibleController:Start()
	for _, instance in CollectionService:GetTagged("Collectible") do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal("Collectible"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("Collectible"):Connect(unregister)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck >= 0.1 then
			lastCheck = now
			check(now)
		end
		if now - lastAnimRefresh >= 0.5 then
			lastAnimRefresh = now
			refreshAnimated(now)
		end
		animate(now)
	end)
end

return CollectibleController
