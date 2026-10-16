# Slice 06 — Egg machine + Sprint training + coin sinks
Type: HITL (gacha odds + training rewards + upgrade pricing need human approval).
Status: needs-human — PRD §5.3/§5.4 values, UI briefs missing.

## What to build
Egg Machine: free common pull hourly; paid pulls with **published odds + visible pity
counter on the machine itself** (PRD §5.4 table). Zone pools stay the best source of
their own rarities — the machine is the deliberate low-risk path, wild snatch the
risky one.
Sprint training loop (PRD §5.3, replaces any idle training): Training Yard rhythm
mini-loop, ~15s tap-the-nodes-in-time, 3 rounds per session, accuracy-scored →
Sprint XP → Sprint levels (0–140, move 16→64, carry at 60%). Training Gear tiers add
multipliers. Sprint gates zones per the §5.2 table.
Coin sinks: pedestal slots, den size, Sanctuary lock upgrades, zone unlocks, Training
Gear, egg pulls, fusion slots (with 11). Early upgrades fast (first slot ~3 catches);
every sink exists before its big source.

## Layers touched
- Client: egg machine UI (odds + pity), TrainingUI rhythm loop, upgrade panel, pull animation.
- Server (authoritative): pull rolls, pity counters, Sprint XP validation (no client math),
  upgrade levels, wallet deduction.
- Remotes: EggPull (C→S), PullResult (S→C), BuyUpgrade (C→S), TrainingScore (C→S).
- Data / persistence: pull history (odds audits), pity counters, upgrade levels,
  Sprint level saved.
- UI: machine + training + upgrade surfaces (brief required).

## Playtest check (acceptance)
- [ ] Free egg granted hourly, exactly once per window.
- [ ] 100 test pulls roughly match published odds; pity fires at its counter.
- [ ] Training session pays Sprint XP on accuracy only; Sprint gates zones.
- [ ] Upgrades drain wallets on curve and respect caps.
- [ ] No new console errors.
- [ ] Mobile: rhythm taps + machine buttons at ≥44px, portrait + landscape.

## UI design artifact
Blocked on UI design approval (machine + training + upgrade panel briefs).

## Blocked by
Slices 01, 02.
