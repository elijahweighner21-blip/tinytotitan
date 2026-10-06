# Monetization

All products live in `src/shared/Config/MonetizationConfig.luau`. Set the real `PassId` / `ProductId` values before publishing (they are `0` placeholders). Prices shown in the shop come from `MarketplaceService` at runtime; `FallbackPrice` is only used if that lookup fails.

## Catalog

| Kind | Key | Contents |
|---|---|---|
| Game pass | `VIP` | +10% Growth Energy, +5% XP, +25% daily streak energy, VIP Lounge, exclusive cosmetics/title |
| Game pass | `DoubleGrowthEnergy` | 2× Growth Energy (multiplicative "Pass" group) |
| Game pass | `ExtraCosmeticSlots` | more equip slots per cosmetic category |
| Game pass | `TitanCosmeticPack` | exclusive trail/aura/footsteps/landing/dash cosmetics |
| Product | `Shards100` … `Shards3000` | Titan Shards (larger packs carry bonus value) |
| Product | `MassBoost15/30/60`, `EnergyBoost30`, `LuckBoost30`, `XPBoost30` | timed boosts |
| Product | `StarterPack` | one-time new-player bundle (shown only up to level 25 / 6 h played) |
| Product | `ExplorerBundle` | one-time bundle (shards, tokens, luck boost, exclusive trail + title) |
| Product | `TitanBundle`, `AscensionBundle` | repeatable shard + boost bundles |
| Product | `HalloweenBundle` ("Spooky Bundle") | limited-time, one-time bundle, only visible inside its event window |

The **FEATURED** tab lists `MonetizationConfig.Featured`. Shop tabs come from `MonetizationConfig.ShopCategories`.

## How a purchase works

1. The client calls `PromptPurchase { Kind, Key }`. The server checks the key exists, the product is configured, the player doesn't already own the pass / one-time product, and a per-player prompt cooldown — then shows Roblox's prompt. **No remote can grant anything.**
2. Roblox calls `ProcessReceipt`. `MonetizationService`:
   * returns `NotProcessedYet` if the product is unknown, the player isn't in this server or their data isn't loaded (Roblox retries later)
   * returns `PurchaseGranted` immediately if the `PurchaseId` is already in the player's receipt ledger (never grants twice)
   * otherwise grants the contents **and** records the `PurchaseId` in the same save, force-saves, and only then returns `PurchaseGranted` (a failed save returns `NotProcessedYet`; the in-memory ledger makes the retry a no-op)
3. The client receives `PurchaseResult` and shows a thank-you card; the shop refetches ownership.

Passes are checked with `UserOwnsGamePassAsync` on join and on `PromptGamePassPurchaseFinished`; their items are re-granted every join, so refunds/re-purchases stay consistent.

## Boosts and stacking

Boosts are stored as **remaining active-play seconds** in the save, so a bought hour is always an hour of play and survives server hops. Buying the same boost again extends its time (up to `MaxStackSeconds`); it never multiplies further. Boosts of the same kind share a multiplicative group — two 2× Mass boosts are still 2×. All multipliers go through `RewardService` (see `RewardConfig` for caps). Titan Shards are never multiplied. Purchased contents themselves never receive multipliers.

## Fairness rules (enforced in code)

* No pay-to-skip on core progression: Robux buys time-limited multipliers, shards and cosmetics, never Mass, levels or leaderboard values.
* Leaderboards only read server-tracked play statistics.
* One-time products cannot be prompted twice; duplicate charges grant `DuplicateCompensation`.
* Limited items show their real end time; nothing uses fake countdowns or pop-ups.

## Testing in Studio

Unconfigured products appear in Studio. Open the admin panel (**F2**, Studio owners are admins) → *Studio purchase testing*:

* **Buy &lt;product&gt;** runs `TestPurchase`, which feeds a synthetic receipt through the real `ProcessReceipt` code path.
* **Pass: &lt;name&gt;** toggles test ownership of a pass.

Both are refused outside Studio regardless of config.

## Analytics hooks

`AnalyticsService` records economy events (sources/sinks of Growth Energy and Titan Shards) and whitelisted UI events from the client: `ShopOpened`, `ShopCategory`, `ProductViewed`, `MenuOpened`, `TutorialHint`, `WelcomeShown`. It forwards to Roblox `AnalyticsService` when available.
