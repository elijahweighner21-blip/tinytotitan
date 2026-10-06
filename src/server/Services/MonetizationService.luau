--!strict
--[[
	MonetizationService
	All Robux purchases. Security model:

	  * The client can only ASK the server to show a purchase prompt. It can
	    never grant anything; there is no remote that adds currency.
	  * Developer Products are granted exclusively in ProcessReceipt:
	      1. unknown product / player not here / data not loaded
	         -> NotProcessedYet (Roblox retries later; nothing granted)
	      2. PurchaseId already in the player's receipt ledger
	         -> PurchaseGranted (never grant twice)
	      3. grant + record PurchaseId in the SAME data, then force-save
	         -> saved: PurchaseGranted, failed: NotProcessedYet (the ledger
	            entry already in memory makes the retry a no-op)
	    The ledger lives in the player's save, so it follows them across
	    servers, rejoins and crashes.
	  * Purchased contents bypass every multiplier (Source = "Purchase").
	  * One-time products (Starter Pack) are never prompted twice; if Roblox
	    somehow charges twice, DuplicateCompensation is granted instead.
	  * Game Passes are verified with UserOwnsGamePassAsync (EntitlementService);
	    owned passes are never prompted again and their items are (re)granted
	    on every join.
	  * Studio-only test purchases run the exact same receipt code path with a
	    synthetic receipt and are refused outside Studio.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Guard = require(Shared.Util.Guard)
local Retry = require(Shared.Util.Retry)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local ReceiptLedger = require(ServerRoot.Logic.ReceiptLedger)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RewardService = require(script.Parent.RewardService)
local EntitlementService = require(script.Parent.EntitlementService)
local InventoryService = require(script.Parent.InventoryService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local AdminService = require(script.Parent.AdminService)

local MonetizationService = {}

local prices: { [string]: number } = {} -- product/pass key -> live Robux price
local inFlight: { [string]: boolean } = {} -- PurchaseId currently being processed
local lastPrompt: { [Player]: { [string]: number } } = {}

------------------------------------------------------------------ visibility

function MonetizationService:IsVisible(player: Player, product: MonetizationConfig.DevProduct): boolean
	local data = PlayerDataService:Get(player)
	if not data then
		return false
	end
	if product.OneTime and (data.Monetization.ProductCounts[product.Key] or 0) > 0 then
		return false
	end
	local vis = product.Visibility
	if not vis then
		return true
	end
	if vis.MaxLevel and data.Progress.Level > vis.MaxLevel then
		return false
	end
	if vis.MaxPlaytimeHours and (data.Stats.Playtime :: number) / 3600 > vis.MaxPlaytimeHours then
		return false
	end
	local now = os.time()
	if vis.Start and now < vis.Start then
		return false
	end
	if vis.End and now >= vis.End then
		return false
	end
	return true
end

------------------------------------------------------------------ receipts

local function grantProduct(player: Player, product: MonetizationConfig.DevProduct, purchaseId: string, spent: number): boolean
	local data = PlayerDataService:Get(player)
	if not data then
		return false
	end
	local monetization = data.Monetization
	local count = monetization.ProductCounts[product.Key] or 0
	local contents = product.Contents
	if product.OneTime and count >= 1 then
		Log.warn("Monetization", "duplicate one-time purchase", product.Key, player.UserId, "- granting compensation")
		contents = product.DuplicateCompensation or { TitanShards = 100 }
	end
	RewardService:Grant(player, contents, { Source = "Purchase", SourceId = product.Key, Multipliers = false, Jackpot = false })
	monetization.ProductCounts[product.Key] = count + 1
	monetization.RobuxSpent += math.max(0, spent)
	if product.Key == "StarterPack" then
		monetization.StarterPackBought = true
	end
	ReceiptLedger.record(monetization.Receipts, purchaseId, os.time())
	ReceiptLedger.prune(monetization.Receipts, GameConfig.MaxProcessedReceipts)
	return true
end

-- Shared by the real ProcessReceipt and Studio test purchases.
local function processFor(player: Player, product: MonetizationConfig.DevProduct, purchaseId: string, spent: number): Enum.ProductPurchaseDecision
	local data = PlayerDataService:WaitForData(player, 20)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if ReceiptLedger.has(data.Monetization.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if inFlight[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	inFlight[purchaseId] = true
	local ok, err = pcall(grantProduct, player, product, purchaseId, spent)
	if not ok then
		inFlight[purchaseId] = nil
		Log.error("Monetization", "grant failed", product.Key, err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local saved = PlayerDataService:ForceSave(player, "Receipt:" .. product.Key)
	inFlight[purchaseId] = nil
	if not saved then
		-- Reward + ledger stay in memory and will be saved with the next save;
		-- Roblox will retry this receipt and step 2 returns PurchaseGranted.
		Log.warn("Monetization", "receipt save deferred", purchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	AnalyticsService:Track(player, "PurchaseGranted", 1, product.Key)
	GameEvents.fire("Purchase", player, product.Key)
	Net.signal(player, "PurchaseResult", { Ok = true, Key = product.Key, Name = product.Name, Contents = product.Contents })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local product = MonetizationConfig.productByRobloxId(receipt.ProductId)
	if not product then
		Log.error("Monetization", "receipt for unknown product id", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return processFor(player, product, tostring(receipt.PurchaseId), tonumber(receipt.CurrencySpent) or 0)
end

------------------------------------------------------------------ passes

local function grantPassItems(player: Player, passKey: string)
	local pass = MonetizationConfig.getPass(passKey)
	local data = PlayerDataService:Get(player)
	if not pass or not data or not EntitlementService:Owns(player, passKey) then
		return
	end
	local titles: { string } = pass.Grants.Titles or {}
	for _, title in titles do
		InventoryService:GrantTitle(player, title)
	end
	local cosmetics: { string } = pass.Grants.Cosmetics or {}
	for _, cosmetic in cosmetics do
		InventoryService:GrantCosmetic(player, cosmetic)
	end
	if not data.Monetization.PassRewardsGranted[passKey] then
		data.Monetization.PassRewardsGranted[passKey] = true
		Net.signal(player, "PurchaseResult", { Ok = true, Key = passKey, Name = pass.Name, Pass = true })
	end
	InventoryService:Publish(player)
end

------------------------------------------------------------------ prompts

local function canPrompt(player: Player, key: string): boolean
	local now = os.clock()
	local map = lastPrompt[player]
	if not map then
		map = {}
		lastPrompt[player] = map
	end
	if (map[key] or 0) > now then
		return false
	end
	map[key] = now + MonetizationConfig.PromptCooldown
	return true
end

local function prompt(player: Player, kind: string, key: string): { [string]: any }
	AnalyticsService:Track(player, "PromptRequested", 1, key)
	if kind == "Pass" then
		local pass = MonetizationConfig.getPass(key)
		if not pass then
			return { ok = false, err = "Unknown pass" }
		end
		if EntitlementService:Owns(player, key) then
			return { ok = false, err = "You already own this", owned = true }
		end
		if pass.PassId == 0 then
			return { ok = false, err = if RunService:IsStudio() then "Pass ID not configured (use admin TestPurchase in Studio)" else "Not available yet" }
		end
		if not canPrompt(player, key) then
			return { ok = false, err = "Please wait" }
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
		return { ok = true }
	end
	local product = MonetizationConfig.getProduct(key)
	if not product then
		return { ok = false, err = "Unknown product" }
	end
	if not MonetizationService:IsVisible(player, product) then
		return { ok = false, err = if product.OneTime then "Already purchased" else "Not available right now" }
	end
	if product.ProductId == 0 then
		return { ok = false, err = if RunService:IsStudio() then "Product ID not configured (use admin TestPurchase in Studio)" else "Not available yet" }
	end
	if not canPrompt(player, key) then
		return { ok = false, err = "Please wait" }
	end
	MarketplaceService:PromptProductPurchase(player, product.ProductId)
	return { ok = true }
end

------------------------------------------------------------------ catalog

local function fetchPrices()
	for key, pass in MonetizationConfig.GamePasses do
		if pass.PassId ~= 0 then
			local ok, info = Retry.call(2, 1, function()
				return MarketplaceService:GetProductInfo(pass.PassId, Enum.InfoType.GamePass)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				prices[key] = info.PriceInRobux
			end
		end
	end
	for key, product in MonetizationConfig.DeveloperProducts do
		if product.ProductId ~= 0 then
			local ok, info = Retry.call(2, 1, function()
				return MarketplaceService:GetProductInfo(product.ProductId, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				prices[key] = info.PriceInRobux
			end
		end
	end
end

-- Catalog for the shop UI (prices are display-only).
function MonetizationService:GetCatalog(player: Player): { [string]: any }
	local passes = {}
	for key, pass in MonetizationConfig.GamePasses do
		table.insert(passes, {
			Key = key,
			Name = pass.Name,
			Description = pass.Description,
			Perks = pass.Perks,
			Icon = pass.Icon,
			Color = pass.Color,
			Price = prices[key] or pass.FallbackPrice,
			Owned = EntitlementService:Owns(player, key),
			Available = pass.PassId ~= 0 or RunService:IsStudio(),
		})
	end
	local products = {}
	for key, product in MonetizationConfig.DeveloperProducts do
		if MonetizationService:IsVisible(player, product) then
			table.insert(products, {
				Key = key,
				Name = product.Name,
				Description = product.Description,
				Category = product.Category,
				Icon = product.Icon,
				Color = product.Color,
				Price = prices[key] or product.FallbackPrice,
				ValueText = product.ValueText,
				Contents = product.Contents,
				OneTime = product.OneTime == true,
				Available = product.ProductId ~= 0 or RunService:IsStudio(),
				EndsAt = if product.Visibility then product.Visibility.End else nil,
			})
		end
	end
	table.sort(products, function(a, b)
		return (a.Price :: number) < (b.Price :: number)
	end)
	return { Passes = passes, Products = products, Featured = MonetizationConfig.Featured, Studio = RunService:IsStudio() }
end

function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = processReceipt
	Net.onRequest(
		"PromptPurchase",
		Guard.shape({ Kind = Guard.oneOf({ "Product", "Pass" }), Key = Guard.id() }),
		function(player, payload)
			return prompt(player, payload.Kind, payload.Key)
		end
	)
	-- Studio-only fake receipts through the real pipeline.
	AdminService.TestPurchase = function(player, key)
		if not RunService:IsStudio() or not GameConfig.AllowStudioTestPurchases then
			return false, "Test purchases are Studio-only"
		end
		local pass = MonetizationConfig.getPass(key)
		if pass then
			return EntitlementService:SetTestOwnership(player, key, true), nil
		end
		local product = MonetizationConfig.getProduct(key)
		if not product then
			return false, "Unknown product"
		end
		local decision = processFor(player, product, "STUDIO-TEST-" .. HttpService:GenerateGUID(false), 0)
		return decision == Enum.ProductPurchaseDecision.PurchaseGranted, nil
	end
end

function MonetizationService:Start()
	task.spawn(fetchPrices)
	PlayerDataService.Loaded:Connect(function(player)
		for key in MonetizationConfig.GamePasses do
			grantPassItems(player, key)
		end
	end)
	EntitlementService.OwnershipChanged:Connect(function(player, key, owned)
		if owned then
			grantPassItems(player, key)
		end
		InventoryService:Publish(player)
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		local player = Players:GetPlayerByUserId(userId)
		local product = MonetizationConfig.productByRobloxId(productId)
		if player and product and not purchased then
			-- Cancelled: tell the UI to reset its button. No retry, no re-prompt.
			Net.signal(player, "PurchaseResult", { Ok = false, Key = product.Key, Cancelled = true })
			AnalyticsService:Track(player, "PromptCancelled", 1, product.Key)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = MonetizationConfig.passByRobloxId(passId)
		if pass and not purchased then
			Net.signal(player, "PurchaseResult", { Ok = false, Key = pass.Key, Cancelled = true })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPrompt[player] = nil
	end)
end

return MonetizationService
