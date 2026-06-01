#!/usr/bin/env bash
# Fetch CC0 / Public-Domain music for BLUE_SCREEN's per-era music slots.
#
# Sources (all CC0 — Creative Commons Zero, no attribution required):
#   1) "4 Chiptunes (Adventure)" by Juhani Junkala  — 4 OGG tracks
#      https://opengameart.org/content/4-chiptunes-adventure
#   2) "NES Shooter Music" by SketchyLogic           — 5 WAV tracks + jingles
#      https://opengameart.org/content/nes-shooter-music-5-tracks-3-jingles
#
# Each pack is a small zip (8 MB and 18 MB) hosted on opengameart.org.
# After download we rename the contents to short, predictable filenames
# under build/BLUE_SCREEN/sounds/ so Main.tscn can reference them.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOUNDS="$ROOT/game_projects/AGCK_Tests/build/BLUE_SCREEN/sounds"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[fetch_era_music] target: $SOUNDS"
mkdir -p "$SOUNDS"

echo "[fetch_era_music] downloading Chiptune Adventures (OGG, ~8 MB)..."
wget --quiet --show-progress -O "$TMP/adv.zip" \
    "https://opengameart.org/sites/default/files/Juhani%20Junkala%20%5BChiptune%20Adventures%5D%20OGG.zip"

echo "[fetch_era_music] downloading NES Shooter Music (WAV, ~18 MB)..."
wget --quiet --show-progress -O "$TMP/nes.zip" \
    "https://opengameart.org/sites/default/files/WAV.zip"

echo "[fetch_era_music] extracting..."
mkdir -p "$TMP/adv" "$TMP/nes"
unzip -q -o "$TMP/adv.zip" -d "$TMP/adv"
unzip -q -o "$TMP/nes.zip" -d "$TMP/nes"

echo "[fetch_era_music] zip contents (Adventure):"
find "$TMP/adv" -type f | sed 's|.*/||'
echo "[fetch_era_music] zip contents (NES):"
find "$TMP/nes" -type f | sed 's|.*/||'

# Map by substring match (file order inside zips can vary).
copy_match() {
    local pattern="$1"
    local dst="$2"
    local src
    src="$(find "$TMP" -type f \( -iname '*.ogg' -o -iname '*.wav' \) -iname "*$pattern*" | head -n1)"
    if [[ -z "$src" ]]; then
        echo "[fetch_era_music] WARN no match for '$pattern' → $dst (skipped)"
        return 0
    fi
    cp -f "$src" "$SOUNDS/$dst"
    echo "[fetch_era_music] $(basename "$src") → $dst"
}

copy_match "Stage 1"      "music_chip_stage1.ogg"
copy_match "Stage 2"      "music_chip_stage2.ogg"
copy_match "Boss Fight"   "music_chip_boss.ogg"
copy_match "Stage Select" "music_chip_select.ogg"

copy_match "BossMain" "music_nes_boss.wav"
copy_match "Venus"   "music_nes_venus.wav"
copy_match "Map"     "music_nes_map.wav"
copy_match "Mars"    "music_nes_mars.wav"
copy_match "Mercury" "music_nes_mercury.wav"

cat >"$SOUNDS/music_CREDITS.txt" <<'EOF'
Era music tracks fetched by scripts/fetch_era_music.sh.

All tracks below are Creative Commons Zero (CC0 / Public Domain). No
attribution is required, but credit is given here as a courtesy:

  music_chip_stage1.ogg
  music_chip_stage2.ogg
  music_chip_boss.ogg
  music_chip_select.ogg
    "4 Chiptunes (Adventure)" — Juhani Junkala / SubspaceAudio
    https://opengameart.org/content/4-chiptunes-adventure
    License: CC0

  music_nes_boss.wav
  music_nes_venus.wav
  music_nes_map.wav
  music_nes_mars.wav
  music_nes_mercury.wav
    "NES Shooter Music (5 tracks, 3 jingles)" — SketchyLogic
    https://opengameart.org/content/nes-shooter-music-5-tracks-3-jingles
    License: CC0
EOF

echo "[fetch_era_music] done."
