--!strict
--[[
	MobileControls
	Touch layout (bottom-right thumb arc), shown only when the last input was
	touch. Roblox's default thumbstick stays for movement; the default jump
	button is hidden because jumping goes through MovementController (coyote
	time, buffering, double jump, glide on hold).

	  Jump (large)   Attack (hold = charged)   Dash   Crouch/Slide   Sprint
	  Interact       appears only when something is interactable
	  Abilities      a row of unlocked hotbar abilities with cooldown sweeps
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig = require(Shared.Config.AbilityConfig)

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local Bus = require(Client.UI.Bus)
local InputController = require(Client.Controllers.InputController)
local MovementController = require(Client.Controllers.MovementController)
local DataController = require(Client.Controllers.DataController)
local CombatController = require(Client.Controllers.CombatController)

local MobileControls = {}

local player = Players.LocalPlayer
local root: Frame
local interactButton: TextButton
local abilityRow: Frame
local abilityButtons: { [string]: { Button: TextButton, Sweep: Frame } } = {}
local sprintButton: TextButton

local function holdButton(
	parent: Instance,
	name: string,
	glyph: string,
	size: number,
	position: UDim2,
	action: string,
	color: Color3?
): TextButton
	local button = Create("TextButton", {
		Name = name,
		Text = glyph,
		TextSize = math.floor(size * 0.42),
		FontFace = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.Text,
		AutoButtonColor = false,
		BackgroundColor3 = color or Theme.Colors.Panel,
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Position = position,
		Parent = parent,
		[Create.Children] = { Create.corner(Theme.RadiusPill), Create.stroke(Color3.new(1, 1, 1), 0.6, 2) },
	})
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			button.BackgroundTransparency = 0.05
			InputController:Press(action)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			button.BackgroundTransparency = 0.25
			InputController:Release(action)
		end
	end)
	return button
end

local function hideDefaultJump()
	local gui = player:FindFirstChild("PlayerGui")
	local touch = gui and gui:FindFirstChild("TouchGui")
	local frame = touch and touch:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") and jump.Visible then
		jump.Visible = false
	end
end

local function hasSkill(skill: string?): boolean
	local data = DataController:Get()
	return skill == nil or (data ~= nil and data.Skills[skill] ~= nil)
end

local function rebuildAbilities()
	for _, entry in abilityButtons do
		entry.Button:Destroy()
	end
	table.clear(abilityButtons)
	local hotbar = CombatController:GetHotbar()
	local order = 0
	for slot = 1, 6 do
		local id = hotbar["Ability" .. slot]
		local def = id and AbilityConfig.get(id)
		if def and hasSkill(def.RequiresSkill) then
			order += 1
			local button =
				holdButton(abilityRow, def.Id, def.Icon or "?", 50, UDim2.fromOffset(0, 0), "Ability" .. slot)
			button.AnchorPoint = Vector2.zero
			button.LayoutOrder = order
			local sweep = Create("Frame", {
				Name = "Cooldown",
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				Size = UDim2.fromScale(1, 0),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				ZIndex = 2,
				Parent = button,
				[Create.Children] = { Create.corner(Theme.RadiusPill) },
			})
			abilityButtons[def.Id] = { Button = button, Sweep = sweep }
		end
	end
end

local function updateVisibility()
	root.Visible = InputController:GetDevice() == "Touch" and not UIManager:IsMenuOpen()
end

function MobileControls.mount()
	root = Create("Frame", {
		Name = "MobileControls",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = UIManager.Hud,
	})
	local cluster = Create("Frame", {
		Name = "Cluster",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(260, 230),
		Parent = root,
	})
	holdButton(cluster, "Jump", "⤒", 96, UDim2.fromOffset(200, 170), "Jump", Theme.Colors.PanelLighter)
	holdButton(cluster, "Attack", "👊", 70, UDim2.fromOffset(95, 190), "Attack")
	holdButton(cluster, "Dash", "💨", 58, UDim2.fromOffset(200, 70), "Dash")
	holdButton(cluster, "Crouch", "⤓", 58, UDim2.fromOffset(120, 110), "Crouch")
	sprintButton = holdButton(cluster, "Sprint", "🏃", 50, UDim2.fromOffset(40, 120), "Sprint")
	interactButton =
		holdButton(cluster, "Interact", "✋", 64, UDim2.fromOffset(110, 30), "Interact", Theme.Colors.Accent)
	interactButton.Visible = false
	abilityRow = Create("Frame", {
		Name = "Abilities",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -256),
		Size = UDim2.fromOffset(330, 50),
		Parent = root,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) },
	})
	Bus.Prompt:Connect(function(prompt)
		interactButton.Visible = prompt ~= nil and prompt.Enabled == true
	end)
	InputController.DeviceChanged:Connect(updateVisibility)
	UIManager.MenuOpened:Connect(updateVisibility)
	UIManager.MenuClosed:Connect(updateVisibility)
	DataController.Changed:Connect(function(key)
		if key == "Skills" then
			rebuildAbilities()
		end
	end)
	DataController.Loaded:Connect(rebuildAbilities)
	if DataController:IsLoaded() then
		rebuildAbilities()
	end
	updateVisibility()
	local last = 0
	RunService.RenderStepped:Connect(function()
		if not root.Visible then
			return
		end
		local now = os.clock()
		if now - last < 0.1 then
			return
		end
		last = now
		hideDefaultJump()
		sprintButton.BackgroundColor3 = if MovementController:IsSprinting()
			then Theme.Colors.Energy
			else Theme.Colors.Panel
		for id, entry in abilityButtons do
			local f = MovementController:CooldownFraction(id)
			entry.Sweep.Size = UDim2.fromScale(1, f)
		end
	end)
end

return MobileControls
