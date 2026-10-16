# Slice 05 — Rarity ladder + variants + mutation hooks
Type: AFK. Status: [~] built + user-verified in playtest (rarity tags, variant tints,
price curve, funds/den guards, zero errors — screenshots).

## What to build
Rarity ladder Common → Uncommon → Rare → Ultra-Rare → Legendary → Mythic → Secret
(+ Shadow spawns reserved for events, slice 09). Starter standard-egg odds + pity per
PRD §5.4 (60/24/10/4/1.5/0.45/0.05%, pity 25/67/222/2000). Zone pools gate rarities
per the §5.2 table; each zone stays the best source of its own rarities.
Variant income multipliers (PRD §5.5): Normal 1×, Gold 2.5×, Diamond 5×, Rainbow 12×.
Mutation-weather hooks for EventService (slice 09): Crystal ~15×, Phantom ~12×,
Cyber ~11× — time-boxed, always also earnable via a free event path.

## Layers touched
- Client: rarity visuals, variant effects, mutation effects.
- Server (authoritative): rarity rolls per zone pool, variant assignment, income
  multipliers, mutation application entry points.
- Remotes: spawn packets carry rarity/variant/mutation.
- Data / persistence: owned rarity + variant + discovery flags saved (feeds slice 11).
- UI: odds/pity readouts where pulls happen (egg machine shows its own in slice 06).

## Playtest check (acceptance)
- [ ] Rarer trail spawns cost and earn per the starter curve.
- [ ] Forced mutation window upgrades a spawn visibly with correct multiplier.
- [ ] Discovery flags persist across rejoin.
- [ ] No new console errors.

## UI design artifact
Odds/pity surfaces belong to slice 06's machine brief; variant/mutation effects reuse
existing billboard patterns unless new ones appear.

## Blocked by
Slice 01.
