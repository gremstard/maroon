# Building & running Maroon from source

Everything is plain GDScript — no plugins, no asset packs, no dependencies
beyond Godot itself.

## Run from source

1. Install [Godot 4.7+](https://godotengine.org/download).
2. Clone and run:
```bash
git clone https://github.com/gremstard/maroon.git
cd maroon
/Applications/Godot.app/Contents/MacOS/Godot --path .   # macOS
# or: godot --path .                                    # any platform with godot on PATH
```
Or open the folder in the Godot editor and press Play.

## Controls (current)

| Key | Action |
|-----|--------|
| WASD / Space / Shift | Move / jump / sprint |
| Mouse + Left click | Look / swing, place, eat |
| 1–0 | Hotbar |
| E | Interact — cook, feed totem, loot, doors, board raft |
| Tab | Crafting menu |
| 7 + scroll / R / X | Build mode: piece select / rotate / demolish |
| Esc | Pause menu |

## Dedicated server

```bash
godot --headless --path . -- --server --seed=12345
```
Listens on UDP 27455. World autosaves every 60 s and on shutdown; saves live
in `user://saves/` and are keyed by seed.

## Dev flags

| Flag | What it does |
|------|--------------|
| `-- --smoke` | Headless self-test of every system (forage→craft→build→quests→boss→saves). CI-friendly: prints `ALL PASS` or failures. |
| `-- --client=<ip>` | Auto-join a host on launch (multiplayer testing). |
| `-- --shot` | Host, screenshot to `user://shot.png`, quit. Add `--shot-menu`, `--shot-crew`, `--shot-build`, `--shot-cave`, `--shot-raft`, `--shot-lev` for staged scenes. |

## Export installable builds

Needs the Godot 4.7.1 export templates once (Editor → Manage Export
Templates → Download, or drop the `.tpz` contents into
`~/Library/Application Support/Godot/export_templates/4.7.1.stable/`). Then:

```bash
./build.sh
```
Produces `build/Maroon-macOS.zip` (universal) and `build/Maroon-Windows.exe`
(single file, data embedded). Presets are in `export_presets.cfg` — unsigned
testing builds.

## Releasing

```bash
./build.sh
gh release create vX.Y.Z build/Maroon-macOS.zip build/Maroon-Windows.exe --title "Maroon vX.Y.Z" --notes "..."
```
The website's download buttons track the **latest** GitHub release
automatically.

## Optional: Firebase accounts

Cloud profiles (name + appearance sync) activate when
`user://firebase_config.json` exists:
```json
{"api_key": "<Web API key>", "project_id": "<project id>"}
```
Enable Email/Password auth + Firestore in the Firebase console. Never commit
this file (it's gitignored).
