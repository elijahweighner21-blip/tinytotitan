-- Instance tree emulation for the headless engine.
local E = __E
local signal = E.signal

E.unknownReads = {}
E.classes = {}
local classes = E.classes

-- class(name, parent, spec) where spec = { defaults, methods, get, set, signals }
local function class(name, parentName, spec)
	spec = spec or {}
	local c = {
		Name = name,
		Parent = if parentName then classes[parentName] else nil,
		defaults = spec.defaults or {},
		methods = spec.methods or {},
		get = spec.get or {},
		set = spec.set or {},
		signals = {},
		init = spec.init,
	}
	for _, s in spec.signals or {} do
		c.signals[s] = true
	end
	classes[name] = c
	return c
end
E.class = class

local function lookup(c, field, key)
	while c do
		local v = c[field][key]
		if v ~= nil then
			return v
		end
		c = c.Parent
	end
	return nil
end
local function isA(c, name)
	while c do
		if c.Name == name then
			return true
		end
		c = c.Parent
	end
	return false
end
E.classIsA = isA

local InstMT = { __inst = true }
E.InstMT = InstMT

local function isInst(v)
	return type(v) == "table" and getmetatable(v) == InstMT
end
E.isInst = isInst

local function sig(o, name)
	local sigs = rawget(o, "__signals")
	local s = sigs[name]
	if not s then
		s = signal(name)
		sigs[name] = s
	end
	return s
end
E.sig = sig

local function fireIf(o, name, ...)
	local s = rawget(o, "__signals")[name]
	if s then
		s:Fire(...)
	end
end
E.fireIf = fireIf

