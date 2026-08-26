# MAROON — Design Document

**Pitch:** Unturned × Rust × Minecraft, minus the toxicity. You and your friends are
marooned on a procedurally generated island. The wilderness is the only enemy.

## The Two Pillars

### 1. PnPvE (Players 'n' Players vs Environment)
You *cannot* attack other players. Not "it's discouraged" — the damage code refuses it.
No friendly fire, no raiding, no chat (so no toxicity, no slurs, no drama). You
communicate the old way: by pointing, jumping, building an arrow out of walls.
Every stranger is a potential ally, never a threat.

### 2. The Goal Ladder
The thing that keeps Minecraft fun alone or with two friends: there is *always a
next goal*. Rust and Unturned go flat once you're geared. Maroon has an explicit,
visible ladder (shown top-right on the HUD), and the world pushes back so your
progress needs *defending* (the Claim Totem, night raids by wolves).

## Progression Ladder

| Tier | Goals | Unlocks |
|------|-------|---------|
| 0 — Castaway | Forage: branches from deadfall, fiber from dry grass, loose stones. Twist string. | Crude tools (branch + stone + string) |
| 1 — Survivor | Crude axe/pick → chop wood, mine boulders. Stone tools, campfire, cook meat | Real damage, real food |
| 2 — Settler | Claim Totem, walls, keep the totem fed | A home that persists |
| 3 — Hunter | Kill night wolves, loot the shipwreck, survive to Day 3 | Confidence + supplies |
| 4 — Smith *(iron in-game; forge planned)* | Mine iron ore in the highlands with a stone pick, build a forge | Metal tools, armor, clothing tier |
| 5 — Mariner *(planned)* | Build a raft, reach the neighbor islands (each seed generates an archipelago; outer islands are harder + richer) | Rare materials |
| 6 — Depths *(planned)* | Sea cave dungeon under the far island, "the Leviathan" boss | Trophy + endgame gear |
| ∞ — Homestead | Farming, animal taming, lighthouse megabuilds | The "just one more day" loop |

## Realistic gathering (no punching trees)
Bare hands can only *forage*: pick up fallen branches, pull fiber from dry grass,
grab loose surface stones, pick berries. Two fiber twist into string; a branch,
two stones and string make a crude axe or pick. Only then can you fell a tree or
crack a boulder. Iron ore needs a stone pick. Forage respawns over time.
Mining stays a first-class loop (the fun Minecraft keeps): boulders → highlands
ore → (next) deep cave veins under the island.

## Quest loops (the "eye of ender" structure)
Minecraft's endgame works because it is a *chain*: each step's reward is the next
step's key, and each step uses a different verb (fight, explore, craft, travel).
Maroon's first chain is in-game:

**Shipwreck** (explore the coast) → **Captain's Journal** (lore reveals the next
link) → **hunt night wolves** for the **Rusted Key** (50% drop) → **the Ruins**
inland, unlock the chest → **Ancient Lens** → **mine iron** with a stone pick
(tool gate) → craft the **Signal Beacon** (lens + iron + wood + string) →
**light it at the island's peak** (geography gate) → *"something answers beyond
the reef"* — the summoning hook for the Leviathan.

Design rule (borrowed from a fellow design doc): **quests point at the game you
want played.** Every link pulls the player into a system — exploring, night
combat, mining, climbing — never "kill 20 of X."

Quest sites, seed-placed:
1. **The Shipwreck** *(in-game)* — beached on the coast; crates + the journal.
2. **The Ruins** *(in-game)* — a collapsed homestead inland; the locked chest.
3. **The Peak** *(in-game)* — the island's highest point; where the beacon burns.
4. **The Sea Cave** *(in-game)* — a roofed grotto beneath the far cliffs,
   opposite the wreck. Genuinely dark inside (the roof blocks the sun). Holds
   iron and the island's only **moonstone** — guarded by **dwellers** that
   torchlight alone keeps back. The moonstone is the next chain's key.
5. **The Leviathan** *(in-game)* — answers the beacon and circles beyond the
   reef at the wreck. Its verb: it surges at anyone on the beach in a straight,
   committed lunge — dodge it and it beaches itself for 3.5 s (the punish
   window). 400 HP, bites for 30. Drops 5 Leviathan Scales — Maroon's "dragon
   egg," and the material for scale armor (next).

## Creature roster
Grounded — every threat is a real animal with one learnable verb, and every
learned mechanic **telegraphs** before it punishes:

