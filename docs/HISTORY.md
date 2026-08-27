# Maroon — Development Chronicle

*The full build history, version by version. Built August 26–27, 2026 by
mrrzone (Brain Dump Inneractive) with Claude as the implementing partner.
One conversation, ~25 releases of work, feature-complete at v0.22.*

The founding prompt, paraphrased: *"You, are marooned. A combination of
Unturned, Rust and Minecraft. Seed-gen map, animal enemies, multiplayer, no
chat. One constraint: PnPvE, not PvPvE — you can't attack other players.
It's just you, your friends, and the wilderness. And like Minecraft, there
must always be goals."*

---

## v0.1 — The island exists
Godot 4.7, plain GDScript, zero external assets (a rule that never broke).
Seeded island heightmap with radial falloff, first-person controller,
harvesting, crafting (2 tool tiers, spear, campfire, wall, totem),
hunger/health, deer & wolves with day/night AI, claim totem upkeep & decay,
goal-ladder HUD, co-op host/join over ENet, dedicated server flag, and the
PnPvE rule enforced in code: hitting another player prints *"Survivors can't
be harmed. You're in this together."* The `--smoke` headless self-test was
born here and guarded every version after.

## v0.2 — Forage realism + persistence + the Shipwreck
No more punching trees: branches from deadfall, fiber from dry grass, string
twisted by hand → crude axe/pick (branch + 2 stone + string). Iron ore
appeared in the highlands as the next-tier tease. World + character
persistence (autosave per seed). First quest site: the Shipwreck, with
lootable crates.

## v0.3 — The first quest chain + bears & boars
Ender-chain structure: wreck → Captain's Journal → night wolves carry the
Rusted Key (50%) → the Ruins' locked chest → Ancient Lens → mine iron →
Signal Beacon → light it at the island's true peak. Creature philosophy
adopted from the SCAVOCK design doc: real animals, one learnable verb each,
always telegraphed. Bear (investigate phase — stand still and it leaves;
charge is a straight line it can't steer). Boar (face-aggro with a freeze/
paw telegraph). The boar photobombed six consecutive screenshots and was
declared studio mascot.

## v0.4 — The Leviathan
Lighting the beacon summons a sea serpent (head + 7 trailing segments) that
circles the wreck, surges at beach-standers, and beaches itself when it
overcommits (the punish window). 400 HP, bites for 30, drops 5 Leviathan
Scales, permanent per world.

## v0.5 — Forge & the gear ladder
SCAVOCK's material ladder adapted: **Fiber → Hide → Iron → Scale**, one
ladder for tools and armor. Armor = % damage reduction, hard-capped at 50%
("top tier vs unarmoured is 3 hits, not 1"). Clothing slots (head/torso/
legs/back), back = carry capacity, weight slows but never caps. Forge
placeable gates iron recipes by proximity. Gear renders on other players —
no chat, so your look is your name.

## v0.6 — Character creator & identity
Main-menu creator (name, skin ×5, hair color ×6, style, beard) with a live
rotating 3D preview; appearance synced to all peers; names on nameplates.
Firebase email auth + Firestore profile sync scaffolded behind a config file
(Google sign-in later removed by decision).

