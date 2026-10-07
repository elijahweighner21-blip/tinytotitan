-- Physical objects, characters, GUI, sounds and remotes.
local E = __E
local class, classes, new, sig, fireIf, isInst = E.class, E.classes, E.new, E.sig, E.fireIf, E.isInst

------------------------------------------------------------------ parts
local function partMoved(o)
	if E.onPartMoved then
		E.onPartMoved(o)
	end
end

class("PVInstance", "Instance")
class("BasePart", "PVInstance", {
	defaults = {
		Size = Vector3.new(4, 1, 2),
		CFrame = CFrame.new(),
		Anchored = false,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		CastShadow = true,
		Transparency = 0,
		LocalTransparencyModifier = 0,
		Reflectance = 0,
		Color = Color3.fromRGB(163, 162, 165),
		Material = function()
			return Enum.Material.Plastic
		end,
		Massless = false,
		Locked = false,
		CollisionGroup = "Default",
		AssemblyLinearVelocity = Vector3.zero,
		AssemblyAngularVelocity = Vector3.zero,
		Shape = function()
			return Enum.PartType.Block
		end,
		TopSurface = function()
			return Enum.SurfaceType.Smooth
		end,
		BottomSurface = function()
			return Enum.SurfaceType.Smooth
		end,
	},
	signals = { "Touched", "TouchEnded" },
	get = {
		Position = function(o)
			return o.CFrame.Position
		end,
		Orientation = function(o)
			local x, y, z = o.CFrame:ToOrientation()
			return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
		end,
		Rotation = function(o)
			local x, y, z = o.CFrame:ToEulerAnglesXYZ()
			return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
		end,
		AssemblyMass = function(o)
			local model = o:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				local total = 0
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and not d.Massless then
						total += d:GetMass()
					end
				end
				return total
			end
			return o:GetMass()
		end,
		Mass = function(o)
			return o:GetMass()
		end,
		BrickColor = function(o)
			return BrickColor.new("Medium stone grey")
		end,
		AssemblyRootPart = function(o)
			return o
		end,
		ResizeableFaces = function()
			return {}
		end,
		ExtentsCFrame = function(o)
			return o.CFrame
		end,
		CenterOfMass = function(o)
			return o.Position
		end,
		AssemblyCenterOfMass = function(o)
			return o.Position
		end,
	},
	set = {
		CFrame = function(o, v)
			assert(typeof(v) == "CFrame", "CFrame must be a CFrame")
			if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
				E.record("warn", "Part " .. o:GetFullName() .. " given a NaN CFrame")
			end
			rawget(o, "__props").CFrame = v
			partMoved(o)
		end,
		Position = function(o, v)
			assert(typeof(v) == "Vector3", "Position must be a Vector3")
			rawget(o, "__props").CFrame = o.CFrame.Rotation + v
			partMoved(o)
		end,
		Orientation = function(o, v)
			rawget(o, "__props").CFrame = CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z)) + o.Position
			partMoved(o)
		end,
		Size = function(o, v)
			assert(typeof(v) == "Vector3", "Size must be a Vector3")
			if v.X < 0 or v.Y < 0 or v.Z < 0 or v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
				E.record("warn", "Part " .. o:GetFullName() .. " given invalid Size " .. tostring(v))
			end
			-- Roblox clamps part sizes to [0.001, 2048] per axis.
			local c = Vector3.new(math.clamp(v.X, 0.001, 2048), math.clamp(v.Y, 0.001, 2048), math.clamp(v.Z, 0.001, 2048))
			if c ~= v then
				E.clampedSizes = (E.clampedSizes or 0) + 1
				E.clampedExamples = E.clampedExamples or {}
				if #E.clampedExamples < 8 then
					table.insert(E.clampedExamples, { Part = o, Size = v })
				end
			end
			rawget(o, "__props").Size = c
			partMoved(o)
		end,
		Shape = function(o, v)
			rawget(o, "__props").Shape = v
			-- Balls are uniform; cylinders have equal Y/Z.
			if v == Enum.PartType.Ball then
				local s = o.Size
				local d = math.min(s.X, s.Y, s.Z)
				rawget(o, "__props").Size = Vector3.new(d, d, d)
			end
		end,
	},
})
local bp = classes.BasePart.methods
function bp.GetMass(o)
	local s = o.Size
	return s.X * s.Y * s.Z * 0.7
