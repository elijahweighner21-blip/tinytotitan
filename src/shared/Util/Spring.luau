--!strict
--[[
	Spring
	Critically-dampable numeric spring used for camera shake, UI bounce and
	smoothed values. Integrates analytically so it is stable at any frame rate.
]]

export type Spring = {
	Position: number,
	Velocity: number,
	Target: number,
	Speed: number,
	Damper: number,
	Update: (self: Spring, dt: number) -> number,
	Impulse: (self: Spring, v: number) -> (),
}

local Spring = {}
Spring.__index = Spring

function Spring.new(initial: number?, speed: number?, damper: number?): Spring
	local p = initial or 0
	local self = setmetatable({
		Position = p,
		Velocity = 0,
		Target = p,
		Speed = speed or 12,
		Damper = damper or 1,
	}, Spring)
	return (self :: any) :: Spring
end

function Spring.Impulse(self: any, v: number)
	self.Velocity += v
end

function Spring.Update(self: any, dt: number): number
	-- Semi-implicit sub-stepping keeps large dt (lag spikes) from exploding.
	local steps = math.clamp(math.ceil(dt / (1 / 120)), 1, 8)
	local h = dt / steps
	local k = self.Speed * self.Speed
	local c = 2 * self.Damper * self.Speed
	for _ = 1, steps do
		local accel = k * (self.Target - self.Position) - c * self.Velocity
		self.Velocity += accel * h
		self.Position += self.Velocity * h
	end
	return self.Position
end

return Spring
