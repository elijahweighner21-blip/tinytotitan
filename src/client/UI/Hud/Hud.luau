--!strict
--[[
	Hud
	The always-visible heads-up display, designed to stay out of the way:

	  top-left      level badge + XP bar, current size tier
	  top-right     Growth Energy / Titan Shards, active boost chips (with
	                remaining play time) and global event multipliers
	  bottom-centre the SIZE bar (progress to the next tier, with the next
	                tier's name) and the energy bar; charge meter when charging
	  above that    ability hotbar with key hints and cooldown sweeps
	                (keyboard/gamepad; touch uses MobileControls)
	  left edge     menu dock (every menu, with its hotkey)
	  top-centre    one-line tutorial hint and zone banner
	  health        appears only after taking damage

	Values animate (count-up numbers, eased bars); updates are event driven
	except the bars, which run on a light RenderStepped.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SizeConfig = require(Shared.Config.SizeConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local TutorialConfig = require(Shared.Config.TutorialConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Progression = require(Shared.Formulas.Progression)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local ProgressBar = require(Client.UI.Components.ProgressBar)
local DataController = require(Client.Controllers.DataController)
local MovementController = require(Client.Controllers.MovementController)
local InputController = require(Client.Controllers.InputController)
local CombatController = require(Client.Controllers.CombatController)
local ZoneController = require(Client.Controllers.ZoneController)

local Hud = {}

local player = Players.LocalPlayer

local DOCK: { { Menu: string, Icon: string, Key: string, Label: string } } = {
	{ Menu = "Upgrades", Icon = "⬆", Key = "U", Label = "Upgrades" },
	{ Menu = "Skills", Icon = "✦", Key = "K", Label = "Skills" },
	{ Menu = "Quests", Icon = "!", Key = "J", Label = "Quests" },
	{ Menu = "Map", Icon = "🗺", Key = "M", Label = "Map" },
	{ Menu = "Challenges", Icon = "⏱", Key = "L", Label = "Challenges" },
	{ Menu = "Collections", Icon = "◆", Key = "O", Label = "Collections" },
	{ Menu = "Inventory", Icon = "🎒", Key = "I", Label = "Inventory" },
	{ Menu = "Daily", Icon = "📅", Key = "G", Label = "Daily" },
	{ Menu = "Achievements", Icon = "🏆", Key = "H", Label = "Achievements" },
	{ Menu = "Ascension", Icon = "∞", Key = "Y", Label = "Ascension" },
	{ Menu = "Leaderboards", Icon = "📊", Key = "", Label = "Leaderboards" },
	{ Menu = "Party", Icon = "👥", Key = "", Label = "Party" },
	{ Menu = "Shop", Icon = "🛒", Key = "B", Label = "Shop" },
	{ Menu = "Settings", Icon = "⚙", Key = "P", Label = "Settings" },
}

-- UI elements ------------------------------------------------------------------
local levelText: TextLabel
local tierText: TextLabel
local xpBar: ProgressBar.ProgressBar
local sizeBar: ProgressBar.ProgressBar
local sizeText: TextLabel
local massText: TextLabel
local energyBar: ProgressBar.ProgressBar
local chargeBar: ProgressBar.ProgressBar
local healthBar: ProgressBar.ProgressBar
local healthFrame: Frame
local currencyLabels: { [string]: TextLabel } = {}
local boostRow: Frame
local hotbar: Frame
local hotbarSlots: { [string]: { Frame: Frame, Sweep: Frame, Key: TextLabel } } = {}
local hintFrame: Frame
local hintText: TextLabel
local bannerFrame: Frame
local bannerTitle: TextLabel
local bannerSub: TextLabel
local dock: Frame
local shrinkChip: TextLabel

local shown: { [string]: number } = {}
local boostClock = 0
local boostSnapshot: { [string]: number } = {}
local lastHurt = 0

local function panel(props: { [any]: any }): Frame
	local base: { [any]: any } = {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.2,
	}
	for k, v in props do
		base[k] = v
	end
	local frame = Create("Frame", base)
	Create.corner(Theme.Radius).Parent = frame
	Create.stroke(nil, 0.88).Parent = frame
	return frame
end

-- Smoothly counts a number label up/down to its new value.
local function countTo(key: string, label: TextLabel, value: number, prefix: string?)
	local from = shown[key] or value
	shown[key] = value
	if from == value then
		label.Text = (prefix or "") .. Format.abbreviate(value)
		return
	end
	local holder = Instance.new("NumberValue")
	holder.Value = from
	holder.Changed:Connect(function(v)
		label.Text = (prefix or "") .. Format.abbreviate(v)
	end)
	local tween = TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = value })
	tween.Completed:Once(function()
		label.Text = (prefix or "") .. Format.abbreviate(value)
		holder:Destroy()
	end)
	tween:Play()
end

------------------------------------------------------------------ builders

local function buildStatus(parent: Instance)
	local frame = panel({
		Name = "Status",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(250, 66),
		Parent = parent,
	})
	local badge = Create("Frame", {
		BackgroundColor3 = Theme.Colors.XP,
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.fromOffset(8, 8),
		Parent = frame,
		[Create.Children] = { Create.corner(Theme.RadiusPill) },
	})
	levelText = Create.label("1", Theme.TextSize.Heading, Color3.fromRGB(20, 10, 40), Theme.Fonts.Display, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = badge,
	})
	tierText = Create.label("Microscopic", Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Title, {
		Position = UDim2.fromOffset(68, 8),
		Size = UDim2.new(1, -78, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	xpBar = ProgressBar.new({
		Parent = frame,
		Color = Theme.Colors.XP,
		Position = UDim2.fromOffset(68, 36),
		Size = UDim2.new(1, -78, 0, 16),
		TextSize = Theme.TextSize.Tiny,
	})
	shrinkChip = Create.label("", Theme.TextSize.Tiny, Theme.Colors.Warning, Theme.Fonts.Title, {
		Position = UDim2.fromOffset(16, 86),
		Size = UDim2.fromOffset(250, 14),
		Visible = false,
		TextStrokeTransparency = 0.5,
		Parent = parent,
	})
end

local function currencyChip(parent: Instance, key: string, icon: string, color: Color3, order: number)
	local chip = panel({
		Name = key,
		Size = UDim2.fromOffset(140, 36),
		LayoutOrder = order,
		Parent = parent,
	})
	Create.label(icon, Theme.TextSize.Heading, color, Theme.Fonts.Display, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(24, 36),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chip,
	})
	currencyLabels[key] = Create.label("0", Theme.TextSize.Heading, Theme.Colors.Text, Theme.Fonts.Display, {
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -50, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = chip,
	})
end

local function buildCurrencies(parent: Instance)
	local column = Create("Frame", {
		Name = "Currencies",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(290, 200),
		Parent = parent,
		[Create.Children] = { Create.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right) },
	})
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(290, 36),
		LayoutOrder = 1,
		Parent = column,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) },
	})
	currencyChip(row, "GrowthEnergy", "⚡", Theme.Colors.Energy, 1)
	currencyChip(row, "TitanShards", "🔷", Theme.Colors.Shards, 2)
	boostRow = Create("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(290, 30),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = column,
		[Create.Children] = {
			Create("UIGridLayout", {
				CellSize = UDim2.fromOffset(140, 28),
				CellPadding = UDim2.fromOffset(6, 6),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})
end

local function buildBars(parent: Instance)
	local frame = Create("Frame", {
		Name = "Bars",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(520, 70),
		Parent = parent,
	})
	sizeText = Create.label("SIZE", Theme.TextSize.Small, Theme.Colors.Mass, Theme.Fonts.Title, {
		Size = UDim2.new(0.7, 0, 0, 16),
		TextStrokeTransparency = 0.5,
		Parent = frame,
	})
	massText = Create.label("0 Mass", Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Title, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.5,
		Parent = frame,
	})
	sizeBar = ProgressBar.new({
		Parent = frame,
		Color = Theme.Colors.Mass,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = Theme.TextSize.Small,
	})
	energyBar = ProgressBar.new({
		Parent = frame,
		Color = Theme.Colors.Energy,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = Theme.TextSize.Tiny,
	})
	chargeBar = ProgressBar.new({
		Parent = parent,
		Color = Theme.Colors.Warning,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.62, 0),
		Size = UDim2.fromOffset(160, 10),
	})
	chargeBar.Instance.Visible = false
	healthFrame = Create("Frame", {
		Name = "Health",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.fromOffset(260, 14),
		Visible = false,
		Parent = parent,
	})
	healthBar = ProgressBar.new({ Parent = healthFrame, Color = Theme.Colors.Danger, Size = UDim2.fromScale(1, 1), TextSize = Theme.TextSize.Tiny })
