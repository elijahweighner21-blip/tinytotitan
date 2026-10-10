--!strict
--[[
	UIManager
	Owns the ScreenGuis and the menu stack rules:
	  * only ONE menu is open at a time (opening another closes the current)
	  * Back / Escape / gamepad B closes the open menu
	  * gamepad selection jumps into a menu when it opens and is cleared on close
	  * everything scales with the viewport (designed at 1280×720) times the
	    player's UI Scale setting, and respects device safe areas
	  * gameplay input (abilities, attacks) is blocked while a menu is open
]]

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)

local Theme = require(script.Parent.Theme)
local Create = require(script.Parent.Create)
local Sound = require(script.Parent.Sound)

export type Menu = {
	Open: () -> (),
	Close: () -> (),
	Root: GuiObject?,
}

local UIManager = {}

UIManager.MenuOpened = Signal.new() :: Signal.Signal<string>
UIManager.MenuClosed = Signal.new() :: Signal.Signal<string>

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local menus: { [string]: Menu } = {}
local current: string? = nil
local userScale = 1
local scales: { UIScale } = {}

local function makeGui(name: string, order: number, insetIgnore: boolean): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		IgnoreGuiInset = insetIgnore,
		ScreenInsets = if insetIgnore then Enum.ScreenInsets.None else Enum.ScreenInsets.DeviceSafeInsets,
		Parent = playerGui,
	}) :: ScreenGui
	local scale = Create("UIScale", { Scale = 1, Parent = gui }) :: UIScale
	table.insert(scales, scale)
	return gui
end

UIManager.Hud = makeGui("TT_HUD", 1, false)
UIManager.Menus = makeGui("TT_Menus", 5, false)
UIManager.Overlay = makeGui("TT_Overlay", 10, true)
UIManager.Loading = makeGui("TT_Loading", 100, true)

-- Behind an open menu: a dim backdrop and (when the graphics preset allows
-- post effects) a soft blur of the world, so the menu has the focus.
local backdrop = Create("Frame", {
	Name = "Backdrop",
	BackgroundColor3 = Color3.fromRGB(6, 8, 16),
	BackgroundTransparency = 1,
	-- Oversized so it still covers the screen under any UIScale.
	Position = UDim2.fromScale(-1.5, -1.5),
	Size = UDim2.fromScale(4, 4),
	ZIndex = 0,
	Visible = false,
	Parent = UIManager.Menus,
}) :: Frame
local blurAllowed = true
local function menuBlur(): BlurEffect
	local blur = Lighting:FindFirstChild("MenuBlur")
	if blur and blur:IsA("BlurEffect") then
		return blur
	end
	local b = Instance.new("BlurEffect")
	b.Name = "MenuBlur"
	b.Size = 0
	b.Parent = Lighting
	return b
end
local function setBackdrop(on: boolean)
	backdrop.Visible = true
	local tween = TweenService:Create(backdrop, Theme.Tween.Normal, { BackgroundTransparency = if on then 0.55 else 1 })
	tween:Play()
	if not on then
		tween.Completed:Once(function()
			if current == nil then
				backdrop.Visible = false
			end
		end)
	end
	TweenService:Create(menuBlur(), Theme.Tween.Normal, { Size = if on and blurAllowed then 10 else 0 }):Play()
end

-- Post effects off (Low preset) also turns the menu blur off.
function UIManager:SetBlurAllowed(allowed: boolean)
	blurAllowed = allowed
end

local function viewportScale(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Theme.ReferenceSize
	local s = math.min(size.X / Theme.ReferenceSize.X, size.Y / Theme.ReferenceSize.Y)
	if size.Y < 500 then
		-- Short (landscape phone) screens: scale by width instead, so text
		-- stays readable; menu windows shrink in height to fit (Window).
		s = math.max(s, math.min(0.74, size.X / 1180))
	end
	return math.clamp(s, 0.58, 1.3)
end

local function applyScale()
	local s = viewportScale() * userScale
	for _, scale in scales do
		scale.Scale = s
	end
end

function UIManager:SetUserScale(value: number)
	userScale = math.clamp(value, 0.7, 1.3)
	applyScale()
end

function UIManager:GetScale(): number
	return viewportScale() * userScale
end

function UIManager:IsSmallScreen(): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.ViewportSize.X < 900 or camera.ViewportSize.Y < 500)
end

function UIManager:RegisterMenu(name: string, menu: Menu)
	menus[name] = menu
end

function UIManager:IsMenuOpen(): boolean
	return current ~= nil
end

function UIManager:Current(): string?
	return current
end

local function focus(root: GuiObject?)
	if not root or UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
		return
	end
	if UserInputService.GamepadEnabled then
		for _, d in root:GetDescendants() do
			if d:IsA("GuiButton") and d.Selectable and d.Visible and d.Name ~= "Close" then
				GuiService.SelectedObject = d
				return
			end
		end
	end
end

function UIManager:Close(name: string?)
	local target = name or current
	if not target or target ~= current then
		return
	end
	local menu = menus[target]
	current = nil
	if menu then
		menu.Close()
	end
	setBackdrop(false)
	GuiService.SelectedObject = nil
	Sound.play("Close")
	UIManager.MenuClosed:Fire(target)
end

function UIManager:Open(name: string)
	local menu = menus[name]
	if not menu then
		warn("[UIManager] unknown menu", name)
		return
	end
	if current == name then
		return
	end
	if current then
		UIManager:Close(current)
	end
	current = name
	setBackdrop(true)
	menu.Open()
	Sound.play("Open")
	focus(menu.Root)
	UIManager.MenuOpened:Fire(name)
end

function UIManager:Toggle(name: string)
	if current == name then
		UIManager:Close(name)
	else
		UIManager:Open(name)
	end
end

function UIManager:Init()
	applyScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
		end
		applyScale()
	end)
	UserInputService.InputBegan:Connect(function(input)
		if current and input.KeyCode == Enum.KeyCode.ButtonB then
			UIManager:Close()
		end
	end)
end

return UIManager
