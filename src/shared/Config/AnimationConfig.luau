--!strict
--[[
	AnimationConfig
	Custom animation asset IDs. Roblox's default Animate script already
	handles idle / walk / run / jump / fall / climb (and scales playback with
	character speed). The parkour and combat moves below need custom
	animations: upload them in Studio (Animation Editor -> Publish) and paste
	"rbxassetid://<id>" here.

	While an entry is "" the AnimationController uses a procedural pose
	(body lean / tuck via the root joint) so every move still reads clearly.
]]

local AnimationConfig = {
	-- INSERT ANIMATION IDS HERE ---------------------------------------------
	Ids = {
		Slide = "",
		WallRunLeft = "",
		WallRunRight = "",
		Dash = "",
		AirDash = "",
		DoubleJump = "",
		Mantle = "",
		LedgeHang = "",
		Vault = "",
		Glide = "",
		GroundPound = "",
		ChargeCrouch = "",
		LightAttack1 = "",
		LightAttack2 = "",
		HeavyAttack = "",
		ChargedAttack = "",
		DashAttack = "",
		TitanStomp = "",
		Roar = "",
		Carry = "",
		Throw = "",
		Push = "",
	} :: { [string]: string },

	-- Procedural fallback poses: root-joint rotation (degrees) and vertical
	-- offset (fraction of height) applied while the move is active.
	Procedural = {
		Slide = { Pitch = -55, Roll = 0, Drop = 0.28 },
		WallRunLeft = { Pitch = 0, Roll = 22, Drop = 0 },
		WallRunRight = { Pitch = 0, Roll = -22, Drop = 0 },
		Dash = { Pitch = 18, Roll = 0, Drop = 0 },
		AirDash = { Pitch = 25, Roll = 0, Drop = 0 },
		DoubleJump = { Pitch = -360, Roll = 0, Drop = 0 }, -- a quick flip
		GroundPound = { Pitch = 35, Roll = 0, Drop = 0.15 },
		Glide = { Pitch = 60, Roll = 0, Drop = 0 },
		LedgeHang = { Pitch = -10, Roll = 0, Drop = 0 },
		ChargeCrouch = { Pitch = 15, Roll = 0, Drop = 0.25 },
		Carry = { Pitch = -6, Roll = 0, Drop = 0 },
		HeavyAttack = { Pitch = 20, Roll = 0, Drop = 0.05 },
		TitanStomp = { Pitch = 12, Roll = 0, Drop = 0.1 },
	} :: { [string]: { Pitch: number, Roll: number, Drop: number } },
}

return AnimationConfig
