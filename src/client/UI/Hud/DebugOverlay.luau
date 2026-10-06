--!strict
--[[
	DebugOverlay
	Developer readout toggled by the admin "Debug" command (DebugMode
	attribute set by the server): FPS, ping, position, zone, scale/tier,
	movement state, energy and instance counts. Hidden for everyone else.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Client = script.Parent.Parent.Parent
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local MovementController = require(Client.Controllers.MovementController)
local DataController = require(Client.Controllers.DataController)
local ZoneController = require(Client.Controllers.ZoneController)
local EnvironmentController = require(Client.Controllers.EnvironmentController)

local DebugOverlay = {}

local player = Players.LocalPlayer

function DebugOverlay.mount()
	local label = Create.label("", Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Mono, {
		Name = "Debug",
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Color3.new(0, 0, 0),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 70, 1, -16),
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = UIManager.Overlay,
		[Create.Children] = { Create.padding(6, 8), Create.corner(Theme.RadiusSmall) },
	})
	local frames = 0
	local fps = 0
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if now - last < 0.5 then
			return
		end
		fps = frames / (now - last)
		frames = 0
		last = now
		local on = player:GetAttribute("DebugMode") == true
		label.Visible = on
		if not on then
			return
		end
		local root = MovementController:GetRoot()
		local p = if root then root.Position else Vector3.zero
		local ping = 0
		pcall(function()
			ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		label.Text = table.concat({
			string.format(
				"FPS %d   Ping %d ms   Preset %s",
				math.floor(fps),
				math.floor(ping),
				EnvironmentController:GetPreset()
			),
			string.format("Pos %.1f, %.1f, %.1f", p.X, p.Y, p.Z),
			string.format("Zone %s", tostring(ZoneController:GetZone())),
			string.format(
				"Scale %.3f  Height %.2f  Tier %d",
				DataController:GetScale(),
				MovementController:GetHeight(),
				DataController:GetTier()
			),
			string.format(
				"State %s  Grounded %s",
				MovementController:GetState(),
				tostring(MovementController:IsGrounded())
			),
			string.format("Energy %.0f / %.0f", MovementController.Energy.Value, MovementController.Energy.Max),
			string.format(
				"Instances %d   Memory %d MB",
				Stats.InstanceCount,
				math.floor(Stats:GetTotalMemoryUsageMb())
			),
		}, "\n")
	end)
end

return DebugOverlay
