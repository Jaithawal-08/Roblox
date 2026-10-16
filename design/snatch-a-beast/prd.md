# PRD: Snatch a Beast
Status: draft (needs-triage) — master design doc v2. Merges the addictive systems of the three
anchor games (below). Tuning numbers are starter values, rebalance after playtests.
Roadmap impact is listed in §19 and is **not yet applied** to `roadmap/snatch-a-beast/ROADMAP.md`.

## 0. Research Basis

Deep dive run Oct 2026 against the three anchors chosen for this game: the current #1 most-played
experience, the biggest evergreen monetizer, and the biggest collector/social economy. Figures are
reported/estimated third-party numbers, not Roblox-confirmed revenue.

| Anchor | Why it's an anchor | Reported scale | What we take |
|---|---|---|---|
| **Steal An Egg** | #1 most-played game on the platform; **same genre as us** (steal → hatch → income) | ~1.1M peak concurrent; ~800k after reupload | Guardian-guarded wilds, carry-slowed snatch runs, speed-gated zones, ~5-min spawn cycles, trail shop, rebirth |
| **Blox Fruits** | Longest-running top earner; the money ladder everyone copies | 63.9B visits; est. $2.2–3.4M/month via DevEx | Gacha with visible rarity tiers, 2x passes (Money/Mastery), timed boost products, zone bosses/quests cadence, permanent vs tradeable items |
| **Adopt Me!** | Highest lifetime visits of any Roblox game; the collector/social king | 87.1B visits | Egg hatching with published odds, aging → Neon → **Mega Neon** (4→16 copies), journals, Ride/Fly potions, friends trading, seasonal eggs, event calendar |

Platform context that shapes §11: Roblox 2025 revenue ~$4.9B; top-10 creators averaged ~$65.7M and
the top 1000 ~$1.4M/yr (RDC 2026). Retention and policy discipline, not raw build quality, decide
whether an experience survives that funnel.

### Deliberately rejected
- **Reels / doomscroll treadmill.** Steal An Egg shipped a short-form video feed on its treadmill and
  was pulled in Aug 2026; Roblox now restricts experiences that show a media feed **and** use
  autoplay/infinite-scroll **and** gate rewards on viewing, keeping them out of the Kids/Select
  catalogs. We never build this. See §11.1.
- **"Steal a ___" naming cluster.** The copycat name pattern is now associated with slop and the
  policy crackdown. `Snatch a Beast` stays as-is: same genre signal, none of the baggage.
- **Real-Pokémon or licensed IP in any form.**
- **Second *buyable* currency.** Prisms (§5.12) are earn-only on purpose.

## 1. Player Promise
Catch wild beasts, pen them in your den for coins, and snatch your friends' best ones before their
guardian gets you. Cute-to-mythic original critters with absurd meme-able names, snatch-back drama,
limited-time Shadows.

## 2. Design Pillars
1. **First snatch in 20 seconds.** No menus, no exposition. Spawn facing a catchable beast.
2. **Two ways to get anything: earn it or snatch it.** Every beast is reachable free.
3. **Risk carries the dopamine.** Carrying a beast makes you slow and visible; the tension *is* the fun.
4. **Always something one step away.** Journal set, aging stage, pass tier, next zone, next Shadow.
5. **Kid-safe is the moat.** Where the anchors use pressure and slop, we use clarity and speed. (§11)

## 3. Core Loop
**Snatch → Pen → Income → Upgrade → Snatch bigger.**
Wild beasts live in speed-gated **zones**. Walk in, grab one, and carry it home at ~60% speed while
the zone Guardian chases; if it tags you, you drop the beast and lose the run. Pen beasts on
pedestals and they pay coins/sec. Spend coins on Sprint training, pedestal slots, zone unlocks and
the Egg Machine. Then do it to *other players*: sneak into an unlocked den, lure a beast off its
pedestal, and haul it home before the Sanctuary lock re-arms.
First fun: a free common beast is in your hands within ~20 seconds of spawn.

## 4. First Session (30–60s)
1. Spawn facing the Trailhead trail (zone 0 — calm, no Guardian).
2. Free common egg hatches in-hand instantly (teaches gacha, costs nothing).
3. Prompt: **"Pen it!"** → coins start ticking with sound + rising counter.
4. Beat 2: 2 coin-bought catches teach the catch loop and the pedestal ladder.
5. Within 60s a nearby rival's lock drops → prompt **"Sneak in and lure one…"** (teaches snatching).
6. Session ends with 2 income sources, 1 theft tasted, 1 journal slot filled, and a visible
   "Zone 1 in 2,500 coins" goal. Nothing explained in a text wall.