end
function bp.GetPivot(o)
	return o.CFrame
end
function bp.PivotTo(o, cf)
	o.CFrame = cf
end
function bp.SetNetworkOwner() end
function bp.SetNetworkOwnershipAuto() end
function bp.GetNetworkOwner()
	return nil
end
function bp.CanSetNetworkOwnership()
	return true
end
function bp.ApplyImpulse(o, impulse)
	o.AssemblyLinearVelocity += impulse / math.max(o.AssemblyMass, 1e-3)
end
function bp.ApplyAngularImpulse() end
function bp.GetTouchingParts()
	return {}
end
function bp.GetConnectedParts(o)
	return { o }
end
function bp.GetJoints()
	return {}
end
function bp.GetVelocityAtPosition(o)
	return o.AssemblyLinearVelocity
end
function bp.BreakJoints() end
for _, n in { "Part", "WedgePart", "CornerWedgePart", "TrussPart", "MeshPart", "UnionOperation", "Seat", "SpawnLocation", "Terrain" } do
	class(n, "BasePart")
end
classes.Terrain.defaults.Anchored = true
-- Terrain fills are recorded (for the screenshot renderer), not voxelised.
E.terrainFills = {}
E.terrainColors = {}
local function fill(kind, cf, size, material)
	table.insert(E.terrainFills, { kind = kind, cf = cf, size = size, material = material })
end
classes.Terrain.methods.FillBlock = function(_, cf, size, material)
	fill("Block", cf, size, material)
end
classes.Terrain.methods.FillBall = function(_, center, radius, material)
	fill("Ball", CFrame.new(center), Vector3.new(radius * 2, radius * 2, radius * 2), material)
end
classes.Terrain.methods.FillCylinder = function(_, cf, height, radius, material)
	fill("Cylinder", cf, Vector3.new(radius * 2, height, radius * 2), material)
end
classes.Terrain.methods.FillWedge = function(_, cf, size, material)
	fill("Wedge", cf, size, material)
end
classes.Terrain.methods.SetMaterialColor = function(_, material, color)
	E.terrainColors[material.Name] = color
end
classes.Terrain.methods.GetMaterialColor = function(_, material)
	return E.terrainColors[material.Name] or Color3.new(0.5, 0.5, 0.5)
end
classes.Terrain.methods.Clear = function()
	table.clear(E.terrainFills)
end

------------------------------------------------------------------ models
local function partsOf(o)
	local out = {}
	for _, d in o:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
E.partsOf = partsOf

local function bounds(parts)
	local mn, mx
	for _, p in parts do
		local cf, s = p.CFrame, p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = cf * Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
					mn = if mn then mn:Min(w) else w
					mx = if mx then mx:Max(w) else w
				end
			end
		end
	end
	return mn, mx
end
E.bounds = bounds

class("Model", "PVInstance", {
	defaults = { LevelOfDetail = function()
		return Enum.ModelLevelOfDetail.Automatic
	end },
	init = function(o)
		rawset(o, "__scale", 1)
	end,
	set = {
		PrimaryPart = function(o, v)
			if v ~= nil and not v:IsDescendantOf(o) then
				E.record("warn", "PrimaryPart of " .. o:GetFullName() .. " must be a descendant")
			end
			rawget(o, "__props").PrimaryPart = v
		end,
	},
})
local mm = classes.Model.methods
function mm.GetPivot(o)
	local pp = rawget(o, "__props").PrimaryPart
	if pp and pp.Parent then
		return pp.CFrame
	end
	local wp = rawget(o, "__props").WorldPivot
	if wp then
		return wp
	end
	local mn, mx = bounds(partsOf(o))
	if not mn then
		return CFrame.new()
	end
	return CFrame.new((mn + mx) / 2)
end
function mm.PivotTo(o, cf)
	local pivot = mm.GetPivot(o)
	local delta = cf * pivot:Inverse()
	for _, p in partsOf(o) do
		p.CFrame = delta * p.CFrame
	end
	if rawget(o, "__props").WorldPivot then
		rawget(o, "__props").WorldPivot = cf
	end
end
mm.SetPrimaryPartCFrame = mm.PivotTo
function mm.GetPrimaryPartCFrame(o)
	return mm.GetPivot(o)
