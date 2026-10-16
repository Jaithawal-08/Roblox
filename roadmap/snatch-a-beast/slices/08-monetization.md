# Slice 08 — Robux ladder
Type: HITL (real money + `roblox-policy-compliance` pass required). Status: needs-human
— policy pass + purchase testing + §11 sign-off.

## What to build
Starter ladder per PRD §8: 49 single-pull refill · 99 Bond potion (age-up burst) ·
129 triple pull + 1h 2× coins · 199 Dash potion (fast carry, tradeable) · 199 Glide
potion (fly over trails, tradeable) · 399 VIP den (cosmetic + 24h 2× luck) · 399 Season
Pass buy-in · 799 30-day private den +1 slot · 799+ passes (2× Coins, 2× Luck,
+2 Pedestal Slots, Auto-Collect, Trail Pack) · Spotlight Shop 48h rotations.
Rules: no store surface until after the player's first steal; offers at need moments;
buy buttons separated from play taps; spend summary visible; every paid random
publishes odds with visible pity. Anti-P2W: speed/odds/convenience only — never zone
access, raid outcomes, Shadows, or Prisms.

## Layers touched
- Client: store UI (post-first-steal only), ownership badges, entitlement display.
- Server (authoritative): receipts, entitlements, boost application/expiry.
- Remotes: purchase grants (server-side only, never client-decided).
- Data / persistence: entitlements + premium pass flag saved.
- UI: store surfaces (brief required).

## Playtest check (acceptance)
- [ ] Sandbox purchases grant and expire correctly.
- [ ] Policy pass: odds published, no paywalled power, no first-session pressure.
- [ ] No new console errors.

## UI design artifact
Blocked on UI design approval (store brief).

## Blocked by
Slice 06.
