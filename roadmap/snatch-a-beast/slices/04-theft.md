# Slice 04 — Theft + Guardian chase + interception bidding
Type: AFK. Status: [~] 04a solo-verified (catch/den/full-den; zero errors); 04b built
(bidding windows open live; guardian code zone-0-exempt by design, hook-posted).
Theft E2E (lure/carry/slap/lock/shield) + bid chains still need a second tester.
Note: biggest slice on the board — split 04a (theft)/04b (Guardian + bidding) if one
playtest cannot cover it.

## What to build
Per-player dens replace the shared 4 pedestals (each player gets their own pen row +
lock). Enter an unlocked den, lure a critter (carried overhead at 60% speed), haul it
to your pedestal. Den locks on a timer block entry; victims can tackle-slap to knock
the carried critter loose. Repeat-theft victims get a 60s revenge shield; repeat
thieves get a "wanted" bounty marker.
Guardian chase (PRD §5.1): every zone past Trailhead has a Guardian (big themed beast).
Grabbing a wild beast there triggers pursuit; tagged = drop it + it respawns in-zone.
Chase + drop only — no damage, no PvP damage anywhere. Zones 0–1 exempt.
Interception bidding (PRD §5.8): grabbing a Rare-or-better wild announces it server-wide
and opens an 8-second Snatch Back window — anyone may pay 150% of coin value to flip
ownership (re-targets to their den; original snatcher must still deliver). Chains
allowed. Never on Shadows.

## Layers touched
- Client: LURE button (≥60px), carry pose/slow, lock countdown display, wanted marker,
  bid countdown presentation.
- Server (authoritative): per-player den assignment, carry state, lock timers, slap
  validation (range + cooldown), shield/bounty flags, Guardian pursue/leash/reset,
  bid windows + ownership flips + announcements.
- Remotes: LureRequest, SlapAttempt, LockState (S→C), BidOffer (C→S), BidResult (S→C).
- Data / persistence: stolen critter ownership transfer saved via slice-02 profiles.
- UI: lock countdowns, wanted marker, bid banner (fold into 03 brief family if new).

## Playtest check (acceptance)
- [ ] Two-player playtest: thief lures while slowed; lock blocks entry; slap frees critter.
- [ ] Victim shield + thief marker behave as specified.
- [ ] Guardian tags carrier → drop + respawn; safe zones never chase.
- [ ] Rare+ grab announces + 8s bid window flips ownership at 150%; chains resolve.
- [ ] No new console errors.
- [ ] Mobile: LURE button reachable without keyboard.

## UI design artifact
Covered by slice-03 brief extension (countdowns, markers, bid banner) — flag if it
needs its own pass.

## Blocked by
Slices 01, 02.
