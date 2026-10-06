--!strict
--[[
	Loader
	Two-phase service lifecycle. All services are required first (so every
	module is available), then `Init` runs on each in ORDER (wire up handlers,
	no yielding on other services), then `Start` runs on each (may spawn loops).
	A failure in one service is logged loudly but does not stop the others.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Log = require(ReplicatedStorage:WaitForChild("Shared").Util.Log)

local Loader = {}

type Service = { Init: ((self: any) -> ())?, Start: ((self: any) -> ())? }

function Loader.run(folder: Instance, order: { string })
	local services: { { name: string, module: Service } } = {}
	local seen: { [string]: boolean } = {}

	local function load(name: string)
		local moduleScript = folder:FindFirstChild(name)
		if not moduleScript or not moduleScript:IsA("ModuleScript") then
			Log.error("Loader", "missing service", name)
			return
		end
		local ok, result = pcall(require, moduleScript)
		if not ok then
			Log.error("Loader", "failed to require", name, result)
			return
		end
		seen[name] = true
		table.insert(services, { name = name, module = result :: any })
	end

	for _, name in order do
		load(name)
	end
	-- Any service not listed explicitly still loads (after the ordered ones).
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") and not seen[child.Name] then
			Log.warn("Loader", "service not in load order, loading last:", child.Name)
			load(child.Name)
		end
	end

	for _, entry in services do
		local init = entry.module.Init
		if init then
			local ok, err = pcall(function()
				init(entry.module)
			end)
			if not ok then
				Log.error("Loader", entry.name .. ":Init failed:", err)
			end
		end
	end
	for _, entry in services do
		local start = entry.module.Start
		if start then
			task.spawn(function()
				local ok, err = pcall(function()
					start(entry.module)
				end)
				if not ok then
					Log.error("Loader", entry.name .. ":Start failed:", err)
				end
			end)
		end
	end
	return #services
end

return Loader
