# Slice 02 — Coins survive rejoin
Type: AFK. Status: [~] implemented (SaveManager + load/save/restore), session-only
verified with zero errors; full rejoin-proof needs a published place.

> Update: implemented (SaveManager + BeastService load/save/restore). Verified: validation
> logic correct, zero console errors, clean session-only fallback. Full rejoin-proof still
> needs a published place — see below.
>
> Update 2 (PRD v2): record a last-seen timestamp in the profile — the offline accrual
> hook for slice 10. Wallet is shared with PlayerDataService (single-game economy).

## What to build
DataStore profile per player: coins, owned critters + pedestal layout, last-seen
timestamp (slice-10 hook). Autosave on interval, save on leave and server shutdown.

## Layers touched
- Client: none (loading screen text at most).
- Server (authoritative): profile load/create, autosave, session locking basics.
- Remotes: reuse IncomeTick/stats packet for loaded balance.
- Data / persistence: DataStore (this slice's whole point).
- UI: none.

## Playtest check (acceptance)
- [ ] Earn coins, stop playtest, rejoin → balance and penned critters intact.
- [ ] No new console errors.

## UI design artifact
No UI design step required.

## Blocked by
Slice 01.
