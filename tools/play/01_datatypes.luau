-- Roblox datatype emulation for the headless engine (tools/play).
-- Real math (CFrame rotation matrices etc.) so gameplay code computes the
-- same values it would in Roblox.
local E = {}
__E = E

local function typed(t, name)
	t.__type = name
	return t
end
E.typed = typed

------------------------------------------------------------------ Vector3
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return Vector3.new(0 / 0, 0 / 0, 0 / 0)
		end
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return V3[k]
end
local function isV3(v)
	return type(v) == "table" and getmetatable(v) == V3
end
Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __type = "Vector3" }, V3)
end
V3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
function V3.Min(a, b)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3.Max(a, b)
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3.Abs(a)
	return Vector3.new(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3.Floor(a)
	return Vector3.new(math.floor(a.X), math.floor(a.Y), math.floor(a.Z))
end
function V3.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
function V3.Angle(a, b)
	return math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)
E.isV3 = isV3

------------------------------------------------------------------ Vector2
local V2 = {}
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return Vector2.new(v.X / m, v.Y / m)
	end
	return V2[k]
end
Vector2 = {}
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0, __type = "Vector2" }, V2)
end
V2.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return Vector2.new(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X / b, a.Y / b)
	end
	return Vector2.new(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a)
	return Vector2.new(-a.X, -a.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
function V2.Dot(a, b)
	return a.X * b.X + a.Y * b.Y
end
function V2.Lerp(a, b, t)
	return a + (b - a) * t
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

------------------------------------------------------------------ CFrame
-- Stored as position + 3x3 rotation (columns = right, up, back).
local CF = {}
local function mkcf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		X = x,
		Y = y,
		Z = z,
		__type = "CFrame",
		r00, r01, r02, r10, r11, r12, r20, r21, r22,
	}, CF)
end
CF.__index = function(c, k)
	if k == "Position" or k == "p" then
		return Vector3.new(c.X, c.Y, c.Z)
	elseif k == "LookVector" then
		return Vector3.new(-c[3], -c[6], -c[9])
	elseif k == "RightVector" or k == "XVector" then
		return Vector3.new(c[1], c[4], c[7])
	elseif k == "UpVector" or k == "YVector" then
		return Vector3.new(c[2], c[5], c[8])
	elseif k == "ZVector" then
		return Vector3.new(c[3], c[6], c[9])
	elseif k == "Rotation" then
		return mkcf(0, 0, 0, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
	end
	return CF[k]
end
CFrame = {}
function CFrame.new(x, y, z, ...)
	if x == nil then
		return mkcf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	if isV3(x) then
		if isV3(y) then
			return CFrame.lookAt(x, y)
		end
		return mkcf(x.X, x.Y, x.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	local rest = { ... }
	if #rest == 9 then
		return mkcf(x, y, z, table.unpack(rest))
	end
	return mkcf(x, y or 0, z or 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end
function CFrame.fromMatrix(pos, rx, ry, rz)
	rz = rz or rx:Cross(ry).Unit
	return mkcf(pos.X, pos.Y, pos.Z, rx.X, ry.X, rz.X, rx.Y, ry.Y, rz.Y, rx.Z, ry.Z, rz.Z)
end
function CFrame.lookAt(at, target, up)
	up = up or Vector3.yAxis
	local look = target - at
	if look.Magnitude < 1e-9 then
		return CFrame.new(at)
	end
	local back = (-look).Unit
	local right = up:Cross(back)
	if right.Magnitude < 1e-6 then
		right = Vector3.xAxis:Cross(back)
		if right.Magnitude < 1e-6 then
			right = Vector3.zAxis:Cross(back)
		end
	end
	right = right.Unit
	local u = back:Cross(right).Unit
	return CFrame.fromMatrix(at, right, u, back)
end
CFrame.lookAlong = function(at, dir, up)
	return CFrame.lookAt(at, at + dir, up)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return mkcf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return mkcf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c)
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return mkcf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end
function CFrame.Angles(x, y, z)
	return rx(x or 0) * ry(y or 0) * rz(z or 0)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z)
	return ry(y or 0) * rx(x or 0) * rz(z or 0)
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local c, s, t = math.cos(angle), math.sin(angle), 1 - math.cos(angle)
	local x, y, z = u.X, u.Y, u.Z
	return mkcf(0, 0, 0, t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c)
end
CF.__mul = function(a, b)
	if isV3(b) then
		return Vector3.new(
			a.X + a[1] * b.X + a[2] * b.Y + a[3] * b.Z,
			a.Y + a[4] * b.X + a[5] * b.Y + a[6] * b.Z,
			a.Z + a[7] * b.X + a[8] * b.Y + a[9] * b.Z
		)
	end
	return mkcf(
		a.X + a[1] * b.X + a[2] * b.Y + a[3] * b.Z,
		a.Y + a[4] * b.X + a[5] * b.Y + a[6] * b.Z,
		a.Z + a[7] * b.X + a[8] * b.Y + a[9] * b.Z,
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7],
		a[1] * b[2] + a[2] * b[5] + a[3] * b[8],
		a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7],
		a[4] * b[2] + a[5] * b[5] + a[6] * b[8],
		a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7],
		a[7] * b[2] + a[8] * b[5] + a[9] * b[8],
		a[7] * b[3] + a[8] * b[6] + a[9] * b[9]
	)
