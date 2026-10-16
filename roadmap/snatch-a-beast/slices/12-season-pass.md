# Slice 12 — Season Pass (4-week, free + premium)
Type: HITL (season rewards + premium pricing need human approval). Status: needs-human
— rewards sign-off; no work before theft + persistence are live (§18).

## What to build
One 4-week season, free track + premium track (Robux buy-in via slice 08). Pass XP
from every core action: catches, snatches, deliveries, den raids, Bond tasks, Journal
milestones. Premium grants cosmetics, convenience and Prisms — never zone access or
raid power. Tier-50 free-track reward is a real Shadow-tier beast, advertised from day
one (Day-7 hook). Season rollover: new season id, journal set refresh hook, balance
pass on compounding.

## Layers touched
- Client: PassUI (tier ladder, free/premium tracks), season banner.
- Server (authoritative): season id, Pass XP ledger, tier + premium flag, reward grants,
  rollover.
- Remotes: PassState (S→C), ClaimTier (C→S).
- Data / persistence: season id, tier, premium flag, claimed tiers saved.
- UI: pass surfaces (brief required).

## Playtest check (acceptance)
- [ ] Core actions accrue Pass XP; tiers + premium rewards grant correctly.
- [ ] Rollover resets season state and preserves lifetime flex (if any).
- [ ] Policy pass: premium never gates zones, raids, or Shadows (§11.4).
- [ ] No new console errors.

## UI design artifact
Blocked on UI design approval (pass brief).

## Blocked by
Slices 06 (reward sources), 11 (journal milestones feed Pass XP).
