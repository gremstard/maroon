#!/bin/bash
# Build distributable Maroon binaries into build/.
# Requires the Godot 4.7.1 export templates (Editor > Manage Export Templates,
# or drop the .tpz contents into
#   ~/Library/Application Support/Godot/export_templates/4.7.1.stable/).
set -e
cd "$(dirname "$0")"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
mkdir -p build
echo "== macOS =="
"$GODOT" --headless --path . --export-release "macOS" build/Maroon-macOS.zip
echo "== Windows =="
"$GODOT" --headless --path . --export-release "Windows Desktop" build/Maroon-Windows.exe
echo
echo "Done:"
ls -lh build/