InstMT.__index = function(o, k)
	local c = rawget(o, "__class")
	local m = lookup(c, "methods", k)
	if m then
		return m
	end
	if k == "Parent" then
		return rawget(o, "__parent")
	elseif k == "Name" then
		return rawget(o, "__name")
	elseif k == "ClassName" then
		return c.Name
	end
	local g = lookup(c, "get", k)
	if g then
		return g(o)
	end
	local props = rawget(o, "__props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	local d = lookup(c, "defaults", k)
	if d ~= nil then
		if type(d) == "function" then
			d = d(o)
			props[k] = d
		end
		return d
	end
	-- Signals: any capitalised key declared as a signal, or the generic ones.
	if lookup(c, "signals", k) then
		return sig(o, k)
	end
	for _, child in rawget(o, "__children") do
		if rawget(child, "__name") == k then
			return child
		end
	end
	local key = c.Name .. "." .. tostring(k)
	if not E.unknownReads[key] then
		E.unknownReads[key] = true
	end
	return nil
end

local setParent

InstMT.__newindex = function(o, k, v)
	if k == "Parent" then
		setParent(o, v)
		return
	elseif k == "Name" then
		rawset(o, "__name", tostring(v))
		fireIf(o, "Changed", "Name")
		local ps = rawget(o, "__propSignals")["Name"]
		if ps then
			ps:Fire()
		end
		return
	end
	local c = rawget(o, "__class")
	local s = lookup(c, "set", k)
	if s then
		s(o, v)
	else
		rawget(o, "__props")[k] = v
	end
	local ps = rawget(o, "__propSignals")[k]
	if ps then
		ps:Fire()
	end
	if rawget(o, "__signals")["Changed"] then
		fireIf(o, "Changed", if isA(c, "ValueBase") and k == "Value" then v else k)
	end
end
InstMT.__tostring = function(o)
	return rawget(o, "__name")
end

local function new(className, parent)
	local c = classes[className]
	if not c then
		c = class(className, "Instance")
	end
	local o = setmetatable({
		__class = c,
		__name = className,
		__props = {},
		__attrs = {},
		__tags = {},
		__children = {},
		__signals = {},
		__propSignals = {},
	}, InstMT)
	local chain = {}
	local cc = c
	while cc do
		table.insert(chain, 1, cc)
		cc = cc.Parent
	end
	for _, k in chain do
		if k.init then
			k.init(o)
		end
	end
	if parent then
		o.Parent = parent
	end
	return o
end
E.new = new

------------------------------------------------------------------ hierarchy
E.game = nil -- set after DataModel creation

local function inGame(o)
	local p = o
	while p do
		if p == E.game then
			return true
		end
		p = rawget(p, "__parent")
	end
	return false
end
E.inGame = inGame

local function inWorkspace(o)
	local ws = E.workspace
	local p = o
	while p do
		if p == ws then
			return true
		end
		p = rawget(p, "__parent")
	end
	return false
end
E.inWorkspace = inWorkspace

local function forSubtree(o, fn)
	fn(o)
	for _, child in rawget(o, "__children") do
		forSubtree(child, fn)
	end
end
E.forSubtree = forSubtree

setParent = function(o, newParent)
	if rawget(o, "__locked") then
		error("The Parent property of " .. rawget(o, "__name") .. " is locked, current parent: NULL, new parent " .. tostring(newParent), 3)
	end
	local old = rawget(o, "__parent")
	if old == newParent then
		return
	end
	if newParent ~= nil and not isInst(newParent) then
		error("Parent must be an Instance", 3)
	end
	-- cycle check
	local p = newParent
	while p do
		if p == o then
			error("Attempt to set " .. rawget(o, "__name") .. " as its own ancestor", 3)
		end
		p = rawget(p, "__parent")
	end
	local wasInGame = inGame(o)
	local wasInWorkspace = wasInGame and inWorkspace(o)
	if old then
		local list = rawget(old, "__children")
		for i, c in list do
			if c == o then
				table.remove(list, i)
				break
			end
		end
		fireIf(old, "ChildRemoved", o)
		local a = old
		while a do
			fireIf(a, "DescendantRemoving", o)
			a = rawget(a, "__parent")
		end
	end
	rawset(o, "__parent", newParent)
	if newParent then
		table.insert(rawget(newParent, "__children"), o)
	end
	local nowInGame = inGame(o)
	local nowInWorkspace = nowInGame and inWorkspace(o)
	if wasInWorkspace ~= nowInWorkspace or wasInGame ~= nowInGame then
		forSubtree(o, function(d)
			if E.onMembership then
				E.onMembership(d, wasInGame, nowInGame, wasInWorkspace, nowInWorkspace)
			end
		end)
	end
	forSubtree(o, function(d)
		fireIf(d, "AncestryChanged", o, newParent)
	end)
	fireIf(o, "Changed", "Parent")
	local ps = rawget(o, "__propSignals")["Parent"]
	if ps then
		ps:Fire()
	end
	if newParent then
		fireIf(newParent, "ChildAdded", o)
		forSubtree(o, function(d)
			local a = newParent
			while a do
				fireIf(a, "DescendantAdded", d)
				a = rawget(a, "__parent")
			end
		end)
	end
end

------------------------------------------------------------------ base class
local base = class("Instance", nil, {
	signals = { "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "AttributeChanged", "Destroying" },
	defaults = { Archivable = true },
})

local m = base.methods
function m.IsA(o, name)
	return isA(rawget(o, "__class"), name)
end
function m.FindFirstChild(o, name, recursive)
	for _, c in rawget(o, "__children") do
		if rawget(c, "__name") == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(o, "__children") do
			local f = m.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function m.FindFirstChildOfClass(o, cn)
	for _, c in rawget(o, "__children") do
		if rawget(c, "__class").Name == cn then
			return c
		end
	end
	return nil
end
function m.FindFirstChildWhichIsA(o, cn, recursive)
	for _, c in rawget(o, "__children") do
		if isA(rawget(c, "__class"), cn) then
			return c
		end
	end
	if recursive then
		for _, c in rawget(o, "__children") do
			local f = m.FindFirstChildWhichIsA(c, cn, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function m.FindFirstAncestor(o, name)
	local p = rawget(o, "__parent")
	while p do
		if rawget(p, "__name") == name then
			return p
		end
		p = rawget(p, "__parent")
	end
	return nil
end
function m.FindFirstAncestorOfClass(o, cn)
	local p = rawget(o, "__parent")
	while p do
		if rawget(p, "__class").Name == cn then
			return p
		end
		p = rawget(p, "__parent")
	end
	return nil
end
function m.FindFirstAncestorWhichIsA(o, cn)
	local p = rawget(o, "__parent")
	while p do
		if isA(rawget(p, "__class"), cn) then
			return p
		end
		p = rawget(p, "__parent")
	end
	return nil
end
function m.WaitForChild(o, name, timeout)
	local found = m.FindFirstChild(o, name)
	if found then
		return found
	end
	local co = coroutine.running()
	local done = false
	local conn
	conn = sig(o, "ChildAdded"):Connect(function(child)
		if not done and rawget(child, "__name") == name then
			done = true
			conn:Disconnect()
			task.spawn(co, child)
		end
	end)
	local warned = false
	local limit = timeout
	task.delay(limit or 5, function()
		if done then
			return
		end
		if limit then
			done = true
			conn:Disconnect()
			task.spawn(co, nil)
		elseif not warned then
			warned = true
			E.record("warn", "Infinite yield possible on '" .. m.GetFullName(o) .. ":WaitForChild(\"" .. tostring(name) .. "\")'\n" .. debug.traceback(co))
		end
	end)
	return coroutine.yield()
end
function m.GetChildren(o)
	return table.clone(rawget(o, "__children"))
end
function m.GetDescendants(o)
	local out = {}
	local function walk(x)
		for _, c in rawget(x, "__children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(o)
	return out
end
function m.IsDescendantOf(o, a)
	local p = rawget(o, "__parent")
	while p do
		if p == a then
			return true
		end
		p = rawget(p, "__parent")
	end
	return false
end
function m.IsAncestorOf(o, d)
	return m.IsDescendantOf(d, o)
end
function m.GetFullName(o)
	local parts = {}
	local p = o
	while p and p ~= E.game do
		table.insert(parts, 1, rawget(p, "__name"))
		p = rawget(p, "__parent")
	end
	return table.concat(parts, ".")
end
function m.Destroy(o)
	if rawget(o, "__destroyed") then
		return
	end
	fireIf(o, "Destroying")
	for _, c in table.clone(rawget(o, "__children")) do
		m.Destroy(c)
	end
	setParent(o, nil)
	rawset(o, "__locked", true)
	rawset(o, "__destroyed", true)
	for _, s in rawget(o, "__signals") do
		for _, conn in s._conns do
			conn.Connected = false
		end
	end
	for _, s in rawget(o, "__propSignals") do
		for _, conn in s._conns do
			conn.Connected = false
		end
	end
	if E.onDestroy then
		E.onDestroy(o)
	end
end
function m.ClearAllChildren(o)
	for _, c in table.clone(rawget(o, "__children")) do
		m.Destroy(c)
	end
end
function m.Clone(o)
	local c = new(rawget(o, "__class").Name)
	rawset(c, "__name", rawget(o, "__name"))
	for k, v in rawget(o, "__props") do
		rawget(c, "__props")[k] = v
	end
	for k, v in rawget(o, "__attrs") do
		rawget(c, "__attrs")[k] = v
	end
	for k in rawget(o, "__tags") do
		rawget(c, "__tags")[k] = true
	end
	if rawget(o, "__source") then
		rawset(c, "__source", rawget(o, "__source"))
		rawset(c, "__file", rawget(o, "__file"))
	end
	local map = { [o] = c }
	for _, child in rawget(o, "__children") do
		local cc = m.Clone(child)
		map[child] = cc
		cc.Parent = c
	end
	-- Remap instance-valued properties that point inside the clone.
	forSubtree(c, function(x)
		local props = rawget(x, "__props")
		for k, v in props do
			if isInst(v) and map[v] then
				props[k] = map[v]
			end
		end
	end)
	return c
end
function m.GetAttribute(o, name)
	return rawget(o, "__attrs")[name]
end
function m.SetAttribute(o, name, value)
	local t = typeof(value)
	if value ~= nil and not ({ string = true, number = true, boolean = true, Vector3 = true, Vector2 = true, CFrame = true, Color3 = true, UDim = true, UDim2 = true, NumberRange = true, NumberSequence = true, ColorSequence = true, Rect = true, BrickColor = true, EnumItem = true, Font = true })[t] then
		error("SetAttribute: unsupported attribute type " .. t .. " for '" .. tostring(name) .. "'", 2)
	end
	if type(value) == "string" and #value > 100000 then
		error("SetAttribute: string too long", 2)
	end
	local attrs = rawget(o, "__attrs")
	if attrs[name] == value then
		return
	end
	attrs[name] = value
	fireIf(o, "AttributeChanged", name)
	local s = rawget(o, "__signals")["Attr:" .. name]
	if s then
		s:Fire()
	end
end
function m.GetAttributes(o)
	return table.clone(rawget(o, "__attrs"))
end
function m.GetAttributeChangedSignal(o, name)
	return sig(o, "Attr:" .. name)
end
function m.GetPropertyChangedSignal(o, prop)
	local ps = rawget(o, "__propSignals")
	local s = ps[prop]
	if not s then
		s = signal(prop)
		ps[prop] = s
	end
	return s
end
function m.AddTag(o, tag)
	E.collection.AddTag(nil, o, tag)
end
function m.RemoveTag(o, tag)
	E.collection.RemoveTag(nil, o, tag)
end
function m.HasTag(o, tag)
	return rawget(o, "__tags")[tag] == true
end
function m.GetTags(o)
	local out = {}
	for t in rawget(o, "__tags") do
		table.insert(out, t)
	end
	return out
end
function m.GetActor()
	return nil
end
function m.GetStyled(o, k)
	return o[k]
end

------------------------------------------------------------------ simple classes
for _, n in { "Folder", "Configuration", "Accessory", "Tool", "Backpack", "PlayerScripts", "StarterGear", "Shirt", "Pants", "BodyColors", "HumanoidDescription", "Animation", "Atmosphere", "Sky", "Clouds", "WeldConstraint", "NoCollisionConstraint", "SpecialMesh", "Decal", "Texture", "SoundGroup", "ForceField", "Fire", "Smoke", "Sparkles", "Explosion", "ProximityPrompt", "ClickDetector", "PathfindingModifier", "Actor" } do
	class(n, "Instance")
end
classes.Animation.defaults.AnimationId = ""
classes.HumanoidDescription.defaults.HeadScale = 1
classes.SoundGroup.defaults.Volume = 0.5
classes.ProximityPrompt.signals.Triggered = true

class("PostEffect", "Instance", { defaults = { Enabled = true } })
for _, n in { "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect", "BlurEffect", "DepthOfFieldEffect" } do
	class(n, "PostEffect")
end
classes.ColorCorrectionEffect.defaults.TintColor = Color3.new(1, 1, 1)
classes.BlurEffect.defaults.Size = 24

class("Light", "Instance", { defaults = { Enabled = true, Brightness = 1, Range = 8, Color = Color3.new(1, 1, 1), Shadows = false } })
for _, n in { "PointLight", "SpotLight", "SurfaceLight" } do
	class(n, "Light")
end

class("ValueBase", "Instance", { defaults = {} })
for n, dv in { NumberValue = 0, IntValue = 0, StringValue = "", BoolValue = false, ObjectValue = false, Vector3Value = Vector3.zero, CFrameValue = CFrame.new(), Color3Value = Color3.new() } do
	local cdef = class(n, "ValueBase")
	if dv ~= false then
		cdef.defaults.Value = dv
	end
end

class("LuaSourceContainer", "Instance", { defaults = { Enabled = true, Disabled = false } })
class("ModuleScript", "LuaSourceContainer")
class("BaseScript", "LuaSourceContainer")
class("Script", "BaseScript")
class("LocalScript", "BaseScript")

class("BindableEvent", "Instance", { signals = { "Event" } })
classes.BindableEvent.methods.Fire = function(o, ...)
	sig(o, "Event"):Fire(...)
end
class("BindableFunction", "Instance")
classes.BindableFunction.methods.Invoke = function(o, ...)
	local fn = rawget(o, "__props").OnInvoke
	return fn(...)
end

------------------------------------------------------------------ attachments / constraints
local function attachmentParentCF(o)
	local p = rawget(o, "__parent")
	if p and isA(rawget(p, "__class"), "BasePart") then
		return p.CFrame
	end
	return CFrame.new()
end
class("Attachment", "Instance", {
	defaults = { CFrame = CFrame.new(), Visible = false },
	get = {
		Position = function(o)
			return o.CFrame.Position
		end,
		WorldPosition = function(o)
			return attachmentParentCF(o) * o.CFrame.Position
		end,
		WorldCFrame = function(o)
			return attachmentParentCF(o) * o.CFrame
		end,
		Axis = function(o)
			return o.CFrame.RightVector
		end,
	},
	set = {
		Position = function(o, v)
			local cf = o.CFrame
			rawget(o, "__props").CFrame = cf.Rotation + v
		end,
		WorldPosition = function(o, v)
			local local_ = attachmentParentCF(o):Inverse() * v
			rawget(o, "__props").CFrame = o.CFrame.Rotation + local_
		end,
		WorldCFrame = function(o, v)
			rawget(o, "__props").CFrame = attachmentParentCF(o):Inverse() * v
		end,
	},
})
class("Bone", "Attachment")

class("Constraint", "Instance", { defaults = { Enabled = true } })
for _, n in { "VectorForce", "AlignPosition", "AlignOrientation", "LinearVelocity", "AngularVelocity", "BodyVelocity", "BodyPosition", "BodyGyro", "RopeConstraint", "SpringConstraint", "Torque" } do
	class(n, "Constraint")
end
classes.VectorForce.defaults.Force = Vector3.zero
classes.AlignPosition.defaults.Position = Vector3.zero
classes.AlignOrientation.defaults.CFrame = CFrame.new()

class("JointInstance", "Instance", { defaults = { C0 = CFrame.new(), C1 = CFrame.new(), Enabled = true } })
class("Motor6D", "JointInstance", { defaults = { Transform = CFrame.new() } })
class("Weld", "JointInstance")

class("Trail", "Instance", { defaults = { Enabled = true, Lifetime = 2 } })
class("Beam", "Instance", { defaults = { Enabled = true } })
class("ParticleEmitter", "Instance", { defaults = { Enabled = true, Rate = 5 } })
classes.ParticleEmitter.methods.Emit = function(o, n)
	E.particlesEmitted = (E.particlesEmitted or 0) + (n or 0)
end
classes.ParticleEmitter.methods.Clear = function() end
class("Highlight", "Instance", { defaults = { Enabled = true } })

------------------------------------------------------------------ animation
class("Animator", "Instance")
local function makeTrack(anim)
	local t = new("AnimationTrack")
	rawget(t, "__props").Animation = anim
	return t
end
class("AnimationTrack", "Instance", {
	defaults = { Looped = false, IsPlaying = false, Length = 1, Speed = 1, TimePosition = 0, WeightCurrent = 1 },
	signals = { "Stopped", "Ended", "DidLoop", "KeyframeReached" },
})
classes.AnimationTrack.methods.Play = function(o)
	rawget(o, "__props").IsPlaying = true
end
classes.AnimationTrack.methods.Stop = function(o)
	rawget(o, "__props").IsPlaying = false
	sig(o, "Stopped"):Fire()
end
classes.AnimationTrack.methods.AdjustSpeed = function() end
classes.AnimationTrack.methods.AdjustWeight = function() end
classes.AnimationTrack.methods.GetMarkerReachedSignal = function(o, n)
	return sig(o, "Marker:" .. n)
end
classes.Animator.methods.LoadAnimation = function(_, anim)
	if not anim or anim.AnimationId == "" then
		error("LoadAnimation requires an Animation with a valid AnimationId", 2)
	end
	return makeTrack(anim)
end
classes.Animator.methods.GetPlayingAnimationTracks = function()
	return {}
end
