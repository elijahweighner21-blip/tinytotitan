--!strict
--[[
	VipLoungeService
	The VIP Lounge: a social hangout with the VIP wardrobe and boutique. It
	is cosmetic/social only — no gameplay advantage. Inside, everyone is
	temporarily sized to Human scale (a "Fixed" scale modifier) so players of
	all sizes can hang out together; leaving restores their size and returns
	them where they were.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SizeConfig = require(Shared.Config.SizeConfig)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local WorldBuilder = require(ServerRoot.World.WorldBuilder)
local EntitlementService = require(script.Parent.EntitlementService)
local CharacterService = require(script.Parent.CharacterService)
local ScaleService = require(script.Parent.ScaleService)
local ChallengeService = require(script.Parent.ChallengeService)

local VipLoungeService = {}

local MODIFIER = "Lounge"
local returnPoints: { [Player]: Vector3 } = {}

local function leave(player: Player, teleport: boolean)
	local back = returnPoints[player]
	if not back then
		return
	end
	returnPoints[player] = nil
	ScaleService:ClearModifier(player, MODIFIER)
	if teleport then
		task.delay(1, function()
			if player.Parent then
				pcall(function()
					player:RequestStreamAroundAsync(back, 5)
				end)
				CharacterService:SafeTeleport(player, back, "LeaveLounge")
			end
		end)
	end
end

function VipLoungeService:Init()
	Net.onRequest("VipLounge", Guard.shape({ Enter = Guard.boolean() }), function(player, payload)
		if not payload.Enter then
			if not returnPoints[player] then
				return { ok = false }
			end
			leave(player, true)
			return { ok = true }
		end
		if not EntitlementService:Owns(player, "VIP") then
			return { ok = false, err = "The VIP Lounge needs the VIP pass", needsPass = "VIP" }
		end
		if returnPoints[player] then
			return { ok = false, err = "Already in the lounge" }
		end
		if ChallengeService:IsInRun(player) then
			return { ok = false, err = "Finish your challenge first" }
		end
		local root = CharacterService:GetRoot(player)
		if not root then
			return { ok = false }
		end
		local height = root.Size.Y
		returnPoints[player] = root.Position - Vector3.new(0, height * 1.5, 0)
		ScaleService:SetModifier(
			player,
			MODIFIER,
			{ Fixed = SizeConfig.getTier(SizeConfig.HumanTier).Scale },
			60 * 60 * 6
		)
		pcall(function()
			player:RequestStreamAroundAsync(WorldBuilder.VipLounge, 5)
		end)
		CharacterService:SafeTeleport(player, WorldBuilder.VipLounge, "EnterLounge")
		return { ok = true }
	end)
end

function VipLoungeService:Start()
	CharacterService.Died:Connect(function(player)
		leave(player, false)
	end)
	CharacterService.Teleported:Connect(function(player, reason)
		if reason ~= "EnterLounge" and reason ~= "LeaveLounge" and reason ~= "Unstuck" and returnPoints[player] then
			leave(player, false)
		end
	end)
	EntitlementService.OwnershipChanged:Connect(function(player, key, owned)
		if key == "VIP" and not owned then
			leave(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		returnPoints[player] = nil
	end)
end

return VipLoungeService