end
CF.__add = function(a, v)
	return mkcf(a.X + v.X, a.Y + v.Y, a.Z + v.Z, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
end
CF.__sub = function(a, v)
	return mkcf(a.X - v.X, a.Y - v.Y, a.Z - v.Z, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
end
CF.__eq = function(a, b)
	for i = 1, 9 do
		if a[i] ~= b[i] then
			return false
		end
	end
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
CF.__tostring = function(c)
	return string.format("CFrame(%g, %g, %g)", c.X, c.Y, c.Z)
end
function CF.Inverse(c)
	local r = mkcf(0, 0, 0, c[1], c[4], c[7], c[2], c[5], c[8], c[3], c[6], c[9])
	local p = r * Vector3.new(-c.X, -c.Y, -c.Z)
	return mkcf(p.X, p.Y, p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
end
function CF.PointToWorldSpace(c, v)
	return c * v
end
function CF.PointToObjectSpace(c, v)
	return c:Inverse() * v
end
function CF.VectorToWorldSpace(c, v)
	return c.Rotation * v
end
function CF.VectorToObjectSpace(c, v)
	return c.Rotation:Inverse() * v
end
function CF.ToWorldSpace(c, o)
	return c * o
end
function CF.ToObjectSpace(c, o)
	return c:Inverse() * o
end
function CF.Lerp(a, b, t)
	-- Positions lerp; rotation snaps halfway (good enough for logic).
	local p = a.Position:Lerp(b.Position, t)
	local r = if t < 0.5 then a.Rotation else b.Rotation
	return r + p
end
function CF.GetComponents(c)
	return c.X, c.Y, c.Z, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9]
end
CF.components = CF.GetComponents
function CF.ToEulerAnglesXYZ(c)
	local y = math.asin(math.clamp(c[3], -1, 1))
	local x = math.atan2(-c[6], c[9])
	local z = math.atan2(-c[2], c[1])
	return x, y, z
end
function CF.ToOrientation(c)
	local x = math.asin(math.clamp(-c[6], -1, 1))
	local y = math.atan2(c[3], c[9])
	local z = math.atan2(c[4], c[5])
	return x, y, z
end
CF.ToEulerAnglesYXZ = CF.ToOrientation
function CF.ToAxisAngle(c)
	return Vector3.yAxis, 0
end
CFrame.identity = CFrame.new()

------------------------------------------------------------------ Color3 / misc
local C3 = {}
C3.__index = C3
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3 = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0, __type = "Color3" }, C3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return Color3.new(v, t, p)
	elseif i == 1 then
		return Color3.new(q, v, p)
	elseif i == 2 then
		return Color3.new(p, v, t)
	elseif i == 3 then
		return Color3.new(p, q, v)
	elseif i == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end
function Color3.fromHex(hex)
	hex = string.gsub(hex, "#", "")
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end
function C3.Lerp(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3.ToHSV(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == c.R then
			h = ((c.G - c.B) / d) % 6
		elseif mx == c.G then
			h = (c.B - c.R) / d + 2
		else
			h = (c.R - c.G) / d + 4
		end
		h /= 6
	end
	return h, if mx > 0 then d / mx else 0, mx
end
function C3.ToHex(c)
	return string.format("%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

local UD = {}
UD.__index = UD
UD.__add = function(a, b)
	return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset)
end
UD.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
UDim = {}
function UDim.new(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0, __type = "UDim" }, UD)
end
local UD2 = {}
UD2.__index = function(u, k)
	if k == "Width" then
		return u.X
	elseif k == "Height" then
		return u.Y
	end
	return UD2[k]
end
UD2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UD2.__sub = function(a, b)
	return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UD2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	if type(xs) == "table" then
		return setmetatable({ X = xs, Y = xo, __type = "UDim2" }, UD2)
	end
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo), __type = "UDim2" }, UD2)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
function UD2.Lerp(a, b, t)
	return UDim2.new(
		a.X.Scale + (b.X.Scale - a.X.Scale) * t,
		a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
	)
