# M2 — Everything decided so far

*The PvPvE sibling. Collected from every M2 conversation during Maroon's
development, so day one of M2 starts from here, not from zero.
Status: waits until Maroon 1.0 ships and teaches its lessons.*

> **Superseded by [CRIMSON-DESIGN.md](CRIMSON-DESIGN.md)** — the full
> master design doc. Where the two disagree (notably the SCAVOCK import
> list, which was narrowed to exactly three things: the combat/weapons
> philosophy, the online approach, and the Steam-grade seriousness),
> CRIMSON-DESIGN.md wins. This file stays as the historical record.

## Name
**Recommended: CRIMSON** — Maroon's blood-red sibling; the color family
tells the story ("You survived Maroon. Crimson survives you."). Shortlist:
Breakwater, Undertow, Landfall (existing-studio name risk), or Scavock if
M2 absorbs that design wholesale. Not yet locked.

## The one-line split
Maroon: PnPvE, 2–8 friends, primitive tech (iron/scale ceiling, never a
gun), beatable, cozy ending. **M2: PvPvE at Rust-scale (~100–300/server),
advanced tech ladder, firearms, rocket launchers, helicopters, raids,
third-party chaos.** The moments M2 exists for: unscripted convergence —
two enemy kinds colliding, the clutch turn, the RPG through the wall while
the owner fights a horde, two guys in a heli.

## Scale calibration (important)
"MMO-scale" in this genre means Rust/DayZ/Arc Raiders scale: 60–300 players
per server — a different engineering universe from Maroon's 8 (dedicated
infra, interest management, anti-cheat, moderation) but an achievable one.
True thousands-per-world MMO netcode is a third universe; don't aim there.

## Adopt from SCAVOCK wholesale (the doc lives in mrrzone's files)
- **Combat**: per-weapon blocking windows; the aggressive/defensive/
  technical triangle (tilt, not rule); LONG TTK as the foundation of the
  social layer (4–6 s even fights — short TTK silently deletes negotiation);
  first-strike ≤2×; probabilistic stagger scaled by weapon weight; gear
  compresses TTK, never below ~3 hits.
- **Noise & stealth**: sound from actions, noise multiplies with group
  size (the solo's compensating advantage).
- **Reinforcement/armor**: separate damage pool, split damage, audible
  break, armor as economic sink.
- **Equip layers**: hotbar / grid / functional clothing slots / cosmetics
  (no functional item = no render) / reinforcement slot.
- **Box-rig art pipeline** (proven twice now by Maroon).
- **Server authority from line one** + artificial latency injection from
  day one (0/50/120/250 ms + loss). Maroon's trust netcode is explicitly
  NOT reusable.
- **Playtime gating + hardware-hash bans** for official servers; open
  sign-in for private/single-player.
- Then **extend past SCAVOCK's no-guns rule**: firearms, RPGs, helicopters
  — SCAVOCK's TTK logic must be re-derived for ranged.

## Comms (decided)
Maroon has none (small groups bring their own). M2 needs the full stack:
**proximity voice + global chat + area chat + group chat.** Groups are
small formal bands — membership also disables accidental friendly fire.

## Locks (decided)
M2 adds the **keypad lock**: 4-digit code, memory-based — anyone who knows
it enters; nothing to carry or lose; harder to brute-force than a key lock.
Knowledge as the key, social engineering as the lockpick. (Key locks and
the household model carry over from Maroon.)

## What Maroon hands M2 on day one
Procedural world gen (dual-island → archipelago patterns), box-rig
character/creature builders, synthesized audio approach, quest-chain
structure, building system bones, grid inventory, weather, the release/
site/CI muscle memory — and a shipped game's worth of judgment about scope.

## Business framing
BDIA portfolio: Maroon = the co-op game with an ending (rare); M2 = the
extraction-adjacent PvPvE (crowded, differentiated by the SCAVOCK ideas
worth keeping — e.g., diggable/persistent world if absorbed). Maroon 1.0
ships to Steam first; M2 begins after, with its own repo and design doc
seeded from this file + the SCAVOCK master doc.
