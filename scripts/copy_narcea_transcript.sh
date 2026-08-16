#!/usr/bin/env bash
# Copy the latest Narcea agent NDJSON transcript from Godot user data into
# tests/narcea_golden/recorded/ for Tier B replay.
#
# Usage:
#   bash scripts/copy_narcea_transcript.sh [project_name] [scenario_id]
#
# Examples:
#   bash scripts/copy_narcea_transcript.sh "VG Narcea Test" ollama_qwen_counter
#   bash scripts/copy_narcea_transcript.sh                  # auto-detect latest
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/tests/narcea_golden/recorded"
PROJECT_NAME="${1:-VG Narcea Test}"
SCENARIO_ID="${2:-}"

USERDATA_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata"
RUNS_DIR="$USERDATA_BASE/$PROJECT_NAME/vg_agent_runs"

if [[ ! -d "$RUNS_DIR" ]]; then
	echo "No transcripts at: $RUNS_DIR" >&2
	echo "Run a Narcea agent session in the editor first (agent mode on)." >&2
	exit 1
fi

LATEST="$(ls -t "$RUNS_DIR"/*.ndjson 2>/dev/null | head -1 || true)"
if [[ -z "$LATEST" ]]; then
	echo "No .ndjson files in $RUNS_DIR" >&2
	exit 1
fi

if [[ -z "$SCENARIO_ID" ]]; then
	BASE="$(basename "$LATEST" .ndjson)"
	SCENARIO_ID="${BASE}_counter"
fi

DEST_NDJSON="$OUT_DIR/${SCENARIO_ID}.ndjson"
cp "$LATEST" "$DEST_NDJSON"
echo "Copied transcript:"
echo "  $LATEST"
echo "  -> $DEST_NDJSON"

# If the ndjson contains a full assistant_response, extract to *_response.txt
python3 - <<'PY' "$DEST_NDJSON" "$OUT_DIR/${SCENARIO_ID}_response.txt"
import json, sys
ndjson_path, out_path = sys.argv[1], sys.argv[2]
response = None
with open(ndjson_path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        if obj.get("type") == "assistant_response" and obj.get("response"):
            response = obj["response"]
if response:
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(response)
    print(f"Extracted assistant response -> {out_path}")
else:
    print("No assistant_response.response in ndjson — copy the chat reply manually to:")
    print(f"  {out_path}")
PY

echo ""
echo "Next: bash scripts/run_narcea_golden.sh --tier B"