end

local function keyGlyph(slot: string): string
	local device = InputController:GetDevice()
	if device == "Gamepad" then
		local map: { [string]: string } = { Ability1 = "LB", Ability2 = "◀", Ability3 = "LT", Ability4 = "▶", Ability5 = "", Ability6 = "" }
		return map[slot] or ""
	end
	return string.sub(slot, 8)
end

local function buildHotbar(parent: Instance)
	hotbar = Create("Frame", {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(400, 52),
		Parent = parent,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) },
	})
end

local function hasSkill(skill: string?): boolean
	local data = DataController:Get()
	return skill == nil or (data ~= nil and data.Skills[skill] ~= nil)
end

local function rebuildHotbar()
	for _, slot in hotbarSlots do
		slot.Frame:Destroy()
	end
	table.clear(hotbarSlots)
	local map = CombatController:GetHotbar()
	for i = 1, 6 do
		local slotName = "Ability" .. i
		local id = map[slotName]
		local def = id and AbilityConfig.get(id)
		if def and hasSkill(def.RequiresSkill) then
			local frame = panel({ Name = def.Id, Size = UDim2.fromOffset(52, 52), LayoutOrder = i, Parent = hotbar })
			Create.label(def.Icon or "?", 24, Theme.Colors.Text, Theme.Fonts.Display, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = frame,
			})
			local sweep = Create("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 0),
				Parent = frame,
				[Create.Children] = { Create.corner(Theme.Radius) },
			})
			local key = Create.label(keyGlyph(slotName), Theme.TextSize.Tiny, Theme.Colors.TextDim, Theme.Fonts.Mono, {
				Position = UDim2.fromOffset(4, 2),
				Size = UDim2.fromOffset(24, 12),
				Parent = frame,
			})
			hotbarSlots[def.Id] = { Frame = frame, Sweep = sweep, Key = key }
		end
	end
