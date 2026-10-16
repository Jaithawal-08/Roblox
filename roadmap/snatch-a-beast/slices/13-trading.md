# Slice 13 — Friends-only trading + value guard
Type: HITL (kid-safety review required). Status: needs-human — safety review + value
meter copy testing; no work before theft + persistence are live (§18).

## What to build
Trade beasts and variants with friends only. Trade window shows a total-value meter
with plain-language unfairness flags ("This trade is very unfair to you"), two-step
confirm, and every trade logged for a support rollback window. Gifting to friends
covers the casual case. No third-party value sites should ever be needed.

## Layers touched
- Client: TradeUI with value meter, two-step confirm, gift flow.
- Server (authoritative): trade session state, value computation, confirm handshake,
  atomic swap, rollback log.
- Remotes: TradeOffer/TradeAccept/TradeConfirm (C→S), TradeState (S→C).
- Data / persistence: trade log (rollback window), ownership transfers via slice-02
  profiles.
- UI: trade surfaces (brief required).

## Playtest check (acceptance)
- [ ] Two-player playtest: fair and lopsided trades both show the right meter state;
  confirm handshake completes an atomic swap.
- [ ] Stranger trade attempts are refused server-side.
- [ ] Rollback log restores a disputed trade.
- [ ] Value-meter copy tested with real players (safety gate, §18).
- [ ] No new console errors.

## UI design artifact
Blocked on UI design approval (trade brief) + safety review.

## Blocked by
Slices 02 (profiles), 11 (beast values are real once aging/journal exist).
