@tool
extends VBoxContainer
## VisualGasic Package Browser — editor panel for managing VG packages.
## Integrates with VisualGasicPackage C++ class for install/remove/search.
##
## Provides:
##   • Installed packages list with version + remove button
##   • Search bar to query the registry
##   • One-click install from search results
##   • Init / refresh project manifest

signal package_installed(pkg_name: String, version: String)
signal package_removed(pkg_name: String)

var _pm: Object = null  # VisualGasicPackage instance
var _project_path: String = ""

# ── UI Widgets ──────────────────────────────────────────────────────────────
var _toolbar: HBoxContainer
var _refresh_btn: Button
var _init_btn: Button

var _search_bar: HBoxContainer
var _search_edit: LineEdit
var _search_btn: Button

var _tabs: TabContainer
var _installed_tree: Tree
var _search_tree: Tree
var _info_label: RichTextLabel

# ── Setup ───────────────────────────────────────────────────────────────────
func setup(project_path: String) -> void:
	_project_path = project_path
	_build_ui()
	_create_package_manager()
	_refresh_installed()

func _build_ui() -> void:
	# ── Toolbar ─────────────────────────────────────────────────────────
	_toolbar = HBoxContainer.new()
	_toolbar.custom_minimum_size.y = 32

	var title_lbl := Label.new()
	title_lbl.text = "📦 VG Packages"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(title_lbl)

	_init_btn = Button.new()
	_init_btn.text = "Init"
	_init_btn.tooltip_text = "Create vg.json manifest"
	_init_btn.pressed.connect(_on_init_pressed)
	_toolbar.add_child(_init_btn)

	_refresh_btn = Button.new()
	_refresh_btn.text = "⟳"
	_refresh_btn.tooltip_text = "Refresh installed packages"
	_refresh_btn.pressed.connect(_refresh_installed)
	_toolbar.add_child(_refresh_btn)

	add_child(_toolbar)

	# ── Search ──────────────────────────────────────────────────────────
	_search_bar = HBoxContainer.new()
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search packages…"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_submitted.connect(_on_search_submitted)
	_search_bar.add_child(_search_edit)

	_search_btn = Button.new()
	_search_btn.text = "Search"
	_search_btn.pressed.connect(func(): _on_search_submitted(_search_edit.text))
	_search_bar.add_child(_search_btn)

	add_child(_search_bar)

	# ── Tabs ────────────────────────────────────────────────────────────
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Installed tab
	var installed_panel := PanelContainer.new()
	installed_panel.name = "Installed"
	_installed_tree = Tree.new()
	_installed_tree.columns = 3
	_installed_tree.set_column_title(0, "Package")
	_installed_tree.set_column_title(1, "Version")
	_installed_tree.set_column_title(2, "")
	_installed_tree.set_column_expand(0, true)
	_installed_tree.set_column_expand(1, false)
	_installed_tree.set_column_expand(2, false)
	_installed_tree.set_column_custom_minimum_width(1, 80)
	_installed_tree.set_column_custom_minimum_width(2, 70)
	_installed_tree.column_titles_visible = true
	_installed_tree.button_clicked.connect(_on_installed_button_clicked)
	installed_panel.add_child(_installed_tree)
	_tabs.add_child(installed_panel)

	# Search results tab
	var search_panel := PanelContainer.new()
	search_panel.name = "Registry"
	_search_tree = Tree.new()
	_search_tree.columns = 3
	_search_tree.set_column_title(0, "Package")
	_search_tree.set_column_title(1, "Version")
	_search_tree.set_column_title(2, "")
	_search_tree.set_column_expand(0, true)
	_search_tree.set_column_expand(1, false)
	_search_tree.set_column_expand(2, false)
	_search_tree.set_column_custom_minimum_width(1, 80)
	_search_tree.set_column_custom_minimum_width(2, 70)
	_search_tree.column_titles_visible = true
	_search_tree.button_clicked.connect(_on_search_button_clicked)
	search_panel.add_child(_search_tree)
	_tabs.add_child(search_panel)

	# Info tab
	var info_panel := PanelContainer.new()
	info_panel.name = "Info"
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.text = "[i]Select a package to see details.[/i]"
	info_panel.add_child(_info_label)
	_tabs.add_child(info_panel)

	add_child(_tabs)

