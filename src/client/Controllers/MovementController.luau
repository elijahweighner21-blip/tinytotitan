--!strict
--[[
	MovementController
	The parkour system. A single explicit state machine drives the character:

	  Idle, Walk, Sprint, Jump, Fall, Slide, Charge, Dash, WallRun,
	  LedgeHang, GroundPound, Glide, Frozen, Dead

	`ALLOWED` lists every legal transition, so impossible combinations
	(sliding + wall running + ground pounding) cannot happen.

	Feel features: acceleration-smoothed speed, size-scaled custom gravity
	(heavier titans, floatier specks), coyote time, jump buffering, variable
	jump height (release early to cut the jump), terminal velocity clamp,
	landing detection with fall height.

	Authority: the client moves instantly; every ability is reported to the
	server (AbilityService), which charges energy/cooldowns and may reject.
	Rejections resync energy and cooldowns here. Abilities are blocked while
	a menu is open; everything stops while dead or frozen (countdowns).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig = require(Shared.Config.AbilityConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Stats = require(Shared.Formulas.Stats)
local Signal = require(Shared.Util.Signal)
local Trove = require(Shared.Util.Trove)
local MathUtil = require(Shared.Util.MathUtil)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local Probe = require(Client.Movement.Probe)
local EnergyModel = require(Client.Movement.EnergyModel)
local DataController = require(script.Parent.DataController)
local InputController = require(script.Parent.InputController)
local SettingsController = require(script.Parent.SettingsController)

local MovementController = {}

MovementController.StateChanged = Signal.new() :: Signal.Signal<string, string>
MovementController.Jumped = Signal.new() :: Signal.Signal<string>
MovementController.Landed = Signal.new() :: Signal.Signal<number, boolean>
MovementController.Footstep = Signal.new() :: Signal.Signal<Vector3, number, Enum.Material>
MovementController.AbilityUsed = Signal.new() :: Signal.Signal<string>
MovementController.Energy = EnergyModel.new()

local player = Players.LocalPlayer

local ALLOWED: { [string]: { [string]: boolean } } = {
	Idle = {
		Walk = true,
		Sprint = true,
		Jump = true,
		Fall = true,
		Slide = false,
		Charge = true,
		Dash = true,
		Frozen = true,
		Dead = true,
	},
	Walk = {
		Idle = true,
		Sprint = true,
		Jump = true,
		Fall = true,
		Charge = true,
		Dash = true,
		Frozen = true,
		Dead = true,
	},
	Sprint = {
		Idle = true,
		Walk = true,
		Jump = true,
		Fall = true,
		Slide = true,
		Dash = true,
		Frozen = true,
		Dead = true,
	},
	Jump = {
		Fall = true,
		Idle = true,
		Walk = true,
		Sprint = true,
		Dash = true,
		WallRun = true,
		LedgeHang = true,
		GroundPound = true,
		Glide = true,
		Jump = true,
		Frozen = true,
		Dead = true,
	},
	Fall = {
		Idle = true,
		Walk = true,
		Sprint = true,
		Jump = true,
		Dash = true,
		WallRun = true,
		LedgeHang = true,
		GroundPound = true,
		Glide = true,
		Frozen = true,
		Dead = true,
	},
	Slide = { Idle = true, Walk = true, Sprint = true, Jump = true, Fall = true, Frozen = true, Dead = true },
	Charge = { Idle = true, Walk = true, Jump = true, Fall = true, Frozen = true, Dead = true },
	Dash = {
		Idle = true,
		Walk = true,
		Sprint = true,
		Fall = true,
		Jump = true,
		WallRun = true,
		Frozen = true,
		Dead = true,
	},
	WallRun = { Jump = true, Fall = true, Idle = true, Walk = true, Sprint = true, Frozen = true, Dead = true },
	LedgeHang = { Jump = true, Fall = true, Frozen = true, Dead = true },
	GroundPound = { Idle = true, Walk = true, Sprint = true, Frozen = true, Dead = true },
	Glide = {
		Fall = true,
		Idle = true,
		Walk = true,
		Sprint = true,
		Jump = true,
		Dash = true,
		GroundPound = true,
		Frozen = true,
		Dead = true,
	},
	Frozen = { Idle = true, Fall = true, Dead = true },
	Dead = {},
}

type Ctx = {
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Force: VectorForce,
	Trove: Trove.Trove,
	State: string,
	StateTime: number,
	Derived: Stats.Derived,
	Height: number,
	Speed: number,
	Coyote: number,
	JumpBuffer: number,
	AirJumps: number,
	AirDashes: number,
	PeakY: number,
	WasGrounded: boolean,
	ForceVelocityY: number?,
	ForceFrames: number,
	DashVelocity: Vector3,
	WallNormal: Vector3,
	WallSide: number,
	LedgeTop: Vector3?,
	Charge: number,
	Sprinting: boolean,
	SprintReported: boolean,
	StepTimer: number,
	SlowUntil: number,
	JumpCut: boolean,
	SlideDir: Vector3,
	LastWallRun: number,
}

local ctx: Ctx? = nil
local sprintToggled = false
local lastUse: { [string]: number } = {}
local jumpHeld = false

------------------------------------------------------------------ helpers

local function hasSkill(skillId: string): boolean
	local data = DataController:Get()
	return data ~= nil and data.Skills[skillId] == true
end

local function canUse(abilityId: string): boolean
	local def = AbilityConfig.get(abilityId)
	if not def then
		return false
	end
	if def.RequiresSkill and not hasSkill(def.RequiresSkill) then
		return false
	end
	local c = ctx
	local mult = if c then c.Derived.CooldownMultiplier else 1
	local last = lastUse[abilityId]
	if last and os.clock() - last < def.Cooldown * mult then
		return false
	end
	local cost = def.EnergyCost * (if def.Kind == "Movement" and c then c.Derived.MovementEnergyMultiplier else 1)
	return MovementController.Energy.Value + 1 >= cost
end

-- Charges locally and tells the server. Returns false if not allowed.
local function useAbility(abilityId: string): boolean
	if InputController:IsBlocked() or not canUse(abilityId) then
		return false
	end
	local def = AbilityConfig.get(abilityId) :: any
	local c = ctx
	local cost = def.EnergyCost * (if def.Kind == "Movement" and c then c.Derived.MovementEnergyMultiplier else 1)
	MovementController.Energy:Spend(cost)
	lastUse[abilityId] = os.clock()
	Net.action("Ability", { Id = abilityId })
	MovementController.AbilityUsed:Fire(abilityId)
	return true
end

local function setState(c: Ctx, new: string)
	local old = c.State
	if old == new then
		return
	end
	if not ALLOWED[old] or not ALLOWED[old][new] then
		return
	end
	-- Exit hooks for continuous abilities.
	if old == "WallRun" then
		Net.action("Ability", { Id = "WallRunEnd" })
		c.LastWallRun = os.clock()
	elseif old == "Glide" then
		Net.action("Ability", { Id = "GlideEnd" })
	end
	c.State = new
	c.StateTime = 0
	MovementController.StateChanged:Fire(new, old)
end

local function grounded(c: Ctx): boolean
	return c.Humanoid.FloorMaterial ~= Enum.Material.Air
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function lookFlat(c: Ctx): Vector3
	local camera = workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else c.Root.CFrame.LookVector
	local f = flat(look)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function moveDir(c: Ctx): Vector3
	local md = c.Humanoid.MoveDirection
	return if md.Magnitude > 0.05 then flat(md).Unit else Vector3.zero
end

local function jumpVelocity(c: Ctx, heightMultiplier: number): number
	return math.sqrt(2 * c.Derived.Gravity * c.Derived.JumpHeight * heightMultiplier)
end

local function launch(c: Ctx, velocity: Vector3, kind: string)
	c.Root.AssemblyLinearVelocity = velocity
	c.ForceVelocityY = velocity.Y
	c.ForceFrames = 2
	c.Coyote = 0
	c.JumpBuffer = 0
	c.JumpCut = false
	c.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	setState(c, "Jump")
	c.PeakY = c.Root.Position.Y
	MovementController.Jumped:Fire(kind)
	if kind == "Jump" then
		Net.action("Ability", { Id = "Jump" })
	end
end

------------------------------------------------------------------ actions

local function tryJump(c: Ctx): boolean
	local v = c.Root.AssemblyLinearVelocity
	local isGrounded = grounded(c) or c.Coyote > 0
	if c.State == "LedgeHang" and c.LedgeTop then
		if not useAbility("Mantle") then
			return false
		end
		local feetY = c.Root.Position.Y - c.Height * 0.5
		local rise = math.max(0, c.LedgeTop.Y - feetY) + c.Height * 0.35
		local up = math.sqrt(2 * c.Derived.Gravity * rise)
		launch(c, Vector3.new(0, up, 0) - c.WallNormal * c.Derived.WalkSpeed * 0.6, "Mantle")
		return true
	end
	if c.State == "WallRun" then
		if not useAbility("WallJump") then
			return false
		end
		local jv = jumpVelocity(c, 1)
		launch(c, c.WallNormal * jv * 0.6 + flat(v) * 0.6 + Vector3.new(0, jv * 0.9, 0), "WallJump")
		return true
	end
	if isGrounded then
		if c.State == "Charge" and c.Charge > 0.15 then
			local t = math.clamp(c.Charge / AbilityConfig.ChargedLeapMaxCharge, 0, 1)
			local mega = t >= 0.99 and hasSkill("MegaJump") and canUse("MegaJump")
			local id = if mega then "MegaJump" else "ChargedLeap"
			if useAbility(id) then
				local mult = if mega
					then AbilityConfig.MegaJumpHeightMultiplier
					else 1 + (AbilityConfig.ChargedLeapHeightMultiplier - 1) * t
				launch(c, flat(v) + Vector3.new(0, jumpVelocity(c, mult), 0), id)
				return true
			end
		end
		if c.State == "Slide" and hasSkill("LongJump") and useAbility("LongJump") then
			local dir = if c.SlideDir.Magnitude > 0 then c.SlideDir else lookFlat(c)
			launch(
				c,
				dir * c.Derived.SprintSpeed * AbilityConfig.LongJumpDistanceMultiplier
					+ Vector3.new(0, jumpVelocity(c, 0.7), 0),
				"LongJump"
			)
			return true
		end
		launch(c, flat(v) + Vector3.new(0, jumpVelocity(c, 1), 0), "Jump")
		return true
	end
	-- Airborne: wall jump first, then double jump.
	if hasSkill("WallJump") then
		local wall = Probe.wallAhead(c.Root, c.Height, moveDir(c) + lookFlat(c) * 0.01, 0.8)
		local side, sideDir = Probe.sideWall(c.Root, c.Height, 0.75)
		local hit = wall or side
		if hit and sideDir ~= nil and useAbility("WallJump") then
			local jv = jumpVelocity(c, 1)
			launch(c, hit.Normal * jv * 0.6 + Vector3.new(0, jv * 0.9, 0), "WallJump")
			return true
		end
	end
	if c.AirJumps < 1 and hasSkill("DoubleJump") and useAbility("DoubleJump") then
		c.AirJumps += 1
		local dir = moveDir(c)
		local horizontal = if dir.Magnitude > 0 then dir * math.max(flat(v).Magnitude, c.Derived.WalkSpeed) else flat(v)
		launch(c, horizontal + Vector3.new(0, jumpVelocity(c, 0.9), 0), "DoubleJump")
		return true
	end
	return false
end

local function tryDash(c: Ctx)
	if c.State == "LedgeHang" or c.State == "GroundPound" or c.State == "Dead" or c.State == "Frozen" then
		return
	end
	local air = not grounded(c)
	if air and c.AirDashes >= 1 then
		return
	end
	local id = if air then "AirDash" else "GroundDash"
	if not useAbility(id) then
		return
	end
	if air then
		c.AirDashes += 1
	end
	local dir = moveDir(c)
	if dir.Magnitude < 0.1 then
		dir = lookFlat(c)
	end
	local speed = AbilityConfig.DashDistanceBodies * c.Height / AbilityConfig.DashDuration
	c.DashVelocity = dir * speed
	setState(c, "Dash")
end

local function onCrouchPressed(c: Ctx)
	if InputController:IsBlocked() then
		return
	end
	if c.State == "LedgeHang" then
		setState(c, "Fall")
		return
	end
	if not grounded(c) then
		if hasSkill("GroundPound") and c.State ~= "GroundPound" then
			local feet = c.Root.Position - Vector3.new(0, c.Height * 0.5, 0)
			local dist = Probe.groundDistance(feet, c.Height, 50)
			if (not dist or dist > c.Height * 0.8) and useAbility("GroundPound") then
				setState(c, "GroundPound")
			end
		end
		return
	end
	if c.State == "Sprint" and hasSkill("Slide") and useAbility("Slide") then
		local dir = moveDir(c)
		c.SlideDir = if dir.Magnitude > 0 then dir else lookFlat(c)
		setState(c, "Slide")
		return
	end
	if (c.State == "Idle" or c.State == "Walk") and hasSkill("ChargedLeap") then
		c.Charge = 0
		setState(c, "Charge")
	end
end

------------------------------------------------------------------ per-frame

local function refreshDerived(c: Ctx)
	c.Derived = DataController:GetDerived()
	c.Height = ScaleMath.height(c.Derived.Scale)
	MovementController.Energy.Max = c.Derived.MaxEnergy
	MovementController.Energy.Regen = c.Derived.EnergyRegen
end

local function landed(c: Ctx)
	local fall = math.max(0, c.PeakY - c.Root.Position.Y)
	local pound = c.State == "GroundPound"
	local bodies = fall / math.max(c.Height, 0.01)
	MovementController.Landed:Fire(bodies, pound)
	if pound or bodies > 2.5 then
		Net.action("Landed", { Height = fall, Pound = pound })
	end
	c.AirJumps = 0
	c.AirDashes = 0
	local dir = moveDir(c)
	setState(c, if dir.Magnitude > 0 then (if c.Sprinting then "Sprint" else "Walk") else "Idle")
end

local function stepPhysics(dt: number)
	local c = ctx
	if not c then
		return
	end
	local humanoid, root = c.Humanoid, c.Root
	if humanoid.Health <= 0 then
		setState(c, "Dead")
		return
	end
	if root.Anchored then
		setState(c, "Frozen")
		c.Force.Force = Vector3.zero
		return
	elseif c.State == "Frozen" then
		setState(c, "Fall")
	end
	c.StateTime += dt
	local derived = c.Derived
	local now = os.clock()
	local isGrounded = grounded(c)
	local v = root.AssemblyLinearVelocity

	-- Ground bookkeeping, coyote time and landing.
	if isGrounded then
		if
			not c.WasGrounded
			and (c.State == "Jump" or c.State == "Fall" or c.State == "GroundPound" or c.State == "Glide" or c.State == "Dash")
			and c.ForceFrames <= 0
		then
			landed(c)
		end
		c.Coyote = AbilityConfig.CoyoteTime
		c.PeakY = root.Position.Y
	else
		c.Coyote = math.max(0, c.Coyote - dt)
		c.PeakY = math.max(c.PeakY, root.Position.Y)
		if c.State == "Idle" or c.State == "Walk" or c.State == "Sprint" or c.State == "Charge" then
			setState(c, "Fall")
		end
	end
	c.WasGrounded = isGrounded

	-- Jump buffering.
	if c.JumpBuffer > 0 then
		c.JumpBuffer -= dt
		if tryJump(c) then
			c.JumpBuffer = 0
		end
	end

	local dir = moveDir(c)
	local gravityScale = 1
	local blocked = InputController:IsBlocked()

	-- State behaviour.
	local state = c.State
	if state == "Dash" then
		local vertical = if isGrounded then v.Y else 0
		root.AssemblyLinearVelocity = c.DashVelocity + Vector3.new(0, vertical, 0)
		gravityScale = if isGrounded then 1 else 0
		if c.StateTime >= AbilityConfig.DashDuration then
			root.AssemblyLinearVelocity = c.DashVelocity * 0.4 + Vector3.new(0, vertical, 0)
			setState(c, if isGrounded then "Walk" else "Fall")
		end
	elseif state == "Slide" then
		local t = math.clamp(c.StateTime / 0.8, 0, 1)
		local speed = MathUtil.lerp(derived.SprintSpeed * 1.35, derived.WalkSpeed * 0.8, t)
		root.AssemblyLinearVelocity = c.SlideDir * speed + Vector3.new(0, math.min(v.Y, 0), 0)
		if t >= 1 or not InputController:IsHeld("Crouch") and c.StateTime > 0.25 then
			setState(c, if dir.Magnitude > 0 then "Sprint" else "Idle")
		end
	elseif state == "Charge" then
		c.Charge = math.min(AbilityConfig.ChargedLeapMaxCharge, c.Charge + dt)
		if not InputController:IsHeld("Crouch") then
			c.Charge = 0
			setState(c, "Idle")
		end
	elseif state == "GroundPound" then
		local down = jumpVelocity(c, 1) * 2.2
		root.AssemblyLinearVelocity = Vector3.new(0, -down, 0)
	elseif state == "Glide" then
		local maxFall = AbilityConfig.GlideFallSpeedBodies * c.Height
		local horizontal = if dir.Magnitude > 0 then dir * derived.WalkSpeed * 1.3 else flat(v) * 0.98
		root.AssemblyLinearVelocity = Vector3.new(horizontal.X, math.max(v.Y, -maxFall), horizontal.Z)
		gravityScale = 0.25
		MovementController.Energy:Drain(AbilityConfig.GlideDrainPerSecond * derived.MovementEnergyMultiplier, dt)
		if not jumpHeld or MovementController.Energy.Value <= 0 or isGrounded then
			setState(c, if isGrounded then "Idle" else "Fall")
		end
	elseif state == "WallRun" then
		local wall, side = Probe.sideWall(root, c.Height, 0.8)
		if
			not wall
			or c.StateTime > AbilityConfig.WallRunDurationMax
			or isGrounded
			or MovementController.Energy.Value <= 0
		then
			setState(c, if isGrounded then "Walk" else "Fall")
		else
			c.WallNormal = wall.Normal
			c.WallSide = side
			local tangent = wall.Normal:Cross(Vector3.yAxis)
			if tangent:Dot(flat(v)) < 0 then
				tangent = -tangent
			end
			local rise = jumpVelocity(c, 1) * 0.35 * (1 - c.StateTime / AbilityConfig.WallRunDurationMax)
			root.AssemblyLinearVelocity = tangent.Unit
					* derived.SprintSpeed
					* (1 + derived.ClimbSpeed / math.max(derived.WalkSpeed, 1) * 0.05)
				- wall.Normal * c.Height * 0.5
				+ Vector3.new(0, rise - c.Height * 0.4 * c.StateTime, 0)
			gravityScale = 0
			MovementController.Energy:Drain(AbilityConfig.WallRunDrainPerSecond * derived.MovementEnergyMultiplier, dt)
		end
	elseif state == "LedgeHang" then
		root.AssemblyLinearVelocity = Vector3.zero
		gravityScale = 0
		if c.StateTime > 4 then
			setState(c, "Fall")
		end
	elseif state == "Jump" or state == "Fall" then
		-- Variable jump height: releasing jump early cuts the ascent.
		if state == "Jump" and not jumpHeld and not c.JumpCut and v.Y > 0 and c.StateTime > 0.06 then
			c.JumpCut = true
			root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y * 0.55, v.Z)
		end
		if v.Y <= 0 and state == "Jump" then
			setState(c, "Fall")
		end
		-- Air control: steer toward input without exceeding sprint speed.
		if dir.Magnitude > 0 then
			local hv = flat(v)
			local target = dir * math.max(hv.Magnitude, derived.WalkSpeed)
			local steer = hv:Lerp(target, math.clamp(derived.AirControl * dt * 4, 0, 1))
			root.AssemblyLinearVelocity = Vector3.new(steer.X, root.AssemblyLinearVelocity.Y, steer.Z)
		end
		if not blocked then
			-- Glide when holding jump while falling.
			if
				jumpHeld
				and v.Y < 0
				and c.StateTime > 0.15
				and hasSkill("Glide")
				and MovementController.Energy.Value > 5
				and useAbility("Glide")
			then
				setState(c, "Glide")
			-- Ledge grab when moving into a wall near its top.
			elseif v.Y < jumpVelocity(c, 1) * 0.35 and dir.Magnitude > 0 then
				local top, normal = Probe.ledge(root, c.Height, dir, 0.35, 1.25)
				if top and normal then
					c.LedgeTop = top
					c.WallNormal = normal
					setState(c, "LedgeHang")
				elseif
					c.Sprinting
					and hasSkill("WallRun")
					and now - c.LastWallRun > 0.5
					and flat(v).Magnitude > derived.WalkSpeed * 0.8
				then
					local wall = Probe.sideWall(root, c.Height, 0.7)
					if wall and useAbility("WallRun") then
						setState(c, "WallRun")
					end
				end
			end
		end
	elseif state == "Idle" or state == "Walk" or state == "Sprint" then
		if dir.Magnitude > 0 then
			setState(c, if c.Sprinting then "Sprint" else "Walk")
		else
			setState(c, "Idle")
		end
		-- Vault over low obstacles while sprinting.
		if c.State == "Sprint" and hasSkill("Vault") and not blocked then
			local h = Probe.vaultable(root, c.Height, dir)
			if h and h > c.Height * 0.2 and h < c.Height * 0.75 and useAbility("Vault") then
				local up = math.sqrt(2 * derived.Gravity * (h + c.Height * 0.15))
				launch(c, dir * math.max(flat(v).Magnitude, derived.SprintSpeed) + Vector3.new(0, up, 0), "Vault")
			end
		end
	end

	-- Forced launch velocity survives the humanoid's state change for 2 frames.
	if c.ForceFrames > 0 and c.ForceVelocityY then
		local cur = root.AssemblyLinearVelocity
		if cur.Y < (c.ForceVelocityY :: number) * 0.9 then
			root.AssemblyLinearVelocity = Vector3.new(cur.X, c.ForceVelocityY :: number, cur.Z)
		end
		c.ForceFrames -= 1
	end

	-- Terminal velocity (prevents tunnelling through thin floors).
	local cur = root.AssemblyLinearVelocity
	local terminal = jumpVelocity(c, 1) * 4
	if cur.Y < -terminal and c.State ~= "GroundPound" then
		root.AssemblyLinearVelocity = Vector3.new(cur.X, -terminal, cur.Z)
	end

	-- Custom gravity: extra downward force so effective g matches the size.
	local mass = root.AssemblyMass
	local extra = derived.Gravity * gravityScale - workspace.Gravity
	c.Force.Force = Vector3.new(0, -mass * extra, 0)
end

local function stepSpeed(dt: number)
	local c = ctx
	if not c then
		return
	end
	local derived = c.Derived
	local energy = MovementController.Energy
	local moving = c.Humanoid.MoveDirection.Magnitude > 0.05
	local wantSprint = (
		if SettingsController:Get("SprintToggle") then sprintToggled else InputController:IsHeld("Sprint")
	) and moving
	local sprinting = wantSprint and c.State ~= "Charge"
	if sprinting ~= c.Sprinting then
		c.Sprinting = sprinting
		Net.action("Sprint", sprinting)
	end
	local target = derived.WalkSpeed
	if c.Sprinting then
		local exhausted = energy.Value < 3
		target = if exhausted
			then derived.WalkSpeed + (derived.SprintSpeed - derived.WalkSpeed) * AbilityConfig.ExhaustedSprintFactor
			else derived.SprintSpeed
		energy:Drain(AbilityConfig.SprintDrainPerSecond * derived.MovementEnergyMultiplier, dt)
	end
	if c.State == "Charge" then
		target = derived.WalkSpeed * 0.25
	end
	if os.clock() < c.SlowUntil then
		target *= 0.3
	end
	-- Acceleration: ramp WalkSpeed toward the target speed.
	local accel = derived.Acceleration * derived.WalkSpeed
	if not moving then
		c.Speed = derived.WalkSpeed * 0.35
	else
		c.Speed = MathUtil.approach(c.Speed, target, accel * dt)
	end
	c.Humanoid.WalkSpeed = c.Speed
	local draining = c.Sprinting or c.State == "WallRun" or c.State == "Glide"
	energy:Tick(dt, draining)

	-- Footsteps scale with stride length.
	if grounded(c) and moving then
		c.StepTimer -= dt
		if c.StepTimer <= 0 then
			local stride = c.Height * (if c.Sprinting then 0.55 else 0.42)
			c.StepTimer = stride / math.max(c.Humanoid.WalkSpeed, 0.1)
			MovementController.Footstep:Fire(
				c.Root.Position - Vector3.new(0, c.Height * 0.5, 0),
				c.Derived.Scale,
				c.Humanoid.FloorMaterial
			)
		end
	end
end

------------------------------------------------------------------ setup

local function onCharacter(character: Model)
	if ctx then
		ctx.Trove:Destroy()
		ctx = nil
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	local trove = Trove.new()
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.AutoJumpEnabled = false
	local attachment = trove:Add(Instance.new("Attachment"))
	attachment.Name = "TTGravity"
	attachment.Parent = root
	local force = trove:Add(Instance.new("VectorForce"))
	force.Name = "TTGravity"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	force.Parent = root
	local c: Ctx = {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Force = force,
		Trove = trove,
		State = "Idle",
		StateTime = 0,
		Derived = DataController:GetDerived(),
		Height = 5,
		Speed = 0,
		Coyote = 0,
		JumpBuffer = 0,
		AirJumps = 0,
		AirDashes = 0,
		PeakY = root.Position.Y,
		WasGrounded = true,
		ForceVelocityY = nil,
		ForceFrames = 0,
		DashVelocity = Vector3.zero,
		WallNormal = Vector3.zero,
		WallSide = 0,
		LedgeTop = nil,
		Charge = 0,
		Sprinting = false,
		SprintReported = false,
		StepTimer = 0,
		SlowUntil = 0,
		JumpCut = false,
		SlideDir = Vector3.zero,
		LastWallRun = 0,
	}
	refreshDerived(c)
	ctx = c
	Probe.refresh()
	trove:Connect(humanoid.Died, function()
		setState(c, "Dead")
		force.Force = Vector3.zero
	end)
	trove:Add(DataController.StatsChanged:Connect(function()
		refreshDerived(c)
	end))
	trove:Connect(character.AncestryChanged, function(_, parent)
		if not parent and ctx == c then
			trove:Destroy()
			ctx = nil
		end
	end)
	trove:Add(function()
		jumpHeld = false
	end)
end

function MovementController:GetState(): string
	return if ctx then ctx.State else "Dead"
end

function MovementController:IsGrounded(): boolean
	local c = ctx
	return c ~= nil and grounded(c)
end

function MovementController:IsSprinting(): boolean
	return ctx ~= nil and (ctx :: Ctx).Sprinting
end

function MovementController:GetHeight(): number
	return if ctx then ctx.Height else 5
end

function MovementController:GetCharge(): number
	return if ctx then ctx.Charge / AbilityConfig.ChargedLeapMaxCharge else 0
end

function MovementController:GetRoot(): BasePart?
	return if ctx then ctx.Root else nil
end

-- Used by the growth sequence: briefly slows the player.
-- -1 / 1 for a wall on the left / right while wall running, else 0.
function MovementController:GetWallSide(): number
	return if ctx then ctx.WallSide else 0
end

function MovementController:Slow(seconds: number)
	if ctx then
		ctx.SlowUntil = os.clock() + seconds
	end
end

function MovementController:CooldownFraction(abilityId: string): number
	local def = AbilityConfig.get(abilityId)
	local last = lastUse[abilityId]
	if not def or not last then
		return 0
	end
	local cd = def.Cooldown * (if ctx then ctx.Derived.CooldownMultiplier else 1)
	return math.clamp(1 - (os.clock() - last) / math.max(cd, 0.01), 0, 1)
end

-- Server-executed abilities (keys 1-6) go through the same local gating.
function MovementController:UseAbility(abilityId: string): boolean
	return useAbility(abilityId)
end

function MovementController:Init()
	InputController.Pressed:Connect(function(action)
		local c = ctx
		if action == "Jump" then
			jumpHeld = true
			if c then
				c.JumpBuffer = AbilityConfig.JumpBufferTime
			end
		elseif action == "Sprint" then
			sprintToggled = not sprintToggled
		elseif action == "Crouch" and c then
			onCrouchPressed(c)
		elseif action == "Dash" and c and not InputController:IsBlocked() then
			tryDash(c)
		end
	end)
	InputController.Released:Connect(function(action)
		if action == "Jump" then
			jumpHeld = false
		end
	end)
	Net.onEnergy(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if type(payload.E) == "number" and type(payload.M) == "number" then
			MovementController.Energy:Sync(payload.E, payload.M)
		end
		if type(payload.Reject) == "string" and payload.Why == "cooldown" then
			lastUse[payload.Reject] = os.clock()
		end
	end)
end

function MovementController:Start()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	Players.PlayerAdded:Connect(function(other)
		other.CharacterAdded:Connect(function()
			task.defer(Probe.refresh)
		end)
	end)
	RunService.PreSimulation:Connect(stepPhysics)
	RunService.Heartbeat:Connect(stepSpeed)
end

return MovementController
