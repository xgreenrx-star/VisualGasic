#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/vg-corpus-audit-checks-XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/plain" "$WORK/handled" "$WORK/missing" "$WORK/empty"
printf "' No expected-output block\n" > "$WORK/missing/example.vg"
printf "' Expected output:\n' answer\n" > "$WORK/plain/example with spaces.vg"
printf "' Expected handled errors:\n' 5|Example|10\n\n' Expected output:\n' answer\n" \
    > "$WORK/handled/example.vg"

cat > "$WORK/fake-godot" <<'ENGINE'
#!/usr/bin/env bash
case "$VG_FAKE_CASE" in
    mismatch) echo wrong ;;
    parser) echo 'Parser Error: rejected'; echo answer ;;
    unexpected_error) echo '[VG Runtime Error 5] expected -- Sub: Example Line: 10 (example.vg)'; echo answer ;;
    handled) echo '[VG Runtime Error 5] expected -- Sub: Example Line: 10 (example.vg)'; echo answer ;;
    extra_error)
        echo '[VG Runtime Error 5] expected -- Sub: Example Line: 10 (example.vg)'
        echo '[VG Runtime Error 6] unexpected -- Sub: Example Line: 11 (example.vg)'
        echo answer ;;
    unhandled)
        echo '[VG Runtime Error 5] expected -- Sub: Example Line: 10 (example.vg)'
        echo "Unhandled runtime error in 'Example': Error 5"
        echo answer ;;
    *) echo answer ;;
esac
if [[ "$VG_FAKE_CASE" != incomplete ]]; then echo VG_CORPUS_COMPLETED; fi
if [[ "$VG_FAKE_CASE" == nonzero ]]; then exit 3; fi
ENGINE
chmod +x "$WORK/fake-godot"

checks=0
check() {
    local scenario="$1" fixture="$2" expected="$3" rc=0
    VG_FAKE_CASE="$scenario" VG_CORPUS_DIR="$WORK/$fixture" \
        GODOT="$WORK/fake-godot" bash "$ROOT/scripts/audit_corpus.sh" \
        > "$WORK/result.log" 2>&1 || rc=$?
    if [[ "$expected" == pass && "$rc" -ne 0 ]] ||
       [[ "$expected" == fail && "$rc" -eq 0 ]]; then
        printf 'FAIL: %s (%s), exit=%s\n' "$scenario" "$fixture" "$rc" >&2
        cat "$WORK/result.log" >&2
        exit 1
    fi
    printf 'PASS: %s (%s)\n' "$scenario" "$fixture"
    checks=$((checks + 1))
}

check success plain pass
check mismatch plain fail
check incomplete plain fail
check nonzero plain fail
check parser plain fail
check unexpected_error plain fail
check handled handled pass
check extra_error handled fail
check unhandled handled fail
check success handled fail
check success missing fail
check success empty fail
printf 'Corpus audit self-tests: %s passed\n' "$checks"
