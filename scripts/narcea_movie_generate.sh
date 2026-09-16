#!/usr/bin/env bash
# narcea_movie_generate.sh — Run real Cursor SDK generation for each movie segment.
#
# Requires: CURSOR_API_KEY (or AI Pair key in Godot EditorSettings), cursor-sdk venv.
# Writes/updates generated/* and refreshes movie_data/transcripts/*.txt from streamed tokens.
#
# Usage:
#   export CURSOR_API_KEY=...
#   scripts/narcea_movie_generate.sh
#   scripts/narcea_movie_generate.sh --segment calculator

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/samples/showcases/vg_narcea_movie_demo"
AGENT="$ROOT/addons/visual_gasic/scripts/vg_cursor_agent.py"
VENV_PY="${VG_CURSOR_PYTHON:-$HOME/.config/visual_gasic/vg_cursor_venv/bin/python3}"
SYSTEM="$PROJECT/movie_data/narcea_slim_system.txt"
CWD="$ROOT"
MODEL="${CURSOR_MODEL:-composer-2.5}"
ONLY_SEGMENT=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--segment) ONLY_SEGMENT="${2:-}"; shift 2 ;;
		-h|--help)
			echo "Usage: $0 [--segment calculator|shader_art|platformer|doom_maze]"
			exit 0
			;;
		*) echo "Unknown: $1" >&2; exit 2 ;;
	esac
done

if [[ ! -x "$VENV_PY" ]]; then
	VENV_PY="$(command -v python3)"
fi

_api_key() {
	if [[ -n "${CURSOR_API_KEY:-}" ]]; then
		echo "$CURSOR_API_KEY"
		return
	fi
	echo "ERROR: Set CURSOR_API_KEY for Cursor Composer generation." >&2
	exit 1
}

_run_segment() {
	local id="$1"
	local prompt_file="$PROJECT/movie_data/prompts/${id}.txt"
	local transcript_out="$PROJECT/movie_data/transcripts/${id}.txt"
	local req_json
	req_json="$(mktemp /tmp/vg_narcea_movie_XXXXXX.json)"
	trap 'rm -f "$req_json"' RETURN

	local refs=""
	case "$id" in
		calculator) refs=$'\nReference: https://en.wikipedia.org/wiki/Calculator' ;;
		shader_art) refs=$'\nReferences:\nhttps://docs.godotengine.org/en/stable/tutorials/shaders/index.html\nhttps://youtu.be/FUw8zgbn_tU' ;;
		platformer) refs=$'\nReferences:\nhttps://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html\nhttps://kenney.nl/assets/platformer-pack-redux' ;;
		doom_maze) refs=$'\nReferences:\nhttps://en.wikipedia.org/wiki/Doom_(1993_video_game)\nhttps://kenney.nl/assets/retro-medieval-kit' ;;
	esac

	local user_prompt
	user_prompt="$(cat "$prompt_file")${refs}

Important: write all files under samples/showcases/vg_narcea_movie_demo/generated/${id}/ relative to repo root. Include runnable main.tscn. Use Visual Gasic (.vg) for game logic."

	python3 - "$req_json" "$CWD" "$SYSTEM" "$user_prompt" "$(_api_key)" <<'PY'
import json, sys
req_path, cwd, system_path, user_prompt, api_key = sys.argv[1:6]
with open(system_path, encoding="utf-8") as f:
    system = f.read()
payload = {
    "api_key": api_key,
    "model": "composer-2.5",
    "cwd": cwd,
    "system_prompt": system,
    "user_prompt": user_prompt,
    "conversation_history": [],
}
with open(req_path, "w", encoding="utf-8") as f:
    json.dump(payload, f)
PY

	echo "── Cursor generate: $id ──"
	local tokens_file
	tokens_file="$(mktemp /tmp/vg_narcea_tokens_XXXXXX.txt)"
	: >"$tokens_file"
	set +e
	"$VENV_PY" "$AGENT" "$req_json" 2>"$tokens_file.stderr" | while IFS= read -r line; do
		echo "$line"
		type=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('type',''))" 2>/dev/null || true)
		if [[ "$type" == "token" ]]; then
			echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('text',''), end='')" >> "$tokens_file"
		fi
	done
	local rc=${PIPESTATUS[0]}
	set -e
	if [[ -s "$tokens_file" ]]; then
		cp "$tokens_file" "$transcript_out"
		echo "Saved transcript → $transcript_out"
	fi
	rm -f "$tokens_file" "$tokens_file.stderr"
	return "$rc"
}

segments=(calculator shader_art platformer doom_maze)
for id in "${segments[@]}"; do
	if [[ -n "$ONLY_SEGMENT" && "$id" != "$ONLY_SEGMENT" ]]; then
		continue
	fi
	_run_segment "$id" || echo "WARN: segment $id failed (keeping bundled apps/transcripts)"
done

echo "Done. Preview: open $PROJECT/project.godot and press F5 (Space starts movie without --write-movie)."
