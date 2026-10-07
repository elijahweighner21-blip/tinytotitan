-- Scenario helpers specific to this project (drive remotes, read state).
local E = __E

function E.serverModule(path)
	local node = E.game:GetService("ServerScriptService"):FindFirstChild("Server")
	for part in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(part)
		assert(node, "no server module " .. path)
	end
	return E.require(node, "server")
end
function E.sharedModule(path, context)
	local node = E.game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
	for part in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(part)
		assert(node, "no shared module " .. path)
	end
	return E.require(node, context or "server")
end

local function remote(name)
	local folder = E.game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	assert(folder, "Remotes folder missing")
	return folder:FindFirstChild(name)
end
E.remote = remote

-- Sends an Action as if `player`'s client called Net.action.
function E.action(player, name, payload)
	E.sig(remote("Action"), "OnServerEvent"):Fire(player, name, E.wireCopy(payload))
	E.run(1 / 30)
end
-- Sends a Request as if `player`'s client called Net.request; returns the result.
function E.request(player, name, payload)
	local handler = rawget(remote("Request"), "__props").OnServerInvoke
	local ok, result = E.call(handler, player, name, E.wireCopy(payload))
	if not ok then
		return { ok = false, err = "invoke error: " .. tostring(result) }
	end
	return result
end

function E.waitFor(cond, timeout, label)
	local t = 0
	while not cond() do
		E.step(1 / 30)
		t += 1 / 30
		if t > (timeout or 30) then
			E.record("warn", "waitFor timed out: " .. tostring(label))
			return false
		end
	end
	return true
end

function E.data(player)
	return E.serverModule("Services.PlayerDataService"):Get(player)
end
function E.root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
function E.teleport(player, position)
	local c = player.Character
	c:PivotTo(CFrame.new(position))
	player:SetAttribute("TeleportGrace", E.epoch + E.now)
end
-- Walks the character toward a point at a plausible speed (keeps anti-exploit happy).
function E.walkTo(player, position, speed, stopWhen)
	local root = E.root(player)
	if not root then
		return
	end
	local start = root.Position
	local dist = (position - start).Magnitude
	local v = speed or 12
	local steps = math.max(1, math.ceil(dist / v * 30))
	for i = 1, steps do
		if stopWhen and stopWhen() then
			return
		end
		local p = start:Lerp(position, i / steps)
		player.Character:PivotTo(CFrame.new(p))
		E.step(1 / 30)
	end
end
function E.errorsSince(mark)
	local out = {}
	for i = mark + 1, #E.log do
		if E.log[i].Kind == "error" then
			table.insert(out, E.log[i].Text)
		end
	end
	return out
end
