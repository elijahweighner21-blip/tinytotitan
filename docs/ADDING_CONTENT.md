# Adding content

Almost everything is data in `src/shared/Config`. Services read configs; the world builders place tagged markers; tests cross-check that every config entry exists in the world. After any change run `./scripts/check.sh && ./scripts/test.sh` — `tests/content.spec`, `tests/world.spec` and `tests/contracts.spec` catch most mistakes (unknown ids, missing placements, unregistered menus, undeclared remotes).

## Size tier — `SizeConfig.luau`

Add an entry with `Scale` (character scale at the start of the tier) and `MassRequired`. Both must strictly increase and `Scale` must stay inside `GameConfig.MinScale..MaxScale`. Then run the economy simulator and adjust until the curve is smooth:

```bash
node tools/test/runner.mjs --script tools/sim/economy.luau
```

## Zone — `ZoneConfig.luau` + `server/World/Regions/<Zone>.luau`

1. Add the zone: `Order` (nested rooms before the area around them), `RequiredTier`, `RecommendedTiers`, `RewardScale`, the bounding box (`Center`, `Size`), `Spawn`, `Resource`, `Ambience`, `Lighting` (a preset in `EnvironmentController`).
2. Create a region module exporting `build(root)` and add its name to the `order` list in `WorldBuilder.build`.
3. Use `Kit` helpers so gameplay systems find things: `Kit.spawnPad`, `Kit.fastTravel` (one per zone, id = zone id), `Kit.discovery`, `Kit.collectible`/`orbLine`/`orbRing`, `Kit.interactable`, `Kit.npc`, `Kit.enemySpawner`, `Kit.bossArena`, `Kit.station`, `Kit.gate`, `Kit.hazard`.
4. Size things for the zone's players with `Kit.zoneHeight(zoneId)`.

## Quest — `QuestConfig.luau`

```lua
{
	Id = "MyQuest", Name = "My Quest", Category = "Exploration", Zone = "Kitchen",
	Giver = "Fern",                        -- NPC id (optional)
	Prerequisites = { "SomeOtherQuest" },  -- optional
	RequiredTier = 6,                      -- optional
	Objectives = {
		{ Type = "Discover", Target = "FridgeLab", Count = 1, Text = "Find the hidden workbench", Marker = "FridgeLab" },
	},
	Rewards = R("Kitchen", 3),             -- zone-scaled reward
},
```

Objective types are listed at the top of the file; each maps to a `GameEvents` event. `Marker` (a discovery / NPC / challenge / boss id) drives the quest arrow and the map. Story quests can't be abandoned.

## Upgrade — `UpgradeConfig.luau`

Add an entry with `Category`, `MaxLevel`, `BaseCost`, `CostGrowth`, `Currency`, `Effect = { Stat, PerLevel, Mode = "Add" | "Mult" }`, optional `RequiredTier` and `ResourceCost`. The stat name must be one consumed in `Formulas/Stats.luau` (`Stats.empty` lists them). The menu picks it up automatically.

## Skill / ability

* **Stat skill**: `SkillConfig` entry with `Grants = { Stats = { ... } }`, a `Position` in its branch grid, `Prerequisites`, `Cost`, `Requirements`.
* **Ability skill**: also add an `AbilityConfig` entry (cooldown, energy, `RequiresSkill`). Server-executed abilities get a function in `AbilityService`'s `handlers` table; movement abilities are implemented in `MovementController`. Give it `Key = "Ability1".."Ability6"` to put it on the hotbar.

## Collectible — `CollectibleConfig.luau`

Add a type (unique types count toward zone collections; respawning ones need `Respawn`). Place instances with `Kit.collectible(parent, typeId, zoneId, position)`; ids are stable as long as placement order is stable — **append** new placements to keep existing players' collected ids valid.

## Discovery / lore

`DiscoveryConfig` entry + `Kit.discovery(model, id, center, size)` in the region. `Lore = "<LoreConfig id>"` unlocks a journal entry; `Hidden = true` keeps it secret until found.

## NPC — `NPCConfig.luau`

