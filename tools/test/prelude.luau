-- Test prelude: minimal Roblox environment for pure-logic modules.
local __env = getfenv(0)

------------------------------------------------------------------ datatypes
local Vector3 = {}
local V3 = {}
V3.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif k == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then return Vector3.new(0, 0, 0) end
		return Vector3.new(self.X / m, self.Y / m, self.Z / m)
	end
	return V3[k]
end
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __type = "Vector3" }, V3)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.yAxis = Vector3.new(0, 1, 0)
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return Vector3.new(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Lerp(a, b, t) return a + (b - a) * t end

local Vector2 = {}
local V2 = { __index = {} }
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0, __type = "Vector2" }, V2) end
Vector2.zero = Vector2.new(0, 0)

local Color3 = {}
function Color3.new(r, g, b) return { R = r or 0, G = g or 0, B = b or 0, __type = "Color3" } end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHSV(h, s, v) return Color3.new(v, v, v) end
function Color3.fromHex() return Color3.new(1, 1, 1) end

local CFrame = {}
local CF = {}
CF.__index = function(self, k)
	if k == "Position" then return self._p end
	if k == "LookVector" then return Vector3.new(0, 0, -1) end
	return CF[k]
end
function CFrame.new(x, y, z)
	if type(x) == "table" then return setmetatable({ _p = x, __type = "CFrame" }, CF) end
	return setmetatable({ _p = Vector3.new(x or 0, y or 0, z or 0), __type = "CFrame" }, CF)
end
function CFrame.Angles() return CFrame.new() end
function CFrame.fromEulerAnglesYXZ() return CFrame.new() end
function CFrame.lookAt(p) return CFrame.new(p) end
CF.__mul = function(a, b)
	if type(b) == "table" and b.__type == "CFrame" then return CFrame.new(a._p + b._p) end
	return a._p + b
end
CFrame.identity = CFrame.new()

local NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
local NumberSequence = { new = function(v) return { v } end }
local ColorSequence = { new = function(v) return { v } end }
local UDim2 = {
	new = function(a, b, c, d) return { a, b, c, d } end,
	fromScale = function(a, b) return { a, 0, b, 0 } end,
	fromOffset = function(a, b) return { 0, a, 0, b } end,
}
local UDim = { new = function(a, b) return { a, b } end }

local Random = {}
local RandomMT = { __index = {} }
function Random.new(seed)
	local s = math.floor(seed or os.clock() * 1e6) % 2147483647
	if s <= 0 then s = s + 2147483646 end
	return setmetatable({ _s = s }, RandomMT)
end
function RandomMT.__index:_next()
	self._s = (self._s * 16807) % 2147483647
	return self._s / 2147483647
end
function RandomMT.__index:NextNumber(a, b)
	local r = self:_next()
	if a then return a + (b - a) * r end
	return r
end
function RandomMT.__index:NextInteger(a, b) return a + math.floor(self:_next() * (b - a + 1)) end

local realTypeof = typeof
local function typeof(v)
	if type(v) == "table" and rawget(v, "__type") then return rawget(v, "__type") end
	if type(v) == "table" and rawget(v, "__instance") then return "Instance" end
	return realTypeof(v)
end

local Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item) return { Name = item, EnumType = enumName, __type = "EnumItem" } end,
		})
	end,
})

------------------------------------------------------------------ task
local task = {}
function task.spawn(fn, ...)
	if type(fn) == "thread" then return coroutine.resume(fn, ...) end
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then error(err, 0) end
	return co
end
task.defer = task.spawn
function task.delay(_, fn, ...) end
function task.wait(t) return t or 0 end
function task.cancel() end

------------------------------------------------------------------ services
local fakeClock = 1000
local services = {}
services.RunService = {
	IsStudio = function() return __env.__isStudio == true end,
	IsServer = function() return true end,
	IsClient = function() return false end,
	Heartbeat = { Connect = function() return { Disconnect = function() end } end },
}
services.HttpService = {
	GenerateGUID = function() return tostring(math.random(1, 1e9)) end,
	JSONEncode = function(_, v) return tostring(v) end,
}
services.Players = { GetPlayers = function() return {} end }
setmetatable(services, {
	__index = function(t, name)
		local svc = setmetatable({ Name = name }, { __index = function() return function() end end })
		rawset(t, name, svc)
		return svc
	end,
})
local rootNodeRef
local game = {
	GetService = function(_, name)
		local node = rootNodeRef and rawget(rootNodeRef, "__children")[name]
		if node then return node end
		return services[name]
	end,
	PlaceId = 0,
	JobId = "test-job",
}

------------------------------------------------------------------ virtual instances
local Instance = {}
local registry = {}
local rootNode = { Name = "game", __instance = true, __children = {} }

local NodeMT = {}
NodeMT.__index = function(self, key)
	local child = rawget(self, "__children")[key]
	if child then return child end
	if key == "FindFirstChild" then
		return function(s, n) return rawget(s, "__children")[n] end
	elseif key == "WaitForChild" then
		return function(s, n) return rawget(s, "__children")[n] end
	elseif key == "GetChildren" then
		return function(s)
			local out = {}
			for _, c in rawget(s, "__children") do table.insert(out, c) end
			table.sort(out, function(a, b) return a.Name < b.Name end)
			return out
		end
	elseif key == "IsA" then
		return function(s, class)
			if class == "ModuleScript" then return rawget(s, "__source") ~= nil end
			return true
		end
	elseif key == "GetFullName" then
		return function(s) return rawget(s, "__path") end
	end
	return nil
end
setmetatable(rootNode, NodeMT)
rootNodeRef = rootNode

