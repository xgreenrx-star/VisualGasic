extends RefCounted
class_name VgAddonInstall
## Install the canonical VisualGasic addon into a new project directory.
##
## Release installs (Asset Library, Windows installers) default to **copy**.
## Developer checkouts may symlink when safe:
##   VG_ADDON_SYMLINK=1  — force symlink (Unix; copies on Windows)
##   VG_ADDON_COPY=1     — force full copy (overrides symlink)
##   VG_ADDON_SOURCE     — when set, symlink on Unix unless VG_ADDON_COPY=1


static func prefer_symlink(_src: String, _dst: String) -> bool:
	if OS.get_environment("VG_ADDON_COPY").strip_edges() == "1":
		return false
	if OS.get_environment("VG_ADDON_SYMLINK").strip_edges() == "1":
		return OS.get_name() != "Windows"
	if not OS.get_environment("VG_ADDON_SOURCE").strip_edges().is_empty():
		return OS.get_name() != "Windows"
	return false


## Install addon tree. `copy_recursive` must be Callable(src_abs, dst_abs) -> int.
static func install(src: String, dst: String, copy_recursive: Callable) -> int:
	var src_norm := src.rstrip("/")
	var dst_norm := dst.rstrip("/")
	if src_norm == dst_norm:
		return OK
	if not FileAccess.file_exists(src_norm + "/plugin.cfg"):
		return ERR_FILE_NOT_FOUND
	if prefer_symlink(src_norm, dst_norm):
		var link_err := _install_symlink(src_norm, dst_norm)
		if link_err == OK:
			_ensure_binaries(src_norm, dst_norm, copy_recursive)
			return OK
		push_warning("[VgAddonInstall] symlink failed (%d) — falling back to copy" % link_err)
	var copy_err: int = int(copy_recursive.call(src_norm, dst_norm))
	if copy_err == OK:
		_ensure_binaries(src_norm, dst_norm, copy_recursive)
	return copy_err


static func _install_symlink(src: String, dst: String) -> int:
	if OS.get_name() == "Windows":
		return ERR_UNAVAILABLE
	var parent := dst.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(parent)
	if err != OK and not DirAccess.dir_exists_absolute(parent):
		return err
	_remove_path(dst)
	var out: Array = []
	var code: int = OS.execute("ln", ["-sfn", src, dst], out, true, false)
	return OK if code == 0 else ERR_CANT_CREATE


static func _remove_path(path: String) -> void:
	if path.is_empty():
		return
	if DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path):
		if OS.get_name() != "Windows":
			OS.execute("rm", ["-rf", path], [], true, false)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func _ensure_binaries(src: String, dst: String, copy_recursive: Callable) -> void:
	var bin_dst := dst + "/bin"
	if DirAccess.dir_exists_absolute(bin_dst):
		return
	var bin_src := src + "/bin"
	if DirAccess.dir_exists_absolute(bin_src):
		copy_recursive.call(bin_src, bin_dst)