## v0.7 — The feel pass
All audio synthesized at startup from noise bursts + sine sweeps — zero
audio files, matching the zero-asset art rule. Chops, mining, pickups,
whooshes, footsteps, hurt, eat, craft/goal chimes, dusk wolf-howl, Leviathan
roar, looping sea-wind. First-person viewmodel tools, swing animations
(yours and other players'), hit recoil on animals, damage vignette,
head-bob, sprint FOV.

## v0.8 — The Sea Cave
Second dungeon: a roofed grotto (genuinely dark — the roof blocks the sun)
opposite the wreck, holding iron + the island's only moonstone
(stone-pick-gated). Torches added (branch + 2 fiber). The dweller: will not
approach light; step past your torchline and it comes fast. Drops silk.

## v0.9 — The Mariner tier
The Far Isle: a second island past the reef (own noise field, taller,
denser predators, richer ore). Rafts (20 wood + 4 string + 1 moonstone —
"the stone guides you through the reef"): E in shallows to launch, WASD to
sail, beach to land, visible to all players. The Monolith at the isle's
heart wakes when fed 3 moonstones. GitHub repo + first public release.

## v0.10 — Building system v1
Craft a Hammer, build straight from raw wood on a 3 m grid with a
green/red ghost preview: foundation, floor, wall, half wall, doorway,
window, gable, flat/sloped/hatched roofs, doors that swing into doorways,
shutters into windows. Scroll cycles pieces, R rotates, E repairs, X
demolishes for half refund.

## v0.11 — Grid inventory
mrrzone's call, reversing an earlier no-grid decision: 4 hotbar **binding**
slots (crafts auto-bind; upgrades replace their lesser cousin in place) + a
Tarkov-style pack grid (4×2, packs add rows; sized stacks — branches 1×2;
stack caps). Pickups refuse when full. Held torches light the way and count
as light to dwellers.

## v0.12 — Stations, storage, context menus
Crafting split by station: bare hands make primitives, the Workbench does
carpentry, the Forge does metal. Storage with real synced inventories
(crate/chest/drawers/cabinet) opening beside the pack — click to transfer.
Furnace + charcoal (charcoal became the smelting fuel). Right-click context
menus (preview, description, Hold / Bind / Drop / Wear); placeables became
hold-only, never hotbar. Controls screen. Professional menu rebuilt with
New World / Continue / My Worlds / Join a World / Added Worlds. Underwear
spawn (clothes must be earned). Pause menu. BDIA branding.

## v0.13 — Cloth, dye & light
Chain: grass → string → cloth → dyes (berries=red, fiber=yellow,
charcoal=black) → colored shirts & pants (worn color = dye color).
Paintings (generative, each unique). Iron lamp (no flame, no fire risk,
glows from your pack). Throwable torches. Fire ignition: open flame near
wooden pieces can set them burning.

## v0.14 — A natural world
Coastlines stopped being circles: angle-sampled noise breathes bays,
headlands, inlets; peninsula lobes hang off the rim; three seeded ponds dip
below the water table. Biomes formalized (shore/forest/meadow/highland),
scatter follows them. Three tree species (pine, broadleaf, banded birch),
leaf litter, flowers. Snake (meadow ambush, venom, berries cure) and crow
(steals food off your pack).

## v0.15 — Fishing + hand fixes
Fishing rod (hand-craftable): cast at water, bobber, 1.2 s bite window;
deep water bites faster and rarely yields the Moonfin (+25 HP raw).
Viewmodel per mrrzone's drawings: the arm runs off the screen edge, tools
rest upright, the chop arcs to near-parallel.

## v0.16 — Weather + dense forests
Server-cycled clear/overcast/rain/storm/fog. Rain gutters unsheltered
flames and douses fires; storms add lightning with delayed thunder and
shove rafts at sea; fog extends wolf hunt range 25→38 m. Forests densified
until canopies join.

## v0.17 — Building v2 + presence
Pillar foundations (four logs sunk per-corner to any ground — aim height
sets deck height, neighbors snap flush; stilt houses over water). Stairs,
ladders (press into them to climb), trapdoors. Viewmodel became the big
Minecraft-style corner arm (per reference drawings). Remote heads pitch
with their owner's gaze.

## v0.18 — The Depths & the first ending
The awakened monolith unseals a hatch → threshold-teleport into a great
hall 30 m beneath the Far Isle: dark, dweller-guarded, red veins glowing,
heartstone (iron-gated), and the Heart of the Island. Three heartstones
restore it: **permanent peaceful mode** — no wolf waves, no rot, ☮ in the
clock, Heart Shard trophy.

## v0.19 — THE LONG GAME
The challenge track: feed the totem a moonstone at night (double-E ritual)
and it darkens. HARD: nightly raider waves per totem, composition drawn
from the totem's biome, scaling with nights and totem count; they wreck
structures and march on the totem; dawn pays the living. 5 nights + another
moonstone → HARDCORE: seeded timed trials during the waves. Pass 7 →
THE END (permanent peace + trophies). Fail a trial → a totem crumbles.
Lose the last → **the world SEALS**: no respawns, the save remains forever
as a tomb, the menu lists it ⳼ SEALED. Released as v0.19.0.

## v0.20 — Death, locks & the household
Death drops your whole pack into a lootable sack where you fell (corpse
runs; empty sacks vanish, unclaimed ones rot). Locks & keys forged as a
bound pair; mount on doors/trapdoors/storage; key-on-you + right name to
open; copies craftable from either half; brute force always possible —
slow, and heard 120 m away. The household: plant a totem and you're family,
E to swear in; members share locks, claim, works. Rounded app icon.

## v0.21 — Everything but the bugs
Settings menu (volume/sensitivity/FOV/invert-Y/fullscreen), synthesized
Am–F–C–G menu theme, bedrolls (claim your respawn), fullscreen default +
F11, macOS ad-hoc signing + "damaged" fix documented, website refreshed
and live at maroongame.web.app.

## v0.22 — Feature complete
Furnace attention economy (watch the bar, pull each batch in a 5 s window
or it's ash; Esc is an exit, not a pause) vs the Range (iron-tier: set an
amount, walk away, perfection). Furniture (chair, table, couch,
self-colored vases and rugs). Salvage (X returns placeables whole).
Save versioning + migration shims. Released v0.22.0.

## v0.22.1 — Know your beast
Playtest-driven readability patch: all seven creatures rebuilt as
species-true box-rigs (wolves pointed, bears humped, boars maned and
tusked, deer antlered, crows flapping, everything walking on real legs),
and held tools made clearly visible on other players (raised arm, bigger
models, always synced).

---

**Where it stands**: feature-complete toward 1.0. Remaining: balance
playtests (Long Game numbers are first-guess), bug fixing, and the Steam
checklist. M2 (working title CRIMSON) waits until Maroon 1.0 ships.
