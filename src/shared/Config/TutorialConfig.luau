--!strict
--[[
	TutorialConfig
	Teach-by-playing tutorial. Each step shows a short hint (one line, no walls
	of text) and completes when the matching gameplay event happens. Steps are
	acknowledged on the server through GameEvents, never by the client saying
	"done", so the tutorial cannot be used to farm rewards.
]]

export type Step = { Id: string, Hint: string, MobileHint: string?, GamepadHint: string?, Event: string, Count: number? }

local Steps: { Step } = {
	{
		Id = "Move",
		Hint = "Move with WASD",
		MobileHint = "Move with the left stick",
		GamepadHint = "Move with the left stick",
		Event = "Moved",
	},
	{
		Id = "Jump",
		Hint = "Press SPACE to jump",
		MobileHint = "Tap the jump button",
		GamepadHint = "Press A to jump",
		Event = "Jumped",
	},
	{ Id = "Orb", Hint = "Collect the glowing Growth Orb", Event = "OrbCollected" },
	{ Id = "Parkour", Hint = "Climb the crumbs to the marked ledge", Event = "Discovered" },
	{ Id = "Mass", Hint = "Mass makes you grow. Fill the Size bar!", Event = "MassEarned", Count = 3 },
	{
		Id = "Upgrade",
		Hint = "Press U to open Upgrades and buy one",
		MobileHint = "Tap ⬆ to open Upgrades and buy one",
		GamepadHint = "Press D-pad Up to open Upgrades",
		Event = "UpgradeBought",
	},
	{ Id = "Grow", Hint = "Reach Dust-Sized", Event = "TierUp" },
	{
		Id = "Sprint",
		Hint = "Hold SHIFT to sprint",
		MobileHint = "Tap 🏃 to sprint",
		GamepadHint = "Click the left stick to sprint",
		Event = "Sprinted",
	},
}

local TutorialConfig = {
	Steps = Steps,
	-- Highlighted target shown after the player grows: something they could
	-- not reach before (the Crumb Mountain ledge, then the shoe).
	FirstGoalDiscovery = "CrumbMountain",
	BigGoalDiscovery = "ShoeSummit",
}

return TutorialConfig
