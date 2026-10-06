--!strict
--[[
	PartyService
	Optional parties of up to 4. Members near each other get a small additive
	reward bonus (RewardConfig.PartyPerMember, capped), and party members share
	enemy/boss kill credit for quests. Nothing in the game requires a party.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
local Guard = require(Shared.Util.Guard)
local ScaleMath = require(Shared.Formulas.ScaleMath)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)

local PartyService = {}

local MAX_MEMBERS = 4
local INVITE_TTL = 60

type Party = { Id: number, Leader: Player, Members: { Player } }

local partyOf: { [Player]: Party } = {}
local invites: { [Player]: { from: Player, expires: number } } = {}
local nextId = 0

local function broadcast(party: Party?)
	if not party then
		return
	end
	local members = {}
	for _, m in party.Members do
		table.insert(members, { UserId = m.UserId, Name = m.DisplayName, Leader = m == party.Leader })
	end
	for _, m in party.Members do
		Net.signal(m, "Party", { Members = members })
	end
end

local function leave(player: Player)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	Net.signal(player, "Party", { Members = {} })
	if #party.Members <= 1 then
		for _, m in party.Members do
			partyOf[m] = nil
			Net.signal(m, "Party", { Members = {} })
		end
		return
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
	end
	broadcast(party)
end

function PartyService:GetMembers(player: Player): { Player }
	local party = partyOf[player]
	return if party then table.clone(party.Members) else { player }
end

-- Party members within range (scaled by the larger character).
function PartyService:NearbyMembers(player: Player): { Player }
	local party = partyOf[player]
	local out = {}
	if not party then
		return out
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return out
	end
	for _, m in party.Members do
		if m ~= player then
			local other = m.Character and m.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if other then
				local scale = math.max((player:GetAttribute("Scale") :: number?) or 1, (m:GetAttribute("Scale") :: number?) or 1)
				local range = ScaleMath.height(scale) * RewardConfig.PartyRange * 10
				if (other.Position - root.Position).Magnitude <= range then
					table.insert(out, m)
				end
			end
		end
	end
	return out
end

function PartyService:GetBonus(player: Player): number
	local nearby = #PartyService:NearbyMembers(player)
	return math.min(nearby * RewardConfig.PartyPerMember, RewardConfig.PartyMax)
end

function PartyService:Init()
	Net.onRequest(
		"Party",
		Guard.shape({ Op = Guard.oneOf({ "Invite", "Accept", "Decline", "Leave", "Kick" }), Target = Guard.optional(Guard.integer(1, 1e12)) }),
		function(player, payload)
			local op = payload.Op
			local target = if payload.Target then Players:GetPlayerByUserId(payload.Target) else nil
			if op == "Invite" then
				if not target or target == player then
					return { ok = false, err = "Player not found" }
				end
				local party = partyOf[player]
				if party and #party.Members >= MAX_MEMBERS then
					return { ok = false, err = "Party is full" }
				end
				if partyOf[target] then
					return { ok = false, err = "They're already in a party" }
				end
				invites[target] = { from = player, expires = os.clock() + INVITE_TTL }
				Net.signal(target, "Party", { Invite = { UserId = player.UserId, Name = player.DisplayName } })
				return { ok = true }
			elseif op == "Accept" then
				local invite = invites[player]
				invites[player] = nil
				if not invite or os.clock() > invite.expires or not invite.from.Parent then
					return { ok = false, err = "Invite expired" }
				end
				leave(player)
				local party = partyOf[invite.from]
				if not party then
					nextId += 1
					party = { Id = nextId, Leader = invite.from, Members = { invite.from } }
					partyOf[invite.from] = party
				end
				if #party.Members >= MAX_MEMBERS then
					return { ok = false, err = "Party is full" }
				end
				table.insert(party.Members, player)
				partyOf[player] = party
				broadcast(party)
				return { ok = true }
			elseif op == "Decline" then
				invites[player] = nil
				return { ok = true }
			elseif op == "Leave" then
				leave(player)
				return { ok = true }
			elseif op == "Kick" then
				local party = partyOf[player]
				if not party or party.Leader ~= player or not target or partyOf[target] ~= party then
					return { ok = false, err = "Only the leader can kick" }
				end
				leave(target)
				return { ok = true }
			end
			return { ok = false }
		end
	)
end

function PartyService:Start()
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player] = nil
	end)
end

return PartyService
