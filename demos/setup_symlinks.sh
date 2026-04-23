#!/bin/bash
# Deprecated — superseded by scripts/sync_addons.sh which handles the whole
# repository (demos/, examples/, game_projects/, test_proj/) uniformly and
# provides status/check/convert/restore subcommands.
#
# This shim is kept only so existing muscle memory and documentation links
# continue to work; it just forwards to the real tool.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "demos/setup_symlinks.sh is deprecated — forwarding to scripts/sync_addons.sh convert"
echo
exec "$REPO_ROOT/scripts/sync_addons.sh" convert "$@"
