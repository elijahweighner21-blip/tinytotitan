--[[
	Generates docs/REMOTE_AUDIT.md from the live networking contract:
	  node tools/test/runner.mjs --script tools/docs/remote-audit.luau > docs/REMOTE_AUDIT.md
	For each client→server message it lists the rate limit, purpose, the
	server module that handles it and the payload guard used there.
]]

local Net = require(Shared.Net)

local handlers: { [string]: { Module: string, Guard: string } } = {}
local function scan(node)
	local src = sourceOf(node)
	if src then
		local start = 1
		while true do
			local s, e, kind, name = string.find(src, "Net%.on(%a+)%(%s*\"([%w_]+)\",", start)
			if not s then
				break
			end
			start = e + 1
			if kind == "Action" or kind == "Request" then
				local rest = string.gsub(string.sub(src, e + 1, e + 120), "^%s+", "")
				local guard = string.match(rest, "^(Guard%.[%w_]+)")
					or (if string.sub(rest, 1, 3) == "nil" then "none (no payload)" elseif string.sub(rest, 1, 8) == "validate" then "custom validator" else "see handler")
				handlers[name] = { Module = rawget(node, "Name"), Guard = guard }
			end
		end
	end
	for _, child in childrenOf(node) do
		scan(child)
	end
end
scan(Server)

local function sortedKeys(t)
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local out = {}
local function line(s)
	table.insert(out, s)
end

line("# Remote security audit")
line("")
line("_Generated from `src/shared/Net/init.luau` by `tools/docs/remote-audit.luau` — do not edit by hand._")
line("")
line("The game uses exactly six remotes. Every client→server message is a `(name, payload)` pair; the server")
line("drops names that are not declared below, enforces the per-player token-bucket rate limit, refuses")
line("gameplay messages until the player's data has loaded, validates the payload with a `Guard` schema, and")
line("only then calls the handler. Handlers never trust client numbers for rewards, positions or prices.")
line("")
line("| Remote | Type | Direction |")
line("|---|---|---|")
for _, name in sortedKeys(Net.Remotes) do
	local dir = if name == "Action" or name == "Request" then "client → server" else "server → client"
	line(string.format("| %s | %s | %s |", name, Net.Remotes[name], dir))
end
line("")
for _, section in { { "Actions (fire-and-forget)", Net.Actions }, { "Requests (return a result)", Net.Requests } } do
	line("## " .. section[1])
	line("")
	line("| Message | Rate (/s) | Burst | Handler | Payload guard | Purpose |")
	line("|---|---|---|---|---|---|")
	for _, name in sortedKeys(section[2]) do
		local limit = section[2][name]
		local h = handlers[name]
		line(string.format("| `%s` | %s | %d | %s | %s | %s |", name, tostring(limit.Rate), limit.Burst, if h then h.Module else "**MISSING**", if h then h.Guard else "-", limit.Purpose))
	end
	line("")
end
line("## Server → client signals")
line("")
line(table.concat(sortedKeys(Net.Signals), ", "))
line("")
line("## Abuse handling")
line("")
line("* Rate-limit overruns and malformed payloads are dropped and reported to `AntiExploitService`, which")
line("  keeps a decaying suspicion score (logged; never auto-bans on a single signal).")
line("* `Admin` requests from non-admins are refused and flagged.")
line("* Movement is client-authoritative for feel, but the server validates speed/teleports, ability")
line("  energy and cooldowns, attack range/arc, pickup distance and interaction reach.")
line("* Robux purchases are granted only inside `ProcessReceipt`, idempotently, with a receipt ledger in")
line("  the player's save; `PromptPurchase` can only show Roblox's prompt.")
print(table.concat(out, "\n"))
