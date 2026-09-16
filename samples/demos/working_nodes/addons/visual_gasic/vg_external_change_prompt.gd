@tool
## VGExternalChangePrompt — shows a non-modal toast when an open
## asset is changed externally (e.g. by another editor or by the
## VGRefRewriter rewriting paths after a rename).
##
## Subscribes to VGAssetBus.asset_invalidated. The watcher only
## emits this for files that were previously opened in the IDE
## (via asset_opened), so the prompt only appears for files the
## user is plausibly working with.
##
## A small AcceptDialog is shown with two buttons: "Reload" (re-emits
## asset_opened so the editor reloads from disk) and "Keep Mine".
## Same path within COOLDOWN seconds is suppressed to avoid spam from
## external tools that touch a file in bursts.
##
## Singleton: VGExternalChangePrompt.get_instance(). Wired up by the
## plugin manager at startup.

class_name VGExternalChangePrompt
extends Node

const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _PLUGIN_ID := "vg_external_change_prompt"

## Don't re-prompt for the same path within this window. Bursty saves
## from a build script or formatter would otherwise stack dialogs.
const COOLDOWN_SEC := 5.0

static var _instance: VGExternalChangePrompt = null

static func get_instance() -> VGExternalChangePrompt:
	if _instance == null or not is_instance_valid(_instance):
		_instance = VGExternalChangePrompt.new()
	return _instance


# Map<path, last_prompt_unix>
var _last_prompted: Dictionary = {}
var _host: Node = null


## Attach the prompt to a scene-tree node so AcceptDialog has somewhere
## to parent itself. Idempotent.
func attach_to(parent: Node) -> void:
	_host = parent
	if get_parent() == parent:
		return
	if get_parent() != null:
		get_parent().remove_child(self)
	parent.add_child(self)


func _ready() -> void:
	var bus = _AssetBus.get_instance()
	if not bus.asset_invalidated.is_connected(_on_asset_invalidated):
		bus.asset_invalidated.connect(_on_asset_invalidated)


# ─── Bus handler ────────────────────────────────────────────

func _on_asset_invalidated(path: String, by_plugin_id: String) -> void:
	# The ref rewriter is itself an automated process — don't ask the
	# user to confirm reloads it triggered, just let editors notice on
	# their own. (This also prevents prompt-on-rename loops.)
	if by_plugin_id == "vg_ref_rewriter":
		return
	var now := Time.get_unix_time_from_system()
	var last: float = float(_last_prompted.get(path, 0.0))
	if now - last < COOLDOWN_SEC:
		return
	_last_prompted[path] = now
	_show_prompt(path)


# ─── UI ─────────────────────────────────────────────────────

func _show_prompt(path: String) -> void:
	var host := _resolve_host()
	if host == null:
		# No host — silently skip; the editor is probably mid-shutdown.
		return
	var dlg := AcceptDialog.new()
	dlg.title = "File Changed Externally"
	dlg.dialog_text = "%s\n\nThis file was modified outside the IDE.\nReload from disk?" % path
	dlg.ok_button_text = "Reload"
	dlg.add_cancel_button("Keep Mine")
	dlg.exclusive = false
	dlg.unresizable = false
	host.add_child(dlg)
	dlg.confirmed.connect(func():
		_AssetBus.get_instance().emit_opened(path, _PLUGIN_ID)
		dlg.queue_free())
	dlg.canceled.connect(func():
		dlg.queue_free())
	dlg.popup_centered(Vector2i(440, 140))


## Resolve a host Control to parent the dialog to. Prefer the editor
## base control so the dialog z-orders above all panels.
func _resolve_host() -> Node:
	if Engine.has_singleton("EditorInterface"):
		var ei = Engine.get_singleton("EditorInterface")
		if ei != null and ei.has_method("get_base_control"):
			var base = ei.get_base_control()
			if base != null:
				return base
	if _host != null and is_instance_valid(_host):
		return _host
	if get_tree() != null:
		return get_tree().root
	return null
