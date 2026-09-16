#!/usr/bin/env bash
# One-time (or idempotent) migration to samples/ layout. Local prep for release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

log() { printf '==> %s\n' "$*"; }

mkdir -p samples/games samples/apps samples/showcases samples/internal

move_project() {
	local src="$1" dest_dir="$2"
	local name
	name="$(basename "$src")"
	if [[ -d "samples/$dest_dir/$name" ]]; then
		log "skip (already moved): samples/$dest_dir/$name"
		return 0
	fi
	if [[ ! -d "projects/$name" ]]; then
		log "skip (missing): projects/$name"
		return 0
	fi
	log "move projects/$name -> samples/$dest_dir/$name"
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "projects/$name" >/dev/null 2>&1; then
		if ! git mv "projects/$name" "samples/$dest_dir/$name" 2>/dev/null; then
			# Nested addon copies sometimes block git mv — filesystem move + re-stage.
			mv "projects/$name" "samples/$dest_dir/$name"
			git add -A "samples/$dest_dir/$name"
			git add -A "projects/$name" 2>/dev/null || true
		fi
	else
		mv "projects/$name" "samples/$dest_dir/$name"
	fi
}

# --- games ---
for p in brotato_vg brotato3d asteroids defender platformer_2d pong_ultimate \
	racing_3d vector_storm zork vg_graven_slice; do
	move_project "$p" games
done

# --- apps ---
for p in vg_twinpane vector_dashboard VG_UI_TOOLS; do
	move_project "$p" apps
done

# --- showcases ---
for p in vg_beta_showcase demoscene_intro vg_narcea_movie_demo; do
	move_project "$p" showcases
done

# --- internal ---
for p in vg_narcea_test vgai_demo AGCK_Tests; do
	move_project "$p" internal
done

# Remove orphan duplicate addon tree under projects/addons (not canonical).
if [[ -d projects/addons && ! -L projects/addons ]]; then
	log "remove orphan projects/addons (use repo addons/visual_gasic)"
	rm -rf projects/addons
fi

# Move demos/ -> samples/demos/
if [[ -d demos && ! -L demos && ! -d samples/demos ]]; then
	log "move demos/ -> samples/demos/"
	if git ls-files demos >/dev/null 2>&1; then
		git mv demos samples/demos
	else
		mv demos samples/demos
	fi
elif [[ -d samples/demos ]]; then
	log "samples/demos already exists"
fi

# Rename demo/ -> engine_lab/
if [[ -d demo && ! -L demo && ! -d engine_lab ]]; then
	log "move demo/ -> engine_lab/"
	if git ls-files demo >/dev/null 2>&1; then
		if ! git mv demo engine_lab 2>/dev/null; then
			mv demo engine_lab
			git add -A engine_lab demo 2>/dev/null || true
		fi
	else
		mv demo engine_lab
	fi
elif [[ -d engine_lab ]]; then
	log "engine_lab/ already exists"
fi

# Quarantine local examples/ mirror (not in git).
if [[ -d examples && ! -L examples ]]; then
	mkdir -p archive
	if [[ ! -d archive/examples_mirror ]]; then
		log "archive local examples/ -> archive/examples_mirror/"
		mv examples archive/examples_mirror
	fi
fi

# Backward-compat symlinks at old paths.
link_compat() {
	local link_path="$1" target="$2"
	if [[ -e "$link_path" && ! -L "$link_path" ]]; then
		return 0
	fi
	if [[ -L "$link_path" ]]; then
		rm -f "$link_path"
	fi
	ln -sf "$target" "$link_path"
	log "symlink $link_path -> $target"
}

link_compat demos samples/demos
link_compat demo engine_lab

# Per-project symlinks under projects/ for old docs/scripts.
mkdir -p projects
for bucket in games apps showcases internal; do
	[[ -d "samples/$bucket" ]] || continue
	for proj in samples/"$bucket"/*; do
		[[ -d "$proj" ]] || continue
		name="$(basename "$proj")"
		if [[ -e "projects/$name" ]]; then
			continue
		fi
		ln -sf "../samples/$bucket/$name" "projects/$name"
	done
done

# Fix addon symlinks (depth changes after move break old ../../../ paths).
if [[ -x scripts/sync_addons.sh ]]; then
	log "repair addon symlinks (scripts/sync_addons.sh convert)"
	scripts/sync_addons.sh convert
fi

log "done — verify: scripts/sync_addons.sh check && scripts/ci_smoke.sh samples/games/brotato3d"
