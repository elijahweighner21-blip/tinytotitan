--!strict
--[[
	Client entry point.

	Boot order:
	  1. loading screen up immediately
	  2. require every controller, Init() all (wire signals, no yielding),
	     then Start() all (begin loops; DataController asks for the save)
	  3. mount the HUD, overlays and every menu
	  4. run the real loading steps (world index → save → character), then
	     fade the loading screen and show the welcome card

	A controller that errors during Init/Start is reported and skipped so
	one broken system can never black-screen the game.
]]

local Players = game:GetService("Players")

local Client = script.Parent
local Controllers = Client.Controllers
local UI = Client.UI

local UIManager = require(UI.UIManager)
local LoadingScreen = require(UI.Hud.LoadingScreen)

LoadingScreen.show()

local Net = require(Client.Net)

local ORDER = {
	"DataController",
	"SettingsController",
	"InputController",
	"MovementController",
	"CameraController",
	"AudioController",
	"EffectsController",
	"CombatController",
	"InteractionController",
	"CollectibleController",
	"ZoneController",
	"EnvironmentController",
	"CosmeticsController",
	"MovementFxController",
	"OverheadController",
	"AnimationController",
	"WorldMarkerController",
}

local loaded: { { Name: string, Module: any } } = {}

for _, name in ORDER do
	local module = Controllers:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(function()
			return require(module) :: any
		end)
		if ok then
			table.insert(loaded, { Name = name, Module = result })
		else
			warn("[Client] failed to load", name, result)
		end
	else
		warn("[Client] missing controller", name)
	end
end

local function phase(method: string)
	for _, entry in loaded do
		local fn = entry.Module[method]
		if type(fn) == "function" then
			local ok, err = pcall(function()
				fn(entry.Module)
			end)
			if not ok then
				warn(string.format("[Client] %s:%s failed: %s", entry.Name, method, tostring(err)))
			end
		end
	end
end

UIManager:Init()
phase("Init")
phase("Start")

------------------------------------------------------------------ UI

local InputController = require(Controllers.InputController)
local SettingsController = require(Controllers.SettingsController)

local MOUNT = {
	UI.Hud.Hud,
	UI.Hud.QuestTracker,
	UI.Hud.Notifications,
	UI.Hud.GrowthSequence,
	UI.Hud.ScreenFade,
	UI.Hud.BossBar,
	UI.Hud.ChallengeHud,
	UI.Hud.DialogueBox,
	UI.Hud.MobileControls,
	UI.Hud.DebugOverlay,
	UI.Screens.UpgradesMenu,
	UI.Screens.SkillsMenu,
	UI.Screens.QuestsMenu,
	UI.Screens.MapMenu,
	UI.Screens.ChallengesMenu,
	UI.Screens.CollectionsMenu,
	UI.Screens.InventoryMenu,
	UI.Screens.DailyMenu,
	UI.Screens.AchievementsMenu,
	UI.Screens.AscensionMenu,
	UI.Screens.LeaderboardsMenu,
	UI.Screens.PartyMenu,
	UI.Screens.ShopMenu,
	UI.Screens.SettingsMenu,
	UI.Screens.AdminMenu,
}

for _, module in MOUNT do
	local ok, err = pcall(function()
		(require(module) :: any).mount()
	end)
	if not ok then
		warn("[Client] UI", module.Name, "failed to mount:", err)
	end
end

-- Gameplay input is suppressed while a menu is open.
InputController:SetMenuBlocker(function()
	return UIManager:IsMenuOpen()
end)

local player = Players.LocalPlayer
InputController.MenuKey:Connect(function(name)
	if name == "Back" then
		UIManager:Close()
	elseif name == "Admin" and player:GetAttribute("IsAdmin") ~= true then
		return
	else
		UIManager:Toggle(name)
	end
end)

UIManager.MenuOpened:Connect(function(name)
	Net.action("Analytics", { Event = "MenuOpened", Detail = name })
end)

local function applyUIScale()
	UIManager:SetUserScale(tonumber(SettingsController:Get("UIScale")) or 1)
end
SettingsController.Changed:Connect(function(key)
	if key == "UIScale" then
		applyUIScale()
	end
end)
applyUIScale()

------------------------------------------------------------------ loading

local ok, err = pcall(function()
	LoadingScreen.run()
end)
if not ok then
	warn("[Client] loading step failed:", err)
end
applyUIScale()
LoadingScreen.hide()

task.delay(0.8, function()
	local welcomeOk, welcomeErr = pcall(function()
		require(UI.Hud.WelcomePanel).show()
	end)
	if not welcomeOk then
		warn("[Client] welcome panel failed:", welcomeErr)
	end
end)