end
function mm.MoveTo(o, pos)
	local pivot = mm.GetPivot(o)
	mm.PivotTo(o, pivot.Rotation + pos)
end
function mm.TranslateBy(o, v)
	mm.PivotTo(o, mm.GetPivot(o) + v)
end
function mm.GetBoundingBox(o)
	local mn, mx = bounds(partsOf(o))
	if not mn then
		return CFrame.new(), Vector3.zero
	end
	return CFrame.new((mn + mx) / 2), mx - mn
end
function mm.GetExtentsSize(o)
	local _, s = mm.GetBoundingBox(o)
	return s
end
function mm.GetScale(o)
	return rawget(o, "__scale")
end
function mm.ScaleTo(o, s)
	if type(s) ~= "number" or s ~= s or s <= 0 then
		error("Model:ScaleTo: invalid scale " .. tostring(s), 2)
	end
	local old = rawget(o, "__scale")
	local f = s / old
	local pivot = mm.GetPivot(o)
	for _, p in partsOf(o) do
		local rel = pivot:Inverse() * p.CFrame
		p.Size = p.Size * f
		p.CFrame = pivot * (rel.Rotation + rel.Position * f)
	end
	for _, d in o:GetDescendants() do
		if d:IsA("Attachment") then
			d.Position = d.Position * f
		elseif d:IsA("JointInstance") then
			d.C0 = d.C0.Rotation + d.C0.Position * f
			d.C1 = d.C1.Rotation + d.C1.Position * f
		elseif d:IsA("Humanoid") then
			d.HipHeight = d.HipHeight * f
		end
	end
	rawset(o, "__scale", s)
end
function mm.BreakJoints() end
function mm.MakeJoints() end
function mm.GetPersistentPlayers()
	return {}
end

------------------------------------------------------------------ humanoid
class("Humanoid", "Instance", {
	defaults = {
		MaxHealth = 100,
		WalkSpeed = 16,
		JumpPower = 50,
		JumpHeight = 7.2,
		UseJumpPower = false,
		HipHeight = 2,
		AutoRotate = true,
		AutoJumpEnabled = true,
		MoveDirection = Vector3.zero,
		Jump = false,
		Sit = false,
		PlatformStand = false,
		BreakJointsOnDeath = true,
		RequiresNeck = true,
		MaxSlopeAngle = 89,
		DisplayName = "",
		WalkToPoint = Vector3.zero,
		CameraOffset = Vector3.zero,
		FloorMaterial = function()
			return Enum.Material.Plastic
		end,
		RigType = function()
			return Enum.HumanoidRigType.R15
		end,
		DisplayDistanceType = function()
			return Enum.HumanoidDisplayDistanceType.Viewer
		end,
		HealthDisplayType = function()
			return Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
		end,
	},
	signals = { "Died", "StateChanged", "Running", "Jumping", "FreeFalling", "HealthChanged", "MoveToFinished", "Touched", "Climbing", "Swimming", "Seated" },
	init = function(o)
		rawset(o, "__health", 100)
		rawset(o, "__state", Enum.HumanoidStateType.Running)
		rawset(o, "__disabledStates", {})
	end,
	get = {
		Health = function(o)
			return rawget(o, "__health")
		end,
		RootPart = function(o)
			local p = o.Parent
			return p and p:FindFirstChild("HumanoidRootPart")
		end,
	},
	set = {
		Health = function(o, v)
			if v ~= v then
				E.record("warn", "Humanoid.Health set to NaN on " .. o:GetFullName())
				v = 0
			end
			local before = rawget(o, "__health")
			local h = math.clamp(v, 0, o.MaxHealth)
			rawset(o, "__health", h)
			if h ~= before then
				sig(o, "HealthChanged"):Fire(h)
			end
			if h <= 0 and before > 0 and not rawget(o, "__dead") then
				rawset(o, "__dead", true)
				local old = rawget(o, "__state")
				rawset(o, "__state", Enum.HumanoidStateType.Dead)
				sig(o, "StateChanged"):Fire(old, Enum.HumanoidStateType.Dead)
				E.deaths = E.deaths or {}
				table.insert(E.deaths, { Who = o.Parent and o.Parent.Name or "?", At = E.now, Why = E.lastDamageSource or "health reached 0" })
				sig(o, "Died"):Fire()
			end
		end,
		MaxHealth = function(o, v)
			rawget(o, "__props").MaxHealth = v
			if rawget(o, "__health") > v then
				rawset(o, "__health", v)
			end
		end,
	},
})
local hm = classes.Humanoid.methods
function hm.TakeDamage(o, n)
	if o.Parent and o.Parent:FindFirstChildOfClass("ForceField") then
		return
	end
	o.Health = o.Health - n
