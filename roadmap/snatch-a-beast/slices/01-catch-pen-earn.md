# Slice 01 — Catch, pen, earn (zone 0 / Trailhead)
Type: AFK. Status: [x] built + playtest-verified in the single merged game (PRD v2 zone 0).

## What to build
Wild critters trot along the forest trail; player taps one, server deducts coins and pens it
on a free pedestal; it generates coins/sec with a visible tick. The thinnest end-to-end core loop.

## Layers touched
- Client: tap-to-catch prompt, pen placement ghost, income tick animation.
- Server (authoritative): ownership, coin deduction, pedestal assignment, income ticks.
- Remotes: CatchRequest (C→S), CatchResult + IncomeTick (S→C).
- Data / persistence: none yet (slice 02).
- UI: coin balance + tick feedback on existing HUD.

## Playtest check (acceptance)
- [ ] In a Studio playtest, tapping a trail critter deducts coins and pens it.
- [ ] Balance visibly ticks up afterwards.
- [ ] No new console errors.
- [ ] Mobile: tappable on a phone-sized viewport.

## UI design artifact
Reuse of existing HUD only — no new surfaces, no brief required.

## Blocked by
None — can start immediately.

## Build Brief

**Category:** enhancement
**Summary:** Tracer bullet: tap a trail critter → server deducts coins and pens it → income ticks.

**Current behavior:** Live in the single merged place: BeastService spawns roamers,
ProximityPrompt catch, shared wallet via PlayerDataService (SetCoins), SnatchHUD +
MainHUD in agreement, Baseplate ground. This slice is zone 0 / Trailhead per PRD v2.

**Desired behavior:** Common-tier critters walk a looping forest trail. Tapping one in range
prompts a catch; the server validates funds and a free pedestal, deducts 50 coins, assigns
the pedestal; the critter moves there and earns its owner 2 coins/sec with a visible tick.
Starting balance 200 (a few catches; tunable). Edge cases: insufficient funds → shake +
"need more coins", no deduction; sanctuary full → "sanctuary full", no deduction; any
server rejection reverts optimistic UI.

**Layers & authority:**
- Client: tap input, placement ghost, tick animation, balance display. Requests only.
- Server (authoritative): validates funds + free pedestal, owns coins, ownership, income.
- Remotes: CatchRequest{critterId}; CatchResult{ok, reason}; IncomeTick{balance}.
- Data: none this slice (slice 02).

**Playtest acceptance:**
- [ ] In a Studio playtest, tapping a critter deducts 50 and pens it, then balance ticks up.
- [ ] Broke/full-den attempts fail with feedback and no deduction.
- [ ] Mobile: catch tap works on a phone-sized viewport.
- [ ] No new console errors.

**Out of scope:**
- Persistence, rarity, stealing, gacha, prestige, HUD redesign (reuse HUD patterns),
  touching any ShadowRealm file or place.
