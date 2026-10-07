-- Script loading, contexts and simulation helpers.
local E = __E
local new = E.new
E.globals = getfenv()

------------------------------------------------------------------ mounting
local function ensurePath(vp, lastKind, source, file)
	local node = E.game:GetService(vp[1])
	for i = 2, #vp do
		local name = vp[i]
		local child = node:FindFirstChild(name)
		local isLast = i == #vp
		if not child then
			local cls = "Folder"
			if isLast then
				cls = if lastKind == "server" then "Script" elseif lastKind == "client" then "LocalScript" else "ModuleScript"
			end
			child = new(cls)
			child.Name = name
			child.Parent = node
		elseif isLast and lastKind == "module" and child.ClassName == "Folder" then
			-- A directory with init.luau becomes a ModuleScript; move children.
			local mod = new("ModuleScript")
			mod.Name = name
			for _, c in child:GetChildren() do
				c.Parent = mod
			end
			child:Destroy()
			mod.Parent = node
			child = mod
		end
		node = child
	end
	if source then
		rawset(node, "__source", source)
		rawset(node, "__file", file)
	end
	return node
end
function E.mount(vp, kind, source, file)
	ensurePath(vp, kind, source, file)
end

------------------------------------------------------------------ contexts
E.moduleCache = { server = {}, client = {} }
local loading = { server = {}, client = {} }

local function makeEnv(scriptInst, context)
	local env
	env = setmetatable({
		script = scriptInst,
		game = E.game,
		workspace = E.workspace,
		Workspace = E.workspace,
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			E.record("print", "[" .. context .. "] " .. table.concat(parts, " "))
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			E.record("warn", "[" .. context .. "] " .. table.concat(parts, " ") .. "  (" .. tostring(rawget(scriptInst, "__file")) .. ")")
		end,
		require = nil,
		Instance = { new = function(className, parent)
			return new(className, parent)
		end },
		shared = {},
	}, { __index = E.globals })
	env.require = function(target)
		return E.require(target, context)
	end
	return env
end

function E.require(target, context)
	if type(target) ~= "table" or not E.isInst(target) or not target:IsA("ModuleScript") then
		error("Attempted to call require with invalid argument(s): " .. tostring(target), 2)
	end
	local cache = E.moduleCache[context]
	local cached = cache[target]
	if cached ~= nil then
		return cached.value
	end
	if loading[context][target] then
		error("Requested module was required recursively: " .. target:GetFullName(), 2)
	end
	local source = rawget(target, "__source")
	if not source then
		error("Module has no source: " .. target:GetFullName(), 2)
	end
	local fn, err = loadstring(source, "=" .. (rawget(target, "__file") or target:GetFullName()))
	if not fn then
		error("Syntax error in " .. target:GetFullName() .. ": " .. tostring(err), 2)
	end
	setfenv(fn, makeEnv(target, context))
	loading[context][target] = true
	local ok, result = pcall(fn)
	loading[context][target] = nil
	if not ok then
		error("Requested module experienced an error while loading: " .. target:GetFullName() .. ": " .. tostring(result), 2)
	end
	cache[target] = { value = result }
	return result
end

function E.runScript(scriptInst, context)
	local source = rawget(scriptInst, "__source")
	local fn, err = loadstring(source, "=" .. (rawget(scriptInst, "__file") or scriptInst:GetFullName()))
	if not fn then
		E.record("error", "Syntax error: " .. tostring(err))
		return
	end
	setfenv(fn, makeEnv(scriptInst, context))
	task.spawn(fn)
end

------------------------------------------------------------------ driving
function E.startServer()
	for _, d in E.game:GetService("ServerScriptService"):GetDescendants() do
		if d:IsA("Script") and not d:IsA("LocalScript") then
			E.runScript(d, "server")
		end
	end
end

function E.startClient(player)
	E.localPlayer = player
	E.clientRunning = true
	local sps = E.game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	for _, child in sps:GetChildren() do
		child:Clone().Parent = player:FindFirstChild("PlayerScripts")
	end
	for _, d in player:FindFirstChild("PlayerScripts"):GetDescendants() do
		if d:IsA("LocalScript") then
			E.runScript(d, "client")
		end
	end
end

-- Runs fn(...) in its own thread and advances time until it finishes.
function E.call(fn, ...)
	local done, results = false, nil
	local args = table.pack(...)
	task.spawn(function()
		results = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
		done = true
	end)
	local guard = 0
	while not done and guard < 30 * 60 do
		E.step(1 / 30)
		guard += 1
	end
	if not done then
		return false, "E.call timed out"
	end
	return table.unpack(results, 1, results.n)
end

function E.shutdown()
	local pending = 0
	for _, fn in E.closeHandlers or {} do
		pending += 1
		task.spawn(function()
			local ok, err = pcall(fn)
			if not ok then
				E.record("error", "BindToClose handler failed: " .. tostring(err))
			end
			pending -= 1
		end)
	end
	local guard = 0
	while pending > 0 and guard < 30 * 30 do
		E.step(1 / 30)
		guard += 1
	end
	return pending == 0
end

------------------------------------------------------------------ reporting
function E.countLog(kind, pattern)
	local n = 0
	for _, l in E.log do
		if l.Kind == kind and (not pattern or string.find(l.Text, pattern, 1, true)) then
			n += 1
		end
	end
	return n
end

local checks = { passed = 0, failed = 0, failures = {} }
E.checks = checks
function E.check(name, cond, detail)
	if cond then
		checks.passed += 1
		print("  ✓ " .. name)
	else
		checks.failed += 1
		local msg = "  ✗ " .. name .. (if detail then " — " .. tostring(detail) else "")
		table.insert(checks.failures, msg)
		print(msg)
	end
end

function E.summary()
	local errors, warns = E.countLog("error"), E.countLog("warn")
	print("")
	print(string.format("== %d checks passed, %d failed · %d errors · %d warnings logged", checks.passed, checks.failed, errors, warns))
	for _, f in checks.failures do
		print(f)
	end
	if E.showUnknown then
		local keys = {}
		for k in E.unknownReads do
			table.insert(keys, k)
		end
		table.sort(keys)
		print("Emulator: unknown property reads (nil): " .. table.concat(keys, ", "))
	end
	local bad = {}
	for k in E.unknownWrites do
		table.insert(bad, k)
	end
	table.sort(bad)
	if #bad > 0 then
		print("✗ property writes that are not valid in real Roblox: " .. table.concat(bad, ", "))
	end
	if checks.failed > 0 or errors > 0 or #bad > 0 then
		print("@@FAIL@@")
	end
end
