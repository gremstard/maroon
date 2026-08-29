# CRIMSON — Master Design Document

*PvPvE survival at scale. The moments game.*
*Studio: Brain Dump Inneractive (BDIA) · by mrrzone*
*Status: pre-production. Development begins after Maroon 1.0 ships to Steam.*

---

## HOW TO READ THIS DOCUMENT

Every statement is tagged by confidence:

- **Confirmed** — decided by the designer. Build it this way.
- **Recommended** — a proposal with stated reasoning. Adopt unless overruled.
- **Open** — genuinely undecided. **Do not invent an answer.** Ask, or build
  the smallest version that leaves the decision reversible.

If something is not in this document, it has not been decided. Do not fill
gaps with plausible defaults — flag them instead. Keep this document current
and hand it to the assistant at the start of each session, so decided systems
don't get re-explained or drift.

---

## 1. ELEVATOR PITCH

Maroon is the survival game where you cannot hurt each other. **Crimson is
what happens when you can.**

A persistent PvPvE survival world at Rust scale — 100–300 players per
server — with firearms, helicopters, rocket launchers, raids, and a living
threat ecology that doesn't care whose side anyone is on. You build, you
arm, you claim territory, and every plan you make is one third party away
from becoming a story.

**The design target is a specific feeling: unscripted convergence.** The
raid interrupted by a horde. The RPG through the wall while the owner is
fighting for their life on the other side of it. Two guys in a helicopter
who were never supposed to be there. The clutch turn nobody could have
scripted. Crimson is not a shooter with crafting or a survival game with
guns — it is a **moments engine**, and every system in this document is
judged by one question: *does it make those collisions more likely, more
legible, and more worth retelling?*

**Tagline:** *You survived Maroon. Crimson survives you.*

---

## 2. WHAT CRIMSON IS NOT

**Not Maroon 2 in content.** Maroon is 2–8 friends, primitive tech, no
guns ever, beatable, cozy ending. Crimson is strangers at scale, an
advanced tech ladder, and a world that never ends — it wipes. The two
games share a studio, an art pipeline, and a color family, nothing else.
Maroon's promise ("you cannot hurt other survivors") is precisely the
promise Crimson breaks, and both games are stronger for the contrast.

**Not SCAVOCK.** SCAVOCK is its own design — voxel-diggable extraction
with evacs, vaults, and no firearms. Crimson takes **exactly three things**
from the SCAVOCK master doc and nothing else (Section 3). No voxel
terrain, no extraction loop, no evac points, no cross-wipe vault, no
no-guns rule. If a SCAVOCK system is not listed in Section 3, it is not
in Crimson.

**Not an indie experiment.** Maroon was built in the open, free, on
itch-style distribution rhythms. **Confirmed: Crimson is a commercial
Steam title from day one** — planned, budgeted, playtested, and shipped
like one. See Section 14.

---

## 3. THE THREE SCAVOCK IMPORTS

This is the complete list of what Crimson adopts from the SCAVOCK master
design document. **Nothing outside this section carries over.**

### Import 1 — The weapons & combat philosophy

- **No single best weapon, ever.** A bounded, hand-tunable roster
  (Section 6) where every option has a genuine strength paid for with a
  genuine weakness. Players win through choice, timing, positioning, and
  strategy — the competitive-Beyblade model: a widely-regarded "best"
  loadout still loses to its specific counter.
- **Skill over gear.** No tier makes a player unbeatable. Gear compresses
  time-to-kill; it never collapses it. Top-tier versus naked is a
  disadvantage, not an execution.
- **Long-for-the-genre TTK as a social load-bearing wall.** Short TTK
  silently deletes negotiation, betrayal, and third-party drama — and the
  loss never gets traced back to a damage number. Re-derived for firearms
  in Section 6; the *reasoning* is the import, the numbers are Crimson's.
- **First-strike advantage capped** so ambush tilts fights without
  deciding them.
- **Fixed rosters over parametric systems** — twenty weapons can be
  balanced by hand; an infinite space always contains an optimum players
  find within days, and fixed stats make server validation trivial.

### Import 2 — The online approach

