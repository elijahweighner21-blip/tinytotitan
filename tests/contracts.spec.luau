-- Client ⇄ server contract checks. The client can't run headless, so these
-- scan source text to catch the bugs a type checker can't: a remote name the
-- server never handles, a signal nobody listens to, a menu that was never
-- registered, a sound that doesn't exist.
local Net = require(Shared.Net)
local AudioConfig = require(Shared.Config.AudioConfig)
local NPCConfig = require(Shared.Config.NPCConfig)
local DataSchema = require(Shared.Data.DataSchema)

local function gather(node, out)
	local src = sourceOf(node)
	if src then
		out[#out + 1] = src
	end
	for _, child in childrenOf(node) do
		gather(child, out)
	end
	return out
end

local clientSrc = table.concat(gather(Client, {}), "\n")
local serverSrc = table.concat(gather(Server, {}), "\n")

local function names(src, pattern)
	local set = {}
	for name in string.gmatch(src, pattern) do
		set[name] = true
	end
	return set
end

local function missing(set, allowed)
	local out = {}
	for name in set do
		if not allowed[name] then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

local function expectNone(list, what)
	if #list > 0 then
		error(what .. ": " .. table.concat(list, ", "))
	end
end

describe("Remotes", function()
	it("client actions are declared", function()
		expectNone(missing(names(clientSrc, 'Net%.action%(%s*"([%w_]+)"'), Net.Actions), "undeclared actions")
	end)
	it("client requests are declared", function()
		local used = names(clientSrc, 'Net%.request%(%s*"([%w_]+)"')
		for k in names(clientSrc, 'Common%.request%(%s*"([%w_]+)"') do
			used[k] = true
		end
		expectNone(missing(used, Net.Requests), "undeclared requests")
	end)
	it("every declared action and request has a server handler", function()
		local handled = names(serverSrc, 'Net%.onAction%(%s*"([%w_]+)"')
		for k in names(serverSrc, 'Net%.onRequest%(%s*"([%w_]+)"') do
			handled[k] = true
		end
		local declared = {}
		for k in Net.Actions do
			declared[k] = true
		end
		for k in Net.Requests do
			declared[k] = true
		end
		expectNone(missing(declared, handled), "declared but unhandled")
		expectNone(missing(handled, declared), "handled but undeclared")
	end)
end)

describe("Signals", function()
	local sent = names(serverSrc, 'Net%.signal%(%s*[%w_%.]+,%s*"([%w_]+)"')
	for k in names(serverSrc, 'Net%.signalAll%(%s*"([%w_]+)"') do
		sent[k] = true
	end
	sent.Challenge = true -- sent through ChallengeService's local helper
	sent.Boss = true -- sent through BossService's broadcast helper
	local heard = names(clientSrc, 'Net%.onSignal%(%s*"([%w_]+)"')
	it("server signals are declared", function()
		expectNone(missing(sent, Net.Signals), "undeclared signals")
	end)
	it("client listens only to declared signals", function()
		expectNone(missing(heard, Net.Signals), "unknown signals")
	end)
	it("every declared signal is actually sent", function()
		expectNone(missing(Net.Signals, sent), "declared but never sent")
	end)
	it("every signal the server sends has a client listener", function()
		expectNone(missing(sent, heard), "signals with no listener")
	end)
end)

describe("Effects", function()
	it("every Fx the server broadcasts is rendered by the client", function()
		local fired = names(serverSrc, 'Net%.fx%(%s*"([%w_]+)"')
		for k in names(serverSrc, 'Net%.fxTo%(%s*[%w_]+,%s*"([%w_]+)"') do
			fired[k] = true
		end
		expectNone(missing(fired, names(clientSrc, 'Net%.onFx%(%s*"([%w_]+)"')), "Fx with no client handler")
	end)
end)

describe("Menus", function()
	local registered = names(clientSrc, 'MenuBase%.new%(%{%s*Name = "([%w_]+)"')
	it("every opened menu is registered", function()
		local opened = names(clientSrc, 'UIManager:Open%(%s*"([%w_]+)"')
		for k in names(clientSrc, 'UIManager:Toggle%(%s*"([%w_]+)"') do
			opened[k] = true
		end
		for k in names(clientSrc, 'Menu = "([%w_]+)", Icon') do -- HUD dock entries
			opened[k] = true
		end
		expectNone(missing(opened, registered), "unregistered menus")
	end)
	it("menu hotkeys open registered menus", function()
		local input = sourceOf(Client.Controllers.InputController)
		local bad = {}
		for _, block in { "MENU_KEYS", "GAMEPAD_MENUS" } do
			local body = string.match(input, "local " .. block .. "[^=]*= (%b{})")
			assert(body, "could not find " .. block)
			for name in string.gmatch(body, '= "([%w_]+)"') do
				if name ~= "Back" and not registered[name] then
					table.insert(bad, name)
				end
			end
		end
		expectNone(bad, "hotkeys for unregistered menus")
	end)
	it("station and NPC menus resolve to registered menus", function()
		local alias = { SkillTree = "Skills", Cosmetics = "Inventory", LeaveLounge = "Settings" }
		local stations = {}
		for _, child in childrenOf(Server.World.Regions) do
			for name in string.gmatch(sourceOf(child), 'Kit%.station%([%w_]+, "([%w_]+)"') do
				stations[alias[name] or name] = true
			end
		end
		for name in string.gmatch(sourceOf(Server.World.WorldBuilder), 'Kit%.station%([%w_]+, "([%w_]+)"') do
			stations[alias[name] or name] = true
		end
		for _, npc in NPCConfig.List do
			if npc.Menu then
				stations[alias[npc.Menu] or npc.Menu] = true
			end
		end
		expectNone(missing(stations, registered), "station/NPC menus not registered")
	end)
	it("watched data keys exist in the save schema", function()
		local bad = {}
		for list in string.gmatch(clientSrc, "Watch = (%b{})") do
			for key in string.gmatch(list, '"([%w_%*]+)"') do
				if key ~= "*" and DataSchema.Defaults[key] == nil then
					table.insert(bad, key)
				end
			end
		end
		expectNone(bad, "unknown data keys")
	end)
end)

describe("Audio", function()
	it("every sound the client plays exists", function()
		local bad = {}
		for args in string.gmatch(clientSrc, "AudioController:Play%(([^\n]-)[,%)]") do
			for name in string.gmatch(args, '"([%w_]+)"') do
				if not AudioConfig.Sounds[name] then
					table.insert(bad, name)
				end
			end
		end
		for name in string.gmatch(clientSrc, 'Sound%.play%(%s*"([%w_]+)"') do
			if not AudioConfig.Sounds[name] then
				table.insert(bad, name)
			end
		end
		-- Notification cards pass the sound as their last argument.
		for name in string.gmatch(clientSrc, ', "([%w_]+)"%)\n') do
			if
				string.find(clientSrc, 'Notifications%.card%([^\n]-"' .. name .. '"%)') and not AudioConfig.Sounds[name]
			then
				table.insert(bad, name)
			end
		end
		expectNone(bad, "unknown sounds")
	end)
end)
