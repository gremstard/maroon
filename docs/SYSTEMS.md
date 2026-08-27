# Maroon — Systems Reference

*How every mechanic works, with the current numbers. The code is the truth
(scripts/game_items.gd holds all recipes/stats); this is the map.
Current as of v0.22.1.*

## The loop
Forage → craft → hunt/fish → build → quest → sail → descend → choose your
ending (Heart = kind, Long Game = earned) → peaceful. 34-goal ladder always
shows the next step (top right).

## Gathering & tools
- Bare hands only forage: branches (deadfall), fiber (dry grass), loose
  stones, berries. Pickups also work with E.
- Tool gates: trees need an axe; rocks a pick; iron/moonstone a Stone Pick
  (mine ≥4); heartstone an Iron Pick (mine ≥6).
- Tool ladder (chop/mine/dmg): crude 3/3/12–14 → stone 5/5/16–20 → iron
  7/7/24–28. Spears: 32 (wood) / 45 (iron). Fishing rod dmg 3 (don't).
- Forage respawns (~90 s); bushes regrow; trees/rocks don't (scatter is
  generous).

## Stations
- **Hands**: string, crude tools, spear, torch, bedroll, campfire, hammer,
  workbench, crate, dyes, fishing rod.
- **Workbench** (12 wood + 4 stone, stand ≤6 m): stone tools, clothing,
  packs, cloth, shirts/pants, totem, beacon, raft, locks, furniture,
  storage, furnace, range, painting.
- **Forge** (20 stone + 10 wood): iron bars (2 ore + 1 charcoal), iron
  tools/armor, scale armor, lamp.
- **Furnace** (16 stone + 4 wood): attended smelting — load wood, light
  (2 wood/batch), 8 s batch bar, 5 s pull window → 2 charcoal; missed
  window → 1 ash into the tray; keeps burning until off/empty; Esc doesn't
  pause it.
- **Range** (4 iron bars + 10 stone + 2 string): load wood, set 2/5/10,
  unattended perfection (1 wood → 1 charcoal / 4 s), collect from tray.

## Food & health
Hunger drains to empty in ~8 real minutes; empty hunger drains HP; >70
hunger regens HP. Cooked meat 40 hunger/+10 HP, cooked fish 34/+8, berries
15 (and the snakebite antidote), Moonfin 30/+25 raw. Raw things hurt.
Campfire (E) cooks meat and fish.

## Clothing & armor
Slots: head/torso/legs/back. Armor sums, capped 50%. Tiers: fiber (4–8%)
→ cloth shirts/pants (dyed, 4–5%, fashion-first) → hide (8–15%) → iron
(12–22%) → scale (16–30%). Back slot = carry: base 60 items, woven pack
+40, hide pack +90; over-capacity slows you (never blocks). Crafting
auto-equips if strictly better; context-menu **Wear** overrides.

## Inventory
4 hotbar binding slots (keys 1–4; empty = fists). Pack grid 4 wide ×
2 rows (+1 woven, +2 hide pack); items have footprints (branch 1×2,
clothing 2×2) and stack caps (wood/stone 50…). Right-click a stack:
preview, description, Hold / Bind / Drop / Wear. Full pack refuses pickups.
Tab = pack; C = crafting list.

## Building (hammer held)
3 m grid, 2.6 m walls, green/red ghost, scroll = piece, R = rotate,
click = place (costs raw wood), E = repair (1 wood) & doors, X = demolish
(half refund) or salvage. Pieces: foundation (four pillars sunk per-corner
to any ground incl. seabed; aim height sets deck height; neighbors snap
flush), floor, wall, half wall, doorway(+door), window(+shutters), gable,
flat/sloped/hatched roofs, stairs, ladder (press into it to climb),
trapdoor. Totem protects vs decay; anything outside a claim rots
(4 HP/min); a starved totem rots itself.

## Storage, locks, household
Containers (stacks): crate 8, chest 12, drawers 12, cabinet 16. E opens
beside your pack; click stacks to transfer. Locks mount on doors/trapdoors/
containers: need key-on-you + maker or household. Lock HP 200; bashing does
half your tool damage per hit and is heard 120 m. Household: plant a totem
(auto) or E→E at one to join; shares locks + claim.

