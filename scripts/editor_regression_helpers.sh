prepare_editor_regression_addon() {
	local project="$1" addon="$1/addons/visual_gasic" entry
	if [[ -L "$addon" ]]; then
		rm "$addon"
	elif [[ -e "$addon" ]]; then
		echo "ERROR: regression addon destination already exists: $addon" >&2
		return 1
	fi
	mkdir -p "$addon" "$project/.godot"
	for entry in "$ROOT/addons/visual_gasic/"* "$ROOT/addons/visual_gasic/".[!.]*; do
		[[ -e "$entry" || -L "$entry" ]] || continue
		[[ "$(basename "$entry")" == bin ]] && continue
		cp -a "$entry" "$addon/"
	done
	ln -s "$ROOT/addons/visual_gasic/bin" "$addon/bin"
	if [[ "$(uname -s)" == Linux &&
			! -f "$addon/plugins/vgmusic/bin/libgdsion.linux.template_debug.x86_64.so" ]]; then
		rm -f "$addon/plugins/vgmusic/libgdsion.gdextension" \
			"$addon/plugins/vgmusic/libgdsion.gdextension.uid"
		echo "NOT TESTED: optional GDSiON; native Linux library is absent"
	fi
	printf '%s\n' res://addons/visual_gasic/visual_gasic.gdextension \
		> "$project/.godot/extension_list.cfg"
}
