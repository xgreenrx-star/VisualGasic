#!/usr/bin/env bash
# VisualGasic one-shot bootstrap installer (Linux MVP)
# =============================================================================
# This is the "new user" installer. Unlike install.sh (which drops the addon
# into an existing Godot project), this bootstraps the full VG experience:
#   1. Downloads Godot 4.6.1 (or uses a local binary if provided)
#   2. Creates a default VG project with the addon enabled
#   3. Installs a launcher script + desktop file so the user can click one
#      icon and land directly in the VG editor
#
# After running this, the user has a working VG IDE — no knowledge of Godot
# is required on their part.
#
# Usage:
#   ./bootstrap_install.sh                        # Download Godot from official mirror
#   ./bootstrap_install.sh --godot-binary PATH    # Use a local Godot binary (dev/CI)
#   ./bootstrap_install.sh --prefix DIR           # Install into DIR instead of default
#   ./bootstrap_install.sh --uninstall            # Remove a previous install
#
# What gets installed (defaults):
#   ~/.local/share/VisualGasic/godot/             — Godot 4.6.1 binary
#   ~/.local/share/VisualGasic/default_project/   — Pre-configured VG project
#   ~/.local/bin/visualgasic                      — Launcher script
#   ~/.local/share/applications/visualgasic.desktop
#                                                 — Menu / launcher entry
# =============================================================================

set -euo pipefail

# ── Colours (skipped if stdout is not a terminal) ─────────────────────────────
if [[ -t 1 ]]; then
    R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; B='\033[1m'; N='\033[0m'
else
    R=''; G=''; Y=''; C=''; B=''; N=''
fi
info()    { printf '%bℹ%b  %s\n' "$C" "$N" "$1"; }
ok()      { printf '%b✓%b  %s\n' "$G" "$N" "$1"; }
warn()    { printf '%b⚠%b  %s\n' "$Y" "$N" "$1"; }
die()     { printf '%b✗%b  %s\n' "$R" "$N" "$1" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────────────────────
GODOT_VERSION="4.6.1-stable"
GODOT_BINARY_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_BINARY_NAME}.zip"

# Source (where the addon lives in the VG repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ADDON_SRC="$REPO_ROOT/addons/visual_gasic"

# Destinations
PREFIX="${HOME}/.local/share/VisualGasic"
BIN_DIR="${HOME}/.local/bin"
APPS_DIR="${HOME}/.local/share/applications"

# CLI options
GODOT_LOCAL_BINARY=""
ACTION="install"

while (($# > 0)); do
    case "$1" in
        --godot-binary) GODOT_LOCAL_BINARY="$2"; shift 2 ;;
        --prefix)       PREFIX="$2"; shift 2 ;;
        --bin-dir)      BIN_DIR="$2"; shift 2 ;;
        --apps-dir)     APPS_DIR="$2"; shift 2 ;;
        --uninstall)    ACTION="uninstall"; shift ;;
        -h|--help)
            sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

GODOT_DIR="$PREFIX/godot"
PROJECT_DIR="$PREFIX/default_project"
LAUNCHER="$BIN_DIR/visualgasic"
DESKTOP_FILE="$APPS_DIR/visualgasic.desktop"

# ── Uninstall path ────────────────────────────────────────────────────────────
if [[ "$ACTION" == "uninstall" ]]; then
    info "Removing VisualGasic from $PREFIX"
    rm -rf "$PREFIX" "$LAUNCHER" "$DESKTOP_FILE"
    ok "Uninstalled."
    exit 0
fi

# ── Banner ────────────────────────────────────────────────────────────────────
printf '%b%b' "$B" "$C"
cat <<'EOF'
  ╔═══════════════════════════════════════════╗
  ║   VisualGasic one-shot bootstrap          ║
  ║   Installs Godot + VG + launcher          ║
  ╚═══════════════════════════════════════════╝
EOF
printf '%b\n' "$N"

info "Prefix:         $PREFIX"
info "Godot:          $GODOT_DIR/$GODOT_BINARY_NAME"
info "Project:        $PROJECT_DIR"
info "Launcher:       $LAUNCHER"
info "Desktop file:   $DESKTOP_FILE"
echo

# ── Sanity ────────────────────────────────────────────────────────────────────
[[ -d "$ADDON_SRC" ]] || die "Addon source missing: $ADDON_SRC (run from VG repo)"

# ── Step 1. Install Godot ─────────────────────────────────────────────────────
install_godot() {
    mkdir -p "$GODOT_DIR"
    local target="$GODOT_DIR/$GODOT_BINARY_NAME"

    if [[ -x "$target" ]]; then
        ok "Godot already installed at $target"
        return
    fi

    if [[ -n "$GODOT_LOCAL_BINARY" ]]; then
        info "Using local Godot binary: $GODOT_LOCAL_BINARY"
        [[ -x "$GODOT_LOCAL_BINARY" ]] || die "Not executable: $GODOT_LOCAL_BINARY"
        cp "$GODOT_LOCAL_BINARY" "$target"
        chmod +x "$target"
    else
        command -v curl >/dev/null || die "curl required"
        command -v unzip >/dev/null || die "unzip required"
        info "Downloading Godot $GODOT_VERSION (~50 MB)..."
        local tmp; tmp="$(mktemp -d)"
        trap "rm -rf '$tmp'" RETURN
        curl -fLsS "$GODOT_URL" -o "$tmp/godot.zip" || die "Download failed"
        unzip -q "$tmp/godot.zip" -d "$tmp" || die "Unzip failed"
        # Extracted archive may be the binary directly, or nested one level.
        if [[ -f "$tmp/$GODOT_BINARY_NAME" ]]; then
            mv "$tmp/$GODOT_BINARY_NAME" "$target"
        else
            local found; found="$(find "$tmp" -name "$GODOT_BINARY_NAME" -type f | head -1)"
            [[ -n "$found" ]] || die "Godot binary not found inside archive"
            mv "$found" "$target"
        fi
        chmod +x "$target"
    fi

    ok "Godot ready: $target"
}