## 5. The Addictive Layers (merged mechanic stack)
This is the heart of the doc: each anchor's proven hook, adapted, with the kid-safe version.

### 5.1 Wild snatch runs with a chasing Guardian *(Steal An Egg)*
Each zone beyond Trailhead has a Guardian (a big themed beast, not a monster — think Bramble Boar,
Grumpy Glacier). Grab a wild beast → it goes overhead → you move at 60% speed → Guardian pursues.
Tagged = drop + respawn the beast back in the zone. Safe zones (0–1) have no Guardian so learning is
painless. Guardians never damage characters: chase + drop only (no PvP damage, §17).

### 5.2 Zone ladder gated by Sprint *(Steal An Egg biomes)*
Zones are the progression spine. Each zone needs a **Sprint level** (and a one-time coin unlock) and
holds better rarity pools. Requirement curve is exponential like the anchor's biome thresholds, but
gentler for our audience (starter values):

| Zone | Name | Unlock (coins) | Sprint req. | Rarity pool | Guardian |
|---|---|---|---|---|---|
| 0 | Trailhead | free | 0 | Common–Uncommon | none |
| 1 | Whisper Woods | 2,500 | 5 | Uncommon–Rare | Bramble Boar (slow) |
| 2 | Sunken Marsh | 50K | 12 | Rare–Ultra-Rare | Marsh Maw |
| 3 | Ember Ridge | 1M | 25 | Ultra-Rare–Legendary | Cinderjaw |
| 4 | Frostbite Peaks | 20M | 45 | Legendary–Mythic | Glacier Grump |
| 5 | Glimmer Rift | 500M | 80 | Mythic–Secret | Rift Warden |
| 6 | Cosmic Dumpster | 15B | 140 | Secret + Shadow spawns | The Landlord |

Zone 0 is the already-built behaviour (§19 slice 01): tame trail, tap-to-catch for `CatchPrice`.
Zones 1+ add the Guardian and free-but-risky snatching, so the built slice stays valid.

### 5.3 Sprint: active training, never AFK *(our replacement for the treadmill)*
**No idle training.** Sprint levels come from a **Training Yard rhythm mini-loop**: a ~15-second
tap-the-nodes-in-time sequence, three rounds per session, scored on accuracy. Rewards Sprint XP →
Sprint levels. Purchased upgrades (Training Gear tiers, Trail items) add multipliers. This is the
direct answer to Steal An Egg's treadmill doomscroll: same stat, engaged input, nothing to watch.

| Sprint level | Move speed | Carry speed | Rough sessions to reach |
|---|---|---|---|
| 0 | 16 | 9.6 | — |
| 5 | 18 | 12 | ~4 |
| 12 | 22 | 15.4 | ~12 |
| 25 | 28 | 21 | ~30 |
| 45 | 36 | 29 | ~60 |
| 80 | 48 | 41 | ~110 |
| 140 | 64 | 58 | ~180 |

### 5.4 Egg Machine with published odds + visible pity *(Blox Fruits gacha, Adopt Me odds)*
Coin-pulled eggs are the deliberate, low-risk path to a beast (the risky path is §5.1). Blox-style
timed free roll (one free common pull hourly) plus paid pulls. **Every pull shows exact odds and the
pity counter on the machine itself.** Starter odds:

| Rarity | Odds (standard egg) | Pity |
|---|---|---|
| Common | 60% | — |
| Uncommon | 24% | — |
| Rare | 10% | — |
| Ultra-Rare | 4% | 1 per 25 |
| Legendary | 1.5% | 1 per 67 |
| Mythic | 0.45% | 1 per 222 |
| Secret | 0.05% | 1 per 2,000 |

Catch/snatch pulls from each zone's own pool, so zones remain the best source of their own rarities.

### 5.5 Variants and mutation weather *(existing PRD, extended)*
Per-beast variant multiplies income. Base variants are permanent and always available:

| Variant | Income × |
|---|---|
| Normal | 1× |
| Gold | 2.5× |
| Diamond | 5× |
| Rainbow | 12× |

