# Remote security audit

_Generated from `src/shared/Net/init.luau` by `tools/docs/remote-audit.luau` — do not edit by hand._

The game uses exactly six remotes. Every client→server message is a `(name, payload)` pair; the server
drops names that are not declared below, enforces the per-player token-bucket rate limit, refuses
gameplay messages until the player's data has loaded, validates the payload with a `Guard` schema, and
only then calls the handler. Handlers never trust client numbers for rewards, positions or prices.

| Remote | Type | Direction |
|---|---|---|
| Action | RemoteEvent | client → server |
| Energy | UnreliableRemoteEvent | server → client |
| Fx | UnreliableRemoteEvent | server → client |
| Request | RemoteFunction | client → server |
| Signal | RemoteEvent | server → client |
| State | RemoteEvent | server → client |

## Actions (fire-and-forget)

| Message | Rate (/s) | Burst | Handler | Payload guard | Purpose |
|---|---|---|---|---|---|
| `Ability` | 14 | 20 | AbilityService | Guard.shape | Use an ability. Server validates skill, cooldown, energy, state. |
| `Analytics` | 3 | 8 | AnalyticsService | Guard.shape | UI analytics hooks (shop opened, product viewed). No rewards. |
| `Attack` | 8 | 10 | CombatService | Guard.shape | Melee attack. Server computes hits; client only plays visuals. |
| `ClientReady` | 0.2 | 2 | PlayerDataService | none (no payload) | Client finished loading; server sends full state. |
| `Collect` | 20 | 30 | CollectibleService | Guard.string | Pick up a collectible; server checks distance + ownership. |
| `Interact` | 5 | 8 | InteractionService | Guard.shape | Interact with a world object (push/carry/throw/break/station). |
| `Landed` | 4 | 6 | AbilityService | Guard.shape | Report a heavy landing for Earthquake Landing; server re-validates. |
| `Sprint` | 6 | 10 | EnergyService | Guard.boolean | Sprint on/off. Server drains energy while sprinting. |
| `ThrowRelease` | 3 | 4 | InteractionService | Guard.shape | Release a carried object in the aimed direction. |
| `TrackQuest` | 3 | 5 | QuestService | Guard.id | Choose the quest shown in the tracker. Cosmetic only. |
| `Tutorial` | 2 | 6 | TutorialService | Guard.shape | Tutorial step acknowledgement. No rewards are granted directly. |

## Requests (return a result)

| Message | Rate (/s) | Burst | Handler | Payload guard | Purpose |
|---|---|---|---|---|---|
| `AbandonQuest` | 2 | 4 | QuestService | Guard.shape | Drop an active non-story quest. |
| `AcceptQuest` | 3 | 5 | QuestService | Guard.shape | Start a quest the player qualifies for. |
| `Admin` | 4 | 10 | AdminService | Guard.shape | Developer commands. Rejected unless the UserId is authorised. |
| `Ascend` | 0.1 | 1 | AscensionService | Guard.shape | Perform Ascension (prestige). |
| `BuyAscensionNode` | 3 | 5 | AscensionService | Guard.shape | Rank up an Ascension tree node. |
| `BuyUpgrade` | 6 | 10 | UpgradeService | Guard.shape | Purchase the next level of an upgrade with Growth Energy. |
| `ClaimCollection` | 2 | 4 | CollectibleService | Guard.shape | Claim a completed zone collection reward. |
| `ClaimDaily` | 2 | 4 | DailyService | Guard.shape | Claim login streak or completed daily/weekly objective. |
| `DialogueChoice` | 3 | 5 | NPCService | Guard.shape | Pick a dialogue option. |
| `EquipCosmetic` | 4 | 8 | InventoryService | Guard.shape | Equip/unequip an owned cosmetic. |
| `EquipTitle` | 2 | 4 | InventoryService | Guard.shape | Equip an owned title. |
| `FastTravel` | 0.5 | 2 | FastTravelService | Guard.shape | Teleport to an unlocked station. |
| `GetLeaderboard` | 1 | 4 | LeaderboardService | Guard.shape | Fetch cached leaderboard pages. |
| `LeaveChallenge` | 1 | 3 | ChallengeService | Guard.none | Abort the current challenge run. |
| `Party` | 1 | 4 | PartyService | Guard.shape | Party invite/accept/leave/kick. |
| `PromptPurchase` | 0.5 | 2 | MonetizationService | Guard.shape | Ask the server to prompt a Robux purchase (it never grants). |
| `RespecSkills` | 0.2 | 1 | SkillService | Guard.none | Refund skill points for Titan Shards. |
| `SaveSettings` | 0.5 | 3 | SettingsService | custom validator | Persist client settings (validated + clamped). |
| `ShopCatalog` | 0.5 | 3 | ShopService | Guard.none | Fetch product prices, daily shop and limited items. |
| `ShopPurchase` | 2 | 4 | ShopService | Guard.shape | Buy a shop item with in-game currency. |
| `StartChallenge` | 1 | 3 | ChallengeService | Guard.shape | Begin a challenge run (must be at the start pad). |
| `Talk` | 2 | 4 | NPCService | Guard.shape | Talk to an NPC (distance-checked). |
| `ToggleShrink` | 1 | 2 | AbilityService | Guard.shape | Choose a Shrink Mode target tier. |
| `UnlockSkill` | 3 | 5 | SkillService | Guard.shape | Unlock a skill tree node. |
| `UseKey` | 1 | 3 | InteractionService | Guard.shape | Use a key item on a locked door (distance + ownership checked). |
| `VipLounge` | 0.5 | 2 | VipLoungeService | Guard.shape | Enter/leave the VIP Lounge (server checks the VIP pass). |

## Server → client signals

Achievement, Boss, Challenge, Damage, Discovery, Gate, LevelUp, Notify, Party, PurchaseResult, QuestComplete, QuestUpdate, Reward, ScanResult, Teleported, TierUp, WorldEvent, WorldInfo

## Abuse handling

* Rate-limit overruns and malformed payloads are dropped and reported to `AntiExploitService`, which
  keeps a decaying suspicion score (logged; never auto-bans on a single signal).
* `Admin` requests from non-admins are refused and flagged.
* Movement is client-authoritative for feel, but the server validates speed/teleports, ability
  energy and cooldowns, attack range/arc, pickup distance and interaction reach.
* Robux purchases are granted only inside `ProcessReceipt`, idempotently, with a receipt ledger in
  the player's save; `PromptPurchase` can only show Roblox's prompt.
