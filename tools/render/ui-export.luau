-- Dumps the client's PlayerGui (HUD, and each menu opened in turn) as JSON
-- for tools/render/ui.mjs, which lays it out with CSS and screenshots it.
local E = __E
local HttpService = E.game:GetService("HttpService")
E.startServer()
E.run(3)
if E.defines.phone then
	-- A touch phone (844×390), so the UI lays itself out for mobile.
	local UIS = E.game:GetService("UserInputService")
	rawget(UIS, "__props").TouchEnabled = true
	rawget(UIS, "__props").KeyboardEnabled = false
	rawget(UIS, "__props").MouseEnabled = false
	E.lastInputType = Enum.UserInputType.Touch
	E.workspace.CurrentCamera.ViewportSize = Vector2.new(844, 390)
end
local p = E.addPlayer("Viewer", { UserId = 9191, client = true })
E.startClient(p)
local PDS = E.serverModule("Services.PlayerDataService")
E.waitFor(function()
	return PDS:IsLoaded(p) and p.Character ~= nil
end, 40, "spawn")
-- A mid-game save so menus have content.
local rewards = E.serverModule("Services.RewardService")
rewards:Grant(p, { Mass = 900, GrowthEnergy = 2500, TitanShards = 120, XP = 400 }, { Source = "Admin" })
E.run(10)

local function c3(c)
	return if c then { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } else nil
end
local function udim2(u)
	return if u then { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } else nil
end
local ZERO = UDim.new(0, 0)
local function ud(u)
	return u or ZERO
end
local function v2(v)
	return if v then { v.X, v.Y } else nil
end
local function enumName(e)
	return if e then e.Name else nil
end
local function colorSeq(seq)
	if not seq then
		return { { 0, { 255, 255, 255 } }, { 1, { 255, 255, 255 } } }
	end
	local out = {}
	for _, k in seq.Keypoints do
		table.insert(out, { k.Time, c3(k.Value) })
	end
	return out
end
local function numSeq(seq)
	if not seq then
		return { { 0, 0 }, { 1, 0 } }
	end
	local out = {}
	for _, k in seq.Keypoints do
		table.insert(out, { k.Time, k.Value })
	end
	return out
end

