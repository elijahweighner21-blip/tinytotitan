--!strict
--[[
	InventoryService
	Cosmetics, titles, key items, relics and lore. Handles equipping (with
	slot limits that depend on the Extra Cosmetic Slots pass) and mirrors what
	is equipped onto player attributes so every client can render it:

	  Attribute "Cosmetics"  JSON array of equipped cosmetic ids
	  Attribute "Title"      equipped title id ("" = none)

	Pass-sourced cosmetics are only equippable while the pass is owned.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local TitleConfig = require(Shared.Config.TitleConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local LoreConfig = require(Shared.Config.LoreConfig)
local Guard = require(Shared.Util.Guard)
local Signal = require(Shared.Util.Signal)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EntitlementService = require(script.Parent.EntitlementService)

local InventoryService = {}

-- (player, kind, id) kind = "Cosmetic" | "Title" | "Item" | "Lore" | "Relic"
InventoryService.Granted = Signal.new() :: Signal.Signal<Player, string, string>

-- Cosmetic id -> pass key that unlocks it (derived from MonetizationConfig).
local passForCosmetic: { [string]: string } = {}
for key, pass in MonetizationConfig.GamePasses do
	local granted = pass.Grants.Cosmetics
	if granted then
		for _, id in granted do
			passForCosmetic[id] = key
		end
	end
end

local function slotsFor(player: Player, category: string): number
	local cat = CosmeticConfig.getCategory(category)
	if not cat then
		return 0
	end
	if EntitlementService:Owns(player, "ExtraCosmeticSlots") then
		return cat.PassSlots
	end
	return cat.BaseSlots
end

local function entitled(player: Player, cosmeticId: string): boolean
	local passKey = passForCosmetic[cosmeticId]
	return passKey == nil or EntitlementService:Owns(player, passKey)
end

local function publish(player: Player)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	local equipped = {}
	for category, list in data.Cosmetics.Equipped do
		local limit = slotsFor(player, category)
		for i, id in list do
			if i <= limit and data.Cosmetics.Owned[id] and entitled(player, id) then
				table.insert(equipped, id)
			end
		end
	end
	player:SetAttribute("Cosmetics", HttpService:JSONEncode(equipped))
	local title = data.Titles.Equipped
	if title ~= "" and not data.Titles.Owned[title] then
		title = ""
	end
	player:SetAttribute("Title", title)
end

function InventoryService:Publish(player: Player)
	publish(player)
end

function InventoryService:GrantCosmetic(player: Player, id: string): boolean
	local data = PlayerDataService:Get(player)
	local def = CosmeticConfig.get(id)
	if not data or not def or data.Cosmetics.Owned[id] then
		return false
	end
	data.Cosmetics.Owned[id] = true
	-- Auto-equip into an empty slot so new items are immediately visible.
	local list = data.Cosmetics.Equipped[def.Category] or {}
	data.Cosmetics.Equipped[def.Category] = list
	if #list < slotsFor(player, def.Category) then
		table.insert(list, id)
	end
	PlayerDataService:Changed(player, "Cosmetics")
	publish(player)
	InventoryService.Granted:Fire(player, "Cosmetic", id)
	return true
end

function InventoryService:GrantTitle(player: Player, idOrText: string): boolean
	local data = PlayerDataService:Get(player)
	local def = TitleConfig.get(idOrText)
	if not data or not def or data.Titles.Owned[def.Id] then
		return false
	end
	data.Titles.Owned[def.Id] = true
	if data.Titles.Equipped == "" then
		data.Titles.Equipped = def.Id
	end
	PlayerDataService:Changed(player, "Titles")
	publish(player)
	InventoryService.Granted:Fire(player, "Title", def.Id)
	return true
end

function InventoryService:OwnsCosmetic(player: Player, id: string): boolean
	local data = PlayerDataService:Get(player)
	return data ~= nil and data.Cosmetics.Owned[id] == true
end

function InventoryService:AddItem(player: Player, itemId: string, amount: number): boolean
	local data = PlayerDataService:Get(player)
	if not data or amount <= 0 or #itemId > 40 then
		return false
	end
	local items = data.Inventory.KeyItems
	items[itemId] = math.min((items[itemId] or 0) + math.floor(amount), 1e6)
	PlayerDataService:Changed(player, "Inventory")
	InventoryService.Granted:Fire(player, "Item", itemId)
	return true
end

function InventoryService:RemoveItem(player: Player, itemId: string, amount: number): boolean
	local data = PlayerDataService:Get(player)
	if not data then
		return false
	end
	local items = data.Inventory.KeyItems
	local have = items[itemId] or 0
	if have < amount then
		return false
	end
	(items :: any)[itemId] = if have - amount > 0 then have - amount else nil
	PlayerDataService:Changed(player, "Inventory")
	return true
end

function InventoryService:HasItem(player: Player, itemId: string): boolean
	local data = PlayerDataService:Get(player)
	return data ~= nil and (data.Inventory.KeyItems[itemId] or 0) > 0
end

function InventoryService:UnlockLore(player: Player, loreId: string): boolean
	local data = PlayerDataService:Get(player)
	if not data or not LoreConfig.get(loreId) or data.Inventory.Lore[loreId] then
		return false
	end
	data.Inventory.Lore[loreId] = true
	PlayerDataService:Changed(player, "Inventory")
	InventoryService.Granted:Fire(player, "Lore", loreId)
	return true
end

function InventoryService:AddRelic(player: Player, relicId: string): boolean
	local data = PlayerDataService:Get(player)
	if not data or data.Inventory.Relics[relicId] then
		return false
	end
	data.Inventory.Relics[relicId] = true
	PlayerDataService:Changed(player, "Inventory")
	InventoryService.Granted:Fire(player, "Relic", relicId)
	return true
end

function InventoryService:Init()
	Net.onRequest(
		"EquipCosmetic",
		Guard.shape({ Id = Guard.id(), Equip = Guard.boolean() }),
		function(player, payload)
			local data = PlayerDataService:Get(player)
			local def = CosmeticConfig.get(payload.Id)
			if not data or not def then
				return { ok = false, err = "Unknown cosmetic" }
			end
			if not data.Cosmetics.Owned[def.Id] then
				return { ok = false, err = "You don't own that yet" }
			end
			if not entitled(player, def.Id) then
				return { ok = false, err = "Requires its Game Pass" }
			end
			local list = data.Cosmetics.Equipped[def.Category] or {}
			data.Cosmetics.Equipped[def.Category] = list
			local index = table.find(list, def.Id)
			if payload.Equip then
				if not index then
					local limit = slotsFor(player, def.Category)
					if #list >= limit then
						-- Replace the oldest equipped item in this category.
						table.remove(list, 1)
					end
					table.insert(list, def.Id)
				end
			elseif index then
				table.remove(list, index)
			end
			PlayerDataService:Changed(player, "Cosmetics")
			publish(player)
			return { ok = true }
		end
	)

	Net.onRequest("EquipTitle", Guard.shape({ Id = Guard.string(48) }), function(player, payload)
		local data = PlayerDataService:Get(player)
		if not data then
			return { ok = false }
		end
		if payload.Id ~= "" and not data.Titles.Owned[payload.Id] then
			return { ok = false, err = "Title not owned" }
		end
		data.Titles.Equipped = payload.Id
		PlayerDataService:Changed(player, "Titles")
		publish(player)
		return { ok = true }
	end)
end

function InventoryService:Start()
	PlayerDataService.Loaded:Connect(function(player)
		publish(player)
	end)
	EntitlementService.OwnershipChanged:Connect(function(player)
		publish(player)
	end)
	Players.PlayerRemoving:Connect(function() end)
end

return InventoryService