**Mutation weather** (hourly, `EventService`) temporarily re-rolls wild spawns into event-only
mutations with much bigger multipliers (Crystal ~15×, Phantom ~12×, Cyber ~11×). Event mutations are
strong but time-boxed, and every one must also be obtainable from a free event path.

### 5.6 Aging → Radiant → Mega Radiant *(Adopt Me's 16-copy sink)*
Aging is the deepest collection sink and it *feeds on theft*: snatching is how you get the duplicate
copies this ladder eats. Beasts age by **active Bonding** (pet, feed, play — Adopt Me's proven task
loop), not by idle time.

- Stages: **Hatchling → Sprout → Stripling → Prime**, then
- **Radiant** = fuse 4 × Prime of the same species/variant.
- **Mega Radiant** = fuse 4 × Radiant = **16 copies**. Cycles colors, +big income multiplier, flex aura.

| Stage | Bond tasks (common → Secret) | Income × |
|---|---|---|
| Hatchling | — | 1× |
| Sprout | 8 → 40 | 1.15× |
| Stripling | 20 → 100 | 1.4× |
| Prime | 40 → 220 | 1.8× |
| Radiant | fuse 4 Prime | 2.6× |
| Mega Radiant | fuse 4 Radiant | 4× |

Bond potions (Robux, §8) grant a burst of Bond tasks instantly — the Adopt Me Age-Up Potion, and the
single best-performing product in that game.

### 5.7 Collection Journal *(Adopt Me journal + Steal a Brainrot Index)*
A book of silhouettes: every species × every variant. Filling a set grants a **permanent global income
multiplier** plus a matching den cosmetic. Set bonuses stack, so the journal is the long-horizon
"always something one step away" chase that survives every balance change. Journal completion is also
where **Prisms** are earned (§5.12), making it the free route to the top shop tier.

