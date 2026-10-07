-- HUD layout at several resolutions/devices: on-screen and non-overlapping.
local E = __E
E.startServer()
E.run(3)
local UIS = E.game:GetService("UserInputService")
local function boot(touch)
	rawget(UIS, "__props").TouchEnabled = touch
	rawget(UIS, "__props").KeyboardEnabled = not touch
	rawget(UIS, "__props").MouseEnabled = not touch
	E.lastInputType = if touch then Enum.UserInputType.Touch else Enum.UserInputType.Keyboard
	local p = E.addPlayer(if touch then "Phone" else "Desk", { client = true })
	E.startClient(p)
	E.waitFor(function()
		return E.data(p) ~= nil and p.Character ~= nil
	end, 30)
	E.run(10)
	return p
end
local SCREENS = {
	{ Name = "small phone", Size = Vector2.new(667, 375), Touch = true },
	{ Name = "phone", Size = Vector2.new(844, 390), Touch = true },
	{ Name = "tablet", Size = Vector2.new(1024, 768), Touch = true },
	{ Name = "laptop", Size = Vector2.new(1366, 768), Touch = false },
	{ Name = "desktop", Size = Vector2.new(1920, 1080), Touch = false },
	{ Name = "ultrawide", Size = Vector2.new(2560, 1080), Touch = false },
}
local function collect(gui)
	local items = {}
	local hud = gui:FindFirstChild("TT_HUD")
	for _, c in hud:GetChildren() do
		if c:IsA("GuiObject") and c.Visible and c.Name ~= "MobileControls" then
			table.insert(items, c)
		end
	end
	local mc = hud:FindFirstChild("MobileControls")
	if mc and mc.Visible then
		for _, c in mc:GetChildren() do
			if c:IsA("GuiObject") then
				table.insert(items, c)
			end
		end
	end
	return items
end
local function overlap(a, b)
	return a.X < b.X + b.W - 2 and b.X < a.X + a.W - 2 and a.Y < b.Y + b.H - 2 and b.Y < a.Y + a.H - 2
end
-- Elements that are allowed to share space (full-screen containers).
local IGNORE = { MarkerArrows = true }
local players = {}
for _, screen in SCREENS do
	local key = if screen.Touch then "touch" else "desk"
	if not players[key] then
		players[key] = boot(screen.Touch)
	end
	local p = players[key]
	E.localPlayer = p
	E.workspace.CurrentCamera.ViewportSize = screen.Size
	E.run(1)
	local gui = p:FindFirstChild("PlayerGui")
	local items = collect(gui)
	local rects = {}
	local off = {}
	for _, item in items do
		local r = E.absRect(item)
		if r and not IGNORE[item.Name] then
			rects[item] = r
			if r.X < -1 or r.Y < -1 or r.X + r.W > screen.Size.X + 1 or r.Y + r.H > screen.Size.Y + 1 then
				table.insert(off, string.format("%s (%d,%d %dx%d)", item.Name, r.X, r.Y, r.W, r.H))
			end
		end
	end
	local overlaps = {}
	local list = {}
	for item, r in rects do
		table.insert(list, { item = item, r = r })
	end
	for i = 1, #list do
		for j = i + 1, #list do
			if overlap(list[i].r, list[j].r) then
				table.insert(overlaps, list[i].item.Name .. " × " .. list[j].item.Name)
			end
		end
	end
	table.sort(overlaps)
	E.check(screen.Name .. " " .. screen.Size.X .. "x" .. screen.Size.Y .. ": HUD fully on screen", #off == 0, table.concat(off, ", "))
	E.check(screen.Name .. ": no overlapping HUD elements", #overlaps == 0, table.concat(overlaps, ", "))
	local menus = gui:FindFirstChild("TT_Menus")
	local worst = nil
	for _, window in menus:GetChildren() do
		if window:IsA("Frame") and window.Name ~= "Backdrop" then
			local r = E.absRect(window)
			local limit = window:FindFirstChildOfClass("UISizeConstraint")
			if r and limit then
				r.W = math.min(r.W, limit.MaxSize.X * r.S)
				r.H = math.min(r.H, limit.MaxSize.Y * r.S)
				r.X = screen.Size.X / 2 - r.W / 2
				r.Y = screen.Size.Y / 2 - r.H / 2
			end
			if r and (r.X < 0 or r.Y < 0 or r.X + r.W > screen.Size.X or r.Y + r.H > screen.Size.Y) then
				worst = string.format("%s %dx%d", window.Name, r.W, r.H)
			end
		end
	end
	E.check(screen.Name .. ": every menu window fits", worst == nil, worst)
end
E.summary()