end
function hm.ChangeState(o, s)
	if rawget(o, "__dead") then
		return
	end
	local old = rawget(o, "__state")
	rawset(o, "__state", s)
	if s == Enum.HumanoidStateType.Dead then
		o.Health = 0
	end
	sig(o, "StateChanged"):Fire(old, s)
end
function hm.GetState(o)
	return rawget(o, "__state")
end
function hm.SetStateEnabled(o, s, on)
	rawget(o, "__disabledStates")[s] = not on
end
function hm.GetStateEnabled(o, s)
	return not rawget(o, "__disabledStates")[s]
end
function hm.Move(o, dir)
	o.MoveDirection = if dir.Magnitude > 0 then dir.Unit else Vector3.zero
end
function hm.MoveTo(o, pos)
	o.WalkToPoint = pos
end
function hm.LoadAnimation(o, anim)
	local animator = o:FindFirstChildOfClass("Animator")
	return classes.Animator.methods.LoadAnimation(animator, anim)
end
function hm.ApplyDescription() end
function hm.ApplyDescriptionAsync() end
function hm.UnequipTools() end
function hm.GetAppliedDescription()
	return new("HumanoidDescription")
end
function hm.GetLimb()
	return Enum.Limb.Unknown
end
function hm.GetPlayingAnimationTracks()
	return {}
end

