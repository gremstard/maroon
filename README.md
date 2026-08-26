# MAROON
*by — **Brain Dump Inneractive** (BDIA)*

You're marooned. It's you, your friends, and the wilderness — never each other.
A PnPvE survival game (Unturned × Rust × Minecraft, minus the toxicity).
See [DESIGN.md](DESIGN.md) for the full vision.

## Play

Open the folder in **Godot 4.7+** and press Play, or from a terminal:

```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

- **Host Island** — enter a seed (or leave blank) and play. Friends join via your IP.
- **Join Friend** — enter the host's IP (same network, or port-forward 27455).

### Controls
| Key | Action |
|-----|--------|
| WASD / Space / Shift | Move / jump / sprint |
| Mouse + Left click | Look / swing tool, place item, eat |
| 1–8 | Hotbar: hand, axe, pick, spear, food, campfire, wall, totem |
| E | Interact — cook at campfire, feed wood to totem |
| Tab | Crafting menu |
| Esc | Release / capture mouse |

### Sharing the game (builds)
Run `./build.sh` to produce distributable binaries in `build/`:
- **Maroon-macOS.zip** — unzip, then **right-click → Open** the first time
  (the app is unsigned, so double-clicking gets blocked by Gatekeeper).
- **Maroon-Windows.exe** — single file, everything embedded. SmartScreen may
  warn on first run (unsigned): "More info → Run anyway".

Playing together: the host picks **Host Island** and shares their IP; friends
enter it and **Join Friend**. Same network = use the LAN IP. Over the internet,
the host forwards **UDP port 27455** on their router (or use Tailscale/ZeroTier
and share that IP — zero router setup).

Requires the Godot 4.7.1 export templates (installed once; `build.sh` has the
path if you ever need to reinstall them).

### Your survivor
The main menu has a character creator: name, skin tone, hair color & style,
beard, shirt — shown live on a rotating preview. Your identity is stored in
`user://profile.json`, follows you into every world, and is what other players
see over your head and on your body.

### Cloud accounts (optional, Firebase)
Offline profiles work out of the box. To enable accounts:
1. Create a Firebase project (console.firebase.google.com) → enable
   **Authentication → Email/Password** and **Firestore**.
2. Put a file at `user://firebase_config.json` (macOS:
   `~/Library/Application Support/Godot/app_userdata/Maroon/`):
   ```json
   {"api_key": "<Web API key>", "project_id": "<project id>"}
   ```
3. The menu now shows Sign In / Register. Your name + appearance sync to
   Firestore (`users/{uid}`) and restore on any machine you sign into.

### How to survive
No punching trees here. Forage first: **fallen branches**, **fiber** from dry
grass, **loose stones** off the ground (click or E). Twist fiber into string,
then craft a **Crude Axe** (branch + 2 stone + string) to chop wood and a
**Crude Pick** to mine boulders. Campfire + hunted deer = cooked meat. Build a
**Claim Totem** and keep it fed with wood or your buildings rot. Wolves hunt at
night, and more come every night. Somewhere on the coast lies the **shipwreck**
you washed up from — its crates are worth finding, and the captain's journal
starts a chain that ends with a **Signal Beacon** burning on the island's peak…
and something answering from beyond the reef. Fight the **Leviathan** from the
beach: dodge its surge and punish it while it's beached. Watch for **bears** in
the highlands (stand perfectly still) and don't look a **boar** in the eye.
Skin your kills and weave grass into **clothes** — armor is worn, not magic
(Fiber → Hide → Iron → Scale). Build a **Forge** to smelt highland iron into
real tools, and forge the Leviathan's scales into the island's best armor.
Packs raise how much you can haul before the weight slows you.
The goal ladder (top right) always gives you a next thing to do.

A moonstone from the **Sea Cave** builds a **raft** — wade into the shallows,
press E, and sail past the reef to the **Far Isle**: richer, meaner, and home
to a monolith that wants three moonstones.

Your world **saves automatically** — host the same seed again to continue it.
You cannot hurt other survivors. The game won't let you. That's the point.

## Dedicated server

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --server --seed=12345
```

## Dev

- `-- --smoke` runs the headless self-test (harvest, craft, place, totem, combat, goals).
- `-- --shot` hosts, saves a screenshot to `user://shot.png`, quits.
- `-- --client=<ip>` auto-joins on launch (multiplayer testing).

## Shipping to Windows & Mac

In the Godot editor: Project → Export → add **Windows Desktop** and **macOS**
presets (download export templates when prompted) → Export Project. One codebase,
both platforms.