| Creature | Verb | Notes |
|---|---|---|
| **Deer** | Flees | Food on legs. |
| **Wolf** | Pack-hunts at night | Carries the Rusted Key (quest drop). |
| **Bear** *(in-game)* | Two-phase | Investigates first — **stand still and it loses interest** (real bear-safety advice, no tutorial needed). Its charge is a dead-straight line it cannot steer: juke it, punish the 2.5 s recovery. Highlands only. |
| **Boar** *(in-game)* | Face-aggro | Eye contact within 14 m: it freezes, paws the ground (the telegraph), then charges. Avert your gaze and walk by. |
| **Snake** *(planned)* | Ambush + poison | Tall grass; antidote from berries at a campfire. |
| **Crow flock** *(planned)* | Steals | Swarms unattended food/camps; cheap instanced threat. |
| **Dweller** *(in-game)* | Fears light | Six legs, four pale eyes, haunts the Sea Cave. Will not approach within 6 m of a burning torch/campfire/beacon — and won't touch a player standing in the glow. Drops silk (string). |
| **The Leviathan** *(in-game)* | Boss: surge & beach | Summoned by the beacon; fought from the shore at the wreck. |

## Clothing & gear (in-game)
Unturned/Rust-style: what you wear is what you get. Slot format and material
ladder borrowed from the SCAVOCK design doc, adapted to a wilderness island.

- **Slots (4):** head, torso, legs, back. (SCAVOCK runs 8; four is enough until
  glasses/shoes have mechanics to hook onto.)
- **Material ladder (gradual slope, never exponential):**
  **Fiber → Hide → Iron → Scale.** Same ladder colors tools and armor; a player
  learns one progression. Fiber is woven from grass; hide is skinned from
  kills (deer 1, wolf 1, boar 2, bear 3); iron is smelted at a forge; scale
  comes only from the Leviathan.
- **Armor is % damage reduction**, summed across worn pieces, **capped at 50%**
  — the SCAVOCK rule that top gear means 3 hits instead of 6, never immunity.
  Skill (dodging the surge, juking the bear) beats gear, always.
- **Back slot = carry capacity.** Weight slows you (never a hard cap — SCAVOCK's
  "weight answers *how fast*, not *how much*"): past your carry limit, speed
  drops toward 70%. Packs raise the limit.
- **Auto-equip:** crafting a piece equips it if it beats what you wear. No
  paper-doll UI yet — the crafting menu is the wardrobe.
- **Identity:** gear renders on your body for other players — torso tier tints
  you, hats and packs are visible boxes. Since there's no chat, your look *is*
  your name. Berry dyes + face variation planned.
- **Durability/repair** *(planned)* — wear from bites and labor, repaired with
  string at a campfire.

## The Forge (in-game)
Placeable (20 stone + 10 wood), glowing ember + chimney. Iron recipes require
standing within 6 m of one: iron bars (2 ore + 2 wood), iron axe/pick (tier-3
harvest), iron spear (45 dmg), iron & scale armor. The forge is the village
heart SCAVOCK's workbenches are — a reason bases exist beyond walls.

## Inventory format — decision note
SCAVOCK uses a Tarkov grid (spatial tradeoff). Maroon deliberately does not:
grids create loot anxiety, and Maroon is the cozy half of the genre. We keep
list inventory + weight-based speed. If a capacity pressure is ever needed,
it comes from weight tuning, not grid cells.

## Art direction — box-rig, Unturned-style (decision)
Adopted from SCAVOCK's single best derisking call: **no sculpted meshes, no
skinned deformation, no vertex painting.** All art is rigid primitives.

**Style rule that keeps it from reading "Minecraft": flat solid colors, never
pixel textures.** The voxel look comes from pixelated texturing, not from box
geometry — untextured flat-color boxes on smooth terrain read as *Unturned*,
which is exactly Maroon's register. If a texture is ever tempting, use a
second colored box instead.

- **Characters:** Unturned-style box-rig, in-game. The three reference registers:
  Minecraft = pixel-textured cubes, Rust = sculpted realism, Unturned = clean
  untextured geometry *with character*. Maroon sits firmly on Unturned:
  - **Tapered segments**, not rectangles — torso narrows at the waist, sleeves
    taper to the wrist, legs to the ankle (procedural tapered-box meshes).
  - **Geometric face**: eye and mouth boxes proud of the head — never a texture.
  - **Deterministic identity** per survivor id: skin tone (5), hair color (6),
    hair cap + back panel, 1-in-3 beard, shirt/pants hues. Your body is rolled
    by the world, your gear is earned — both readable at a glance.
  - Hands and boots as separate skin/leather boxes; walk cycle keyframed in
    code from movement speed; hats replace hair (crown + brim), packs bolt on.
  Animals follow the same path (primitive assemblies + bolt-on parts).
