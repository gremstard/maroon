# Maroon — Decision Log

*Every significant call made during development, with its reasoning. ADR
style, so future-us (and M2) never re-litigates settled questions without
knowing why they were settled.*

## D1 — PnPvE, permanently (the founding pillar)
Players can never harm players — enforced in code, not etiquette. The rule
IS the pitch: "the co-op survival island where you cannot hurt each other."
Combined with D2, this is the game's identity. Revisited once (see D8) and
locked forever.

## D2 — Always a next goal
Minecraft stays fun alone because there is always a ladder (armor → nether
→ end). Maroon's goal ladder (34 steps by feature-complete) plus quest
chains plus the Long Game give every session a "next thing," and the game
can actually be *beaten* — the rarest feature in the genre.

## D3 — Zero external assets, forever
No imported models, textures, or audio. Everything is procedural: box-rig
characters and fauna, primitive-assembled structures, synthesized SFX and
music, generated icons and emblems. Adopted from SCAVOCK's derisking logic:
art production is a specialist bottleneck; code is not. Consequence: one
person + AI can build and maintain the whole game.

## D4 — Box-rig ≠ Minecraft (the style law)
The "Minecraft look" comes from pixel textures, not box geometry. Untextured
flat-color boxes on smooth terrain read as *Unturned*. Law: never
pixel-texture anything; if a texture is tempting, use another colored box.
Refined by mrrzone's reference drawings: big corner arm with the tip up,
tools resting upright, chops arcing to parallel, slight tapers/skews so
nothing reads machine-cut.

## D5 — Trust-based netcode, because friends
Clients report their own inventory, movement, and hits; the server is a
relay + world authority. This is only sane because of D1: private servers
of 2–8 friends have no cheating incentive. Explicitly NOT reusable for M2
(which needs server authority from line one).

## D6 — No chat or voice, ever (Maroon)
1–8 friends already have a group chat or a call; building comms would
duplicate it. Side effect turned feature: your appearance/gear IS your
identity ("your look is your name"). M2 inverts this (see M2 notes).

## D7 — Creature design: one learnable verb, always telegraphed
Every animal has exactly one rule (bear: stand still / juke the straight
charge; boar: don't meet its eyes; dweller: light is safety; snake: watch
the grass; crow: guard your lunch; Leviathan: dodge the surge, punish the
beaching). Learned mechanics must telegraph before they punish (the boar
paws the ground). Borrowed from SCAVOCK's roster philosophy.

## D8 — The two-game split (PvPvE goes to M2)
mrrzone proposed flipping to PvPvE for the "crazy moments." Resolution:
those moments require strangers, big servers, and authoritative netcode —
none of which Maroon has or wants. Decision: Maroon stays PnPvE forever;
a second game (M2) gets MMO-scale PvPvE, guns, vehicles. Every future
"what about PvP?" is answered with one word: M2.

## D9 — The Long Game arc (the shape of the whole game)
STORY → HARD → HARDCORE → THE END → PEACEFUL. You earn the cozy game by
beating the brutal one. Key sub-decisions:
- Arming is a *ritual* (feed the totem a moonstone at night, confirm
  press), never an automatic trigger — group consent by ceremony.
- A failed hardcore trial destroys ONE totem; game over only when the last
  falls (softening mrrzone's fail-once-die proposal into a totem-count
  tradeoff: more totems = harder waves but more lives).
- Game over = the world SEALS: you don't lose the base, you lose the way
  back in. The save survives forever as a tomb. Stakes without vandalism.
- Two endings coexist: the Heart (kind) and the gauntlet (earned).

## D10 — Attention as a cost axis (torch/lamp, furnace/range)
A recurring economy law: the cheap option demands your presence and carries
risk (torch: fire hazard, must be held/placed; furnace: watch the bar, pull
the batch or it's ash — Esc is an exit, not a pause); iron buys the version
that works without you (lamp: safe, glows from your pack; range: set an
amount, walk away, perfection).

## D11 — Grid inventory (a reversal, by playtest)
Initially rejected ("grids create loot anxiety; Maroon is the cozy half"),
then adopted at mrrzone's explicit request after play: 4 binding-slot
hotbar + Tarkov-style pack. Recorded as an overridden decision — playtest
evidence beats prior reasoning.

## D12 — Hotbar slots are bindings, not containers
Slots reference items by name; counts live in the inventory. Crafts
auto-bind to a free slot; upgraded tools replace their lesser cousin in
place. Placeables are hold-only (right-click → Hold), never bound.

## D13 — The Depths is a threshold, not a tunnel
Heightmap terrain cannot be dug. Rather than fake or fight it, the descent
is a doorway: the unsealed hatch teleports you into a hall built 30 m below
the Far Isle. Classic dungeon-zone logic; nobody has ever minded.

## D14 — Locks: possession + name, brute force always
One recipe forges lock+key as a bound pair. Opening needs the key
physically on you AND the maker's name (or shared household). Copies craft
from either surviving half; owners can salvage a lock to recover its key.
Brute force is never blocked — just slow (200 lock HP, damage halved) and
LOUD (heard 120 m). The household (join at the totem) is the sharing unit.

## D15 — Death drops everything, bedrolls answer it
Dying spills your whole pack into a lootable sack where you fell (worn
gear and learned tools stay). Empty sacks vanish; unclaimed ones rot on the
world-decay clock (~natural recovery window). Bedrolls set your respawn.
Adopted at mrrzone's direction; gives the Long Game and the Depths teeth.

## D16 — Attribution & identity
Creator: mrrzone. Studio: Brain Dump Inneractive (BDIA), braindumpia.web.app.
Site: maroongame.web.app (Firebase Hosting; downloads track the GitHub
*latest* release so new releases need no site redeploy). Real-name mentions
scrubbed from current files (old git history still contains them; a
history rewrite was offered and not taken).

## D17 — Saves are sacred
No wipes, ever (sealed worlds persist as tombs). Save versioning with
migration shims from v0.22: every world/character/profile is format-stamped
and migrates forward; newer-than-us saves warn and load best-effort.

## D18 — Ship constantly
Every feature pass ends with: smoke test (headless self-check of every
system), multiplayer regression (server+client, zero script errors),
staged screenshot, commit, push. Releases at milestones with binaries for
both platforms; ad-hoc signed on macOS ("damaged" fix documented). The
smoke test caught real bugs constantly — including the test player starving
to death mid-test and dropping a surprise death-pack, twice.

## D19 — M2's name (recommended, not yet locked)
Recommendation: **CRIMSON** — the color family tells the story (Maroon's
blood-red sibling: bigger, armed, PvPvE). Shortlist: Breakwater, Undertow,
Landfall (name-collision risk), or Scavock if M2 absorbs that doc wholesale.
Decision pending mrrzone.