- **Server authority on everything, from line one.** Position, movement,
  hit registration, loot, containers, build placement, damage — validated
  server-side, never client-reported. Maroon's trust-based netcode is
  explicitly, permanently **not reusable**: it was safe only because
  Maroon players cannot hurt each other. Assume all client code is
  visible and modifiable; get authority right and most cheating is
  impossible rather than punishable.
- **Artificial latency injection from day one.** A dev setting buffering
  packets by N ms with configurable jitter and loss. Test matrix: 0 / 50 /
  120 / 250 ms and 2% loss. LAN hides every prediction and reconciliation
  bug; retrofitting this later means touching every message path.
- **Playtime gating for official servers** (1–3 server-validated hours on
  community/private play first) — hours are the one friction cheaters
  can't buy cheaply.
- **Hardware-hash bans** (salted hash, never raw IDs; multiple signals;
  reserved for confirmed cheating) plus **IP as a registration rate limit
  only**, never a ban.
- **Two-tier ban structure:** community-server bans are the admin's
  business; global bans are developer-issued, official servers only, and
  never lock anyone out of playing with friends.
- **Server-side state replay for moderation** — positions, damage events,
  inventory transactions on a rolling window; state, not video.
- **Mechanical anti-abuse over rules-and-reports** — if a behavior (spawn
  camping, safe-zone violence) must not happen, make it impossible in
  code; moderation by human report does not scale.

### Import 3 — The seriousness

- **This document's own discipline** — confirmed/recommended/open tags,
  no invented canon, the doc handed to every dev session.
- **Steam-first commercial posture** (Section 14): a paid product with a
  store page, wishlist campaign, Early Access plan, achievements, cloud
  saves, workshop ambitions — not a free build on a personal site.
- **Incremental versioned milestones** with playtesting and bugfixing
  folded into each increment before moving on (Section 15).
- **Honest effort accounting** — multiplayer-at-scale is the long pole;
  playtesting and balance are the largest line item and do not shrink;
  social systems cannot be solo-tested and need scheduled multi-player
  sessions as a distinct unit of work.
- **Ecosystem thinking shipped early, not at 1.0** — community servers,
  admin tools, and (post-1.0) modding surface, because platforms outlive
  games and ecosystems only take root while the game is still small.

**Explicitly cut from earlier import lists** (superseded by this
document): SCAVOCK's noise-multiplication stealth system, reinforcement
damage-pool armor, equip-layer scheme, vault/evac/wipe economy, voxel
world, and the no-firearms rule. Where Crimson needs an equivalent system
it derives its own — mostly from Maroon's shipped code (Section 4).

---

## 4. WHAT MAROON HANDS CRIMSON ON DAY ONE

Proven twice-shipped foundations, carried forward as *starting points*,
each expected to be rebuilt harder where scale demands:

- **Box-rig art pipeline** — characters, fauna, vehicles from rigid boxes
  and flat colors; no sculpting, no skinning, no external assets ever.
  The single biggest derisking decision, now proven in a shipped game.
- **Procedural worldgen** — heightmap terrain, biome layering, coast
  wobble, quest-site placement (dual-island logic generalizes to
  archipelago and continent patterns).
- **Building system bones** — pillar foundations, snap grid, walls/roofs/
  doors/ladders/trapdoors, claim-and-upkeep logic.
- **Grid inventory** — Tarkov-style multi-cell items with rotation,
  binding hotbar, container UI.
- **Locks & households** — lock/key pairs, shared household access,
  loud brute-forcing; Crimson adds the keypad lock (Section 10).
- **Weather, day/night, synthesized audio, generated icons, save
  versioning with migration shims, the release/site/CI muscle memory** —
  and a shipped game's worth of judgment about scope.

**Confirmed: engine is Godot 4.x**, same as Maroon — the team's fluency
in it is now an asset, and Godot ships dedicated Linux server exports.
The netcode, however, is written new against Import 2's rules; nothing
from Maroon's `sv_*`/trust model survives contact with PvP.

---

## 5. WORLD

- **Confirmed: seed-generated persistent world**, one per server,
  wiped on a schedule (Section 12). New seed every official wipe so
  terrain can't be permanently memorized.
- **Recommended: one large landmass with a coastline and satellite
  islands** — Rust-pattern rather than Maroon's two islands. Roads and
  rivers as travel arteries; travel time is what makes territory real
  and helicopters valuable.
