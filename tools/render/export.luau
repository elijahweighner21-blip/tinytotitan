-- Dumps the generated world (parts, lights) and each zone's client lighting
-- as JSON for tools/render/render.mjs. Run through the play emulator.
local E = __E
local HttpService = E.game:GetService("HttpService")
E.startServer()
E.run(3)
local p = E.addPlayer("Camera", { UserId = 9090, client = true })
E.startClient(p)
local PDS = E.serverModule("Services.PlayerDataService")
E.waitFor(function()
	return PDS:IsLoaded(p) and p.Character ~= nil
end, 40, "spawn")
local ZoneConfig = E.sharedModule("Config.ZoneConfig")
local SizeConfig = E.sharedModule("Config.SizeConfig")
E.serverModule("Services.ProgressionService"):SetMass(p, SizeConfig.getTier(#SizeConfig.Tiers).MassRequired + 1, "Admin")
E.run(4)

local function c3(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end
local function v3(v)
	return { v.X, v.Y, v.Z }
end
local Lighting = E.game:GetService("Lighting")
local function lighting()
	local out = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = c3(Lighting.Ambient),
		OutdoorAmbient = c3(Lighting.OutdoorAmbient),
		Exposure = Lighting.ExposureCompensation,
		DiffuseScale = Lighting.EnvironmentDiffuseScale,
		SpecularScale = Lighting.EnvironmentSpecularScale,
		Latitude = Lighting.GeographicLatitude,
	}
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") then
			out.Atmosphere = { Density = c.Density, Offset = c.Offset, Color = c3(c.Color), Decay = c3(c.Decay), Glare = c.Glare, Haze = c.Haze }
		elseif c:IsA("ColorCorrectionEffect") then
			out.Grade = { Brightness = c.Brightness, Contrast = c.Contrast, Saturation = c.Saturation, Tint = c3(c.TintColor), Enabled = c.Enabled }
		elseif c:IsA("BloomEffect") then
			out.Bloom = { Intensity = c.Intensity, Size = c.Size, Threshold = c.Threshold, Enabled = c.Enabled }
		elseif c:IsA("SunRaysEffect") then
			out.SunRays = { Intensity = c.Intensity, Spread = c.Spread, Enabled = c.Enabled }
		elseif c:IsA("DepthOfFieldEffect") then
			out.DepthOfField = { Enabled = c.Enabled, FarIntensity = c.FarIntensity, FocusDistance = c.FocusDistance, InFocusRadius = c.InFocusRadius }
		elseif c:IsA("Sky") then
			out.Sky = { Celestial = c.CelestialBodiesShown, Stars = c.StarCount }
		elseif c:IsA("Clouds") then
			out.Clouds = { Cover = c.Cover, Density = c.Density, Color = c3(c.Color) }
		end
	end
	for _, c in E.workspace.Terrain:GetChildren() do
		if c:IsA("Clouds") then
			out.Clouds = { Cover = c.Cover, Density = c.Density, Color = c3(c.Color) }
		end
	end
	return out
end

local zones = {}
for _, z in ZoneConfig.Zones do
	E.teleport(p, z.Spawn + Vector3.new(0, 30, 0))
	E.run(5)
	zones[z.Id] = {
		Id = z.Id,
		Name = z.Name,
		Center = v3(z.Center),
		Size = v3(z.Size),
		Spawn = v3(z.Spawn),
		RequiredTier = z.RequiredTier,
		Recommended = z.RecommendedTiers,
		Lighting = lighting(),
	}
end

-- Remove the camera player's own body from the export.
local skip = {}
if p.Character then
	for _, d in p.Character:GetDescendants() do
		skip[d] = true
	end
end
local parts = {}
local lights = {}
for _, d in E.workspace:GetDescendants() do
	if skip[d] then
		continue
	end
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		if d.Transparency < 0.99 then
			local shape = "Block"
			if d:IsA("Part") then
				shape = d.Shape.Name
			elseif d:IsA("WedgePart") then
				shape = "Wedge"
			elseif d:IsA("CornerWedgePart") then
				shape = "CornerWedge"
			end
			local model = d:FindFirstAncestorOfClass("Model")
			table.insert(parts, {
				n = d.Name,
				m = model and model.Name or nil,
				s = shape,
				z = v3(d.Size),
				c = { d.CFrame:GetComponents() },
				k = c3(d.Color),
				t = d.Transparency,
				r = d.Reflectance,
				mt = d.Material.Name,
			})
		end
	elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
		local parent = d.Parent
		if parent and parent:IsA("BasePart") and d.Enabled then
			table.insert(lights, { p = v3(parent.Position), k = c3(d.Color), b = d.Brightness, r = d.Range })
		end
	end
end
local tiers = {}
for i, t in SizeConfig.Tiers do
	tiers[i] = { Name = t.Name, Scale = t.Scale }
end
-- Printed in chunks: very long single lines get truncated.
local json = HttpService:JSONEncode({ parts = parts, lights = lights, zones = zones, tiers = tiers })
for i = 1, #json, 30000 do
	print("@@WORLD@@" .. string.sub(json, i, i + 29999))
end
