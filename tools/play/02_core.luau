-- Scheduler, signals and logging for the headless engine.
local E = __E
E.deferredEvents = true -- like Workspace.SignalBehavior = Default (Deferred) in real Roblox

E.now = 1000 -- virtual seconds since "server start"
E.epoch = 1791000000 -- os.time() at now = 0 (a fixed date for reproducibility)
E.log = {} -- { Kind = "error"|"warn"|"print", Text = string }
E.printEcho = false

local function record(kind, text)
	table.insert(E.log, { Kind = kind, Text = text, At = E.now })
	if kind ~= "print" or E.printEcho then
		print((if kind == "error" then "ERROR " elseif kind == "warn" then "WARN  " else "      ") .. text)
	end
end
E.record = record

------------------------------------------------------------------ profiling
local realClock = os.clock
E.realClock = realClock
E.profile = {} -- label -> { time, calls }
E.profiling = false
local labels = setmetatable({}, { __mode = "k" })
local function labelFor(fn)
	local src, line, name = debug.info(fn, "sln")
	return string.format("%s:%d %s", tostring(src), line or 0, name or "")
end

------------------------------------------------------------------ threads
local waiting = {} -- array of { thread, wake, token, args }
local deferred = {} -- array of { thread, args }
local tokens = setmetatable({}, { __mode = "k" }) -- thread -> current wait token
local WAIT = {}
E.WAIT = WAIT

local function reportError(co, err)
	local msg = tostring(err)
	record("error", msg .. "\n" .. debug.traceback(co))
end

-- Resumes a thread; handles engine waits and errors.
local function resume(co, ...)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	tokens[co] = nil
	local t0 = if E.profiling then realClock() else 0
	local ok, a, b = coroutine.resume(co, ...)
	if E.profiling then
		local label = labels[co] or "?"
		local entry = E.profile[label]
		if not entry then
			entry = { time = 0, calls = 0 }
			E.profile[label] = entry
		end
		entry.time += realClock() - t0
		entry.calls += 1
	end
	if not ok then
		reportError(co, a)
		return
	end
	if a == WAIT and coroutine.status(co) == "suspended" then
		local token = {}
		tokens[co] = token
		table.insert(waiting, { thread = co, wake = E.now + b, token = token, started = E.now })
	end
end
E.resume = resume

local function spawnFn(fn, ...)
	if type(fn) == "thread" then
		resume(fn, ...)
		return fn
	end
	local co = coroutine.create(fn)
	labels[co] = labelFor(fn)
	resume(co, ...)
	return co
end

task = {}
function task.spawn(fn, ...)
	return spawnFn(fn, ...)