local function ensureNode(vp)
	local node = rootNode
	local pathSoFar = "game"
	for _, name in vp do
		pathSoFar = pathSoFar .. "." .. name
		local children = rawget(node, "__children")
		local child = children[name]
		if not child then
			child = setmetatable({ Name = name, Parent = node, __instance = true, __children = {}, __path = pathSoFar }, NodeMT)
			children[name] = child
		end
		node = child
	end
	return node
end

function __register(vp, file, source)
	local node = ensureNode(vp)
	rawset(node, "__source", source)
	rawset(node, "__file", file)
end

local cache = {}
local loading = {}
local function requireNode(node)
	if type(node) ~= "table" or not rawget(node, "__source") then
		error("require: not a ModuleScript: " .. tostring(node and rawget(node, "__path")), 2)
	end
	if cache[node] ~= nil then return cache[node] end
	if loading[node] then error("cyclic require: " .. rawget(node, "__path"), 2) end
	loading[node] = true
	local fn, err = loadstring(rawget(node, "__source"), "=" .. rawget(node, "__file"))
	if not fn then error(err, 0) end
	local env = setmetatable({ script = node }, { __index = __env })
	setfenv(fn, env)
	local result = fn()
	loading[node] = nil
	cache[node] = result
	return result
end

------------------------------------------------------------------ globals
__env.Vector3 = Vector3
__env.Vector2 = Vector2
__env.Color3 = Color3
__env.CFrame = CFrame
__env.NumberRange = NumberRange
__env.NumberSequence = NumberSequence
__env.ColorSequence = ColorSequence
__env.UDim2 = UDim2
__env.UDim = UDim
__env.Random = Random
__env.typeof = typeof
__env.Enum = Enum
__env.task = task
__env.game = game
__env.workspace = services.Workspace
__env.Instance = Instance
__env.require = requireNode
__env.warn = function(...) if __env.__showWarnings then print("WARN", ...) end end
__env.tick = os.clock
__env.DateTime = { now = function() return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 } end }

__env.sourceOf = function(node) return rawget(node, "__source") end
__env.childrenOf = function(node) local out = {} for _, c in rawget(node, "__children") do table.insert(out, c) end return out end
-- Convenience roots for specs.
__env.Shared = rootNode.ReplicatedStorage and rootNode.ReplicatedStorage.Shared
__env.setClock = function(t) fakeClock = t end
__env.fakeClock = function() return fakeClock end

------------------------------------------------------------------ test API
local passed, failed = 0, 0
local failures = {}
local currentSpec = ""
local currentGroup = ""

local function fmt(v)
	if type(v) == "string" then return string.format("%q", v) end
	return tostring(v)
end

local function makeExpect(actual)
	local e = {}
	function e.toBe(expected)
		if actual ~= expected then error(string.format("expected %s to be %s", fmt(actual), fmt(expected)), 2) end
	end
	function e.toEqual(expected)
		local function eq(a, b)
			if type(a) ~= type(b) then return false end
			if type(a) ~= "table" then return a == b end
			for k, v in a do if not eq(v, b[k]) then return false end end
			for k in b do if a[k] == nil then return false end end
			return true
		end
		if not eq(actual, expected) then error("tables not equal", 2) end
	end
	function e.toBeTruthy() if not actual then error("expected truthy, got " .. fmt(actual), 2) end end
	function e.toBeFalsy() if actual then error("expected falsy, got " .. fmt(actual), 2) end end
	function e.toBeNear(expected, eps)
		if math.abs(actual - expected) > (eps or 1e-6) then
			error(string.format("expected %s ≈ %s", fmt(actual), fmt(expected)), 2)
		end
	end
	function e.toBeGreaterThan(n) if not (actual > n) then error(string.format("expected %s > %s", fmt(actual), fmt(n)), 2) end end
	function e.toBeLessThan(n) if not (actual < n) then error(string.format("expected %s < %s", fmt(actual), fmt(n)), 2) end end
	function e.toBeAtLeast(n) if not (actual >= n) then error(string.format("expected %s >= %s", fmt(actual), fmt(n)), 2) end end
	function e.toBeAtMost(n) if not (actual <= n) then error(string.format("expected %s <= %s", fmt(actual), fmt(n)), 2) end end
	function e.toBeFinite()
		if type(actual) ~= "number" or actual ~= actual or actual == math.huge or actual == -math.huge then
			error("expected finite number, got " .. fmt(actual), 2)
		end
	end
	function e.toThrow()
		local ok = pcall(actual)
		if ok then error("expected function to throw", 2) end
	end
	return e
end

__env.expect = makeExpect
__env.describe = function(name, fn)
	local prev = currentGroup
	currentGroup = name
	fn()
	currentGroup = prev
end
__env.it = function(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, string.format("  ✗ [%s] %s › %s\n      %s", currentSpec, currentGroup, name, tostring(err)))
	end
end

function __runSpec(name, source)
	currentSpec = name
	__env.Shared = rootNode.ReplicatedStorage.Shared
	__env.Server = rootNode.ServerScriptService and rootNode.ServerScriptService.Server
	__env.Client = rootNode.StarterPlayer and rootNode.StarterPlayer.Client
	local fn, err = loadstring(source, "=" .. name)
	if not fn then
		failed += 1
		table.insert(failures, "  ✗ [" .. name .. "] failed to compile: " .. tostring(err))
		return
	end
	setfenv(fn, setmetatable({}, { __index = __env }))
	local ok, runErr = pcall(fn)
	if not ok then
		failed += 1
		table.insert(failures, "  ✗ [" .. name .. "] crashed: " .. tostring(runErr))
	end
end

function __finish()
	for _, f in failures do print(f) end
	print(string.format("\n%d passed, %d failed", passed, failed))
	if failed > 0 then error("tests failed", 0) end
end