## Death
Your pack drops into a sack where you fell (worn gear + tools kept).
Empty sacks vanish; unclaimed ones decay. Respawn at your claimed bedroll,
else the beach. In a sealed world there is no respawn.

## Fauna (one verb each)
| Creature | HP | Dmg | Verb |
|---|---|---|---|
| Deer | 40 | – | flees; drops meat×2, hide; half have antlers |
| Wolf | 60 | 10 | night pack hunts (fog: from 38 m); carries the Rusted Key (50%) |
| Boar | 70 | 15 | face-aggro: eye contact ≤14 m → freeze/paw telegraph → charge |
| Bear | 150 | 25 | investigates; stand still 2.5 s and it leaves; straight-line charge, 2.5 s recovery |
| Dweller | 90 | 20 | won't come within 6 m of light (torch/campfire/beacon/lamp/held torch); drops silk |
| Snake | 25 | 6+venom | waits in meadow grass; strikes at 2.4 m; venom 1.3 HP/s ×8 s; berries cure |
| Crow | 15 | – | circles; steals one food item on contact |
| Leviathan | 400 | 30 | circles the wreck; surges at beach-standers; beaches 3.5 s on a miss |

## Quest chains
1. Wreck → Journal → wolf Rusted Key → Ruins chest → Ancient Lens → iron →
   Beacon at the peak → **Leviathan** → scales.
2. Sea Cave (torches, dweller) → moonstone → **Raft** → Far Isle →
   **Monolith** (3 moonstones).
3. Monolith unseals the hatch → **the Depths** (dark hall, dwellers,
   heartstone ×3 via iron pick) → **Heart of the Island** (3 heartstones)
   → permanent peaceful mode + Heart Shard.

## Weather (server-cycled, 2.5–5 min spells)
- Rain: unsheltered torches/campfires gutter (−6 HP/tick), burning douses,
  no new ignition. Roofs shelter (piece above within 1.8 m).
- Storm: heavier, lightning + delayed thunder, sea shoves rafts.
- Fog: thick air, wolf hunt range 25→38 m.

## Fire
Torch/campfire within 2.4 m of wooden pieces: 1.5%/2 s ignition chance;
burning pieces lose HP and can be doused by rain. Torch is throwable
(click beyond reach) and lights the area while held. Lamp never burns
anything and glows from your inventory.

## THE LONG GAME
Arm: at night, E→E on a totem with a moonstone (blocked while peaceful).
- **HARD**: nightly waves per totem: 4 + nights + 2×rounds raiders
  (cap 12/totem), composition by the totem's biome (highland: bears;
  meadow: boars/snakes; forest/shore: wolves). Raiders bite players (7 m
  aggro) and hit structures for 10/1.6 s while marching on the totem.
  Dawn clears survivors and pays everyone.
- **HARDCORE** (after 5 nights, feed again): every night also rolls a
  seeded trial — deposit 20+8r wood / slay all raiders / hold stock ≥
  25+10r at dawn. Pass 7 → **THE END** (permanent peace + trophies).
  Fail → one totem is destroyed. No totems left → **SEALED**: no respawns,
  save preserved forever, menu shows ⳼ SEALED.

## Multiplayer & saves
Host/join by IP (UDP 27455), 8 max, LAN or Tailscale or port-forward.
Everything syncs to late joiners. Worlds autosave per seed every 60 s and
on quit; characters save per seed per machine; profile (identity +
settings) is global, optionally cloud-synced via Firebase. Saves are
version-stamped with forward migration.

## Dev harness
`-- --smoke` = full headless self-test (every system, ALL PASS/FAILURES).
`-- --server --seed=N` = dedicated server. `-- --client=<ip>` = auto-join.
`-- --shot[-menu|-crew|-build|-pack|-fish|-stilt|-storm|-isle|-cave|-raft|-lev|-depths|-wave|-fauna]`
= staged screenshots. `./build.sh` = both platform binaries.