-- Builds an R15-like rig (part sizes match Roblox defaults at scale 1).
function E.buildRig(name)
	local model = new("Model")
	model.Name = name
	local function part(n, size, offset)
		local p = new("Part")
		p.Name = n
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Parent = model
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
	root.Transparency = 1
	root.CanCollide = true
	local lower = part("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.2, 0))
	part("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.8, 0))
	local head = part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2.2, 0))
	part("LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.9, 0))
	part("RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.9, 0))
	part("LeftLowerArm", Vector3.new(1, 1, 1), Vector3.new(-1.5, -0.2, 0))
	part("RightLowerArm", Vector3.new(1, 1, 1), Vector3.new(1.5, -0.2, 0))
	part("LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -1, 0))
	part("RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -1, 0))
	part("LeftLowerLeg", Vector3.new(1, 1, 1), Vector3.new(-0.5, -2, 0))
	part("RightLowerLeg", Vector3.new(1, 1, 1), Vector3.new(0.5, -2, 0))
	local motor = new("Motor6D")
	motor.Name = "Root"
	motor.Part0 = root
	motor.Part1 = lower
	motor.Parent = lower
	local neck = new("Motor6D")
	neck.Name = "Neck"
	neck.Part1 = head
	neck.Parent = head
	local humanoid = new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	new("Animator").Parent = humanoid
	model.PrimaryPart = root
	return model
end

------------------------------------------------------------------ camera
class("Camera", "Instance", {
	defaults = {
		CFrame = CFrame.new(0, 10, 20),
		Focus = CFrame.new(),
		FieldOfView = 70,
		ViewportSize = Vector2.new(1280, 720),
		CameraType = function()
			return Enum.CameraType.Custom
		end,
		NearPlaneZ = -0.1,
	},
})
local cm = classes.Camera.methods
function cm.WorldToViewportPoint(o, p)
	local rel = o.CFrame:Inverse() * p
	local depth = -rel.Z
	local vs = o.ViewportSize
	local f = 1 / math.tan(math.rad(o.FieldOfView) / 2)
	local aspect = vs.X / vs.Y
	local x = (rel.X / math.max(math.abs(depth), 1e-3)) * f / aspect
	local y = (rel.Y / math.max(math.abs(depth), 1e-3)) * f
	local sx = (x + 1) / 2 * vs.X
	local sy = (1 - y) / 2 * vs.Y
	local on = depth > 0 and sx >= 0 and sx <= vs.X and sy >= 0 and sy <= vs.Y
	return Vector3.new(sx, sy, depth), on
end
cm.WorldToScreenPoint = cm.WorldToViewportPoint
function cm.ViewportPointToRay(o, x, y)
	return Ray.new(o.CFrame.Position, o.CFrame.LookVector)
end
cm.ScreenPointToRay = cm.ViewportPointToRay
function cm.GetPartsObscuringTarget()
	return {}
end

------------------------------------------------------------------ GUI
class("GuiBase2d", "Instance", {
	get = {
		AbsoluteSize = function(o)
			return E.absSize(o)
		end,
		AbsolutePosition = function(o)
			return Vector2.zero
		end,
		AbsoluteRotation = function()
			return 0
		end,
	},
})
function E.absSize(o)
	local parent = o.Parent
	local base = if parent and parent:IsA("GuiBase2d") then E.absSize(parent) else E.workspace.CurrentCamera.ViewportSize
	if o:IsA("LayerCollector") then
		if o:IsA("BillboardGui") or o:IsA("SurfaceGui") then
			return Vector2.new(200, 50)
		end
		return E.workspace.CurrentCamera.ViewportSize
	end
	local s = o.Size
	return Vector2.new(base.X * s.X.Scale + s.X.Offset, base.Y * s.Y.Scale + s.Y.Offset)
end
class("LayerCollector", "GuiBase2d", { defaults = { Enabled = true, ResetOnSpawn = true } })
class("ScreenGui", "LayerCollector", { defaults = { DisplayOrder = 0, IgnoreGuiInset = false } })
class("BillboardGui", "LayerCollector", { defaults = { Size = UDim2.fromOffset(100, 100), MaxDistance = math.huge, AlwaysOnTop = false, StudsOffset = Vector3.zero, StudsOffsetWorldSpace = Vector3.zero } })
class("SurfaceGui", "LayerCollector")
class("GuiObject", "GuiBase2d", {
	defaults = {
		Size = UDim2.new(0, 100, 0, 100),
		Position = UDim2.new(),
		AnchorPoint = Vector2.zero,
		Visible = true,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 1,
		ZIndex = 1,
		LayoutOrder = 0,
		Rotation = 0,
		ClipsDescendants = false,
		Active = false,
		Selectable = false,
		Interactable = true,
	},
	signals = { "InputBegan", "InputEnded", "InputChanged", "MouseEnter", "MouseLeave", "MouseMoved", "SelectionGained", "SelectionLost", "TouchTap" },
})
local textDefaults = {
	Text = "",
	TextSize = 14,
	TextColor3 = Color3.new(0, 0, 0),
	TextTransparency = 0,
	TextStrokeTransparency = 1,
	TextWrapped = false,
	TextScaled = false,
	RichText = false,
	MaxVisibleGraphemes = -1,
}
local textGet = {
	TextBounds = function(o)
		return Vector2.new(#tostring(o.Text) * (o.TextSize or 14) * 0.5, o.TextSize or 14)
	end,
	TextFits = function()
		return true
	end,
	ContentText = function(o)
		return o.Text
	end,
}
class("Frame", "GuiObject")
class("CanvasGroup", "GuiObject")
class("ScrollingFrame", "GuiObject", {
	defaults = { CanvasSize = UDim2.new(), CanvasPosition = Vector2.zero, ScrollBarThickness = 12 },
	get = { AbsoluteCanvasSize = function(o)
		return E.absSize(o)
	end, AbsoluteWindowSize = function(o)
		return E.absSize(o)
	end },
})
class("TextLabel", "GuiObject", { defaults = textDefaults, get = textGet })
class("ImageLabel", "GuiObject", { defaults = { Image = "", ImageTransparency = 0 } })
class("ViewportFrame", "GuiObject")
class("VideoFrame", "GuiObject")
class("GuiButton", "GuiObject", {
	defaults = { AutoButtonColor = true, Selected = false, Modal = false },
	signals = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click" },
})
class("TextButton", "GuiButton", { defaults = textDefaults, get = textGet })
class("ImageButton", "GuiButton", { defaults = { Image = "" } })
class("TextBox", "GuiObject", { defaults = textDefaults, get = textGet, signals = { "FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard" } })
classes.TextBox.methods.CaptureFocus = function() end
classes.TextBox.methods.ReleaseFocus = function() end
classes.TextBox.methods.IsFocused = function()
	return false
end
-- Simulates a player clicking/tapping a button.
function E.click(button)
	sig(button, "Activated"):Fire()
	sig(button, "MouseButton1Click"):Fire()
end

class("UIComponent", "Instance")
for _, n in { "UICorner", "UIStroke", "UIPadding", "UIScale", "UIGradient", "UIAspectRatioConstraint", "UISizeConstraint", "UITextSizeConstraint", "UIFlexItem" } do
	class(n, "UIComponent")
end
classes.UIScale.defaults.Scale = 1
classes.UIStroke.defaults.Thickness = 1
class("UIGridStyleLayout", "UIComponent", { get = { AbsoluteContentSize = function(o)
	return Vector2.new(100, 100)
end } })
class("UIListLayout", "UIGridStyleLayout", { defaults = { Padding = UDim.new() } })
class("UIGridLayout", "UIGridStyleLayout", { defaults = { CellSize = UDim2.fromOffset(100, 100), CellPadding = UDim2.fromOffset(5, 5) } })
class("UIPageLayout", "UIGridStyleLayout")

class("PlayerGui", "Instance", { defaults = { ScreenOrientation = function()
	return Enum.ScreenOrientation.LandscapeSensor
end } })
classes.PlayerGui.methods.GetGuiObjectsAtPosition = function()
	return {}
end
class("StarterGui", "Instance")
classes.StarterGui.methods.SetCoreGuiEnabled = function() end
classes.StarterGui.methods.SetCore = function() end
classes.StarterGui.methods.GetCoreGuiEnabled = function()
	return true
end

------------------------------------------------------------------ sound
class("Sound", "Instance", {
	defaults = { SoundId = "", Volume = 0.5, PlaybackSpeed = 1, Looped = false, Playing = false, TimeLength = 1.5, TimePosition = 0, IsLoaded = true, RollOffMaxDistance = 10000, RollOffMinDistance = 10 },
	signals = { "Ended", "Played", "Loaded", "Stopped", "Paused", "Resumed" },
	get = {
		IsPlaying = function(o)
			return o.Playing
		end,
	},
})
local sm = classes.Sound.methods
function sm.Play(o)
	if o.SoundId == "" then
		E.emptySounds = (E.emptySounds or 0) + 1
	end
	E.soundsPlayed = (E.soundsPlayed or 0) + 1
	o.Playing = true
	sig(o, "Played"):Fire(o.SoundId)
	if not o.Looped then
		task.delay(o.TimeLength / math.max(o.PlaybackSpeed, 0.01), function()
			if o.Playing and not rawget(o, "__destroyed") then
				o.Playing = false
				sig(o, "Ended"):Fire(o.SoundId)
			end
		end)
	end
end
function sm.Stop(o)
	o.Playing = false
	sig(o, "Stopped"):Fire()
end
function sm.Pause(o)
	o.Playing = false
end
function sm.Resume(o)
	o.Playing = true
end

------------------------------------------------------------------ remotes
-- Network payloads are deep-copied like Roblox serialisation: tables are
-- copied (functions dropped, mixed tables keep string/number keys), instances
-- pass by reference.
local function wireCopy(v, depth)
	depth = depth or 0
	if depth > 30 then
		error("remote payload too deep", 0)
	end
	local t = type(v)
	if t == "function" or t == "thread" or t == "userdata" then
		return nil
	end
	if t ~= "table" or isInst(v) or rawget(v, "__type") then
		if t == "number" and v ~= v then
			return v
		end
		return v
	end
	local out = {}
	for k, x in v do
		if type(k) == "string" or type(k) == "number" then
			out[k] = wireCopy(x, depth + 1)
		end
	end
	E.netBytes = (E.netBytes or 0) + 16
	return out
end
local function wirePack(...)
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = wireCopy(args[i])
	end
	return args
end
E.wireCopy = wireCopy

class("BaseRemoteEvent", "Instance", { signals = { "OnServerEvent", "OnClientEvent" } })
class("RemoteEvent", "BaseRemoteEvent")
class("UnreliableRemoteEvent", "BaseRemoteEvent")
local rm = classes.BaseRemoteEvent.methods
E.remoteTraffic = {}
local function count(o, dir)
	local key = o.Name .. ":" .. dir
	E.remoteTraffic[key] = (E.remoteTraffic[key] or 0) + 1
end
function rm.FireServer(o, ...)
	local player = E.localPlayer
	assert(player, "FireServer called with no local player")
	count(o, "up")
	local args = wirePack(...)
	task.defer(function()
		sig(o, "OnServerEvent"):Fire(player, table.unpack(args, 1, args.n))
	end)
end
function rm.FireClient(o, player, ...)
	assert(isInst(player) and player:IsA("Player"), "FireClient: player expected")
	count(o, "down")
	if player ~= E.localPlayer or not E.clientRunning then
		return
	end
	local args = wirePack(...)
	task.defer(function()
		sig(o, "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
	end)
end
function rm.FireAllClients(o, ...)
	count(o, "all")
	if E.localPlayer and E.clientRunning then
		local args = wirePack(...)
		task.defer(function()
			sig(o, "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
		end)
	end
end

class("RemoteFunction", "Instance")
local rfm = classes.RemoteFunction.methods
function rfm.InvokeServer(o, ...)
	local player = E.localPlayer
	count(o, "invoke")
	local handler = rawget(o, "__props").OnServerInvoke
	local co = coroutine.running()
	local args = wirePack(...)
	task.defer(function()
		if not handler then
			handler = rawget(o, "__props").OnServerInvoke
		end
		if not handler then
			task.spawn(co, false, "OnServerInvoke not set")
			return
		end
		local res = table.pack(pcall(handler, player, table.unpack(args, 1, args.n)))
		task.spawn(co, table.unpack(res, 1, res.n))
	end)
	local res = table.pack(coroutine.yield())
	if not res[1] then
		error("InvokeServer failed: " .. tostring(res[2]), 2)
	end
	for i = 2, res.n do
		res[i] = wireCopy(res[i])
	end
	return table.unpack(res, 2, res.n)
end
function rfm.InvokeClient()
	error("InvokeClient is not allowed by this project", 2)
end

------------------------------------------------------------------ layout math
-- Absolute rectangle of a GuiObject (nil when placed by a UI layout, whose
-- arrangement the emulator doesn't compute). UIScale on the ScreenGui scales
-- offsets, matching how UIManager scales the whole UI.
function E.absRect(o)
	if o:IsA("LayerCollector") then
		local vs = E.workspace.CurrentCamera.ViewportSize
		local scale = 1
		local us = o:FindFirstChildOfClass("UIScale")
		if us then
			scale = us.Scale
		end
		return { X = 0, Y = 0, W = vs.X, H = vs.Y, S = scale }
	end
	local parent = o.Parent
	if not parent or not parent:IsA("GuiBase2d") then
		return nil
	end
	if parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return nil
	end
	local pr = E.absRect(parent)
	if not pr then
		return nil
	end
	local s = pr.S
	local size, pos, anchor = o.Size, o.Position, o.AnchorPoint
	local w = pr.W * size.X.Scale + size.X.Offset * s
	local h = pr.H * size.Y.Scale + size.Y.Offset * s
	local auto = o.AutomaticSize
	if auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY then
		h = math.max(h, E.contentHeight(o, s))
	end
	local x = pr.X + pr.W * pos.X.Scale + pos.X.Offset * s - anchor.X * w
	local y = pr.Y + pr.H * pos.Y.Scale + pos.Y.Offset * s - anchor.Y * h
	return { X = x, Y = y, W = w, H = h, S = s }
end

-- Approximate content height for AutomaticSize containers (vertical lists).
function E.contentHeight(o, s)
	local layout = o:FindFirstChildOfClass("UIListLayout")
	local total, count, maxH = 0, 0, 0
	for _, c in o:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then
			local ch = c.Size.Y.Offset * s
			local a = c.AutomaticSize
			if a == Enum.AutomaticSize.Y or a == Enum.AutomaticSize.XY then
				ch = math.max(ch, E.contentHeight(c, s))
			end
			total += ch
			count += 1
			maxH = math.max(maxH, ch)
		end
	end
	local pad = o:FindFirstChildOfClass("UIPadding")
	local extra = if pad then (pad.PaddingTop.Offset + pad.PaddingBottom.Offset) * s else 0
	if layout and layout.FillDirection ~= Enum.FillDirection.Horizontal then
		return total + math.max(0, count - 1) * layout.Padding.Offset * s + extra
	end
	return maxH + extra
end