### 5.8 Interception bidding on rare spawns *(Steal a Brainrot's Red Carpet)*
When a Rare-or-better wild beast is grabbed, the server announces it ("<Player> snagged a Cinder
Cub!") and opens an **8-second Snatch Back window**: anyone can pay **150% of its coin value** to take
ownership, and it re-targets to their den. The original snatcher must still deliver it. Chains are
allowed. This is the purest drama generator in the genre and doubles as a coin sink. Only Rare+ and
never on Shadows (those are event-only, §5.10).

### 5.9 Capped offline income
Pens keep paying while away at **25% rate, capped at 8 hours**, presented on rejoin as a
"Welcome back" card with a single Claim button. Deliberately capped and one-tap: a rejoin hook, not
an idle game.

### 5.10 Evolution Prestige *(existing PRD)*
Release the whole den → rank up **E → D → C → B → A → S → SS → SSS → SSS+** → permanent global
multiplier. Rank is the prestige flex; it also raises the Shadow weekend spawn odds.

### 5.11 Friends-only trading with a value guard
Trade beasts and variants **only with friends**. The trade window shows a **total-value meter** that
flags lopsided trades in plain language ("This trade is very unfair to you"), requires a two-step
confirm, and logs every trade for a support rollback window. Trading is optional; gifting to friends
covers the casual case. No third-party value sites should ever be needed (§11.6).

### 5.12 Prisms (earn-only currency)
A second currency that **cannot be bought**, dropping from live events, rare-spawn bonuses and Journal
set completions. Prisms gate the top shop tier (den skins, aura trails, event cosmetics). This gives
Blox-Fruits-style economic layering without a pay-to-win valve.

### 5.13 Season Pass *(4 weeks, free + premium track)*
One 4-week season with a free track and a premium track (Robux buy-in, §8). Pass XP is earned from
**every core action**: catches, snatches, deliveries, den raids, Bond tasks, Journal milestones.
Premium grants cosmetics, convenience and Prisms — never zone access or raid power. Tier 50 free-track
reward is a real Shadow-tier beast, advertised from day one (the Day-7 return hook, §9).

## 6. Systems To Build
Server-authoritative systems own all valuable state; clients only present and request.

| System | Type | Valuable state | Responsibility |
|---|---|---|---|
| TrailSpawner | server | spawn schedule, rarity rolls | Walk/spawn wilds per zone, ~5-min cycle, announces Rare+ |
| ZoneService | server | zone unlocks | Sprint + coin gates, zone pools, Guardian behavior |
| SanctuaryService | server | ownership, pedestal contents | Dens, slots, upgrades, lock timers |
| EconomyService | server | coins, **prisms**, income ticks, offline cap | Server-authoritative ticks, no client math |
| SprintService | server | Sprint level, training run records | Validate training mini-loop results, pay Sprint XP |
| BondService | server | aging stages, bond progress | Bond tasks → stages → fusion eligibility |
| FusionService | server | Radiant/Mega Radiant state | 4→1 fusions, consumes exactly the right copies |
| JournalService | server | discovery bitmap, set bonuses | Permanent multipliers, Prism payouts |
| EggMachine | server | pull odds, pity counters | Free hourly pull, paid pulls, published odds |
| TheftService | server | carry state, lock timers, revenge shields | Lure/carry/slap/lock |
| BidService | server | interception windows, ownership flips | 150% Snatch Back, chain resolution, announcements |
| TradeService | server | trade logs, value meter | Friends-only, value guard, 2-step confirm, rollback log |
| PassService | server | season id, tier, premium flag | Pass XP, reward grants, season rollover |
| EventService | server | active windows | Mutation weather, weekly critter, Shadow weekends |
| SaveService | server | everything above | DataStore profiles, autosave, leave/shutdown |
| MonetizationService | server | receipts, entitlements | Passes, dev products, VIP, private dens |
| HUDController / DenPanel / EggUI / TrainingUI / JournalUI / PassUI / TradeUI / WelcomeBackUI | client | none | Presentation only; never decides value |

## 7. Economy
**Sources:** pedestal income (base ~1/20th of beast price per sec), wild snatch (free, risk-gated),
interception wins, offline income (capped), Journal set bonuses, events, Prisms from events/journal.
**Sinks:** coin catches in zone 0, zone unlocks, pedestal slots, den size, Sanctuary lock upgrades,
Sprint training gear, Egg Machine pulls, Bond potions, fusion slots, den skins, interception bids.

Rules: early upgrades must be fast (first pedestal slot ~3 catches), every sink must exist before its
big source, and the compounding from offline income + Journal multipliers must be re-checked every
season. Baseline values stay as shipped in `SnatchConfig` (StartingCoins 200, CatchPrice 50,
IncomePerSec 2, PedestalCount 4) and are the zone-0 reference point.

## 8. Monetization
Ladder (starter prices in Robux). **No store surface until after the player's first steal.**

| Price | Offer | Type | Notes |
|---|---|---|---|
| 49 | Single pull refill | dev product | Timing convenience only |
| 99 | Bond potion (age-up burst) | dev product | Adopt Me's best-performing product |
| 129 | Triple pull + 1h 2× coins | dev product | |
| 199 | Dash potion (fast carry) | dev product, tradeable | Ride-potion analogue |
| 249 | Glide potion (fly over trails) | dev product, tradeable | Fly-potion analogue |
| 399 | VIP den (cosmetic + 24h 2× luck) | game pass | |
| 399 | Season Pass (4-week premium track) | game pass | Cosmetics/convenience/Prisms only |
| 799 | 30-day private den, +1 slot | game pass | |
| 799+ | Game passes: 2× Coins, 2× Luck, +2 Pedestal Slots, Auto-Collect, Trail Pack | game passes | Blox Fruits 2× Money/Mastery analogue |
| — | Spotlight Shop: rotating 48h limited cosmetics/bundle | dev product | Timer is real, never resets |

**Anti-P2W rule:** everything is speed, odds or convenience. Prisms are never purchasable, no Shadow
is Robux-only, no zone or raid outcome is sold, all paid randoms publish odds with visible pity, and
premium pass rewards never include zone access.

## 9. Retention Map
- **Day 1** — first snatch in 20s; free hourly egg; Zone 1 unlock visible.
- **Day 2** — capped offline income to claim; unfinished Journal set; a Bond task mid-stage.
- **Day 3** — first Radiant fusion or zone-3 push around the 2–3h mark; first theft survived.
- **Days 4–6** — Journal set completion, pass tier climb, den cosmetics, friends-only trading.
- **Day 7** — the Shadow tier advertised on day one, delivered by the free pass track.
Retention is carried by **pass + journal + offline + events + trading**. Daily-quest/streak/code
systems were considered and are deferred (§17), not silently assumed.

## 10. Live-Ops Cadence
- **Hourly:** mutation weather window; free egg roll.
- **Daily:** rotating zone bonus (e.g. +coins in Sunken Marsh).
- **Weekly:** new critter + a Spotlight Shop rotation.
- **Biweekly:** Shadow weekend (limited critters, prestige-scaled odds).
- **4-weekly:** Season rollover, journal set refresh, balance pass on offline/multiplier compounding.

## 11. Kid-Safe Design Rules (the differentiator — non-negotiable)
1. **No media feed, ever.** No short-form video, no autoplay/autoscroll/infinite scroll, and no reward
   gated on watching anything. (Roblox's Aug 2026 policy that pulled Steal An Egg; violating it costs
   Kids/Select catalog eligibility.)
2. **Published odds + visible pity** on every paid random.
3. **No fake urgency.** Every countdown is real; no resetting "expires in" timers; no loss-aversion
   streak that punishes a missed day.
4. **Never sell power.** Robux never unlocks a zone, wins a raid, or gates a Shadow.
5. **Spend transparency.** Real-money spend summary visible to the player; purchase buttons separated
   from play taps; no store before the first steal; parental controls respected.
6. **Safe trading.** Friends-only, plain-language value meter, two-step confirm, logged trades with a
   support rollback window.
7. **No wagering.** No coin flipping, no lootbox that only exists for Robux, no exchanging beasts for
   currency outside the game.
8. **Session respect.** A gentle "you've played a while" nudge after ~60 minutes; leaving is never
   punished and offline income is capped, not withheld.
9. **First-party analytics only** — no third-party ad or tracking SDKs (§16).
10. **Moderation-ready.** Filtered naming/chat/trade, report + revert path, and no user-authored text
    rendered on beasts.

## 12. Player Stories
1. As a player, I want to grab a wild beast in under 30 seconds, so that I have fun immediately.
2. As a player, I want wild runs to carry real risk, so that a clean delivery feels earned.
3. As a player, I want my penned beasts to earn coins while I play, so that my den feels alive.
4. As a player, I want to snatch from unlocked dens, so that I can get rares faster and brag.
5. As a player, I want to lock my den, so that my best beasts are safe sometimes.
6. As a player, I want to bid on someone's rare spawn mid-run, so that I can turn their win into drama.
7. As a player, I want active training to make me faster, so that getting better zones is a skill.
8. As a player, I want to bond and age beasts through Radiant to Mega Radiant, so that I chase the long goal.
9. As a player, I want a Journal of everything I've collected, so that completion gives permanent power.
10. As a player, I want limited-time Shadow beasts, so that I don't miss out (FOMO, honestly framed).
11. As a player, I want Evolution Prestige ranks (E→SSS+), so that resets feel rewarding.
12. As a player, I want capped offline income waiting for me, so that rejoining is a reward.
13. As a player, I want to trade with friends and see a value warning, so that I never get scammed.
14. As a player, I want a 4-week season pass, so that every session feeds one visible ladder.
15. As a player, I want to earn Prisms from events and my Journal, so that the best cosmetics are reachable free.
16. As a player, I want to buy convenience (2× coins, luck, VIP, private den), so that I progress faster without gating free players.
17. As a mobile player, I want one-tap catch/pen/lure with big buttons, so that I never need a keyboard.
18. As a returning player, I want hourly events, weekly critters and a pass, so that there is always a reason to rejoin.

## 13. Persistence
**Survives:** coins, prisms, inventory (beasts + variants + aging stage + fusion state), Journal
discoveries, Sprint level, zone unlocks, pedestal/sanctuary upgrades, prestige rank, pass season +
tier + premium flag, entitlements, trade log (rollback window), settings.
**Session-only:** carry state, Guardian aggro, lock timers (resume conservative default), in-flight
interception bids, event window progress, offline accrual timer (timestamp only).

## 14. UI & Design
Needs artifacts (draft, **not approved**): HUD-top-center layout, DenPanel bottom-sheet, EggMachine UI
(odds + pity), TrainingUI rhythm loop, JournalUI, Season Pass UI, TradeUI with value meter,
WelcomeBack offline card, interception countdown presentation. Batch-1 HUD fixes (top-center, 44px
targets) set the pattern. **No UI slice is ready-to-build until its brief is approved** — create these
under `design/features/<feature-slug>/design.md` per `roblox-game-ux`.

## 15. Mobile & Performance Targets
- Touch targets ≥44px; full-row taps in panels; readable at 360px width, portrait + landscape.
- One-tap actions only; camera staging over text; panels scale by viewport + scroll.
- The aging ladder multiplies beasts per den (16 copies per Mega Radiant) — this is the main new perf
  risk. Cap rendered pedestals per zone/den (render nearest N, instance the rest), and cache instance
  refs instead of per-frame recursive FindFirstChild.
- Guardian chase runs on server-authoritative movement; no client-owned carry positions.

## 16. Analytics (first-party only)
Funnel: spawn → first catch → first pen → first snatch attempt → first theft survived → zone 1 unlock.
Economy: coin sources/sinks per hour, prism faucet rate, offline claim size, journal completion rate.
Monetization: store views, attempts, completions, repeat rate, pass conversion per tier.
Safety: trade value-guard warnings shown, trades confirmed, reports filed, rollbacks granted.
Retention: D1/D3/D7, session length, 60-minute nudge rate.

## 17. Out Of Scope
Turn-based battling; player-vs-player damage; trading with strangers (friends-only); **any media feed,
autoplay video, infinite scroll, or viewing-gated reward**; a purchasable second currency; real-Pokémon
or licensed IP in any form; desktop-only controls; selling beasts for real money or Robux.
**Deferred (considered, not selected):** Trainer Level XP gating, Guardian boss encounters, daily
quests/login streaks/redeemable codes.

## 18. Risks
1. **Scope creep.** The stack is now ~13 slices (was 9) with four new systems. Check: slice strictly,
   ship §19's order, and do not start trading or the pass before persistence and theft are live.
2. **Griefing.** Snatching punishes new players. Check: revenge shields + wanted markers + Guardian
   cover in safe zones, validated in a slice-4 playtest.
3. **Compliance.** Any slide toward feed/doomscroll mechanics costs catalog eligibility and the whole
   differentiator. Check: a `roblox-policy-compliance` pass before any paid pull or store ships, and
   an explicit "no media feed" review on every UI brief.
4. **Economy inflation.** Offline income + Journal multipliers + interception bids can compound.
   Check: instrument coin faucets and re-tune each season rollover.
5. **Perf on low-end phones** once Mega Radiant dens hold 16× copies. Check: mobile playtest at the
   worst-case den before slice 11 (aging) ships.
6. **Trading scams** reaching kids despite the guard. Check: value-meter copy testing with real
   players, plus rollback logging from day one of trading.

## 19. Slicing / Roadmap Impact (proposed, not yet applied)
Existing roadmap slices 01–09 remain valid; the merged systems land as edits plus four new slices.

| Slice | Change |
|---|---|
| 01 Catch, pen, earn | unchanged (already built) — becomes zone 0 / Trailhead |
| 02 Persistence | unchanged (built) — add offline timestamp when §5.9 lands |
| 03 Onboarding + HUD | add Zone-1 goal + Journal first slot to the brief |
| 04 Steal, lock, slap | add Guardian chase (§5.1), carry-slow, **interception bidding (§5.8)** |
| 05 Rarity + mutations | add variant multipliers table (§5.5) + mutation weather hooks |
| 06 Egg machine + sinks | add **published odds + visible pity** UI; add Sprint training loop (§5.3) |
| 07 Prestige ranks | unchanged |
| 08 Robux ladder | add Dash/Glide potions, Bond potion, 2× passes, Spotlight Shop, spend summary |
| 09 Live-ops framework | add zones 1–6 spawn pools, weekly critter, Shadow weekends, daily zone bonus |
| **10 (new)** | **Capped offline income + WelcomeBack card** |
| **11 (new)** | **Bond aging → Radiant → Mega Radiant + Collection Journal + Prisms** |
| **12 (new)** | **Season Pass (4-week, free + premium)** |
| **13 (new)** | **Friends-only trading with value guard** |

## 20. Open Decisions
- Zone names and the meme-able beast naming scheme (needs a naming pass + IP/meme safety check).
- Whether Guardian chase uses a hard leash-and-reset or a soft slow-and-catch.
- Prism faucet rate vs top-tier shop pricing (must stay reachable for a free player).
- Rejoin hook strength for capped offline income (25% / 8h is a starter guess).
