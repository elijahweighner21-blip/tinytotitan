--!strict
--[[
	SettingsConfig
	Player-facing settings metadata (labels, ranges, order) used by the
	Settings menu, plus graphics presets. Defaults and server-side validation
	live in Data/DataSchema so they can never disagree.
]]

export type SettingDef = {
	Key: string,
	Label: string,
	Kind: "Slider" | "Toggle" | "Choice",
	Section: string,
	Min: number?,
	Max: number?,
	Step: number?,
	Choices: { string }?,
	Hint: string?,
}

local Settings: { SettingDef } = {
	{ Key = "MusicVolume", Label = "Music", Kind = "Slider", Section = "Audio", Min = 0, Max = 1, Step = 0.05 },
	{ Key = "SfxVolume", Label = "Sound Effects", Kind = "Slider", Section = "Audio", Min = 0, Max = 1, Step = 0.05 },
	{ Key = "AmbientVolume", Label = "Ambience", Kind = "Slider", Section = "Audio", Min = 0, Max = 1, Step = 0.05 },
	{ Key = "PerformancePreset", Label = "Graphics Preset", Kind = "Choice", Section = "Graphics", Choices = { "Auto", "Low", "Medium", "High" }, Hint = "Auto adapts to your frame rate." },
	{ Key = "Particles", Label = "Particles", Kind = "Slider", Section = "Graphics", Min = 0, Max = 1, Step = 0.1 },
	{ Key = "HideOtherEffects", Label = "Hide Other Players' Effects", Kind = "Toggle", Section = "Graphics" },
	{ Key = "CameraShake", Label = "Camera Shake", Kind = "Slider", Section = "Comfort", Min = 0, Max = 1, Step = 0.1 },
	{ Key = "MotionEffects", Label = "Motion Effects (speed lines, tilt)", Kind = "Toggle", Section = "Comfort" },
	{ Key = "ScreenFlashes", Label = "Screen Flashes", Kind = "Toggle", Section = "Comfort" },
	{ Key = "FovEffects", Label = "Speed FOV Changes", Kind = "Toggle", Section = "Comfort" },
	{ Key = "FieldOfView", Label = "Field of View", Kind = "Slider", Section = "Comfort", Min = 60, Max = 100, Step = 1 },
	{ Key = "UIScale", Label = "UI Scale", Kind = "Slider", Section = "Interface", Min = 0.7, Max = 1.3, Step = 0.05 },
	{ Key = "DamageNumbers", Label = "Damage Numbers", Kind = "Toggle", Section = "Interface" },
	{ Key = "ShowTitles", Label = "Show Titles Above Players", Kind = "Toggle", Section = "Interface" },
	{ Key = "SprintToggle", Label = "Sprint Toggle (instead of hold)", Kind = "Toggle", Section = "Controls" },
}

export type Preset = {
	Particles: number,
	Shadows: boolean,
	Trails: boolean,
	EnvironmentDetail: boolean,
	OtherPlayerEffects: number,
	MaxParticlesPerEmit: number,
	PostEffects: boolean,
}

local Presets: { [string]: Preset } = {
	Low = { Particles = 0.3, Shadows = false, Trails = false, EnvironmentDetail = false, OtherPlayerEffects = 3, MaxParticlesPerEmit = 8, PostEffects = false },
	Medium = { Particles = 0.65, Shadows = true, Trails = true, EnvironmentDetail = true, OtherPlayerEffects = 8, MaxParticlesPerEmit = 20, PostEffects = true },
	High = { Particles = 1, Shadows = true, Trails = true, EnvironmentDetail = true, OtherPlayerEffects = 12, MaxParticlesPerEmit = 40, PostEffects = true },
}

local SettingsConfig = {
	Settings = Settings,
	Sections = { "Audio", "Graphics", "Comfort", "Interface", "Controls" },
	Presets = Presets,
	-- Auto preset: drops to a lower tier when FPS stays below these values.
	AutoThresholds = { HighToMedium = 45, MediumToLow = 30, Recover = 57, Window = 4 },
}

return SettingsConfig
