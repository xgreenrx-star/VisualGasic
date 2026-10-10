#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"
OUT="$ROOT/release/v$VERSION"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/vg-macos-setup.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DEST="$WORK/VisualGasic-Setup"
mkdir -p "$DEST/offline/addons"
cp -aL "$ROOT/addons/visual_gasic" "$DEST/offline/addons/"
cp "$ROOT/VERSION" "$DEST/offline/"
cp "$ROOT/scripts/bootstrap_vg.py" "$ROOT/scripts/bootstrap_gui.py" "$DEST/"
cat > "$DEST/Install VisualGasic.command" <<'EOF'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v python3 >/dev/null; then
  echo "Install Python 3 from https://www.python.org/downloads/macos/ and run this again."
  read -r -p "Press Return to close."
  exit 1
fi
exec python3 bootstrap_vg.py --offline "$PWD/offline" --launch "$@"
EOF
chmod +x "$DEST/Install VisualGasic.command"
cat > "$DEST/README.txt" <<EOF
VisualGasic $VERSION — macOS setup (Intel and Apple Silicon)

1. Install Python 3 from https://www.python.org/downloads/macos/ if needed.
2. Unzip this archive into a writable folder.
3. Control-click "Install VisualGasic.command", choose Open, and follow setup.

The launcher is unsigned and is not notarized. macOS may ask you to approve
opening it. This is a command-line setup launcher, not a signed DMG.
The addon is bundled; the online setup downloads Godot 4.6.1.
Use the separate offline archive to include Godot without a network download.
Optional AI companions require internet and are not part of offline setup.

Docs: https://github.com/xgreenrx-star/VisualGasic/blob/v$VERSION/docs/guides/INSTALLATION.md
EOF
mkdir -p "$OUT"
(cd "$WORK" && zip -qr "$OUT/VisualGasic-Installer-v$VERSION-macos-universal.zip" VisualGasic-Setup)
curl -fL --retry 3 -o "$DEST/offline/Godot_v4.6.1-stable_macos.universal.zip" \
  https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_macos.universal.zip
(cd "$WORK" && zip -qr "$OUT/VisualGasic-Installer-Offline-v$VERSION-macos-universal.zip" VisualGasic-Setup)
