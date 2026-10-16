# Slice 10 — Capped offline income + WelcomeBack card
Type: AFK. Status: [~] built + pushed; server boot clean with zero errors. Full rejoin
E2E needs a published place (DataStore); claim path + math statically reviewed.
Note: `_G.SnatchOps` is NOT reachable from MCP `execute_luau` (ModuleScript sandbox
gets its own globals — verified twice), so live driving must go through prompts.

## What to build
Pens pay while away at 25% rate, capped at 8 hours (PRD §5.9 starter values). Rejoin
shows a "Welcome back" card with the accrued amount and a single Claim button. Rejoin
hook, not an idle game — capped, one-tap, never withheld to punish leaving.

## Layers touched
- Client: WelcomeBack card (claim button ≥44px), claim toast.
- Server (authoritative): accrual computed from slice-02 last-seen timestamp × live
  pen income × 25%, capped at 8h. No client math.
- Remotes: OfflineClaim (C→S), OfflineGrant (S→C).
- Data / persistence: last-seen timestamp updated on leave/save; accrual is computed,
  never stored as a balance.
- UI: WelcomeBack card (small brief if new patterns).

## Playtest check (acceptance)
- [ ] Simulated 8h+ absence grants exactly the 8h cap at 25% rate.
- [ ] Claim pays once; card never reappears for the same absence.
- [ ] No new console errors.
- [ ] Mobile: card readable/tappable on phone viewport.

## UI design artifact
Small; new brief only if the card introduces new patterns.

## Blocked by
Slice 02 (needs the last-seen timestamp hook).
