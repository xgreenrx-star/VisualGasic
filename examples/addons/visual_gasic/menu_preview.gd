@tool
extends PopupPanel
## Design-time menu preview for VB6-style menu editing
## Shows menu structure and allows double-click to edit event handlers

signal menu_item_double_clicked(item_name: String, item_caption: String)

var menu_tree: Tree
var menu_structure: Dictionary = {}
var form_node: Node

func _ready() -> void:
	size = Vector2i(300, 400)
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var label = Label.new()
	label.text = "Menu Preview (Double-click to edit code)"
	vbox.add_child(label)
	
	menu_tree = Tree.new()
	menu_tree.custom_minimum_size = Vector2(280, 350)
	menu_tree.hide_root = true
	menu_tree.select_mode = Tree.SELECT_ROW
	menu_tree.item_activated.connect(_on_item_double_clicked)
	vbox.add_child(menu_tree)

func show_menu_structure(structure: Dictionary, form: Node) -> void:
	"""Display menu structure in tree format"""
	menu_structure = structure
	form_node = form
	
	menu_tree.clear()
	var root = menu_tree.create_item()
	
	if structure.has("items"):
		for top_menu in structure.items:
			_add_menu_item(root, top_menu, 0)

func _add_menu_item(parent: TreeItem, item_data: Dictionary, depth: int) -> void:
	"""Recursively add menu items to tree"""
	var tree_item = menu_tree.create_item(parent)
	
	var caption = item_data.get("caption", "")
	var name = item_data.get("name", "")
	var shortcut = item_data.get("shortcut", "")
	
	# Format display text
	var display = caption
	if caption == "-":
		display = "──────────"
	elif shortcut != "":
		display += " (" + shortcut + ")"
	
	tree_item.set_text(0, display)
	tree_item.set_metadata(0, {"name": name, "caption": caption})
	
	# Add children
	if item_data.has("children"):
		for child in item_data.children:
			_add_menu_item(tree_item, child, depth + 1)

func _on_item_double_clicked() -> void:
	"""Handle double-click on menu item"""
	var selected = menu_tree.get_selected()
	if not selected:
		print("MenuPreview: No item selected")
		return
	
	var metadata = selected.get_metadata(0)
	if not metadata:
		print("MenuPreview: No metadata on item")
		return
	
	var item_name = metadata.get("name", "")
	var caption = metadata.get("caption", "")
	
	print("MenuPreview: Double-clicked item: ", caption, " (", item_name, ")")
	
	# Don't create handlers for separators or top-level menus with children
	if caption == "-":
		print("MenuPreview: Separator clicked, ignoring")
		return
	
	if item_name == "":
		print("MenuPreview: Item has no name, generating from caption")
		item_name = caption.replace("...", "").replace("&", "").strip_edges()
	
	# Emit signal to create/navigate to event handler
	print("MenuPreview: Emitting signal for ", item_name)
	menu_item_double_clicked.emit(item_name, caption)
	hide()