func _create_package_manager() -> void:
	_pm = ClassDB.instantiate("VisualGasicPackage")
	if _pm:
		_pm.initialize(_project_path)

# ── Refresh installed list ──────────────────────────────────────────────────
func _refresh_installed() -> void:
	if _installed_tree == null:
		return
	_installed_tree.clear()
	var root := _installed_tree.create_item()
	_installed_tree.hide_root = true

	if _pm == null:
		return

	var pkgs := _pm.get_installed_packages() as Dictionary
	for pkg_name in pkgs:
		var info := pkgs[pkg_name] as Dictionary
		var item := _installed_tree.create_item(root)
		item.set_text(0, str(pkg_name))
		item.set_text(1, str(info.get("version", "?")))
		item.add_button(2, _get_icon("Remove"), 0, false, "Remove")
		item.set_metadata(0, pkg_name)

func _get_icon(icon_name: String) -> Texture2D:
	# Try to get built-in editor icon; fall back to null
	var base := EditorInterface.get_base_control() if Engine.is_editor_hint() else null
	if base and base.has_theme_icon(icon_name, "EditorIcons"):
		return base.get_theme_icon(icon_name, "EditorIcons")
	return null

# ── Search ──────────────────────────────────────────────────────────────────
func _on_search_submitted(query: String) -> void:
	if query.strip_edges().is_empty() or _pm == null:
		return

	_search_tree.clear()
	var root := _search_tree.create_item()
	_search_tree.hide_root = true

	var results := _pm.search_packages(query) as Array
	for pkg in results:
		var d := pkg as Dictionary
		var item := _search_tree.create_item(root)
		item.set_text(0, str(d.get("name", "?")))
		item.set_text(1, str(d.get("version", "?")))
		item.add_button(2, _get_icon("Add"), 0, false, "Install")
		item.set_metadata(0, d.get("name", ""))

	_tabs.current_tab = 1  # Switch to Registry tab
	if results.is_empty():
		var empty_item := _search_tree.create_item(root)
		empty_item.set_text(0, "(no results)")

# ── Install from search ────────────────────────────────────────────────────
func _on_search_button_clicked(item: TreeItem, _col: int, _id: int, _mouse: int) -> void:
	var pkg_name := str(item.get_metadata(0))
	if pkg_name.is_empty():
		return
	var result := _pm.install_package(pkg_name) as Dictionary
	if result.get("success", false):
		package_installed.emit(pkg_name, str(result.get("version", "")))
		_refresh_installed()
		_show_info("[b]Installed:[/b] " + pkg_name + " " + str(result.get("version", "")))
	else:
		_show_info("[color=red]Install failed:[/color] " + str(result.get("message", "")))

# ── Remove installed ────────────────────────────────────────────────────────
func _on_installed_button_clicked(item: TreeItem, _col: int, _id: int, _mouse: int) -> void:
	var pkg_name := str(item.get_metadata(0))
	if pkg_name.is_empty():
		return
	if _pm.uninstall_package(pkg_name):
		package_removed.emit(pkg_name)
		_refresh_installed()
		_show_info("[b]Removed:[/b] " + pkg_name)
	else:
		_show_info("[color=red]Remove failed:[/color] " + pkg_name)

# ── Init manifest ──────────────────────────────────────────────────────────
func _on_init_pressed() -> void:
	if _pm == null:
		return
	var result := _pm.initialize_project(_project_path) as Dictionary
	_show_info("[b]Project initialized.[/b] vg.json created.")

func _show_info(bbcode: String) -> void:
	if _info_label:
		_info_label.text = bbcode
		_tabs.current_tab = 2  # Switch to Info tab

# ── Cleanup ─────────────────────────────────────────────────────────────────
func cleanup() -> void:
	if _pm:
		_pm.shutdown()
		_pm = null
