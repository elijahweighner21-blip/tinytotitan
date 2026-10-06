--!strict
--[[
	Signal
	A lightweight, allocation-friendly signal used for in-process events on both
	server and client. Handlers run on fresh threads (task.spawn) so a yielding
	or erroring listener can never break the firing code path.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type Node = {
	fn: (...any) -> (),
	next: Node?,
	connected: boolean,
	once: boolean,
}

local Signal = {}
Signal.__index = Signal

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false
	self._node.connected = false
	local signal = self._signal
	-- Unlink from the list; firing iterates a snapshot so this is safe mid-fire.
	if signal._head == self._node then
		signal._head = self._node.next
	else
		local prev = signal._head
		while prev and prev.next ~= self._node do
			prev = prev.next
		end
		if prev then
			prev.next = self._node.next
		end
	end
end

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _head = nil :: Node? }, Signal)
	return (self :: any) :: Signal<T...>
end

local function connect(self: any, fn: (...any) -> (), once: boolean): Connection
	local node: Node = { fn = fn, next = self._head, connected = true, once = once }
	self._head = node
	local connection = setmetatable({ Connected = true, _node = node, _signal = self }, ConnectionClass)
	node.fn = if once
		then function(...)
			if connection.Connected then
				connection:Disconnect()
				fn(...)
			end
		end
		else fn
	return (connection :: any) :: Connection
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	return connect(self, fn, false)
end

function Signal.Once(self: any, fn: (...any) -> ()): Connection
	return connect(self, fn, true)
end

function Signal.Fire(self: any, ...: any)
	-- Snapshot first so listeners connecting/disconnecting during fire behave predictably.
	local snapshot: { Node } = {}
	local node = self._head
	while node do
		table.insert(snapshot, node)
		node = node.next
	end
	for i = #snapshot, 1, -1 do
		local current = snapshot[i]
		if current.connected then
			task.spawn(current.fn, ...)
		end
	end
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	connect(self, function(...)
		task.spawn(thread, ...)
	end, true)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: any)
	local node = self._head
	while node do
		node.connected = false
		node = node.next
	end
	self._head = nil
end

function Signal.Destroy(self: any)
	self:DisconnectAll()
end

return Signal