local function node(o)
	local n = { c = o.ClassName, n = o.Name, kids = {} }
	if o:IsA("ScreenGui") then
		n.enabled = o.Enabled
		n.order = o.DisplayOrder
	elseif o:IsA("GuiObject") then
		n.vis = o.Visible
		n.size = udim2(o.Size)
		n.pos = udim2(o.Position)
		n.anchor = v2(o.AnchorPoint)
		n.z = o.ZIndex
		n.lo = o.LayoutOrder
		n.bg = c3(o.BackgroundColor3)
		n.bgt = o.BackgroundTransparency
		n.rot = o.Rotation
		n.clip = o.ClipsDescendants
		n.auto = enumName(o.AutomaticSize)
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			n.text = o.Text
			n.tc = c3(o.TextColor3)
			n.tt = o.TextTransparency
			n.ts = o.TextSize
			n.scaled = o.TextScaled
			n.wrap = o.TextWrapped
			n.xa = enumName(o.TextXAlignment)
			n.ya = enumName(o.TextYAlignment)
			n.rich = o.RichText
			local face = o.FontFace
			n.weight = if face and face.Weight then face.Weight.Name else "Regular"
			n.mono = face and string.find(face.Family, "Mono") ~= nil
			n.st = o.TextStrokeTransparency
			n.sc = c3(o.TextStrokeColor3)
		end
		if o:IsA("ImageLabel") or o:IsA("ImageButton") then
			n.img = o.Image
			n.ic = c3(o.ImageColor3)
			n.it = o.ImageTransparency
		end
		if o:IsA("ScrollingFrame") then
			n.canvas = udim2(o.CanvasSize)
		end
	elseif o:IsA("UICorner") then
		n.r = { ud(o.CornerRadius).Scale, ud(o.CornerRadius).Offset }
	elseif o:IsA("UIStroke") then
		n.color = c3(o.Color)
		n.th = o.Thickness or 1
		n.t = o.Transparency or 0
		n.mode = enumName(o.ApplyStrokeMode)
		n.on = o.Enabled
	elseif o:IsA("UIGradient") then
		n.color = colorSeq(o.Color)
		n.t = numSeq(o.Transparency)
		n.rot = o.Rotation
		n.on = o.Enabled
	elseif o:IsA("UIPadding") then
		n.pad = {
			ud(o.PaddingTop).Scale,
			ud(o.PaddingTop).Offset,
			ud(o.PaddingRight).Scale,
			ud(o.PaddingRight).Offset,
			ud(o.PaddingBottom).Scale,
			ud(o.PaddingBottom).Offset,
			ud(o.PaddingLeft).Scale,
			ud(o.PaddingLeft).Offset,
		}
	elseif o:IsA("UIListLayout") then
		n.dir = enumName(o.FillDirection)
		n.gap = { ud(o.Padding).Scale, ud(o.Padding).Offset }
		n.ha = enumName(o.HorizontalAlignment)
		n.va = enumName(o.VerticalAlignment)
		n.sort = enumName(o.SortOrder)
		n.wraps = o.Wraps
	elseif o:IsA("UIGridLayout") then
		n.cell = udim2(o.CellSize) or { 0, 100, 0, 100 }
		n.cellPad = udim2(o.CellPadding) or { 0, 5, 0, 5 }
		n.dir = enumName(o.FillDirection)
		n.ha = enumName(o.HorizontalAlignment)
		n.va = enumName(o.VerticalAlignment)
		n.sort = enumName(o.SortOrder)
		n.maxCells = o.FillDirectionMaxCells or 0
	elseif o:IsA("UISizeConstraint") then
		n.min = v2(o.MinSize) or { 0, 0 }
		n.max = v2(o.MaxSize) or { 1e9, 1e9 }
	elseif o:IsA("UIAspectRatioConstraint") then
		n.ratio = o.AspectRatio
	elseif o:IsA("UIScale") then
		n.scale = o.Scale or 1
	elseif o:IsA("UITextSizeConstraint") then
		n.maxText = o.MaxTextSize
		n.minText = o.MinTextSize
	else
		return nil
	end
	for _, child in o:GetChildren() do
		local k = node(child)
		if k then
			table.insert(n.kids, k)
		end
	end
	return n
end

local function snapshot(name)
	local guis = {}
	for _, g in p.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") then
			table.insert(guis, node(g))
		end
	end
	local json = HttpService:JSONEncode({ name = name, guis = guis })
	for i = 1, #json, 30000 do
		print("@@UI@@" .. name .. "@@" .. string.sub(json, i, i + 29999))
	end
end

local function client(path)
	local nodeInst = p:FindFirstChild("PlayerScripts"):FindFirstChild("Client")
	for part in string.gmatch(path, "[^%.]+") do
		nodeInst = nodeInst:FindFirstChild(part)
	end
	return E.require(nodeInst, "client")
end
local UIManager = client("UI.UIManager")
-- Dismiss the welcome card if it is up.
pcall(function()
	UIManager:CloseAll()
end)
E.run(2)
do
	-- Re-show the loading screen on top of the loaded game to capture it.
	local LoadingScreen = client("UI.Hud.LoadingScreen")
	LoadingScreen.show()
	E.run(2)
	snapshot("loading")
	p.PlayerGui.TT_Loading.Loading:Destroy()
	E.run(0.5)
end
snapshot("hud")
for _, menu in (E.uiMenus or {
	"Upgrades",
	"Skills",
	"Shop",
	"Quests",
	"Inventory",
	"Daily",
	"Map",
	"Settings",
	"Challenges",
	"Collections",
	"Achievements",
	"Ascension",
}) do
	task.spawn(function()
		UIManager:Open(menu)
	end)
	E.run(1.5)
	snapshot(menu)
	task.spawn(function()
		UIManager:Close(menu)
	end)
	E.run(0.6)
end
