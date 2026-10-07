--!strict
--[[
	ShopMenu
	FEATURED · GAME PASSES · BOOSTS · TITAN SHARDS · BUNDLES · COSMETICS

	Design rules (see docs/MONETIZATION.md):
	  * prices come from the server catalog (live MarketplaceService prices,
	    falling back to config) — the client never decides what is owned
	  * owned passes / one-time bundles show OWNED and cannot be re-prompted
	  * buying only PROMPTS; items arrive through the server receipt pipeline
	    and a "thank you" card appears when they do (PurchaseResult)
	  * a pending purchase disables its button until the result or a timeout
	  * cosmetics bought with in-game currency use ShopPurchase (no Robux)
	  * no pop-ups, no fake timers: limited items show their real end time
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Client = UI.Parent
local Net = require(Client.Net)
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local Card = require(UI.Components.Card)
local Scroll = require(UI.Components.Scroll)
local Dialog = require(UI.Components.Dialog)
local UIManager = require(UI.UIManager)
local Bus = require(UI.Bus)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local ShopMenu = {}

local grid: ScrollingFrame
local menuRef: MenuBase.Menu
local catalog: { [string]: any }? = nil
local fetchedAt = 0
local fetching = false
local pending: { [string]: number } = {}

local PENDING_TIMEOUT = 25

local function robux(price: number): string
	return "R$ " .. Format.commas(price)
end

local function fetch(force: boolean?)
	if fetching or (not force and catalog and os.clock() - fetchedAt < 60) then
		return
	end
	fetching = true
	local result = Net.request("ShopCatalog")
	fetching = false
	if result.ok and type(result.Catalog) == "table" then
		catalog = result.Catalog
		fetchedAt = os.clock()
	end
end

local function contentsText(contents: { [string]: any }?): string
	if not contents then
		return ""
	end
	local parts = { Common.rewardText(contents) }
	if type(contents.Boosts) == "table" then
		for id, seconds in contents.Boosts do
			local boost = MonetizationConfig.Boosts[id]
			table.insert(
				parts,
				(if boost then boost.Icon .. " " .. boost.Name else id) .. " " .. Format.duration(seconds)
			)
		end
	end
	if type(contents.Cosmetics) == "table" then
		for _, id in contents.Cosmetics do
			local c = CosmeticConfig.get(id)
			table.insert(parts, "✨ " .. (if c then c.Name else id))
		end
	end
	if type(contents.Titles) == "table" then
		for _, id in contents.Titles do
			table.insert(parts, "🏷 " .. id)
		end
	end
	local out = {}
	for _, p in parts do
		if p ~= "" then
			table.insert(out, p)
		end
	end
	return table.concat(out, "   ")
end

local function prompt(kind: string, key: string, button: Button.Button)
	if pending[key] and os.clock() - pending[key] < PENDING_TIMEOUT then
		return
	end
	Net.action("Analytics", { Event = "ProductViewed", Detail = key })
	local result = Net.request("PromptPurchase", { Kind = kind, Key = key })
	if not result.ok then
		Bus.toast(tostring(result.err or "Purchase unavailable"), if result.owned then "Info" else "Warning")
		return
	end
	pending[key] = os.clock()
	button:SetText("…")
	button:SetEnabled(false)
	task.delay(PENDING_TIMEOUT, function()
		if pending[key] then
			pending[key] = nil
			menuRef:Refresh()
		end
	end)
end

local function passCard(pass: { [string]: any }, order: number, big: boolean?)
	local card = Card.new({
		Icon = pass.Icon,
		Title = pass.Name,
		Description = pass.Description
			.. (if type(pass.Perks) == "table" then "\n• " .. table.concat(pass.Perks, "\n• ") else ""),
		Accent = pass.Color,
		LayoutOrder = order,
		Parent = grid,
	})
	card.Description.Size = UDim2.new(1, -62, 1, -70)
	card:SetTag(if big then "FEATURED" else "GAME PASS", Theme.Colors.Gold)
	if pass.Owned then
		card:SetTag("OWNED ✔", Theme.Colors.Success)
		if pass.Key == "VIP" then
			Button.new({
				Text = "Enter VIP Lounge",
				Style = "Gold",
				Size = UDim2.fromOffset(170, 34),
				TextSize = Theme.TextSize.Small,
				Parent = card.Footer,
				OnClick = function()
					local result = Common.request("VipLounge", { Enter = true })
					if result.ok then
						UIManager:Close("Shop")
					end
				end,
			})
		else
			Button.new({ Text = "✔ OWNED", Style = "Owned", Size = UDim2.fromOffset(120, 34), Parent = card.Footer })
				:SetEnabled(false)
		end
		return
	end
	local isPending = pending[pass.Key] ~= nil
	local button: Button.Button
	button = Button.new({
		Text = if isPending then "…" else robux(pass.Price),
		Style = "Robux",
		Size = UDim2.fromOffset(130, 34),
		Parent = card.Footer,
		OnClick = function()
			prompt("Pass", pass.Key, button)
		end,
	})
	button:SetEnabled(pass.Available and not isPending)
end

local function productCard(product: { [string]: any }, order: number, featured: boolean?)
	local card = Card.new({
		Icon = product.Icon,
		Title = product.Name,
		Description = product.Description .. "\n" .. contentsText(product.Contents),
		Accent = product.Color,
		LayoutOrder = order,
		Parent = grid,
	})
	card.Description.Size = UDim2.new(1, -62, 1, -70)
	local tag = if featured then "FEATURED" else product.ValueText
	if product.EndsAt then
		local left = product.EndsAt - workspace:GetServerTimeNow()
		if left > 0 then
			tag = "Ends in " .. Format.duration(left)
		end
	end
	if tag then
		card:SetTag(tag, if product.EndsAt then Theme.Colors.Danger else Theme.Colors.Gold)
	end
	local isPending = pending[product.Key] ~= nil
	local button: Button.Button
	button = Button.new({
		Text = if isPending then "…" else robux(product.Price),
		Style = "Robux",
		Size = UDim2.fromOffset(130, 34),
		Parent = card.Footer,
		OnClick = function()
			prompt("Product", product.Key, button)
		end,
	})
	button:SetEnabled(product.Available and not isPending)
end

local function cosmeticCard(id: string, order: number, label: string?)
	local def = CosmeticConfig.get(id)
	local data = DataController:Get()
	if not def or not def.Price or not data then
		return
	end
	local owned = data.Cosmetics.Owned[id] == true
	local color = CosmeticConfig.RarityColors[def.Rarity] or Theme.Colors.TextDim
	local card = Card.new({
		Icon = CosmeticConfig.getCategory(def.Category).Icon,
		Title = def.Name,
		Description = def.Description,
		Accent = color,
		LayoutOrder = order,
		Parent = grid,
	})
	card.Icon.BackgroundColor3 = def.Colors[1]:Lerp(Theme.Colors.Background, 0.4)
	card:SetTag(label or def.Rarity, color)
	if owned then
		card:SetTag("OWNED ✔", Theme.Colors.Success)
		Button.new({ Text = "✔ OWNED", Style = "Owned", Size = UDim2.fromOffset(120, 34), Parent = card.Footer })
			:SetEnabled(false)
		return
	end
	local price = def.Price
	local affordable = Common.balance(price.Currency) >= price.Amount
	local button = Button.new({
		Text = Common.costText(price.Currency, price.Amount),
		Style = if affordable then "Primary" else "Secondary",
		Size = UDim2.fromOffset(130, 34),
		TextSize = Theme.TextSize.Small,
		Parent = card.Footer,
		OnClick = function()
			Dialog.confirm({
				Title = "Buy " .. def.Name .. "?",
				Body = "Costs " .. Common.costText(price.Currency, price.Amount) .. ". Cosmetics are purely visual.",
				Confirm = "Buy",
				Parent = UIManager.Menus,
			}, function(ok)
				if ok then
					Common.request("ShopPurchase", { Id = id }, def.Name .. " added to your Inventory!")
				end
			end)
		end,
	})
	if not affordable then
		button.Label.TextColor3 = Theme.Colors.Danger
	end
end

local function render(menu: MenuBase.Menu, tab: string)
	Scroll.clear(grid)
	local c = catalog
	if not c then
		Create.label(
			"Loading the shop…",
			Theme.TextSize.Body,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{ Size = UDim2.fromOffset(400, 40), Parent = grid }
		)
		task.spawn(function()
			fetch(true)
			if catalog then
				menu:Refresh()
			end
		end)
		return
	end
	local data = DataController:Get()
	if data then
		menu.Window:SetSubtitle(
			string.format(
				"%s   %s",
				Common.costText("GrowthEnergy", data.Currencies.GrowthEnergy),
				Common.costText("TitanShards", data.Currencies.TitanShards)
			)
		)
	end
	Net.action("Analytics", { Event = "ShopCategory", Detail = tab })
	local passesByKey: { [string]: any } = {}
	for _, pass in c.Passes or {} do
		passesByKey[pass.Key] = pass
	end
	local productsByKey: { [string]: any } = {}
	for _, product in c.Products or {} do
		productsByKey[product.Key] = product
	end
	if tab == "Featured" then
		for i, key in c.Featured or {} do
			if passesByKey[key] then
				passCard(passesByKey[key], i, true)
			elseif productsByKey[key] then
				productCard(productsByKey[key], i, true)
			end
		end
	elseif tab == "GamePasses" then
		local list = c.Passes or {}
		table.sort(list, function(a, b)
			return a.Price < b.Price
		end)
		for i, pass in list do
			passCard(pass, i)
		end
	elseif tab == "Cosmetics" then
		local cos = c.Cosmetics or {}
		local order = 0
		if type(cos.Daily) == "table" and #cos.Daily > 0 then
			menu.Window:SetSubtitle("Daily shop refreshes in " .. Format.duration(tonumber(cos.ResetsIn) or 0))
			for _, id in cos.Daily do
				order += 1
				cosmeticCard(id, order, "DAILY")
			end
		end
		if type(cos.Limited) == "table" and #cos.Limited > 0 then
			for _, entry in cos.Limited do
				order += 1
				local left = (tonumber(entry.Ends) or 0) - workspace:GetServerTimeNow()
				cosmeticCard(
					entry.Id,
					order,
					if left > 0 then tostring(entry.Event) .. " · " .. Format.duration(left) else "LIMITED"
				)
			end
		end
		if type(cos.Permanent) == "table" then
			for _, id in cos.Permanent do
				local def = CosmeticConfig.get(id)
				if def and not def.Limited then
					order += 1
					cosmeticCard(id, order)
				end
			end
		end
	else
		local order = 0
		for _, product in c.Products or {} do
			if product.Category == tab then
				order += 1
				productCard(product, order)
			end
		end
		if order == 0 then
			Create.label(
				"Nothing here right now.",
				Theme.TextSize.Body,
				Theme.Colors.TextDim,
				Theme.Fonts.Body,
				{ Size = UDim2.fromOffset(400, 40), Parent = grid }
			)
		end
	end
	if c.Studio then
		menu.Window:SetSubtitle("Studio: unconfigured product IDs can be tested from the Admin panel (TestPurchase)")
	end
end

function ShopMenu.mount()
	local tabs = {}
	for _, category in MonetizationConfig.ShopCategories do
		table.insert(tabs, { Id = category.Id, Text = category.Name, Icon = category.Icon })
	end
	menuRef = MenuBase.new({
		Name = "Shop",
		Title = "Shop",
		Icon = Theme.Icons.Shop,
		Accent = Theme.Colors.Gold,
		Size = UDim2.fromOffset(980, 600),
		Tabs = tabs,
		Watch = { "Cosmetics", "Currencies", "Boosts" },
		Render = render,
		OnOpen = function()
			Net.action("Analytics", { Event = "ShopOpened" })
			task.spawn(function()
				local before = catalog
				fetch()
				if catalog ~= before then
					menuRef:Refresh()
				end
			end)
		end,
	})
	grid = Scroll.grid(menuRef.Content, UDim2.new(0.5, -8, 0, 170), { Name = "Shop" })
	Net.onSignal("PurchaseResult", function(p)
		if type(p) == "table" and type(p.Key) == "string" then
			pending[p.Key] = nil
			-- Ownership/visibility may have changed: refetch now.
			task.spawn(function()
				fetch(true)
				menuRef:Refresh()
			end)
		end
	end)
end

return ShopMenu
