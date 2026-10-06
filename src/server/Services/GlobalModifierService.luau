--!strict
--[[
	GlobalModifierService
	Server-wide reward modifiers (world events such as Growth Surge). Kept
	separate from WorldEventService so RewardService can read them without a
	circular dependency. Modifiers are mirrored to a Workspace attribute so
	every client's HUD can show active server bonuses.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardMath = require(Shared.Formulas.RewardMath)

local GlobalModifierService = {}

type Entry = { modifier: RewardMath.Modifier, expires: number?, label: string }

local active: { [string]: Entry } = {}

local function publish()
	local list = {}
	for id, entry in active do
		table.insert(list, {
			Id = id,
			Label = entry.label,
			Currency = entry.modifier.Currency,
			Value = entry.modifier.Value,
			Kind = entry.modifier.Kind,
			Expires = entry.expires,
		})
	end
	workspace:SetAttribute("GlobalModifiers", HttpService:JSONEncode(list))
end

function GlobalModifierService:Set(id: string, modifier: RewardMath.Modifier, label: string, duration: number?)
	active[id] = {
		modifier = modifier,
		expires = if duration then workspace:GetServerTimeNow() + duration else nil,
		label = label,
	}
	publish()
end

function GlobalModifierService:Clear(id: string)
	if active[id] then
		active[id] = nil
		publish()
	end
end

function GlobalModifierService:GetModifiers(): { RewardMath.Modifier }
	local now = workspace:GetServerTimeNow()
	local out = {}
	local expired = false
	for id, entry in active do
		if entry.expires and now >= entry.expires then
			active[id] = nil
			expired = true
		else
			table.insert(out, entry.modifier)
		end
	end
	if expired then
		publish()
	end
	return out
end

function GlobalModifierService:Init()
	publish()
end

return GlobalModifierService
