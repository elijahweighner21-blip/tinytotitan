--!strict
--[[
	EnemyFxController
	Makes nearby threats readable and hits feel solid:
	  * the closest enemies get a soft outline (red; bosses orange), so dark
	    creatures never vanish against dark floors
	  * every hit flashes the creature white for a moment
	Roblox renders a limited number of Highlights, so only the nearest few
	get one (fewer on the Low preset).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MovementController = require(script.Parent.MovementController)
local EnvironmentController = require(script.Parent.EnvironmentController)

local EnemyFxController = {}

type Tracked = { Highlight: Highlight, Conn: RBXScriptConnection, LastHealth: number }

local tracked: { [Model]: Tracked } = {}
local lastRefresh = 0

local function untrack(model: Model)
	local t = tracked[model]
	if t then
		t.Conn:Disconnect()
		t.Highlight:Destroy()
		tracked[model] = nil
	end
end

local function track(model: Model, boss: boolean)
	if tracked[model] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "TT_Threat"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 1
	highlight.OutlineColor = if boss then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(255, 90, 90)
	highlight.OutlineTransparency = 0.55
	highlight.Parent = model
	local entry: Tracked = {
		Highlight = highlight,
		LastHealth = (model:GetAttribute("Health") :: number?) or 0,
		Conn = model:GetAttributeChangedSignal("Health"):Connect(function()
			local t = tracked[model]
			if not t then
				return
			end
			local hp = (model:GetAttribute("Health") :: number?) or 0
			if hp < t.LastHealth then
				t.Highlight.FillTransparency = 0.35
				TweenService:Create(t.Highlight, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { FillTransparency = 1 })
					:Play()
			end
			t.LastHealth = hp
		end),
	}
	tracked[model] = entry
end

local function refresh()
	local root = MovementController:GetRoot()
	if not root then
		return
	end
	local origin = root.Position
	local range = math.max(MovementController:GetHeight() * 40, 160)
	local limit = if EnvironmentController:GetPreset() == "Low" then 3 else 6
	local candidates: { { Model: Model, D: number, Boss: boolean } } = {}
	for _, tag in { "Enemy", "Boss" } do
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("Model") and inst.PrimaryPart and inst.Parent then
				local d = (inst.PrimaryPart.Position - origin).Magnitude
				if d < range then
					table.insert(candidates, { Model = inst, D = d, Boss = tag == "Boss" })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		-- Bosses always keep their outline.
		if a.Boss ~= b.Boss then
			return a.Boss
		end
		return a.D < b.D
	end)
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(#candidates, limit) do
		local c = candidates[i]
		keep[c.Model] = true
		track(c.Model, c.Boss)
	end
	for model in tracked do
		if not keep[model] or not model.Parent then
			untrack(model)
		end
	end
end

function EnemyFxController:Start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastRefresh >= 0.5 then
			lastRefresh = now
			refresh()
		end
	end)
end

return EnemyFxController
