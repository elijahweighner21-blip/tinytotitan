--!strict
--[[
	Net
	The complete networking contract. The game uses only SIX remotes:

	  Action  (RemoteEvent, client -> server)   fire-and-forget gameplay input
	  Request (RemoteFunction, client -> server) requests that need an answer
	  State   (RemoteEvent, server -> client)   replication of the player's own data
	  Signal  (RemoteEvent, server -> client)   gameplay notifications
	  Fx      (UnreliableRemoteEvent, s -> c)   cosmetic effect broadcasts
	  Energy  (UnreliableRemoteEvent, s -> c)   energy/cooldown corrections

	Every client->server message is a (name, payload) pair. Names must appear in
	`Actions` or `Requests` below; anything else is dropped. Each entry has a
	per-player token-bucket rate limit and a description used in the remote
	security audit (docs/REMOTE_AUDIT.md). Payload validation lives next to each
	handler on the server.

	The server NEVER invokes a RemoteFunction on a client.
]]

export type Limit = { Rate: number, Burst: number, Purpose: string }

local Net = {}

Net.FolderName = "Remotes"

Net.Remotes = {
	Action = "RemoteEvent",
	Request = "RemoteFunction",
	State = "RemoteEvent",
	Signal = "RemoteEvent",
	Fx = "UnreliableRemoteEvent",
	Energy = "UnreliableRemoteEvent",
} :: { [string]: string }

Net.Actions = {
	ClientReady = { Rate = 0.2, Burst = 2, Purpose = "Client finished loading; server sends full state." },
	Ability = { Rate = 14, Burst = 20, Purpose = "Use an ability. Server validates skill, cooldown, energy, state." },
	Sprint = { Rate = 6, Burst = 10, Purpose = "Sprint on/off. Server drains energy while sprinting." },
	Attack = { Rate = 8, Burst = 10, Purpose = "Melee attack. Server computes hits; client only plays visuals." },
	Interact = { Rate = 5, Burst = 8, Purpose = "Interact with a world object (push/carry/throw/break/station)." },
	Collect = { Rate = 20, Burst = 30, Purpose = "Pick up a collectible; server checks distance + ownership." },
	Landed = { Rate = 4, Burst = 6, Purpose = "Report a heavy landing for Earthquake Landing; server re-validates." },
	TrackQuest = { Rate = 3, Burst = 5, Purpose = "Choose the quest shown in the tracker. Cosmetic only." },
	Analytics = { Rate = 3, Burst = 8, Purpose = "UI analytics hooks (shop opened, product viewed). No rewards." },
	Tutorial = { Rate = 2, Burst = 6, Purpose = "Tutorial step acknowledgement. No rewards are granted directly." },
	ThrowRelease = { Rate = 3, Burst = 4, Purpose = "Release a carried object in the aimed direction." },
} :: { [string]: Limit }

Net.Requests = {
	BuyUpgrade = { Rate = 6, Burst = 10, Purpose = "Purchase the next level of an upgrade with Growth Energy." },
	UnlockSkill = { Rate = 3, Burst = 5, Purpose = "Unlock a skill tree node." },
	RespecSkills = { Rate = 0.2, Burst = 1, Purpose = "Refund skill points for Titan Shards." },
	AcceptQuest = { Rate = 3, Burst = 5, Purpose = "Start a quest the player qualifies for." },
	AbandonQuest = { Rate = 2, Burst = 4, Purpose = "Drop an active non-story quest." },
	StartChallenge = { Rate = 1, Burst = 3, Purpose = "Begin a challenge run (must be at the start pad)." },
	LeaveChallenge = { Rate = 1, Burst = 3, Purpose = "Abort the current challenge run." },
	FastTravel = { Rate = 0.5, Burst = 2, Purpose = "Teleport to an unlocked station." },
	Ascend = { Rate = 0.1, Burst = 1, Purpose = "Perform Ascension (prestige)." },
	BuyAscensionNode = { Rate = 3, Burst = 5, Purpose = "Rank up an Ascension tree node." },
	EquipCosmetic = { Rate = 4, Burst = 8, Purpose = "Equip/unequip an owned cosmetic." },
	EquipTitle = { Rate = 2, Burst = 4, Purpose = "Equip an owned title." },
	ShopPurchase = { Rate = 2, Burst = 4, Purpose = "Buy a shop item with in-game currency." },
	PromptPurchase = { Rate = 0.5, Burst = 2, Purpose = "Ask the server to prompt a Robux purchase (it never grants)." },
	ClaimDaily = { Rate = 2, Burst = 4, Purpose = "Claim login streak or completed daily/weekly objective." },
	ClaimCollection = { Rate = 2, Burst = 4, Purpose = "Claim a completed zone collection reward." },
	SaveSettings = { Rate = 0.5, Burst = 3, Purpose = "Persist client settings (validated + clamped)." },
	Talk = { Rate = 2, Burst = 4, Purpose = "Talk to an NPC (distance-checked)." },
	DialogueChoice = { Rate = 3, Burst = 5, Purpose = "Pick a dialogue option." },
	Party = { Rate = 1, Burst = 4, Purpose = "Party invite/accept/leave/kick." },
	GetLeaderboard = { Rate = 1, Burst = 4, Purpose = "Fetch cached leaderboard pages." },
	ShopCatalog = { Rate = 0.5, Burst = 3, Purpose = "Fetch product prices, daily shop and limited items." },
	ToggleShrink = { Rate = 1, Burst = 2, Purpose = "Choose a Shrink Mode target tier." },
	VipLounge = { Rate = 0.5, Burst = 2, Purpose = "Enter/leave the VIP Lounge (server checks the VIP pass)." },
	UseKey = { Rate = 1, Burst = 3, Purpose = "Use a key item on a locked door (distance + ownership checked)." },
	Admin = { Rate = 4, Burst = 10, Purpose = "Developer commands. Rejected unless the UserId is authorised." },
} :: { [string]: Limit }

-- Server -> client signal names (documentation + typo protection on client).
Net.Signals = {
	Notify = true, -- generic toast
	Reward = true, -- reward popup with amounts
	TierUp = true, -- growth sequence
	LevelUp = true,
	Discovery = true,
	QuestUpdate = true,
	QuestComplete = true,
	Challenge = true,
	Boss = true,
	WorldEvent = true,
	Achievement = true,
	PurchaseResult = true,
	WorldInfo = true,
	Party = true,
	Teleported = true,
	ScanResult = true,
	Gate = true,
	Damage = true,
} :: { [string]: boolean }

return Net