- **Monuments** — authored-flavor procedural sites (port, refinery, radar
  station, drowned town, military checkpoint) that concentrate loot,
  danger, and therefore players. Monuments are the scheduled collision
  generators; the map between them is the unscheduled one.
- **Biomes** carry their own threat ecology and resources (Maroon's
  biome logic, scaled up). **Open:** final biome list.
- **PvE as the third party.** The threat ecology is not set dressing —
  hordes migrate, predators den near loot, and gunfire draws them.
  **Confirmed: every PvE threat responds to noise**, so every fight
  risks inviting the world in. This one rule is the moments engine's
  primary fuel.
- **Open:** map size and its coupling to the population cap — density is
  a temperature dial; decide the two together during alpha.

---

## 6. COMBAT

### Firearms, re-derived from the imported philosophy

SCAVOCK banned guns partly because hitscan lag compensation is the
hardest networking problem in the genre. Crimson keeps the guns and
imports the *reasoning* instead:

- **Confirmed: all firearms are projectile-based, no hitscan.** Bullets
  have travel time, drop, and server-simulated flight (Rust's own
  choice). This preserves most of the netcode benefit, rewards skill
  (leading targets), and makes range a real gradient instead of a
  binary.
- **Recommended TTK targets, even fight, mid-tier gear:** ~4–7 body
  shots with a rifle (roughly 1.5–3 s of sustained accurate fire),
  longer at range via damage falloff; headshots multiply (~1.75–2×) but
  never one-shot through mid-tier head protection except from dedicated
  sniper-class weapons at close range. Fast enough that guns feel
  lethal, slow enough that a caught player can reach cover, turn a
  fight, or scream for allies — the social layer survives at the range
  band where most fights actually happen.
- **First-strike reality check:** with guns the ambush bonus is
  positional, not statistical — no damage multiplier for attacking
  first. The cap is enforced by TTK: even ambushed, a mid-tier player
  survives long enough to respond from cover.

### The roster

**Confirmed: a fixed, bounded roster — 15–25 weapons at 1.0**, each a
role rather than a rank:

- **Melee tier** (always relevant — silent, no ammo): knife, spear,
  machete, mace. Maroon's melee feel, hardened for PvP.
- **Primitive ranged:** bow, crossbow — silent, recoverable ammo, the
  early-wipe and stealth backbone.
- **Improvised firearms:** pipe pistol, double-barrel, nail rifle —
  loud, cheap, wildly inaccurate past close range.
- **Manufactured firearms:** revolver, pump shotgun, SMG, semi-auto
  rifle, bolt sniper, and one full-auto rifle at the top.
- **Explosive/heavy:** grenades, satchels, the rocket launcher (a raid
  tool first, an anti-helicopter tool second, a murder weapon a distant
  third — priced accordingly).

**Every advantage is paid for:** full-auto eats scarce ammo and roars
across the map; silent weapons are short-ranged; the sniper is helpless
inside a doorway. **Ammo is the economy's consumable sink** — crafted or
looted, never abundant, with the noisiest weapons hungriest.

- **Recommended: no stamina meter; movement speed governed by carried
  weight** (imported logic, Maroon-compatible): looted-heavy players
  are slow, chases resolve, "one more crate or leave now" is a real
  decision.