- **Items/tools/structures:** primitive assemblies with flat materials (the
  current style — the forge is three boxes and an emissive ember).
- **Variety is cheap:** a new animal is a retint + one bolt-on box (the boar is
  the wolf plus tusks); mutations/gear are parented boxes.
- **No GLB imports, no art pipeline, no artist bottleneck.** If Maroon ever
  gets real models, they replace visuals only — gameplay never references mesh
  shape, only collision capsules.

## The Claim Totem (tools-cupboard analog, PvE-flavored)
- Placing a totem claims a 20 m radius.
- The totem **consumes wood** from its stock over time.
- Structures inside a *fed* claim never decay. Structures outside (or in a starved
  claim) rot away. The island reclaims what you don't maintain.
- Deposit wood with **E**. The floating label shows remaining stock.
- This is the "protect your world" pressure: log in, feed the totem, patch the walls
  the wolves chewed on.

## World
- **Seed-generated island**: enter any seed at the menu (blank = random). Same seed =
  same island for everyone; the host's seed is sent to joiners automatically.
- Radial-falloff heightmap island: sand beaches → grass interior → rocky highlands,
  surrounded by shallow sea.
- Scattered trees, boulders, berry bushes (bushes regrow).
- **Day/night cycle** (12 real minutes). Wolves are passive-ish by day, hunt you at
  night, and more arrive each night.

## Multiplayer
- Host & join over LAN/IP (ENet, port 27455). Dedicated server: `--server --seed=N`.
- Server-authoritative world state (resources, animals, structures, time).
- No text chat, no voice, no names beyond a small ID tag. By design.

## The Long Game — mode arc (designed, not yet built)
The game's shape: Minecraft never ends, Rust never rests. Maroon does both —
**you earn the cozy game by beating the brutal one.** Target: 10–20 hours to
beat for a big group, then peaceful forever (realistically 30+ total).

**STORY → HARD → HARDCORE → THE END → PEACEFUL**

- **Story** *(confirmed, current game)* — the 30-goal ladder, both chains.
- **Hard mode** *(confirmed)* — armed deliberately: **feed the totem a
  moonstone at night; it drinks the light and darkens.** A group-consent
  ritual, not an accidental trigger *(recommended over auto-start at goal 30)*.
  Every night the totem calls **enemy waves** that assault the claim — they
  target walls and the totem itself, scaling each night. Between waves:
  **seed-generated goals** (gather quotas before dawn, keep stock above X,
  slay all raiders) with loot-crate rewards at the totem. Wave composition
  draws from the **biome the totem stands in** — where you built, hours ago,
  becomes strategy.
- **Hardcore** *(confirmed)* — seed-generated goal gauntlet on **timers**,
  fought while waves continue. Rewards are large: the loot from each round is
  what survives the next. *(Recommended failure rule: a failed goal destroys
  ONE totem; game over only when the last totem falls — so extra totems are
  harder waves in hard mode but extra lives in hardcore. The one-fail-and-out
  variant stays as an optional "Iron" toggle.)*
- **Game over** *(confirmed)* — you do not lose the base; **you lose the way
  back in.** The world save remains forever, sealed. A tomb with your name on
  it. New respawns refused; the group's run is over.
- **The End** *(confirmed)* — survive the full gauntlet and the game is
  *beaten*. Victory is recorded in the save and announced to everyone.
- **Peaceful** *(confirmed)* — the reward state: no waves, no decay, hostiles
  scarce. Harvest, build, sprawl. New material: **brick** (shore clay, fired
  at the forge). Occasional *optional* seeded events and goals so there's
  always a reason to gather tomorrow. Multiple totems now cost nothing —
  claim the whole island. It's yours. You paid for it.

**Open:** exact wave sizes/night curves and round counts (tuned only through
playtests — 10–20 h is the target, numbers are servants of that); whether a
sealed world can be reopened as a fresh-seed "pilgrimage" (read-only visit).