end

local function simple(name, fields)
	local cls = {}
	cls.new = function(...)
		local args = { ... }
		local o = { __type = name }
		for i, f in fields do
			o[f] = args[i]
		end
		return o
	end
	return cls
end
NumberRange = {
	new = function(a, b)
		return { Min = a, Max = b or a, __type = "NumberRange" }
	end,
}
NumberSequenceKeypoint = simple("NumberSequenceKeypoint", { "Time", "Value", "Envelope" })
ColorSequenceKeypoint = simple("ColorSequenceKeypoint", { "Time", "Value" })
NumberSequence = {
	new = function(a, b)
		local kp = if type(a) == "table" then a else { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) }
		return { Keypoints = kp, __type = "NumberSequence" }
	end,
}
ColorSequence = {
	new = function(a, b)
		local kp = if type(a) == "table" and not a.R then a else { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) }
		return { Keypoints = kp, __type = "ColorSequence" }
	end,
}
Rect = simple("Rect", { "MinX", "MinY", "MaxX", "MaxY" })
PhysicalProperties = simple("PhysicalProperties", { "Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight" })
Ray = { new = function(o, d)
	return { Origin = o, Direction = d, __type = "Ray" }
end }
TweenInfo = {
	new = function(time, style, dir, repeatCount, reverses, delay)
		return {
			Time = time or 1,
			EasingStyle = style,
			EasingDirection = dir,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delay or 0,
			__type = "TweenInfo",
		}
	end,
}
Font = {
	new = function(family, weight, style)
		return { Family = family, Weight = weight, Style = style, __type = "Font" }
	end,
	fromEnum = function(e)
		return { Family = tostring(e), __type = "Font" }
	end,
	fromName = function(n)
		return { Family = n, __type = "Font" }
	end,
}
BrickColor = {
	new = function(n)
		return { Name = tostring(n), Color = Color3.new(0.5, 0.5, 0.5), __type = "BrickColor" }
	end,
}
BrickColor.random = function()
	return BrickColor.new("random")
end
local function params(kind)
	return {
		new = function()
			local p = {
				FilterType = nil,
				FilterDescendantsInstances = {},
				IgnoreWater = false,
				RespectCanCollide = false,
				CollisionGroup = "Default",
				MaxParts = 0,
				__type = kind,
			}
			function p.AddToFilter(self, x)
				if type(x) == "table" and not rawget(x, "__inst") then
					for _, i in x do
						table.insert(self.FilterDescendantsInstances, i)
					end
				else
					table.insert(self.FilterDescendantsInstances, x)
				end
			end
			return p
		end,
	}
end
RaycastParams = params("RaycastParams")
OverlapParams = params("OverlapParams")

------------------------------------------------------------------ Random
local RNG = {}
RNG.__index = RNG
Random = {}
function Random.new(seed)
	local s = math.floor(tonumber(seed) or (os.clock() * 1e6)) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return setmetatable({ s = s, __type = "Random" }, RNG)
end
function RNG:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function RNG:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function RNG:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end
function RNG:NextUnitVector()
	local v = Vector3.new(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1))
	return if v.Magnitude > 0 then v.Unit else Vector3.xAxis
end
function RNG:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RNG:Clone()
	return setmetatable({ s = self.s, __type = "Random" }, RNG)
end

------------------------------------------------------------------ Enum
local enumCache = {}
local enumCounter = 0
local EnumItemMT = {
	__tostring = function(e)
		return "Enum." .. e.EnumType .. "." .. e.Name
	end,
}
local function enumType(name)
	local t = enumCache[name]
	if t then
		return t
	end
	local items = {}
	t = setmetatable({}, {
		__index = function(_, item)
			if item == "GetEnumItems" then
				return function()
					local out = {}
					for _, v in items do
						table.insert(out, v)
					end
					return out
				end
			end
			local v = items[item]
			if not v then
				enumCounter += 1
				v = setmetatable({ Name = item, Value = enumCounter, EnumType = name, __type = "EnumItem" }, EnumItemMT)
				function v.IsA(self, n)
					return self.EnumType == n
				end
				items[item] = v
			end
			return v
		end,
		__tostring = function()
			return "Enum." .. name
		end,
	})
	enumCache[name] = t
	return t
