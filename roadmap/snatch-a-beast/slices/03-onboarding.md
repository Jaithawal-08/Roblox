# Slice 03 — First-session onboarding + HUD
Type: HITL (mini design brief must be approved first). Status: needs-human — mini brief missing.

## What to build
Fresh spawn faces the trail; a free common egg hatches in the player's hands; one contextual
prompt ("Pen it!"); coins tick with sound + counter; HUD shows the "Zone 1 in 2,500 coins"
goal and the first Journal silhouette slot; within 60s a nearby rival shield drops
with a "Sneak in…" prompt. No tutorial text walls, no menu-first start.

## Layers touched
- Client: contextual prompts, hatch effect, HUD top-center layout (Batch-1 pattern).
- Server (authoritative): free-egg grant (once per player), shield-drop scheduler.
- Remotes: prompt triggers, egg grant.
- Data / persistence: free-egg-claimed flag.
- UI: prompt styling + HUD arrangement (brief covers mobile + states).

## Playtest check (acceptance)
- [ ] Fresh player reaches first income tick in under 60s with zero explanation read.
- [ ] Free egg granted exactly once.
- [ ] No new console errors.
- [ ] Mobile: prompts readable/tappable on phone viewport, portrait + landscape.

## UI design artifact
Blocked on UI design approval — mini brief (prompts, hatch moment, HUD states).

## Blocked by
Slice 01.
