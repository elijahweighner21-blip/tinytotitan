-- Builds every enemy and boss body side by side (same scale) on a plain
-- floor and dumps it in the export.luau format, for judging creature art.
local E = __E
local HttpService = E.game:GetService("HttpService")
local CreatureBuilder = E.serverModule("World.CreatureBuilder")
local EnemyConfig = E.sharedModule("Config.EnemyConfig")
local BossConfig = E.sharedModule("Config.BossConfig")

local folder = E.new("Folder")
folder.Name = "Lineup"
folder.Parent = E.workspace
local floor = E.new("Part")
floor.Size = Vector3.new(400, 1, 60)
floor.Position = Vector3.new(150, -0.5, 0)
floor.Color = Color3.fromRGB(200, 205, 210)
floor.Material = Enum.Material.SmoothPlastic
floor.Anchored = true
floor.Parent = folder

local defs = {}
for _, d in EnemyConfig.List do
	table.insert(defs, { d.Id, d.Shape, d.Color })
end
for _, d in BossConfig.List do
	table.insert(defs, { d.Id, d.Shape, d.Color })
end
local seen = {}
local x = 0
for _, d in defs do
	local key = d[2] .. tostring(d[3])
	if not seen[key] then
		seen[key] = true
		local model = CreatureBuilder.build(d[1], d[2], d[3], 2)
		model:PivotTo(CFrame.new(x, 5, 0) * CFrame.Angles(0, math.rad(200), 0))
		model.Parent = folder
		x += 14
	end
end

local function c3(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end
local function v3(v)
	return { v.X, v.Y, v.Z }
end
local parts = {}
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.99 then
		local shape = if d:IsA("Part") then d.Shape.Name elseif d:IsA("WedgePart") then "Wedge" else "Block"
		local model = d:FindFirstAncestorOfClass("Model")
		table.insert(parts, {
			n = d.Name,
			m = model and model.Name or nil,
			s = shape,
			z = v3(d.Size),
			c = { d.CFrame:GetComponents() },
			k = c3(d.Color),
			t = d.Transparency,
			r = 0,
			mt = d.Material.Name,
		})
	end
end
local lighting = {
	ClockTime = 13,
	Brightness = 3,
	Ambient = { 110, 116, 126 },
	OutdoorAmbient = { 150, 162, 178 },
	Exposure = 0.1,
	Atmosphere = { Density = 0.1, Offset = 0, Color = { 199, 222, 244 }, Decay = { 106, 129, 160 }, Glare = 0, Haze = 0 },
	Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.5 },
}
local json = HttpService:JSONEncode({
	parts = parts,
	lights = {},
	zones = { Lineup = { Id = "Lineup", Center = { x / 2, 0, 0 }, Size = { x, 20, 40 }, Spawn = { 0, 0, 0 }, Lighting = lighting } },
	tiers = { { Name = "x", Scale = 1 } },
	count = x / 14,
})
for i = 1, #json, 30000 do
	print("@@WORLD@@" .. string.sub(json, i, i + 29999))
end
