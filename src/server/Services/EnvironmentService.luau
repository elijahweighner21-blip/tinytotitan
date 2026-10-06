--!strict
--[[
	EnvironmentService
	Server-side ambient motion that affects gameplay: traffic on the front
	street (a hazard for small players, scenery for big ones). Purely visual
	ambience (grass sway, dust motes, lights) lives on the client in
	EnvironmentController so it costs the server nothing.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local EnvironmentService = {}

local LANES = {
	{ Z = 780, From = -2550, To = 3350, Speed = 260 },
	{ Z = 940, From = 3350, To = -2550, Speed = 220 },
}

local function makeCar(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "TrafficCar"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(200, 60, 90)
	body.Color = color
	body.Material = Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Size = Vector3.new(110, 40, 84)
	cabin.Color = Color3.fromRGB(40, 60, 80)
	cabin.Material = Enum.Material.Glass
	cabin.Anchored = true
	cabin.CanCollide = false
	cabin.Parent = model
	model.PrimaryPart = body
	CollectionService:AddTag(body, "Hazard")
	body:SetAttribute("Damage", 35)
	return model
end

local function driveLoop(lane: { Z: number, From: number, To: number, Speed: number }, color: Color3, offset: number)
	local folder = workspace:FindFirstChild("World") or workspace
	local car = makeCar(color)
	car.Parent = folder
	local body = car.PrimaryPart :: BasePart
	local cabin = car:FindFirstChild("Cabin") :: BasePart
	local dir = math.sign(lane.To - lane.From)
	local length = math.abs(lane.To - lane.From)
	local duration = length / lane.Speed
	task.wait(offset)
	while car.Parent do
		local startCF = CFrame.lookAt(Vector3.new(lane.From, 31, lane.Z), Vector3.new(lane.From + dir, 31, lane.Z)) * CFrame.Angles(0, math.rad(90), 0)
		local endCF = startCF + Vector3.new(lane.To - lane.From, 0, 0)
		body.CFrame = startCF
		cabin.CFrame = startCF * CFrame.new(10, 50, 0)
		local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
		local t1 = TweenService:Create(body, info, { CFrame = endCF })
		local t2 = TweenService:Create(cabin, info, { CFrame = endCF * CFrame.new(10, 50, 0) })
		t1:Play()
		t2:Play()
		t1.Completed:Wait()
		task.wait(2 + math.random() * 4)
	end
end

function EnvironmentService:Start()
	local colors = { Color3.fromRGB(200, 50, 50), Color3.fromRGB(50, 90, 200), Color3.fromRGB(240, 240, 240), Color3.fromRGB(240, 190, 40) }
	for i, lane in LANES do
		for j = 1, 2 do
			task.spawn(function()
				local ok, err = pcall(function()
					driveLoop(lane, colors[(i + j) % #colors + 1], (j - 1) * 12)
				end)
				if not ok then
					Log.warn("Environment", "traffic loop stopped", err)
				end
			end)
		end
	end
end

return EnvironmentService
