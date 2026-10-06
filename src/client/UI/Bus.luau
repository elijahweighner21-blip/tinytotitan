--!strict
--[[
	Bus
	Client-side event bus so gameplay controllers can ask the UI for
	something (show a toast, open a dialogue, highlight a quest) without
	requiring screen modules — screens subscribe, controllers fire.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local Bus = {}

-- (text, kind) kind: Info | Success | Warning | Error | Level | Ascension | Collect
Bus.Toast = Signal.new() :: Signal.Signal<string, string>
-- Talk response from NPCService (Name, Role, Line, Menu?, Quests).
Bus.Dialogue = Signal.new() :: Signal.Signal<{ [string]: any }>
-- (menuName, context?) — open a menu at a specific page/item.
Bus.OpenMenu = Signal.new() :: Signal.Signal<string, any>
-- Interaction prompt text for the HUD on touch devices (nil hides it).
Bus.Prompt = Signal.new() :: Signal.Signal<{ [string]: any }?>
-- Fired when the local player's carried object changes (id or nil).
Bus.Carrying = Signal.new() :: Signal.Signal<string?>

function Bus.toast(text: string, kind: string?)
	Bus.Toast:Fire(text, kind or "Info")
end

return Bus