# ── Step 2. Build the default project ─────────────────────────────────────────
#
# The project's purpose is to *be* the VG IDE. When Godot opens it with
# --editor, the VG plugin activates, which moves the user straight into the
# VG code editor view. The project ships with a blank Module1.vg so the user
# sees an editable file on first open instead of a "create something" prompt.
build_default_project() {
    info "Creating default project: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR/addons"

    # Copy (or re-link) the addon. A symlink keeps updates free when the
    # user re-runs the installer from an updated repo; a real copy is safer
    # if we ever ship this from a release artifact without the repo present.
    rm -rf "$PROJECT_DIR/addons/visual_gasic"
    cp -rL "$ADDON_SRC" "$PROJECT_DIR/addons/visual_gasic"

    # Minimal project.godot: enables the VG plugin and starts in code-editor
    # mode (the plugin honours vg_default_mode — once Form Designer becomes
    # a separate plugin this will also pick the right initial dock).
    cat >"$PROJECT_DIR/project.godot" <<EOF
; VisualGasic default project — generated by bootstrap_install.sh
; Opening this project in Godot lands the user in the VG IDE.

config_version=5

[application]
config/name="VisualGasic"
config/description="Default VisualGasic IDE workspace. Your code goes here."
config/features=PackedStringArray("4.6", "GL Compatibility")
config/icon="res://icon.svg"

[editor_plugins]
enabled=PackedStringArray("res://addons/visual_gasic/plugin.cfg")

[vg]
default_mode="code"
EOF

    # Starter file — a greeting Module so the code editor is populated on
    # first open. User can immediately press Run or edit this.
    cat >"$PROJECT_DIR/Module1.vg" <<'EOF'
' Welcome to VisualGasic!
'
' This is a Module — the simplest kind of VG file. Press Run (F5) to see
' it execute, or replace this code with your own.

Sub Main()
    MsgBox "Hello from VisualGasic!"
End Sub
EOF

    # Placeholder icon so Godot's project manager shows a picture.
    if [[ ! -f "$PROJECT_DIR/icon.svg" ]]; then
        cat >"$PROJECT_DIR/icon.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><rect width="128" height="128" fill="#2c5aa0"/><text x="64" y="84" font-size="72" text-anchor="middle" fill="#fff" font-family="sans-serif" font-weight="bold">VG</text></svg>
EOF
    fi

    ok "Project ready"
}

# ── Step 3. Launcher + desktop entry ──────────────────────────────────────────
install_launcher() {
    mkdir -p "$BIN_DIR" "$APPS_DIR"

    # Launcher script — the single command the user (or desktop entry) runs.
    # Resolved paths are baked in so the script works regardless of cwd.
    cat >"$LAUNCHER" <<EOF
#!/usr/bin/env bash
# VisualGasic launcher (generated by bootstrap_install.sh)
exec "$GODOT_DIR/$GODOT_BINARY_NAME" --path "$PROJECT_DIR" --editor "\$@"
EOF
    chmod +x "$LAUNCHER"

    # Desktop entry for app menus / taskbars. Icon path points at the
    # project icon we just dropped.
    cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=VisualGasic
GenericName=VB6-style IDE for Godot
Comment=Visual programming IDE — code, run, ship
Exec=$LAUNCHER %F
Icon=$PROJECT_DIR/icon.svg
Terminal=false
Categories=Development;IDE;
StartupNotify=true
MimeType=text/x-visualgasic;
EOF

    # Refresh the launcher cache so the entry appears immediately.
    if command -v update-desktop-database >/dev/null; then
        update-desktop-database -q "$APPS_DIR" 2>/dev/null || true
    fi

    ok "Launcher: $LAUNCHER"
    ok "Menu entry: $DESKTOP_FILE"
}

# ── Step 4. Prime the project ────────────────────────────────────────────────
#
# Godot's first interactive --editor launch imports resources *before* it
# activates [editor_plugins], which means the VG plugin appears inactive
# and the user sees a stock Godot editor on first launch instead of the
# VG IDE. Running --headless --import once here forces the import to
# complete and (as a side effect) loads the VG plugin so it can dock its
# panels and persist them into editor_layout.cfg. After this pass the
# next interactive open lands directly in the VG IDE.
prime_project() {
    info "Priming project (first-time import + plugin activation)..."
    local godot_bin="$GODOT_DIR/$GODOT_BINARY_NAME"
    if ! "$godot_bin" --path "$PROJECT_DIR" --headless --import >/dev/null 2>&1; then
        warn "Priming pass returned non-zero. The IDE should still open;"
        warn "if the VG dock is missing, toggle the VisualGasic plugin off"
        warn "and on under Project Settings → Plugins."
    else
        ok "Project primed; VG plugin pre-activated."
    fi
}

# ── Run ───────────────────────────────────────────────────────────────────────
install_godot
build_default_project
install_launcher
prime_project

echo
ok "Install complete."
echo
printf '%bLaunch with:%b  %s\n' "$B" "$N" "$LAUNCHER"
printf '%bOr:%b           Applications menu → VisualGasic\n' "$B" "$N"
echo
if ! [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in your PATH — add it with:"
    printf '  echo '\''export PATH="%s:$PATH"'\'' >> ~/.bashrc\n' "$BIN_DIR"
fi