end

local function buildDock(parent: Instance)
	dock = Create("Frame", {
		Name = "Dock",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 20),
		Size = UDim2.fromOffset(48, 600),
		Parent = parent,
		[Create.Children] = { Create.list(Enum.FillDirection.Vertical, 5, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) },
	})
	for i, entry in DOCK do
		local button = Create("TextButton", {
			Name = entry.Menu,
			Text = entry.Icon,
			TextSize = 20,
			FontFace = Theme.Fonts.Display,
			TextColor3 = if entry.Menu == "Shop" then Theme.Colors.Gold else Theme.Colors.Text,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.2,
			AutoButtonColor = true,
			Size = UDim2.fromOffset(38, 38),
			LayoutOrder = i,
			Parent = dock,
			[Create.Children] = { Create.corner(Theme.RadiusSmall), Create.stroke(nil, 0.88) },
		}) :: TextButton
		local tip = Create.label(entry.Label .. (if entry.Key ~= "" then "  [" .. entry.Key .. "]" else ""), Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Title, {
			Position = UDim2.new(1, 8, 0.5, -10),
			Size = UDim2.fromOffset(160, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.1,
			Visible = false,
			Parent = button,
			[Create.Children] = { Create.corner(Theme.RadiusSmall), Create.padding(2, 8) },
		})
		button.MouseEnter:Connect(function()
			tip.Visible = true
		end)
		button.MouseLeave:Connect(function()
			tip.Visible = false
		end)
		button.Activated:Connect(function()
			UIManager:Toggle(entry.Menu)
		end)
	end
end

local function buildHint(parent: Instance)
	hintFrame = panel({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = parent,
	})
	Create.padding(6, 16).Parent = hintFrame
	hintText = Create.label("", Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.Title, {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Parent = hintFrame,
	})
	bannerFrame = Create("Frame", {
		Name = "ZoneBanner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(600, 70),
		Visible = false,
		Parent = parent,
	})
	bannerTitle = Create.label("", Theme.TextSize.Hero, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.new(1, 0, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Parent = bannerFrame,
	})
	bannerSub = Create.label("", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		Parent = bannerFrame,
	})
