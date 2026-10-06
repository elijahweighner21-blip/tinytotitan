--!strict
--[[
	EnergyModel
	Client-side prediction of the server's Energy so the bar and ability
	checks feel instant. The server's value wins whenever they disagree by
	more than a small tolerance (Sync), so prediction can never be used to
	gain energy.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AbilityConfig = require(Shared.Config.AbilityConfig)

export type EnergyModel = {
	Value: number,
	Max: number,
	Regen: number,
	LastSpend: number,
	Spend: (self: EnergyModel, amount: number) -> boolean,
	Drain: (self: EnergyModel, perSecond: number, dt: number) -> (),
	Tick: (self: EnergyModel, dt: number, draining: boolean) -> (),
	Sync: (self: EnergyModel, server: number, max: number) -> (),
	Fraction: (self: EnergyModel) -> number,
}

local EnergyModel = {}
EnergyModel.__index = EnergyModel

function EnergyModel.new(): EnergyModel
	local self = setmetatable({
		Value = AbilityConfig.BaseMaxEnergy,
		Max = AbilityConfig.BaseMaxEnergy,
		Regen = AbilityConfig.BaseRegenPerSecond,
		LastSpend = 0,
	}, EnergyModel)
	return (self :: any) :: EnergyModel
end

function EnergyModel.Spend(self: any, amount: number): boolean
	if amount <= 0 then
		return true
	end
	if self.Value + 1 < amount then
		return false
	end
	self.Value = math.max(0, self.Value - amount)
	self.LastSpend = os.clock()
	return true
end

function EnergyModel.Drain(self: any, perSecond: number, dt: number)
	self.Value = math.max(0, self.Value - perSecond * dt)
	self.LastSpend = os.clock()
end

function EnergyModel.Tick(self: any, dt: number, draining: boolean)
	if not draining and os.clock() - self.LastSpend > AbilityConfig.RegenDelay then
		self.Value = math.min(self.Max, self.Value + self.Regen * dt)
	end
end

function EnergyModel.Sync(self: any, server: number, max: number)
	self.Max = max
	if math.abs(server - self.Value) > 6 then
		self.Value = server
	end
	self.Value = math.min(self.Value, self.Max)
end

function EnergyModel.Fraction(self: any): number
	return if self.Max > 0 then self.Value / self.Max else 0
end

return EnergyModel
