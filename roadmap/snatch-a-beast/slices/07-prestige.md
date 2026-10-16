# Slice 07 — Evolution Prestige ranks
Type: AFK. Status: [~] built + user-verified (Evolve hold-prompt, den wipe, E→D→C→B
chain, Rank on leaderboard, zero errors — server log).

Note (PRD v2): reuses the E→SSS+ vocabulary — `RankConfig` already defines these
ranks; wire prestige multipliers to it instead of a second table.

## What to build
Release the whole sanctuary to evolve trainer rank (E→SSS+, reusing that vocabulary) for a
permanent income multiplier. Board wipes, rank persists.

## Layers touched
- Client: prestige confirm dialog, rank reveal effect.
- Server (authoritative): rank, multiplier application, sanctuary wipe.
- Remotes: PrestigeRequest (C→S), RankUpdate (S→C).
- Data / persistence: rank saved; wiped inventory saved consistently.
- UI: confirm + reveal (small brief if new patterns).

## Playtest check (acceptance)
- [ ] Prestige wipes sanctuary, bumps rank, multiplier applies to new income.
- [ ] Rank survives rejoin.
- [ ] No new console errors.

## UI design artifact
Small; fold into slice-03 brief family unless new patterns appear.

## Blocked by
Slices 02, 05.