- **Open:** whether creatures and players share one damage model;
  downed-state/revive design (PvP changes the calculus — study Rust's
  wounded state); armor model (Crimson derives its own from Maroon's
  clothing tiers — **not** SCAVOCK's reinforcement pool).

---

## 7. THE THREAT ECOLOGY (PvE)

Maroon's "creatures with one rule each" readability, scaled to a world
with guns:

- **Carryovers, hardened:** wolf packs, bears (investigate/charge),
  boars (face-aggro with telegraph), snakes, crows — box-rig, one
  learnable rule apiece.
- **New pressure class — the horde:** infected-style humanoid mass
  threat that migrates at night and swarms toward sustained gunfire.
  Cheap per-unit (one model, instanced), expensive in aggregate.
- **New tactical class — hostile raider NPCs** at monuments: aim, take
  cover, retreat; a mid-game gear check and the reason monuments stay
  dangerous even on a quiet server. Visually unmistakable as NPCs.
- **Apex events:** a patrol helicopter, a leviathan-class sea threat, or
  a migrating mega-horde — server-wide, visible-from-everywhere events
  that create scheduled convergence the way Rust's heli does. **Open:**
  which ships at 1.0 (recommend exactly one, done well).

---

## 8. BUILDING, RAIDING & TERRITORY

- Building carries over from Maroon (foundations/walls/floors/roofs,
  snap, tiers) with **material upgrade tiers** (thatch → wood → stone →
  sheet metal → armored) because walls now face rockets.
- **Confirmed: raiding is possible, expensive, and loud.** Explosives
  are the wall answer; cost is tuned so raiding a base is an investment
  that can fail, not an impulse. Every explosion is heard across a huge
  radius and draws both players and the horde — **raids are supposed to
  get crashed.**
- **Claim & upkeep:** Maroon's totem logic becomes a tool-cupboard-style
  claim with material upkeep; unfed claims decay and open to the world.
  Decay is the world's self-cleaning mechanism — no admin removal.
- **Offline raiding: Open.** The genre's hardest social problem. Study
  softer options (decay-gated windows, online-scaled explosive damage)
  during alpha rather than locking dogma now.

---

## 9. COMMS

**Confirmed (long-standing decision): Crimson ships the full stack that
Maroon deliberately has none of:**

- **Proximity voice** — the moments engine's second fuel; negotiation,
  bluffing, and betrayal all live here.
- **Global chat, area chat, group chat** — text.
- **Groups** are small formal bands; membership disables friendly fire
  (accident insurance, not PnP — leaving the group re-arms it).
- Mute/block per player; community servers can disable global chat.

---

## 10. LOCKS & ACCESS

Carried from Maroon: lock/key pairs, households, loud brute-forcing.

**Confirmed addition — the keypad lock:** 4-digit code, memory-based.
Anyone who knows the code enters; nothing to carry, nothing to loot off
a corpse; harder to brute-force than a key lock. Knowledge as the key,
social engineering as the lockpick — codes get shared, leaked, extorted,
and changed in a panic at 2 a.m. That is content.

---

## 11. PROGRESSION

- **Tech ladder:** primitive (Maroon-tier) → workbench 1 (improvised
  guns, stone/metal tools) → workbench 2 (manufactured guns, vehicles
  parts) → workbench 3 (top-tier weapons, rockets, helicopter). Each
  tier is a base investment that must be defended — progression is
  physical and raidable, not an account unlock.
- **Within a wipe only.** No cross-wipe power. **Recommended:** the only
  things that persist across wipes are cosmetic and reputational
  (skins, stats, achievements) — level playing field every cycle is
  what keeps a wipe-based game joinable forever.
- **Blueprint/unlock model: Open** (found blueprints vs. scrap-research
  vs. pure workbench gating — decide in alpha with data).

---

## 12. SERVERS, SCALE & WIPES

- **Confirmed: Rust-scale, not MMO-scale.** 100–300 players per server
  is the target — a different engineering universe from Maroon's 8
  (dedicated Linux servers, interest management/AOI, tick budgets),
  but an achievable one. Thousands-per-world is a third universe;
  do not aim there.
- **Official servers** (developer-run, gated per Import 2, monthly
  wipes, new seed each wipe) and **community servers** (admin-run,
  their own rules, wipe whenever, fixed seeds allowed) from day one.
  Community servers are where the game becomes a platform.
- **Recommended: launch population target 100–150**, raised as the
  interest-management layer proves itself. Advertised caps you can't
  hold are how launches die.
- **Open:** wipe cadence for official (monthly is the working
  assumption), map-size-per-population table.

---

## 13. ART, AUDIO & TONE

- **Box-rig everything, flat colors, zero external assets** — the BDIA
  house style, proven by Maroon. Readability at 200 m matters more in a
  gun game: silhouettes and tier colors must be identifiable at range.
- **Synthesized audio** approach carries over, but gunshots, and the
  directional/distance audio pipeline around them, are a first-class
  system — in a game where noise summons everything, audio *is* game
  design.
- **Tone:** grounded and grim where Maroon is warm. Crimson's palette
  leads with its name.

---

## 14. BUSINESS & DISTRIBUTION

- **Confirmed: paid title on Steam. Not free, not itch-first.**
  Rationale: a price tag is itself anti-cheat friction (banned accounts
  cost money to replace — the standard economics of the genre), funds
  the server infrastructure a 300-player game actually requires, and
  positions the game in the market segment it competes in.
- **Recommended: Early Access at $14.99–19.99**, price raised at 1.0.
  Wishlist campaign starts the day the store page can look credible;
  Maroon's Steam release is the dry run for the entire pipeline
  (store assets, builds, achievements, cloud saves).
- **Windows and macOS at minimum** (Maroon parity); Linux desktop
  **Open**; dedicated servers on Linux **Confirmed**.
- Maroon stays free forever and becomes the funnel: the studio's
  calling card, the community seed, and the "same studio, opposite
  promise" story that makes Crimson's pitch land.
- **Open:** monetization beyond the box price (cosmetics-only is the
  working assumption; **never** functional items — hard rule).

---

## 15. ROADMAP

Incremental versions, one increment per session, playtested before
moving on. Multiplayer foundation is expected to take longer than
everything before it combined — plan for it, don't be surprised by it.

**Phase 0 — Foundation (pre-alpha)**
- New repo, new netcode skeleton: server-authoritative movement with
  client prediction + reconciliation, **latency injection built in
  before the second feature exists**
- Box-rig player, gray-box world, grid inventory port
- Projectile weapon prototype: one gun, one bow, server-simulated
  flight, hit registration — tuned at 120 ms artificial latency

**Phase 1 — The fight (alpha)**
- Full combat loop: roster v1 (≈8 weapons), damage model, armor v1
- Building + material tiers + claim/upkeep + decay; raiding v1
- Threat ecology v1: wolves, bear, the horde; noise attraction
- Proximity voice + chat stack; groups + friendly-fire-off

**Phase 2 — The world (beta)**
- Full worldgen: continent, biomes, monuments, roads
- Tech ladder + workbenches; vehicles (ground, boat); locks + keypads
- 100-player load tests on real dedicated hardware — **scheduled
  multi-player playtests as their own budgeted workstream**
- Accounts, playtime gate, hardware-hash bans, server replay

**Phase 3 — The moments (release candidate)**
- The helicopter (flyable) and the apex event
- Rockets and the full raid economy; balance pass against real wipe data
- Official server fleet, wipe automation, Early Access launch

**Post-1.0:** modding/workshop surface, additional apex events, Linux
client, the systems playtests demand that this document didn't predict.

---

## 16. CONSOLIDATED OPEN QUESTIONS

1. Final name — CRIMSON is the recommended working title, not yet locked
2. Map size ↔ population cap coupling
3. Biome list and per-biome threat tables
4. Armor model (derive from Maroon clothing tiers)
5. Downed/wounded state and revives under PvP
6. Shared vs. split damage model for creatures and players
7. Blueprint/unlock model
8. Offline-raid mitigation
9. Which apex event ships at 1.0
10. Official wipe cadence (monthly assumed)
11. Linux client at launch
12. Monetization beyond box price (cosmetics-only assumed)

---

## 17. QUICK REFERENCE

- **Genre:** PvPvE survival, Rust-scale (100–300/server), persistent
  wiped worlds. Godot 4.x, box-rig art, zero external assets.
- **Loop:** land naked → forage and arm → build and claim → climb the
  tech ladder → raid and be raided → survive the convergence — repeat
  until the wipe, then again on a new seed.
- **Core differentiator:** the moments engine — a threat ecology that
  answers noise, long-for-the-genre TTK, proximity voice, and expensive
  loud raids, all tuned to manufacture unscripted three-way collisions.
- **From SCAVOCK, exactly three imports:** the combat philosophy (no
  best weapon, skill over gear, social-load-bearing TTK), the online
  approach (server authority, latency injection, playtime gates,
  hardware bans), and the seriousness (this document's discipline,
  Steam-first commerce, milestone rigor).
- **From Maroon:** the art pipeline, worldgen, building, inventory,
  locks, audio, and a shipped game's worth of scope judgment. Not the
  netcode — never the netcode.
- **Business:** paid Early Access on Steam; Maroon stays free as the
  funnel. *You survived Maroon. Crimson survives you.*
