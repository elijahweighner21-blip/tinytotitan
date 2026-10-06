--!strict
--[[
	AscensionService
	Prestige. The reset itself lives in Logic/AscensionLogic (unit-tested to
	reset exactly AscensionConfig.Resets and keep AscensionConfig.Keeps).
	This service validates the request, applies it, refreshes every derived
	system (stats, scale, quests), shrinks the player back to Microscopic with
	a sequence, returns them to the Floor World and force-saves immediately.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AscensionConfig = require(Shared.Config.AscensionConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local AscensionLogic = require(ServerRoot.Logic.AscensionLogic)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local StatService = require(script.Parent.StatService)
local ScaleService = require(script.Parent.ScaleService)
local CharacterService = require(script.Parent.CharacterService)
local InventoryService = require(script.Parent.InventoryService)
local ProgressionService = require(script.Parent.ProgressionService)

local AscensionService = {}

local inProgress: { [Player]: boolean } = {}

local function ascend(player: Player): { [string]: any }
	local data = PlayerDataService:Get(player)
	if not data or inProgress[player] then
		return { ok = false, err = "Busy" }
	end
	local ok, reason = AscensionLogic.canAscend(data)
	if not ok then
		return { ok = false, err = reason }
	end
	inProgress[player] = true
	local stats = StatService:GetStats(player)
	ScaleService:ClearModifier(player, "Shrink")
	ScaleService:ClearModifier(player, "Overgrowth")
	local summary = AscensionLogic.apply(data, os.time(), stats.StartEnergy, stats.StartSkills >= 1)
	-- Push every touched key to the client and refresh derived systems.
	for _, key in { "Currencies", "Upgrades", "Resources", "Skills", "Progress", "Quests", "Ascension" } do
		PlayerDataService:Changed(player, key)
	end
	-- Fire a currency change so tier/scale listeners re-derive (Mass is 0).
	CurrencyService.Changed:Fire(player, "Mass", 0, 0)
	StatService:Invalidate(player)
	player:SetAttribute("Tier", 1)
	task.spawn(function()
		ScaleService:PlaySequence(player, 2.5)
		local floor = ZoneConfig.get("FloorWorld")
		if floor then
			CharacterService:SafeTeleport(player, floor.Spawn, "Ascension")
		end
	end)
	GameEvents.fire("Ascended", player, summary.Count)
	Net.signal(player, "Notify", { Kind = "Ascension", Text = string.format("ASCENDED! +%d Ascension Points", summary.Points) })
	task.spawn(function()
		PlayerDataService:ForceSave(player, "Ascension")
		inProgress[player] = nil
	end)
	return { ok = true, points = summary.Points, count = summary.Count, refunded = summary.RefundedSkillPoints }
end

local function buyNode(player: Player, nodeId: string): { [string]: any }
	local data = PlayerDataService:Get(player)
	local node = AscensionConfig.getNode(nodeId)
	if not data or not node then
		return { ok = false, err = "Unknown node" }
	end
	local tree = data.Ascension.Tree
	local rank = tree[nodeId] or 0
	if rank >= node.MaxRank then
		return { ok = false, err = "Max rank" }
	end
	for _, req in node.Requires do
		if (tree[req] or 0) <= 0 then
			local reqNode = AscensionConfig.getNode(req)
			return { ok = false, err = "Requires " .. (if reqNode then reqNode.Name else req) }
		end
	end
	local cost = AscensionConfig.nodeCost(node, rank)
	if not CurrencyService:Remove(player, "AscensionPoints", cost, "AscensionNode:" .. nodeId) then
		return { ok = false, err = "Not enough Ascension Points" }
	end
	tree[nodeId] = rank + 1
	PlayerDataService:Changed(player, "Ascension")
	StatService:Invalidate(player)
	if node.Stat == "CosmeticAscendedAura" then
		InventoryService:GrantCosmetic(player, "AscendedAura")
	elseif node.Stat == "StartSkills" then
		-- Takes effect immediately for the current run as well.
		data.Skills.DoubleJump = true
		data.Skills.Slide = true
		PlayerDataService:Changed(player, "Skills")
	end
	return { ok = true, rank = rank + 1 }
end

function AscensionService:Init()
	Net.onRequest("Ascend", Guard.shape({ Confirm = Guard.oneOf({ "ASCEND" }) }), function(player)
		return ascend(player)
	end)
	Net.onRequest("BuyAscensionNode", Guard.shape({ Id = Guard.id() }), function(player, payload)
		return buyNode(player, payload.Id)
	end)
end

function AscensionService:Start()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		inProgress[player] = nil
	end)
	local _ = ProgressionService
end

return AscensionService
