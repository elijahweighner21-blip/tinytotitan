--!strict
--[[
	InputController
	Turns keyboard/mouse, gamepad and touch input into named game actions so
	gameplay code never cares which device is used.

	  Actions (press/release): Jump, Sprint, Crouch, Dash, Attack, HeavyAttack,
	  Interact, Ability1..Ability6
	  Menus (press only): Upgrades, Skills, Quests, Map, Shop, Inventory,
	  Collections, Challenges, Settings, Daily, Ascension, Achievements, Back

	Jump is bound through ContextActionService at high priority so the
	default Roblox jump never fires — the movement system owns jumping.
	Touch buttons (MobileControls) call InputController:Press/Release.
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)

local InputController = {}

InputController.Pressed = Signal.new() :: Signal.Signal<string>
InputController.Released = Signal.new() :: Signal.Signal<string>
InputController.MenuKey = Signal.new() :: Signal.Signal<string>
InputController.DeviceChanged = Signal.new() :: Signal.Signal<string>

local held: { [string]: boolean } = {}
local device = "Keyboard"
local menuBlocker: (() -> boolean)? = nil

local KEYBOARD: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.LeftShift] = "Sprint",
	[Enum.KeyCode.RightShift] = "Sprint",
	[Enum.KeyCode.LeftControl] = "Crouch",
	[Enum.KeyCode.C] = "Crouch",
	[Enum.KeyCode.Q] = "Dash",
	[Enum.KeyCode.E] = "Interact",
	[Enum.KeyCode.F] = "HeavyAttack",
	[Enum.KeyCode.One] = "Ability1",
	[Enum.KeyCode.Two] = "Ability2",
	[Enum.KeyCode.Three] = "Ability3",
	[Enum.KeyCode.Four] = "Ability4",
	[Enum.KeyCode.Five] = "Ability5",
	[Enum.KeyCode.Six] = "Ability6",
}

local MENU_KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.U] = "Upgrades",
	[Enum.KeyCode.K] = "Skills",
	[Enum.KeyCode.J] = "Quests",
	[Enum.KeyCode.M] = "Map",
	[Enum.KeyCode.B] = "Shop",
	[Enum.KeyCode.I] = "Inventory",
	[Enum.KeyCode.O] = "Collections",
	[Enum.KeyCode.L] = "Challenges",
	[Enum.KeyCode.P] = "Settings",
	[Enum.KeyCode.G] = "Daily",
	[Enum.KeyCode.Y] = "Ascension",
	[Enum.KeyCode.H] = "Achievements",
	[Enum.KeyCode.Escape] = "Back",
	[Enum.KeyCode.Backspace] = "Back",
}

local GAMEPAD: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.ButtonL3] = "Sprint",
	[Enum.KeyCode.ButtonB] = "Crouch",
	[Enum.KeyCode.ButtonR1] = "Dash",
	[Enum.KeyCode.ButtonX] = "Interact",
	[Enum.KeyCode.ButtonR2] = "Attack",
	[Enum.KeyCode.ButtonY] = "HeavyAttack",
	[Enum.KeyCode.ButtonL1] = "Ability1",
	[Enum.KeyCode.ButtonL2] = "Ability3",
	[Enum.KeyCode.DPadLeft] = "Ability2",
	[Enum.KeyCode.DPadRight] = "Ability4",
}

local GAMEPAD_MENUS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.DPadUp] = "Upgrades",
	[Enum.KeyCode.DPadDown] = "Quests",
	[Enum.KeyCode.ButtonSelect] = "Map",
	[Enum.KeyCode.ButtonStart] = "Settings",
}

function InputController:IsHeld(action: string): boolean
	return held[action] == true
end

function InputController:GetDevice(): string
	return device
end

-- Menus open → gameplay input (not movement) is suppressed by consumers via this.
function InputController:SetMenuBlocker(fn: () -> boolean)
	menuBlocker = fn
end

function InputController:IsBlocked(): boolean
	return menuBlocker ~= nil and menuBlocker()
end

function InputController:Press(action: string)
	if held[action] then
		return
	end
	held[action] = true
	InputController.Pressed:Fire(action)
end

function InputController:Release(action: string)
	if not held[action] then
		return
	end
	held[action] = false
	InputController.Released:Fire(action)
end

local function setDevice(inputType: Enum.UserInputType)
	local new = device
	if inputType == Enum.UserInputType.Touch then
		new = "Touch"
	elseif string.find(inputType.Name, "Gamepad") then
		new = "Gamepad"
	elseif inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") then
		new = "Keyboard"
	end
	if new ~= device then
		device = new
		InputController.DeviceChanged:Fire(device)
	end
end

function InputController:Init()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		device = "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		device = "Gamepad"
	end
	ContextActionService:BindActionAtPriority("TT_Jump", function(_, state)
		if state == Enum.UserInputState.Begin then
			InputController:Press("Jump")
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			InputController:Release("Jump")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	UserInputService.InputBegan:Connect(function(input, processed)
		setDevice(input.UserInputType)
		if processed then
			return
		end
		local menu = MENU_KEYS[input.KeyCode] or GAMEPAD_MENUS[input.KeyCode]
		if menu then
			InputController.MenuKey:Fire(menu)
			return
		end
		local action = KEYBOARD[input.KeyCode] or GAMEPAD[input.KeyCode]
		if not action and input.UserInputType == Enum.UserInputType.MouseButton1 then
			action = "Attack"
		end
		if action then
			InputController:Press(action)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local action = KEYBOARD[input.KeyCode] or GAMEPAD[input.KeyCode]
		if not action and input.UserInputType == Enum.UserInputType.MouseButton1 then
			action = "Attack"
		end
		if action then
			InputController:Release(action)
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(setDevice)
	-- Lose focus → release everything (no stuck sprint after alt-tab).
	UserInputService.WindowFocusReleased:Connect(function()
		for action, isHeld in held do
			if isHeld then
				InputController:Release(action)
			end
		end
	end)
end

return InputController