## Biomes (designed, next build pass)
Formalize the zones that already exist and give each a resident threat:
| Biome | Where | Signature | Resident enemy |
|---|---|---|---|
| Shore | coast ring | forage, clay *(new)* | **Crow flock** — steals unattended camp items |
| Forest | mid elevation | wood, deadfall, deer/boar | wolves at night |
| Dry Meadow | grass patches | fiber | **Snake** — ambush + venom (antidote: berries at campfire) |
| Highlands | h > 10 | iron, moonstone, bears | bear |
| The Dark | sea cave (+ future depths) | moonstone | dweller |
| Far Isle | past the reef | everything, denser | all of the above, hungrier |
Hard-mode waves are drawn from the totem's biome: build on the shore, fight
crows and wolves; build in the highlands, bears come. Location = loadout.

## Deliberate non-goals — and the two-game decision (locked)
- **No PvP, ever. This is now permanent.** The PvPvE itch — third-party
  convergence, clutch turns, RPG raids, heli snipes — is real and worth
  chasing, but it structurally requires strangers, big servers, and
  server-authoritative netcode. It gets its own game: **M2** (working title) —
  MMO-scale (Rust-scale: ~100–300/server) PvPvE, advanced tech ladder,
  vehicles and firearms, likely absorbing the best of the SCAVOCK design doc
  (box-rig, server authority from day one, playtime gating, noise/stealth).
  M2 gets its own repo and design doc when it starts. Maroon answers every
  future "what about PvP?" with one word: *M2.*
  **M2 adopts from SCAVOCK wholesale where it fits**: the combat doc (per-weapon
  blocking windows, aggressive/defensive/technical triangle, long TTK as the
  social layer's foundation, probabilistic weight-scaled stagger), noise &
  stealth, reinforcement/armor damage-pool model, equip layers — then extends
  the tech ladder past SCAVOCK's no-guns rule: firearms, rocket launchers,
  helicopters, Rust-style. SCAVOCK's TTK logic gets re-derived for guns.

## Road to 1.0
What "fully fledged" means for Maroon, beyond bug fixing. Ordered — each line
is roughly one release. The Long Game arc is the 1.0 centerpiece: 1.0 ships
when a group can play story → hard → hardcore → the End → peaceful, start to
finish, and it holds 10–20 hours.

**Content & systems (the playtest queue below, then):**
- 0.11 Grid inventory (4 hotbar + Tarkov grid, item icons)
- 0.12 Storage & stations (chest/crate/cabinet/drawers, furnace + charcoal,
  workbench) — chests need the grid, so it comes second
- 0.13 Cloth & dye chain + lighting overhaul (held/thrown torches, fire
  spread, iron lamp)
- 0.14 Environment depth + biomes formalized + snake & crow
- 0.15 **Fishing** — an island survival game without fishing is missing a
  limb: rod (branch+string), shore vs deep (raft) catches, cooking
- 0.16 **Weather** — rain (fires gutter, visibility drops), storms at sea
  (sailing risk), fog nights (wolves closer than they sound); pure atmosphere
  until hard mode weaponizes it
- 0.17 **Chain #3: the Depths** — the awakened monolith opens the descent;
  underground biome, the last ore, ties into the Long Game's End
- 0.18–0.19 **The Long Game** — hard mode waves, hardcore gauntlet, game
  over (sealed worlds), the End, peaceful mode + brick; farming & taming
  land here as peaceful-mode systems (the ∞ tier)
- 0.20+ Balance campaign: scripted bot runs + real group playtests until the
  10–20 h target holds

**Product completeness (not content, still required for 1.0):**
- Settings menu: audio sliders, mouse sensitivity, invert Y, FOV,
  fullscreen/windowed, keybind remapping
- Menu/ambient music + per-biome ambience (same procedural approach or
  hand-made later)
- Death rules decided and final (currently: keep inventory, respawn on
  beach — too soft for hard mode; beds/bedrolls as spawn points)
- Save versioning + migration (old worlds must survive updates)
- Network resilience: rejoin-in-progress polish, graceful host-quit for
  clients, error messages a human can read
- Onboarding: the first 10 minutes watched over a stranger's shoulder,
  goals-as-tutorial sharpened
- Accessibility: text scale, colorblind-safe tier colors, hold-vs-toggle
  sprint
- Performance pass at 8 players + a fully built base

**Steam (the hope, and the checklist):** Steamworks account ($100 one-time
per game), store page live ≥2 weeks before launch, capsule art + trailer +
6 screenshots, achievements (the goal ladder maps 1:1), cloud saves, Steam
networking as an optional transport (fixes port-forwarding for good), review
build. Maroon's pitch on the page: *"the co-op survival island where you
cannot hurt each other — and the game can be beaten."* M2 follows once
Maroon 1.0 is out and earning lessons.

## Playtest queue (from mrrzone's first sessions)
Big systems, in build order, each its own pass:
1. **Building system** — ghost preview, snapping, foundation/floor/wall/
   doorway/door/window/stairs/roof, wood→stone→brick, hammer (approved scope,
   awaiting go).
2. **Grid inventory** — 4 hotbar slots + Tarkov-style grid (start 2×4, packs
   expand it), multi-cell rotatable items with icons. Supersedes the earlier
   "no grid" note — mrrzone's call after playtesting.
3. **Cloth & dye chain** — dead grass → string → cloth → berry/flower dyes →
   colored clothing; crafted shirts/pants as the *only* way to be dressed.
4. **Environment depth** — broadleaf + birch trees, fallen-leaf litter, twigs,
   varied rocks, ponds/streams, richer ground cover. Realism is the bar.
5. **Advanced crafting stations** — **furnace** (burns wood → charcoal;
   charcoal keeps fires fed and smelts iron better), **workbench** (gates
   higher recipes). Forge stays the metalworking station.
6. **Storage & decor** — storage as placeables with real inventories:
   **chest** (proper-looking), **crate**, **cabinet**, **drawers**; decor
   starting with **paintings** (player-pickable art?), rugs, trophies
   (Leviathan head over the door).
7. **Lighting overhaul** — **torch**: holdable (lights around you while held),
   placeable on floor OR wall, **throwable**, but open flame: chance to set
   structures/grass/you on fire (campfires too — fire spread as a system).
   **Iron lamp**: costs iron, can't be thrown, zero fire risk, and lights
   around you passively *while merely in your inventory*. Safety is what the
   iron buys.
- Maroon stays: PnPvE, 5–8 friends, tech ceiling at iron/scale (never a gun),
  beatable, then peaceful. No raiding of claims. No chat/comms of any kind.
- **Why no chat (decided):** Maroon groups are 1–8 people who already have a
  group chat or a voice call — building comms would duplicate what every small
  group brings with it. **M2 is the opposite case:** 50+ strangers can't share
  a Discord call, so M2 needs **proximity voice + global chat + area chat +
  group chat** — groups being small formal bands, which is also what disables
  accidental friendly fire inside them.
- No wipes — worlds are meant to be kept.

## v0.12a status (this repo)
Added in v0.12a — inventory & crafting depth: **right-click context menus** on
pack stacks (preview swatch, name, description, Hold / Bind to hotbar / Drop);
**Hold** carries anything temporarily without binding (placeables are hold-only
now — they never sit on the hotbar); **crafting split by station** — bare hands
make only the primitives (string, crude tools, torch, campfire, hammer,
workbench), the new **Workbench** placeable unlocks real carpentry (stone
tools, clothing, totem, beacon, raft), the forge keeps metal. C toggles the
crafting list. **Controls** screen in the main menu. Rebuilt first-person arm
(forearm + fist, tools gripped through the hand). Compact styled HUD status.

## v0.11 status
Added in v0.11 — **the grid inventory**: 4 hotbar **binding** slots (keys 1–4;
crafts auto-bind; upgrades replace their lesser tool in place) + a Tarkov-style
pack grid (4 × 2 cells, +1 row woven pack, +2 hide pack; stacks with per-item
sizes and stack caps; branches are 1×2). Tab opens the pack + crafting screen:
click-to-move stacks, bind items to hotbar, DROP to discard, overflow shown in
red. Pickups now refuse when the pack is full. **Held torches light the area**
(first slice of the lighting overhaul) and count as light for dwellers —
first-person flame viewmodel + visible in others' hands. Hotbar honesty kept:
counts shown, missing items dimmed. Layout + bindings persist per seed.

## v0.10 status
Added in v0.10 — **the building system**: craft a **Hammer**, select the build
slot (7), and build straight from raw wood. 12 pieces on a 3 m grid —
foundation (snaps to terrain, extends edge-to-edge), wall, half wall, doorway,
window wall, gable, floor, flat roof, sloped roof, hatched roof, **doors**
(snap into doorways, swing open on E), **shutters** (snap into windows).
Ghost preview (green/red validity + cost check), scroll to cycle pieces,
R rotates, E repairs (1 wood), X demolishes (half refund). Old freestanding
wall placeable retired. Also: playtest queue notes for furnace/charcoal,
workbench, storage units, decor, and the torch/lamp lighting overhaul.

## v0.9 status
**Shippable**: `build.sh` exports Maroon-macOS.zip (universal) and
Maroon-Windows.exe (single file, embedded pack) — unsigned testing builds.

Added in v0.9 — the Mariner tier: **the Far Isle**, a second seed-generated
island ~190 m past the reef (smaller, taller, denser predators — 2 bears,
3 wolves, a boar — and far richer iron + moonstone); **rafts** (20 wood +
4 string + 1 moonstone — "the stone guides you through the reef"): E in the
shallows to launch, WASD to sail, beach on any shallows, raft visible to all
players; **the Monolith** at the Far Isle's heart — feed it 3 moonstones and
it wakes, burning blue across the water (chain #2 complete, chain #3 teased:
"what sleeps beneath the stone"). 30-goal ladder; monolith state persists.

## v0.8 status
Added in v0.8: **the Sea Cave** — a dark roofed grotto opposite the wreck with
iron + 3 moonstone nodes (stone-pick gated); **torches** (branch + 2 fiber,
placeable light, hotbar slot 10/key 0); **dwellers** (light-fearing cave
guardians that drop silk); cave-discovery event + 3 new goals (27 total); the
moonstone ends the ladder as the next chain's hook.

## v0.7 status
Added in v0.7 — the feel pass: **procedural audio** (every sound synthesized
from noise bursts + sine sweeps at startup, zero audio files: chops, mining,
pickups, whooshes, footsteps, hurt, eat, craft chime, goal chime, structure
thuds, dusk wolf-howl, Leviathan roar, looping sea-wind ambient);
**first-person viewmodel** (box-built held tool per tier that swings on
attack); **remote swing animation** (other survivors' arms arc when they
swing, audible); **hit feedback** (animals recoil-pulse for everyone, camera
kick on impact, red damage-flash overlay); **head bob + footsteps + sprint
FOV kick**. Google sign-in removed — email auth only.

## v0.6 status
Added in v0.6: **character creator + identity** — main-menu editor (name, skin,
hair color, hair style short/long/bald, beard, shirt) with a live rotating 3D
preview; appearance stored in user://profile.json, applied to your rig in-game,
synced to all peers, and shown on nameplates. **Firebase scaffold**: email/
password auth via REST (drop api_key + project_id into firebase_config.json),
profile sync to Firestore users/{uid}. Everything works fully offline without
config. (Google sign-in considered and dropped — email only.)

## v0.5 status
Added in v0.5: **the Forge and the gear ladder** — Fiber → Hide → Iron → Scale
clothing across 4 slots with %-armor (capped 50%) and carry weight that slows
overloaded players; hide drops from all kills; forge-gated iron smelting and
iron tools (tier-3 axe/pick, 45-dmg spear); scale armor from Leviathan scales;
gear visible on other players (tier tint + hat + pack); auto-equip on craft;
2-column tier-colored crafting menu; 24-step goal ladder; equipment persists.

## v0.4 status
Added in v0.4: **the Leviathan boss fight** — lighting the beacon at the peak
summons a sea serpent (head + 7 trailing segments, server-driven, synced to all
peers) that circles the wreck, surges at players on the beach, and beaches
itself when it overcommits. Slaying it grants Leviathan Scales, completes the
18-step ladder, and is permanent per world (persisted; a still-burning beacon
re-summons a living one on load, a slain one stays slain).

## v0.3 status
Added in v0.3: the full first **quest chain** (shipwreck journal → wolf key →
Ruins chest → Ancient Lens → Signal Beacon at the peak), the **Ruins** site,
**bears** (two-phase investigate/charge AI) and **boars** (telegraphed
face-aggro), kind-specific meat drops, a 17-step goal ladder ending on the
Leviathan hook, and quest-state persistence.

## v0.2 status
Implemented: seeded island gen, FPS controller, realistic forage chain
(branch/fiber/string → crude tools), chopping/mining with tool gating, iron ore in
the highlands, crafting (crude + stone tiers, spear, campfire, wall, totem),
hunger/health, deer & wolves with day/night AI, claim totem upkeep & decay,
the Shipwreck quest site, 13-step goal ladder HUD, co-op host/join, dedicated
server flag, and **persistence** — host the same seed again and your world (day,
structures, totem stock, harvested nodes, looted crates) plus your character
(inventory, tools, progress) come back. Autosaves every 60 s and on window close.
Next up: forge + iron tier, clothing/armor system, Sea Cave, rafts + archipelago,
sounds & art pass.
