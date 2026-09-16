@tool
extends RefCounted
class_name VGTweakSwapRegistry

# Project-agnostic catalog of swap options.
#
#   - register_scene_swap("ship", "res://entities/ship_classic.tscn")
#   - register_scene_swap("ship", "res://entities/ship_arrow.tscn")
#
# Adapters for Node2D / Control can consult this catalog by group name.
# Canvas-group adapters can register draw recipes the same way.

static var _scenes: Dictionary = {}   # group -> [{id, path}]
static var _recipes: Dictionary = {}  # group -> [{id, callable}]
static var _discovered: Dictionary = {}  # group -> bool (cache)

const AUTO_DISCOVERY_ROOT := "res://swaps"

static func register_scene_swap(group: String, path: String, label: String = "") -> void:
	if not _scenes.has(group):
		_scenes[group] = []
	_scenes[group].append({"id": path, "label": label if label != "" else path.get_file()})

static func register_recipe_swap(group: String, id: String, recipe: Callable) -> void:
	if not _recipes.has(group):
		_recipes[group] = []
	_recipes[group].append({"id": id, "label": id, "callable": recipe})

static func options_for(group: String) -> Array:
	_auto_discover(group)
	var out: Array = []
	for s in _scenes.get(group, []):
		out.append({"id": "scene:" + s["id"], "label": s["label"], "kind": "scene"})
	for r in _recipes.get(group, []):
		out.append({"id": "recipe:" + r["id"], "label": r["label"], "kind": "recipe"})
	return out

static func _auto_discover(group: String) -> void:
	# Auto-pick up res://swaps/<group>/*.tscn the first time a group is queried.
	if _discovered.get(group, false):
		return
	_discovered[group] = true
	var dir_path := "%s/%s" % [AUTO_DISCOVERY_ROOT, group]
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tscn"):
			register_scene_swap(group, dir_path + "/" + entry)
		entry = dir.get_next()
	dir.list_dir_end()

static func swap_node_scene(node: Node, scene_path: String) -> bool:
	# Replaces `node` in its parent with an instance of `scene_path`,
	# preserving position/owner when possible.
	if node == null or node.get_parent() == null:
		return false
	if not ResourceLoader.exists(scene_path):
		return false
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return false
	var inst := packed.instantiate()
	var parent := node.get_parent()
	var idx := node.get_index()
	var name := node.name
	var owner := node.owner
	if node is Node2D and inst is Node2D:
		inst.position = node.position
		inst.rotation = node.rotation
		inst.scale = node.scale
	elif node is Control and inst is Control:
		inst.position = node.position
		inst.size = node.size
	parent.remove_child(node)
	node.queue_free()
	parent.add_child(inst)
	parent.move_child(inst, idx)
	inst.name = name
	if owner:
		inst.owner = owner
	return true

static func apply_recipe(target_id: String, canvas: Node, group: String, recipe_id: String) -> bool:
	for r in _recipes.get(group, []):
		if r["id"] == recipe_id and r["callable"].is_valid():
			r["callable"].call(canvas, target_id)
			return true
	return false
