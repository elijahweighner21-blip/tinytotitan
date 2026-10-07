# Architecture

## Boot

**Server** (`src/server/Main.server.luau`)

1. `Net.init()` creates the six remotes immediately, so clients never wait on them.
2. `WorldBuilder.build()` generates every region, challenge course and the VIP lounge, tags gameplay markers (`DiscoveryRegion`, `Collectible`, `NPCSpawn`, `BossArena`, …), validates that every configured discovery/NPC/boss/station exists, and publishes `ReplicatedStorage.WorldIndex` (positions of named targets for quest markers and the map).
3. `Loader.run` requires all 44 services, calls `Init` on each in dependency order (wire handlers; no yielding on other services), then `Start` (loops, player hooks). A failing service is logged and skipped; it never stops the others.

**Client** (`src/client/Main.client.luau`)

1. Loading screen appears instantly.
2. Controllers are required, then `Init` (signals) and `Start` (loops) run for each, isolated by `pcall`.
3. HUD, overlays and menus mount.
4. Real loading steps — world index → save data → character — then the loading screen fades and the welcome card appears.

## Authority model

The server is authoritative for everything that matters: currencies, Mass and size, rewards, upgrades, skills, quests, challenge timing, damage, pickups, interactions, purchases. The client owns only what must feel instant:

| Client does | Server verifies |
|---|---|
| Moves the character (parkour state machine, custom gravity) | speed/teleport/hover sanity, zone access (`ZoneService`, `AntiExploitService`) |
| Plays an ability immediately | skill owned, cooldown, energy (rejections resync the client) |
| Swings an attack | cooldown, energy, range and arc from the server's view of positions |
| Reports a pickup | distance (with latency grace), per-player cooldown, ownership |
| Opens the Robux prompt | `ProcessReceipt` is the only grant path, idempotent via a receipt ledger in the save |

Every client message is declared in `src/shared/Net/init.luau` with a rate limit; the server drops undeclared names, rate-limits per player, refuses gameplay until the save is loaded, validates payloads with `Guard` schemas, then calls the handler. See [REMOTE_AUDIT.md](REMOTE_AUDIT.md).

## Data

`src/shared/Data/DataSchema.luau` is the single source of truth for the save: defaults, version, migrations, `reconcile` (fill new fields), `sanitize` (clamp/repair every value) and `clientView` (strips server-only sections such as receipts).

`PlayerDataService`:

* loads with `UpdateAsync` and a **session lock** (`Logic/SessionLock`) so two servers can never write the same profile; stale locks expire
* retries with backoff, kicks with a friendly message if the save truly can't load (never plays on default data that could overwrite progress)
* autosaves every `AutosaveInterval`, keeps rolling backups, saves on leave and in `BindToClose`
* replicates a full snapshot on `ClientReady`, then key-level patches (`State` remote) when a service calls `PlayerDataService:Changed(player, key)`

## Rewards

All gains go through `RewardService:Grant(player, reward, context)`:

```
final = floor(base × (1 + Σ additive) × Π max(multiplier per group))
```

Additive sources (VIP, events, upgrades, ascension, party) are summed and capped; multiplicative sources are grouped (two 2× Mass boosts don't make 4×); the total is capped. Purchases/admin/refunds bypass multipliers; Titan Shards are never boosted. Zone content uses `RewardConfig.zone` / `RewardService:ScaleZone` so rewards stay meaningful as players grow. Pacing is checked with `tools/sim/economy.luau`.

## Size

`Progression.scaleForMass` maps Mass to a character scale (log-interpolated inside a tier, with a visible spurt at each tier-up). `ScaleService` publishes the `Scale` attribute — the one value movement, camera, combat reach, interaction strength, audio pitch and VFX size all read — and applies it with `Model:ScaleTo`, keeping feet planted, throttling small changes and animating tier-ups. If growing wedges a player inside geometry, `CharacterService` moves them somewhere roomier.

## Client structure

* **Controllers** own one concern each (input, movement, camera, audio, effects, interaction, collectibles, zones, environment, cosmetics, overhead tags, animation, world markers).
* **UI**: `UIManager` owns the ScreenGuis and the one-menu-at-a-time rule; `MenuBase` gives every menu a window, tabs, close handling and re-render-on-data-change *only while open*; `Bus` lets gameplay controllers request UI (toasts, dialogue) without depending on screens.

## Performance

* World geometry is mostly anchored, non-colliding decor where possible. `StreamingEnabled` is off: the world is ~4k parts, and streaming could leave a freshly spawned player without a floor.
* Collectibles: proximity checks every 0.1s, only the ~80 nearest animate.
* Effects are pooled, scaled by the Particles setting and graphics preset; other players' effects are capped (closest N) and can be hidden.
* The Auto graphics preset steps quality down when FPS stays low and recovers slowly.
* Fx broadcasts use an `UnreliableRemoteEvent`; data replication sends key-level patches, not whole saves.
