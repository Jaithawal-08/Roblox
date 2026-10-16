# Slice 11 — Bond aging → Radiant/Mega + Journal + Prisms
Type: AFK. Status: [~] built + partially verified live (bond tasks + Sprout stage-up
print, Bond/Lure/Fuse prompts structural, prisms plumbing; zero errors).
Pending: full fuse (needs 4 matching Primes — long grind) and journal milestone
payouts (need 6 combos + den space) — both code-reviewed, user-long-play items.
Note: MCP `input` holds don't complete hold-to-confirm prompts; Evolve holds were
human-verified earlier (E→D→C→B).

## What to build
Bond aging (PRD §5.6): beasts age by active Bonding tasks (pet, feed, play — never
idle time): Hatchling → Sprout → Stripling → Prime with per-rarity task counts and
1×/1.15×/1.4×/1.8× income. Fusion: 4 × Prime (same species/variant) → Radiant (2.6×);
4 × Radiant → Mega Radiant (4×, color-cycling + flex aura). Snatching feeds the
duplicate copies this ladder eats.
Collection Journal (PRD §5.7): species × variant silhouette book; set completion pays
a permanent global income multiplier + den cosmetic; bonuses stack.
Prisms (PRD §5.12): earn-only currency from live events, rare-spawn bonuses, Journal
sets. Gates the top shop tier (den skins, aura trails, event cosmetics). Never
purchasable.

## Layers touched
- Client: bond task prompts/progress, fusion UI, JournalUI book, prism balance display.
- Server (authoritative): bond progress, stage transitions, fusion validation (consumes
  exactly the right 4 copies), discovery bitmap, set bonuses, prism grants.
- Remotes: BondTask (C→S), FuseRequest (C→S), JournalState (S→C), PrismGrant (S→C).
- Data / persistence: aging stage + bond progress, fusion state, journal bitmap, prism
  balance saved.
- UI: fusion + journal surfaces (brief if new patterns beyond HUD).

## Playtest check (acceptance)
- [ ] Bond tasks advance stages at the right counts; idle time advances nothing.
- [ ] 4-Prime fusion consumes exactly those copies and pays Radiant; 4-Radiant → Mega.
- [ ] Journal set completion applies a permanent multiplier + prism payout.
- [ ] Prisms have no purchase path anywhere.
- [ ] No new console errors.
- [ ] Mobile: worst-case Mega den playtested on a phone-sized viewport (perf gate, §18).

## UI design artifact
Fusion + journal briefs if they introduce new patterns; prism display reuses coin patterns.

## Blocked by
Slices 04 (duplicates feed fusion), 05 (rarity/variant/discovery data).
