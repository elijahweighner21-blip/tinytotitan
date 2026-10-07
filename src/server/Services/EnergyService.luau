--!strict
--[[
	EnergyService
	Server-authoritative Energy (stamina). The client predicts energy for
	instant feedback; the server owns the real value and corrects the client
	through the unreliable Energy remote a few times per second.

	Sprinting never stops the player dead: below the threshold they keep a
	reduced sprint (AbilityConfig.ExhaustedSprintFactor), so energy creates
	decisions without frustration.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig = require(Shared.Config.AbilityConfig)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local StatService = require(script.Parent.StatService)
local CharacterService = require(script.Parent.CharacterService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EnergyService = {}

type State = {
	energy: number,
	lastSpend: number,
	sprinting: boolean,
	drains: { [string]: number }, -- continuous drains per second (wall run, glide, climb)
	sprintReported: boolean,
	sentE: number?, -- last values sent to the client
	sentM: number?,
	sentAt: number?,
}

local states: { [Player]: State } = {}

local function stateFor(player: Player): State
	local s = states[player]
	if not s then
		s = {
			energy = StatService:GetDerived(player).MaxEnergy,
			lastSpend = 0,
			sprinting = false,
			drains = {},
			sprintReported = false,
		}
		states[player] = s
	end
	return s
end

function EnergyService:Get(player: Player): number
	return stateFor(player).energy
end

function EnergyService:GetMax(player: Player): number
	return StatService:GetDerived(player).MaxEnergy
end

-- Attempts to spend energy. Returns false (and spends nothing) if short.
function EnergyService:Spend(player: Player, amount: number): boolean
	if amount <= 0 then
		return true
	end
	local s = stateFor(player)
	-- Small tolerance absorbs client/server regen timing differences.
	if s.energy + 2 < amount then
		return false
	end
	s.energy = math.max(0, s.energy - amount)
	s.lastSpend = os.clock()
	return true
end

function EnergyService:Refill(player: Player, fraction: number)
	local s = stateFor(player)
	s.energy = math.min(EnergyService:GetMax(player), s.energy + EnergyService:GetMax(player) * fraction)
end

function EnergyService:SetDrain(player: Player, id: string, perSecond: number?)
	local s = stateFor(player)
	local drains: any = s.drains
	drains[id] = perSecond
end

function EnergyService:IsSprinting(player: Player): boolean
	return stateFor(player).sprinting
end

function EnergyService:Init()
	Net.onAction("Sprint", Guard.boolean(), function(player, on)
		local s = stateFor(player)
		s.sprinting = on
		if on and not s.sprintReported then
			s.sprintReported = true
			GameEvents.fire("Sprinted", player)
		end
	end)
end

function EnergyService:Start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	CharacterService.Spawned:Connect(function(player)
		local s = stateFor(player)
		s.energy = EnergyService:GetMax(player)
		s.sprinting = false
		table.clear(s.drains)
	end)
	local TICK = 0.1
	local syncTimer = 0
	task.spawn(function()
		while true do
			task.wait(TICK)
			syncTimer += TICK
			local sync = syncTimer >= 0.5
			if sync then
				syncTimer = 0
			end
			for _, player in Players:GetPlayers() do
				if PlayerDataService:IsLoaded(player) then
					local s = stateFor(player)
					local derived = StatService:GetDerived(player)
					local max = derived.MaxEnergy
					local drain = 0
					local root = CharacterService:GetRoot(player)
					if s.sprinting and root then
						local v = root.AssemblyLinearVelocity
						if Vector3.new(v.X, 0, v.Z).Magnitude > derived.WalkSpeed * 0.5 then
							drain += AbilityConfig.SprintDrainPerSecond * derived.MovementEnergyMultiplier
						end
					end
					for _, perSecond in s.drains do
						drain += perSecond * derived.MovementEnergyMultiplier
					end
					if drain > 0 then
						s.energy = math.max(0, s.energy - drain * TICK)
						s.lastSpend = os.clock()
					elseif os.clock() - s.lastSpend > AbilityConfig.RegenDelay then
						s.energy = math.min(max, s.energy + derived.EnergyRegen * TICK)
					end
					if s.energy > max then
						s.energy = max
					end
					-- Only correct the client when the value moved (it predicts
					-- regen itself), with a slow keep-alive.
					local changed = math.abs(s.energy - (s.sentE or -1)) >= 1 or math.floor(max) ~= s.sentM
					if sync and (changed or os.clock() - (s.sentAt or 0) > 5) then
						s.sentE, s.sentM, s.sentAt = s.energy, math.floor(max), os.clock()
						Net.energy(player, { E = math.floor(s.energy * 10) / 10, M = math.floor(max) })
					end
				end
			end
		end
	end)
end

return EnergyService