end
Enum = setmetatable({}, {
	__index = function(_, name)
		return enumType(name)
	end,
})

------------------------------------------------------------------ typeof
local rawTypeof = typeof
function typeof(v)
	if type(v) == "table" then
		local t = rawget(v, "__type")
		if t then
			return t
		end
		if rawget(v, "__inst") then
			return "Instance"
		end
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, "__inst") then
			return "Instance"
		end
	end
	return rawTypeof(v)
end

------------------------------------------------------------------ JSON
local JSON = {}
E.JSON = JSON
local function encodeValue(v, out, seen)
	local t = type(v)
	if v == nil then
		table.insert(out, "null")
	elseif t == "boolean" then
		table.insert(out, tostring(v))
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			error("JSONEncode: invalid number (NaN/inf)", 0)
		end
		if v == math.floor(v) and math.abs(v) < 1e15 then
			table.insert(out, string.format("%d", v))
		else
			table.insert(out, string.format("%.17g", v))
		end
	elseif t == "string" then
		table.insert(out, '"' .. string.gsub(v, '[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[c] or string.format("\\u%04x", string.byte(c))
		end) .. '"')
	elseif t == "table" then
		if rawget(v, "__type") then
			error("JSONEncode: cannot encode " .. tostring(rawget(v, "__type")), 0)
		end
		if seen[v] then
			error("JSONEncode: cyclic table", 0)
		end
		seen[v] = true
		local n = #v
		local isArray = n > 0 or next(v) == nil
		if isArray then
			for k in v do
				if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
					isArray = false
					break
				end
			end
		end
		if isArray then
			table.insert(out, "[")
			for i = 1, n do
				if i > 1 then
					table.insert(out, ",")
				end
				encodeValue(v[i], out, seen)
			end
			table.insert(out, "]")
		else
			table.insert(out, "{")
			local first = true
			for k, x in v do
				if type(k) ~= "string" and type(k) ~= "number" then
					error("JSONEncode: invalid key type " .. type(k), 0)
				end
				if not first then
					table.insert(out, ",")
				end
				first = false
				encodeValue(tostring(k), out, seen)
				table.insert(out, ":")
				encodeValue(x, out, seen)
			end
			table.insert(out, "}")
		end
		seen[v] = nil
	else
		error("JSONEncode: cannot encode " .. t, 0)
	end
end
function JSON.encode(v)
	local out = {}
	encodeValue(v, out, {})
	return table.concat(out)
end
function JSON.decode(s)
	local i = 1
	local function ws()
		i = string.find(s, "[^ \t\r\n]", i) or (#s + 1)
	end
	local parse
	local function str()
		i += 1
		local buf = {}
		while true do
			local c = string.sub(s, i, i)
			if c == '"' then
				i += 1
				return table.concat(buf)
			elseif c == "\\" then
				local n = string.sub(s, i + 1, i + 1)
				local map = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }
				if n == "u" then
					table.insert(buf, utf8.char(tonumber(string.sub(s, i + 2, i + 5), 16)))
					i += 6
				else
					table.insert(buf, map[n] or n)
					i += 2
				end
			elseif c == "" then
				error("JSONDecode: unterminated string", 0)
			else
				table.insert(buf, c)
				i += 1
			end
		end
	end
	parse = function()
		ws()
		local c = string.sub(s, i, i)
		if c == "{" then
			i += 1
			local o = {}
			ws()
			if string.sub(s, i, i) == "}" then
				i += 1
				return o
			end
			while true do
				ws()
				local k = str()
				ws()
				i += 1 -- :
				o[k] = parse()
				ws()
				local d = string.sub(s, i, i)
				i += 1
				if d == "}" then
					return o
				end
			end
		elseif c == "[" then
			i += 1
			local a = {}
			ws()
			if string.sub(s, i, i) == "]" then
				i += 1
				return a
			end
			while true do
				table.insert(a, parse())
				ws()
				local d = string.sub(s, i, i)
				i += 1
				if d == "]" then
					return a
				end
			end
		elseif c == '"' then
			return str()
		elseif string.sub(s, i, i + 3) == "true" then
			i += 4
			return true
		elseif string.sub(s, i, i + 4) == "false" then
			i += 5
			return false
		elseif string.sub(s, i, i + 3) == "null" then
			i += 4
			return nil
		else
			local num = string.match(s, "^-?[%d%.eE+-]+", i)
			if not num then
				error("JSONDecode: unexpected '" .. c .. "' at " .. i, 0)
			end
			i += #num
			return tonumber(num)
		end
	end
	return parse()
end
