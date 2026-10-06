# Verification

## Automated (run on every change)

| Check | Command | Covers |
|---|---|---|
| Build | `./scripts/check.sh` | Rojo builds the place from the project file |
| Types | `./scripts/check.sh` | every script type-checked in `--!strict` against the Roblox API definitions (luau-lsp) |
| Format | `./scripts/check.sh` | StyLua (`stylua.toml`) |
| Unit tests | `./scripts/test.sh` | size/progression curves, pricing, reward stacking and caps, combat math, stats, save schema (defaults, migrations, sanitising corrupt data), session locking, receipt ledger idempotency, quests, ascension resets/keeps, daily objectives, content cross-references |
| World placement | `./scripts/test.sh` | every configured discovery, NPC, boss arena, fast-travel station, collectible type, interactable and enemy is placed by a region builder |
| Client ⇄ server contracts | `./scripts/test.sh` | every remote the client sends is declared and handled; every signal is declared, sent and listened to; every server Fx is rendered; every opened menu, hotkey, station and NPC menu is registered; watched data keys exist; every sound name exists |
| Economy pacing | `node tools/test/runner.mjs --script tools/sim/economy.luau` | time-to-tier curve for an idealised free player |
| Remote audit | `node tools/test/runner.mjs --script tools/docs/remote-audit.luau` | regenerates [REMOTE_AUDIT.md](REMOTE_AUDIT.md) |

## What automation can't cover

Physics, rendering, character scaling, DataStores, MarketplaceService and real devices only exist inside Roblox. Before each release, play-test in Studio (and a live private server for purchases/DataStores):

### Core loop
- [ ] Loading screen steps through *Loading World → Loading Progress → Preparing Character*, then fades
- [ ] New player: tutorial hints advance (move, jump, orb, parkour, mass, upgrade, grow, sprint)
- [ ] Collecting orbs grows the size bar; tier-up plays the growth sequence and the character scales with feet planted
- [ ] Growing inside a tight space moves the player somewhere roomier
- [ ] Size gates block until the required tier, then let the player through; walking into a locked zone returns them with a message

### Movement (keyboard, gamepad and touch)
- [ ] Sprint, slide, vault, mantle/ledge grab, wall jump, wall run, air dash, double jump, glide (hold), charged jump, ground pound
- [ ] Coyote time and jump buffering feel forgiving; energy drains/regenerates and the HUD bar matches
- [ ] Touch: custom jump/attack/dash/crouch/sprint buttons work; interact button appears only near interactables

### Systems
- [ ] Push / carry / throw / break respond to strength; "too heavy" messages appear when weak
- [ ] Combat: light/heavy/charged/dash attacks, enemy telegraphs, damage numbers, death and respawn
- [ ] Each boss: intro, phases, telegraphs, health bar, defeat rewards, arena reset when everyone leaves
- [ ] Challenges: countdown, timer, checkpoints/tokens/targets, medals, results card, retry, leave
- [ ] Quests: accept from NPC dialogue and menu, tracker + world marker, completion card, story chain
- [ ] Upgrades, skill tree (unlock/respec), ascension (both confirmations, resets exactly the listed items)
- [ ] Daily login streak and objectives; collections milestones; achievements; titles; cosmetics equip and render for other players
- [ ] Fast travel from the map; party invite/accept/leave; leaderboards load (live server)
- [ ] World events start/end, outage lighting returns to normal

### Saving
- [ ] Rejoin restores everything; leaving during a save loses nothing
- [ ] Joining a second server while the first still holds the session lock waits, then loads correctly
- [ ] Shutting down the server (`BindToClose`) saves all players

### Monetization (live private server with real IDs)
- [ ] Each pass prompts, grants on purchase, shows OWNED, and is never prompted again
- [ ] Each product grants exactly once (check the receipt ledger after a rejoin), boosts tick down only while playing
- [ ] Starter Pack disappears after purchase; limited bundles show only inside their window
- [ ] Cancelling a prompt grants nothing and re-enables the button

### Performance & devices
- [ ] Phone: UI fits safe areas, buttons reachable, Auto graphics preset steps down on low FPS
- [ ] Console: every menu navigable with the gamepad, B closes menus
- [ ] 20+ players: other players' effects are capped; no memory growth over a long session (Debug overlay: F2 → Debug Overlay)