end

------------------------------------------------------------------ updates

local function refreshProgress()
	local data = DataController:Get()
	if not data then
		return
	end
	local mass = data.Currencies.Mass
	local tier, fraction, nextReq = Progression.tierProgress(mass)
	local tierDef = SizeConfig.getTier(tier)
	tierText.Text = tierDef.Name
	tierText.TextColor3 = tierDef.Color
	if nextReq then
		local nextDef = SizeConfig.getTier(tier + 1)
		sizeText.Text = "SIZE  →  " .. string.upper(nextDef.Name)
		sizeBar:SetText(string.format("%s / %s", Format.abbreviate(mass), Format.abbreviate(nextReq)))
		sizeBar:SetPulse(fraction >= 0.95)
	else
		sizeText.Text = "SIZE  ·  MAXIMUM"
		sizeBar:SetText(Format.abbreviate(mass))
		sizeBar:SetPulse(false)
	end
	sizeBar:Set(fraction)
	sizeBar:SetColor(tierDef.Color:Lerp(Theme.Colors.Mass, 0.5))
	countTo("Mass", massText, mass, "Mass  ")
	local level = data.Progress.Level
	levelText.Text = tostring(level)
	local need = Progression.xpToNext(level)
	xpBar:Set(if need > 0 then data.Progress.XP / need else 1)
	xpBar:SetText(string.format("%s / %s XP", Format.abbreviate(data.Progress.XP), Format.abbreviate(need)))
	local shrink = player:GetAttribute("Shrink")
	shrinkChip.Visible = shrink == true
	shrinkChip.Text = "🔻 SHRINK MODE"
end

local function refreshCurrencies()
	local data = DataController:Get()
	if not data then
		return
	end
	countTo("GrowthEnergy", currencyLabels.GrowthEnergy, data.Currencies.GrowthEnergy)
	countTo("TitanShards", currencyLabels.TitanShards, data.Currencies.TitanShards)
end

local function boostChip(order: number, color: Color3, text: string)
	local chip = panel({ Size = UDim2.fromOffset(140, 28), LayoutOrder = order, Parent = boostRow })
	chip.BackgroundColor3 = color:Lerp(Theme.Colors.Panel, 0.75)
	Create.label(text, Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Title, {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = chip,
	})
end

local function refreshBoosts()
	for _, child in boostRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local elapsed = os.clock() - boostClock
	local order = 0
	for id, remaining in boostSnapshot do
		local def = MonetizationConfig.Boosts[id]
		local left = remaining - elapsed
		if def and left > 0 then
			order += 1
			boostChip(order, def.Color, string.format("%s %s  %s", def.Icon, def.Name, Format.clock(left)))
		end
	end
	-- Server-wide modifiers (world events, weekend boosts).
	local raw = workspace:GetAttribute("GlobalModifiers")
	if type(raw) == "string" and raw ~= "" then
		local ok, list = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(list) == "table" then
			for _, entry in list do
				if type(entry) == "table" and type(entry.Label) == "string" then
					order += 1
					local expires = tonumber(entry.Expires)
					local left = if expires then expires - workspace:GetServerTimeNow() else nil
					local text = "🌐 " .. entry.Label .. (if left and left > 0 then "  " .. Format.clock(left) else "")
					boostChip(order, Theme.Colors.Accent, text)
				end
			end
		end
	end
end

local function snapshotBoosts()
	local data = DataController:Get()
	boostSnapshot = {}
	if data and data.Boosts then
		for id, seconds in data.Boosts do
			boostSnapshot[id] = seconds
		end
	end
	boostClock = os.clock()
	refreshBoosts()
end

local function refreshHint()
	local data = DataController:Get()
	if not data or data.Tutorial.Done then
		hintFrame.Visible = false
		return
	end
	local step = TutorialConfig.Steps[data.Tutorial.Step + 1]
	if not step then
		hintFrame.Visible = false
		return
	end
	local device = InputController:GetDevice()
	hintText.Text = "💡 " .. (if device == "Touch" and step.MobileHint then step.MobileHint elseif device == "Gamepad" and step.GamepadHint then step.GamepadHint else step.Hint)
	hintFrame.Visible = true