end
function task.defer(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	if type(fn) == "function" then
		labels[co] = labelFor(fn)
	end
	table.insert(deferred, { thread = co, args = table.pack(...) })
	return co
end
function task.delay(t, fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	if type(fn) == "function" then
		labels[co] = labelFor(fn)
	end
	local args = table.pack(...)
	local token = {}
	tokens[co] = token
	table.insert(waiting, { thread = co, wake = E.now + (t or 0), token = token, args = args, fresh = true })
	return co
end
function task.wait(t)
	local co = coroutine.running()
	if not co or not coroutine.isyieldable() then
		error("task.wait called outside a yieldable thread", 2)
	end
	local start = E.now
	coroutine.yield(WAIT, math.max(t or 0, 1 / 60))
	return E.now - start
end
function task.cancel(co)
	tokens[co] = nil
	if type(co) == "thread" and coroutine.status(co) == "suspended" then
		pcall(coroutine.close, co)
	end
end
wait = task.wait
spawn = task.spawn
delay = task.delay

-- Yields the current thread until `resumeWith` is called by someone.
function E.yieldUntilResumed()
	return coroutine.yield()
end

------------------------------------------------------------------ signals
local SignalMT = {}
SignalMT.__index = SignalMT
function E.signal(name)
	return setmetatable({ _conns = {}, _name = name, __type = "RBXScriptSignal" }, SignalMT)
end
function SignalMT:Connect(fn)
	local conn
	conn = {
		Connected = true,
		_fn = fn,
		__type = "RBXScriptConnection",
		Disconnect = function(c)
			c.Connected = false
		end,
	}
	table.insert(self._conns, conn)
	return conn
end
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
SignalMT.ConnectParallel = SignalMT.Connect
function SignalMT:Wait()
	local co = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end
function SignalMT:Fire(...)
	local list = self._conns
	local alive = {}
	for _, c in list do
		if c.Connected then
			table.insert(alive, c)
		end
	end
	self._conns = alive
	for _, c in alive do
		if c.Connected then
			if E.deferredEvents then
				-- Workspace.SignalBehavior = Deferred (the default for new
				-- places): handlers run at the next resumption point, and a
				-- connection disconnected in the meantime never runs.
				local co = task.defer(function(...)
					if c.Connected then
						c._fn(...)
					end
				end, ...)
				if E.profiling then
					labels[co] = labelFor(c._fn)
				end
			else
				spawnFn(c._fn, ...)
			end
		end
	end
end
function SignalMT:Count()
	local n = 0
	for _, c in self._conns do
		if c.Connected then
			n += 1
		end
	end
	return n
end

------------------------------------------------------------------ stepping
E.stepSignals = {} -- ordered list of { signal, name }
E.renderBindings = {} -- name -> { priority, fn }

local function runDeferred()
	local guard = 0
	while #deferred > 0 and guard < 10000 do
		guard += 1
		local d = table.remove(deferred, 1)
		resume(d.thread, table.unpack(d.args, 1, d.args.n))
	end
end
E.runDeferred = runDeferred

local function runTimers()
	for _ = 1, 1000 do
		local due, keep = {}, {}
		for _, w in waiting do
			if w.wake <= E.now then
				table.insert(due, w)
			else
				table.insert(keep, w)
			end
		end
		if #due == 0 then
			return
		end
		waiting = keep
		table.sort(due, function(a, b)
			return a.wake < b.wake
		end)
		for _, w in due do
			if tokens[w.thread] == w.token then
				if w.fresh then
					resume(w.thread, table.unpack(w.args, 1, w.args.n))
				else
					resume(w.thread, E.now - w.started)
				end
			end
			runDeferred()
		end
	end
end

-- Advances virtual time by dt, firing per-frame signals and timers.
function E.step(dt)
	E.now += dt
	E.frameDt = dt
	runTimers()
	for _, entry in E.stepSignals do
		entry.signal:Fire(if entry.withTime then E.now else dt, dt)
		runDeferred()
	end
	local binds = {}
	for name, b in E.renderBindings do
		table.insert(binds, b)
	end
	table.sort(binds, function(a, b)
		return a.priority < b.priority
	end)
	for _, b in binds do
		spawnFn(b.fn, dt)
	end
	runDeferred()
	if E.afterStep then
		E.afterStep(dt)
	end
end

-- Runs the simulation for `seconds` at `fps`.
function E.run(seconds, fps)
	local dt = 1 / (fps or 30)
	local steps = math.max(1, math.floor(seconds / dt + 0.5))
	for _ = 1, steps do
		E.step(dt)
	end
end

function E.pendingCount()
	return #waiting, #deferred
end

------------------------------------------------------------------ time
local realOs = os
E.realOs = realOs
os = setmetatable({
	clock = function()
		return E.now
	end,
	time = function(t)
		if t then
			return realOs.time(t)
		end
		return math.floor(E.epoch + E.now)
	end,
}, { __index = realOs })
tick = function()
	return E.epoch + E.now
end
time = function()
	return E.now
end
elapsedTime = time
DateTime = {
	now = function()
		local t = E.epoch + E.now
		return { UnixTimestamp = math.floor(t), UnixTimestampMillis = math.floor(t * 1000), __type = "DateTime" }
	end,
	fromUnixTimestamp = function(t)
		return { UnixTimestamp = t, UnixTimestampMillis = t * 1000, __type = "DateTime" }
	end,
}

function E.profileReport(top, seconds)
	local rows = {}
	local total = 0
	for label, e in E.profile do
		table.insert(rows, { label = label, time = e.time, calls = e.calls })
		total += e.time
	end
	table.sort(rows, function(a, b)
		return a.time > b.time
	end)
	print(string.format("   total script CPU: %.1f ms per simulated second", total * 1000 / seconds))
	for i = 1, math.min(top or 15, #rows) do
		local r = rows[i]
		print(string.format("   %6.2f ms/s  %6d calls  %s", r.time * 1000 / seconds, r.calls, r.label))
	end
end
