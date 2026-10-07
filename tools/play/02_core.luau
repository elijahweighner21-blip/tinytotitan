-- Scheduler, signals and logging for the headless engine.
local E = __E

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
	local ok, a, b = coroutine.resume(co, ...)
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
	resume(co, ...)
	return co
end

task = {}
function task.spawn(fn, ...)
	return spawnFn(fn, ...)
end
function task.defer(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	table.insert(deferred, { thread = co, args = table.pack(...) })
	return co
end
function task.delay(t, fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
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
			spawnFn(c._fn, ...)
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
