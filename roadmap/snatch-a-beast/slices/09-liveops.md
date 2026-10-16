# Slice 09 — Live-ops framework
Type: AFK. Status: [~] verified live (scheduler fires hourly from a 2-min opening
festival; weather visibly mutates 2 beasts + new spawns; daily bonus + weekly/
shadow flags announced; zero errors). Zones 1–6 pools + full shadow weekends land
with zone geography (future).

## What to build
EventService scheduler: hourly mutation weather (applies slice-05 mutations) + free
egg roll hook; daily rotating zone bonus; weekly new critter + Spotlight rotation
hook; biweekly Shadow weekends (limited critters, prestige-scaled odds per §5.10);
monthly season rollover hook (pass + journal refresh, §12); zones 1–6 spawn pools
per the §5.2 table. Force-trigger hooks for testing each window type.

## Layers touched
- Client: event banners, countdown displays (all countdowns real, §11.3).
- Server (authoritative): window state, schedule, season rollover.
- Remotes: EventState (S→C).
- Data / persistence: season scores, participation flags.
- UI: banners/countdowns (brief if new patterns).

## Playtest check (acceptance)
- [ ] Each window type force-triggers and expires on schedule.
- [ ] Limited Shadow appears and disappears with its window.
- [ ] Mutation weather visibly re-rolls wild spawns.
- [ ] No new console errors.

## UI design artifact
Fold into existing briefs unless new patterns appear.

## Blocked by
Slice 05.
