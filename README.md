# TINY → TITAN

A Roblox progression/parkour game built with **Luau** and **Rojo**. You start as a speck of dust on a living-room carpet and grow — through 15 size tiers and 8 regions — into a mountain-sized Titan. Every system (movement, combat, interaction, rewards, camera, UI scale) is size-aware: the same soda can is a wall, then a block you can push, then a projectile.

The whole place is generated from code: the world is built procedurally at server start, so there is no `.rbxl` to merge.

## Quick start

```bash
# 1. Tools: rojo, luau-lsp, stylua and the standalone luau runtime (for tests)
#    are downloaded into ./.tools (git-ignored). The check/test scripts call
#    this automatically; Rokit users can also `rokit install` (rokit.toml).
./scripts/bootstrap-tools.sh

# 2. Serve into Studio (install the Rojo plugin, then click Connect)
rojo serve default.project.json

# or build a place file
rojo build default.project.json -o build/TinyToTitan.rbxlx
```

In Studio: **Game Settings → Security → Enable Studio Access to API Services** if you want real DataStores. Without it the game falls back to an in-memory store (Studio only; never in live servers) and tells you so in the output.

## Verifying changes

```bash
./scripts/check.sh   # rojo build + strict type-check of every script + StyLua format check
./scripts/test.sh    # headless unit/contract tests (configs, formulas, saves, receipts, client⇄server contracts)
node tools/test/runner.mjs --script tools/sim/economy.luau      # economy pacing simulation
node tools/test/runner.mjs --script tools/docs/remote-audit.luau > docs/REMOTE_AUDIT.md
node tools/test/runner.mjs --play tools/play/scenarios/lifecycle.luau  # full game in a headless engine emulator
```

The play scenarios (`tools/play/scenarios`) run the real server and client code against a headless Roblox engine emulator: joining, saving, rejoining, purchases, menus, combat, layout at several resolutions and server load. Physics, rendering and real devices still need Studio — see the checklist in [docs/VERIFICATION.md](docs/VERIFICATION.md).

## Before publishing

| What | Where |
|---|---|
| Game pass IDs (VIP, 2× Growth Energy, Extra Cosmetic Slots, Titan Cosmetic Pack) | `src/shared/Config/MonetizationConfig.luau` → `GamePasses[*].PassId` |
| Developer product IDs (shards, boosts, bundles) | `MonetizationConfig.luau` → `DeveloperProducts[*].ProductId` |
| Admin user IDs / admin group | `src/shared/Config/GameConfig.luau` → `Admins`, `AdminGroup` |
| Music & ambience (uploaded audio) | `src/shared/Config/AudioConfig.luau` (empty IDs are skipped) |
| Parkour/combat animations (optional) | `src/shared/Config/AnimationConfig.luau` (empty IDs use procedural poses) |
| DataStore names / save version | `GameConfig.luau`, `src/shared/Data/DataSchema.luau` |

Products with ID `0` show as unavailable in live games; in Studio they can be bought through the admin panel's **TestPurchase**, which runs the real receipt pipeline.

## Project layout

```
src/
  shared/            ReplicatedStorage.Shared — used by server and client
    Config/          all content & tuning (sizes, zones, quests, upgrades, shop…)
    Formulas/        pure math: scale, progression, pricing, rewards, combat, stats
    Data/            save schema, defaults, migrations, sanitising
    Net/             the networking contract (6 remotes, every message declared)
    Util/            Signal, Trove, Guard (payload validation), RateLimiter, Format…
  server/            ServerScriptService.Server
    Main.server.luau builds the world, then boots services in dependency order
    Services/        44 services (data, rewards, scale, combat, quests, monetization…)
    Logic/           pure server logic (session lock, receipt ledger, quests, ascension)
    World/           procedural world: Kit helpers, 9 region builders, challenge courses
  client/            StarterPlayerScripts.Client
    Main.client.luau boots controllers, mounts UI, runs the loading screen
    Controllers/     movement, camera, input, audio, effects, interaction, cosmetics…
    UI/              UIManager, theme, components, HUD overlays, 15 menus
tests/               headless specs (run by tools/test/runner.mjs)
tools/               test runner, engine emulator + play scenarios, economy simulator, doc generators
docs/                architecture, content guides, monetization, audits, verification
```

## Documentation

* [Architecture](docs/ARCHITECTURE.md) — boot order, data flow, authority model, performance
* [Adding content](docs/ADDING_CONTENT.md) — zones, tiers, quests, upgrades, skills, cosmetics, bosses, challenges, products
* [Monetization](docs/MONETIZATION.md) — passes, products, receipts, boosts, shop rules
* [Remote audit](docs/REMOTE_AUDIT.md) — generated table of every client→server message
* [Verification](docs/VERIFICATION.md) — what is verified automatically and the Studio test checklist
