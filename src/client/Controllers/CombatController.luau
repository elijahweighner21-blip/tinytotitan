--!strict
--[[
	CombatController
	Turns attack input into Attack actions. The server decides hits and
	damage; the client only gates obvious spam (cooldowns, energy) so the
	swing animation never plays for an attack the server would reject.

	  Attack (tap)              Light
	  Attack (hold ≥ 0.45s)     Charged   (needs Charged Strike)
	  Attack while dashing      Dash      (needs Dash Strike)
	  HeavyAttack               Heavy     (needs Heavy Strike)
	  Ability1..6               hotbar abilities from AbilityConfig.Key
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig = require(Shared.Config.AbilityConfig)
local Signal = require(Shared.Util.Signal)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local Bus = require(Client.UI.Bus)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local DataController = require(script.Parent.DataController)

local CombatController = {}

-- (kind) fired when an attack is sent, for animation + sound.
CombatController.Swing = Signal.new() :: Signal.Signal<string>

local ATTACK_ABILITY: { [string]: string } = {
	Light = "LightAttack",
	Heavy = "HeavyAttack",
	Dash = "DashAttack",
	Charged = "ChargedAttack",
}
local CHARGE_TIME = 0.45

local lastAttack: { [string]: number } = {}
local attackHeldAt: number? = nil
local hotbar: { [string]: string } = {}

local function hasSkill(skill: string?): boolean
	if not skill then
		return true
	end
	local data = DataController:Get()
	return data ~= nil and data.Skills ~= nil and data.Skills[skill] ~= nil
end

function CombatController:CanAttack(kind: string): boolean
	local def = AbilityConfig.get(ATTACK_ABILITY[kind])
	if not def or not hasSkill(def.RequiresSkill) then
		return false
	end
	local cd = def.Cooldown * DataController:GetDerived().CooldownMultiplier
	if os.clock() - (lastAttack[kind] or 0) < cd then
		return false
	end
	return MovementController.Energy.Value + 1 >= def.EnergyCost
end

local function facing(): Vector3
	local camera = workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else Vector3.zAxis
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		local root = MovementController:GetRoot()
		return if root then root.CFrame.LookVector else Vector3.zAxis
	end
	return flat.Unit
end

function CombatController:Attack(kind: string): boolean
	if InputController:IsBlocked() or not MovementController:GetRoot() then
		return false
	end
	if not CombatController:CanAttack(kind) then
		return false
	end
	local def = AbilityConfig.get(ATTACK_ABILITY[kind]) :: any
	lastAttack[kind] = os.clock()
	MovementController.Energy:Spend(def.EnergyCost)
	local dir = facing()
	-- Turn the character toward the swing so the hit arc matches the camera.
	local root = MovementController:GetRoot()
	if root and MovementController:IsGrounded() then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
	Net.action("Attack", { Kind = kind, Facing = dir })
	CombatController.Swing:Fire(kind)
	return true
end

local function releaseAttack()
	local heldAt = attackHeldAt
	attackHeldAt = nil
	if not heldAt then
		return
	end
	local held = os.clock() - heldAt
	if held >= CHARGE_TIME and CombatController:CanAttack("Charged") then
		CombatController:Attack("Charged")
	elseif MovementController:GetState() == "Dash" and CombatController:CanAttack("Dash") then
		CombatController:Attack("Dash")
	else
		CombatController:Attack("Light")
	end
end

-- 0..1 charge for the HUD while the attack button is held.
function CombatController:GetCharge(): number
	if not attackHeldAt or not hasSkill("ChargedStrike") then
		return 0
	end
	return math.clamp((os.clock() - attackHeldAt) / CHARGE_TIME, 0, 1)
end

function CombatController:GetHotbar(): { [string]: string }
	return hotbar
end

function CombatController:Init()
	for _, def in AbilityConfig.List do
		if def.Key and string.sub(def.Key, 1, 7) == "Ability" then
			hotbar[def.Key] = def.Id
		end
	end
	InputController.Pressed:Connect(function(action)
		if action == "Attack" then
			attackHeldAt = os.clock()
		elseif action == "HeavyAttack" then
			CombatController:Attack("Heavy")
		else
			local abilityId = hotbar[action]
			if abilityId then
				local def = AbilityConfig.get(abilityId) :: any
				if not hasSkill(def.RequiresSkill) then
					Bus.toast(def.Name .. " is locked — unlock it in the Skill Tree", "Warning")
				elseif not MovementController:UseAbility(abilityId) then
					if MovementController:CooldownFraction(abilityId) > 0 then
						Bus.toast(def.Name .. " is recharging", "Info")
					end
				end
			end
		end
	end)
	InputController.Released:Connect(function(action)
		if action == "Attack" then
			releaseAttack()
		end
	end)
end

function CombatController:Start() end

return CombatController