end

function Hud.banner(title: string, subtitle: string, color: Color3?)
	bannerTitle.Text = string.upper(title)
	bannerTitle.TextColor3 = color or Theme.Colors.Text
	bannerSub.Text = subtitle
	bannerFrame.Visible = true
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	TweenService:Create(bannerTitle, Theme.Tween.Slow, { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, Theme.Tween.Slow, { TextTransparency = 0 }):Play()
	local token = os.clock()
	bannerFrame:SetAttribute("Token", token)
	task.delay(3.2, function()
		if bannerFrame:GetAttribute("Token") ~= token then
			return
		end
		TweenService:Create(bannerTitle, Theme.Tween.Slow, { TextTransparency = 1 }):Play()
		local t = TweenService:Create(bannerSub, Theme.Tween.Slow, { TextTransparency = 1 })
		t:Play()
		t.Completed:Once(function()
			if bannerFrame:GetAttribute("Token") == token then
				bannerFrame.Visible = false
			end
		end)
	end)
end

local function step()
	energyBar:Set(MovementController.Energy:Fraction(), true)
	energyBar:SetText(string.format("%d / %d", math.floor(MovementController.Energy.Value), math.floor(MovementController.Energy.Max)))
	local charge = math.max(MovementController:GetCharge(), CombatController:GetCharge())
	chargeBar.Instance.Visible = charge > 0.02
	if charge > 0.02 then
		chargeBar:Set(charge, true)
	end
	for id, slot in hotbarSlots do
		slot.Sweep.Size = UDim2.fromScale(1, MovementController:CooldownFraction(id))
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local fraction = humanoid.Health / math.max(humanoid.MaxHealth, 1)
		healthFrame.Visible = fraction < 0.999 or os.clock() - lastHurt < 3
		healthBar:Set(fraction)
		healthBar:SetText(string.format("%d / %d", math.ceil(humanoid.Health), math.floor(humanoid.MaxHealth)))
	end
end

function Hud.setVisible(visible: boolean)
	UIManager.Hud.Enabled = visible
end

function Hud.mount()
	local root = UIManager.Hud
	buildStatus(root)
	buildCurrencies(root)
	buildBars(root)
	buildHotbar(root)
	buildDock(root)
	buildHint(root)

	DataController.Changed:Connect(function(key)
		if key == "Currencies" then
			refreshProgress()
			refreshCurrencies()
		elseif key == "Progress" then
			refreshProgress()
		elseif key == "Boosts" then
			snapshotBoosts()
		elseif key == "Skills" then
			rebuildHotbar()
		elseif key == "Tutorial" then
			refreshHint()
		end
	end)
	DataController.Loaded:Connect(function()
		refreshProgress()
		refreshCurrencies()
		snapshotBoosts()
		rebuildHotbar()
		refreshHint()
	end)
	if DataController:IsLoaded() then
		refreshProgress()
		refreshCurrencies()
		snapshotBoosts()
		rebuildHotbar()
		refreshHint()
	end
	InputController.DeviceChanged:Connect(function(device)
		hotbar.Visible = device ~= "Touch"
		dock.Visible = true
		rebuildHotbar()
		refreshHint()
	end)
	hotbar.Visible = InputController:GetDevice() ~= "Touch"
	player:GetAttributeChangedSignal("Shrink"):Connect(refreshProgress)
	workspace:GetAttributeChangedSignal("GlobalModifiers"):Connect(refreshBoosts)
	ZoneController.ZoneChanged:Connect(function(zoneId, old)
		local zone = ZoneConfig.get(zoneId)
		if zone and old then
			Hud.banner(zone.Name, zone.Description, zone.MapColor)
		end
	end)
	UIManager.MenuOpened:Connect(function()
		dock.Visible = false
		hotbar.Visible = false
	end)
	UIManager.MenuClosed:Connect(function()
		dock.Visible = true
		hotbar.Visible = InputController:GetDevice() ~= "Touch"
	end)
	local lastBoostTick = 0
	RunService.RenderStepped:Connect(function()
		step()
		local now = os.clock()
		if now - lastBoostTick >= 1 then
			lastBoostTick = now
			refreshBoosts()
		end
	end)
end

function Hud.hurt()
	lastHurt = os.clock()
end

return Hud
