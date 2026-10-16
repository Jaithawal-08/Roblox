# ROADMAP: Snatch a Beast
PRD: `design/snatch-a-beast/prd.md` (v2). Convention: `[ ]` not started ·
`[~]` built + tested, awaiting approval · `[x]` only after build + playtest + human approval.

Build order follows loop → save → social/return → monetization → live events.
04 is the biggest slice (theft + Guardian + bidding); split it 04a/04b if one
playtest cannot cover it.

- [x] 01 — Catch, pen, earn (zone 0 / Trailhead) → built, playtest-verified, human-approved
- [~] 02 — Coins survive rejoin (+ offline timestamp hook for 10) → implemented, needs published place to fully verify
- [ ] 03 — First-session onboarding + HUD (Zone-1 goal, Journal first slot) → needs-human (mini brief first)
- [~] 04 — Theft (per-player dens, lure/carry/slap, locks, shields) + Guardian chase + interception bidding → catch/den solo-verified with zero errors; 2-player theft E2E pending a second tester (Guardian + bidding = 04b, not started)
- [~] 05 — Rarity ladder + variants + mutation hooks → user-verified in playtest (screenshots)
- [ ] 06 — Egg machine (published odds + pity) + Sprint training loop + sinks → needs-human (odds + briefs)
- [~] 10 — Capped offline income + WelcomeBack card → built + pushed; rejoin E2E needs publish
- [~] 07 — Evolution Prestige ranks → user-verified (E→D→C→B chain, zero errors)
- [~] 11 — Bond aging → Radiant/Mega + Journal + Prisms → bond live-verified; fuse + milestone payouts user-long-play
- [~] 09 — Live-ops framework → verified live (weather mutates, daily/flags announced)
- [ ] 12 — Season Pass (4-week, free + premium) → needs-human (rewards sign-off; after 06, 11)
- [ ] 08 — Robux ladder → needs-human (policy pass; after 06)
- [ ] 13 — Friends-only trading + value guard → needs-human (safety review; after 02, 11)

Gates: every slice needs a Studio playtest, zero new console errors, and a mobile
viewport check on UI. Policy pass (`roblox-policy-compliance`) before 08 and 12.
Per PRD §18: no trading or pass work before theft + persistence are live.