Define `Lines` for each relative size (`Tiny`, `Similar`, `Bigger`, `Titan`), `Remember` lines, optional `Menu` (opens a station menu) and place with `Kit.npc`.

## Enemy / boss

* Enemy: `EnemyConfig` entry (scale, health, damage, rewards, zone) + `Kit.enemySpawner`.
* Boss: `BossConfig` entry (phases, attacks, `ArenaRadius` in boss heights, rewards, cosmetics) + `Kit.bossArena(model, bossId, center)`.

## Challenge — `ChallengeConfig.luau`

Use `timed({ ... })` (time trials, climbs, rising water) or `scored({ ... })` (resource rush, long jump, hidden objects). The `Course` describes segments/gaps/rises in body lengths; `CourseBuilder` derives geometry from jump physics so every course is completable at its `RequiredTier`. `Anchor` is the start pad position in the world. Medal thresholds for timed courses are derived from the ideal time.

## World event — `WorldEventConfig.luau`

Add the definition, then a `handlers.<Id> = function(event)` in `WorldEventService` (use `event.Trove` for cleanup).

## Cosmetics, titles, achievements

* `CosmeticConfig`: `Category` (Trail, Aura, Footstep, Landing, Dash, Growth, NameColor), `Style` (renderer in `CosmeticsController`), `Colors`, `Source`, optional `Price` and `Limited` window.
* `TitleConfig`, `AchievementConfig` (condition forms are documented at the top of the file).

## Monetization

See [MONETIZATION.md](MONETIZATION.md).

## A new remote message

1. Declare it in `src/shared/Net/init.luau` (`Actions` or `Requests`) with `Rate`, `Burst`, `Purpose`.
2. Register the handler on the server with a payload guard: `Net.onRequest("Name", Guard.shape({ ... }), fn)`.
3. Call it from the client with `Net.action` / `Net.request`.
4. Regenerate `docs/REMOTE_AUDIT.md`. `tests/contracts.spec` fails if any step is missing.

## A new menu

Create `client/UI/Screens/<Name>Menu.luau` using `MenuBase.new{ Name, Title, Tabs?, Watch, Render }`, add it to `MOUNT` in `Main.client.luau`, and (optionally) a dock entry in `UI/Hud/Hud.luau` and a hotkey in `InputController`.

## Sounds and animations

`AudioConfig` holds every sound (category, volume, pitch variance, anti-stacking limits). `AnimationConfig.Ids` takes uploaded animation ids for parkour/combat moves; empty ids use procedural poses.

## 3D models — `tools/models/`

Creatures have real 3D models built from Blender scripts (`tools/models/creatures.py`, one function per creature shape). Each part is a named role coloured in game, so there are no textures; roles marked `"Tint"`/`"TintDark"`/`"TintLight"` take the enemy's config colour.

1. Build: `.tools/blender-venv/bin/python tools/models/build.py [Name ...]` writes `build/models/<Name>.fbx`, a manifest and a preview PNG. (Set up once with `python3 -m venv .tools/blender-venv && .tools/blender-venv/bin/pip install bpy`.)
2. Regenerate the library: `python3 tools/models/manifest.py` → `shared/Config/ModelLibrary.luau`.
3. Upload: `ROBLOX_API_KEY=… ROBLOX_USER_ID=… node tools/models/upload.mjs [Name ...]` (Open Cloud key with Assets read + write, under the account or group that owns the game). Ids land in `shared/Config/ModelAssets.luau`; re-uploading keeps the id.

World props have models too (`tools/models/props.py`: couch, sneaker, bed, dresser, toy chest, fridge, trees, pines), built in game studs at the exact layout of their block versions. A region marks a prop with `Kit.skin(model, "Name", parts)`; once the model loads it is fitted to those parts' bounding box and the parts turn invisible but keep colliding, so climbing is unchanged.

In game, `server/World/ModelSkins.luau` loads each uploaded model at boot, orients it against the manifest and swaps it in for the creature's block body. Without an id (or while loading) the blocks stay, so models can go live one at a time.
