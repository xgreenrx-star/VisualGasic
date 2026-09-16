@tool
extends RefCounted
## Registers native Godot 2D/3D toolbox entries with sub-tab groups.

const BASE_2D := "res://addons/visual_gasic/prototypes/godot2d/"
const BASE_3D := "res://addons/visual_gasic/prototypes/godot3d/"

## group = sub-tab inside the Godot 2D / Godot 3D main tab
const GODOT_2D_TOOLS: Array[Dictionary] = [
	# ── Node2D (spatial / drawable) ──
	{"name": "Pointer", "class": "", "icon": "ToolSelect", "scene": "", "group": "Node2D"},
	{"name": "Node2D", "class": "Node2D", "icon": "Node2D", "scene": "Node2D.tscn", "group": "Node2D"},
	{"name": "Sprite2D", "class": "Sprite2D", "icon": "Sprite2D", "scene": "Sprite2D.tscn", "group": "Node2D"},
	{"name": "AnimatedSprite2D", "class": "AnimatedSprite2D", "icon": "AnimatedSprite2D", "scene": "AnimatedSprite2D.tscn", "group": "Node2D"},
	{"name": "Camera2D", "class": "Camera2D", "icon": "Camera2D", "scene": "Camera2D.tscn", "group": "Node2D"},
	{"name": "Line2D", "class": "Line2D", "icon": "Line2D", "scene": "Line2D.tscn", "group": "Node2D"},
	{"name": "Polygon2D", "class": "Polygon2D", "icon": "Polygon2D", "scene": "Polygon2D.tscn", "group": "Node2D"},
	{"name": "Marker2D", "class": "Marker2D", "icon": "Marker2D", "scene": "Marker2D.tscn", "group": "Node2D"},
	{"name": "TileMapLayer", "class": "TileMapLayer", "icon": "TileMap", "scene": "TileMapLayer.tscn", "group": "Node2D"},
	{"name": "Parallax2D", "class": "Parallax2D", "icon": "Parallax2D", "scene": "Parallax2D.tscn", "group": "Node2D"},
	{"name": "Light2D", "class": "PointLight2D", "icon": "PointLight2D", "scene": "PointLight2D.tscn", "group": "Node2D"},
	{"name": "CPUParticles2D", "class": "CPUParticles2D", "icon": "CPUParticles2D", "scene": "CPUParticles2D.tscn", "group": "Node2D"},
	{"name": "GPUParticles2D", "class": "GPUParticles2D", "icon": "GPUParticles2D", "scene": "GPUParticles2D.tscn", "group": "Node2D"},
	# ── Controls (CanvasItem UI) ──
	{"name": "Button", "class": "Button", "icon": "Button", "scene": "Button.tscn", "group": "Controls"},
	{"name": "Label", "class": "Label", "icon": "Label", "scene": "Label.tscn", "group": "Controls"},
	{"name": "LineEdit", "class": "LineEdit", "icon": "LineEdit", "scene": "LineEdit.tscn", "group": "Controls"},
	{"name": "TextEdit", "class": "TextEdit", "icon": "TextEdit", "scene": "TextEdit.tscn", "group": "Controls"},
	{"name": "RichTextLabel", "class": "RichTextLabel", "icon": "RichTextLabel", "scene": "RichTextLabel.tscn", "group": "Controls"},
	{"name": "CheckBox", "class": "CheckBox", "icon": "CheckBox", "scene": "CheckBox.tscn", "group": "Controls"},
	{"name": "OptionButton", "class": "OptionButton", "icon": "OptionButton", "scene": "OptionButton.tscn", "group": "Controls"},
	{"name": "ProgressBar", "class": "ProgressBar", "icon": "ProgressBar", "scene": "ProgressBar.tscn", "group": "Controls"},
	{"name": "HSlider", "class": "HSlider", "icon": "HSlider", "scene": "HSlider.tscn", "group": "Controls"},
	{"name": "VSlider", "class": "VSlider", "icon": "VSlider", "scene": "VSlider.tscn", "group": "Controls"},
	{"name": "HScrollBar", "class": "HScrollBar", "icon": "HScrollBar", "scene": "HScrollBar.tscn", "group": "Controls"},
	{"name": "VScrollBar", "class": "VScrollBar", "icon": "VScrollBar", "scene": "VScrollBar.tscn", "group": "Controls"},
	{"name": "SpinBox", "class": "SpinBox", "icon": "SpinBox", "scene": "SpinBox.tscn", "group": "Controls"},
	{"name": "TextureRect", "class": "TextureRect", "icon": "TextureRect", "scene": "TextureRect.tscn", "group": "Controls"},
	{"name": "ColorRect", "class": "ColorRect", "icon": "ColorRect", "scene": "ColorRect.tscn", "group": "Controls"},
	{"name": "Panel", "class": "Panel", "icon": "Panel", "scene": "Panel.tscn", "group": "Controls"},
	{"name": "NinePatchRect", "class": "NinePatchRect", "icon": "NinePatchRect", "scene": "NinePatchRect.tscn", "group": "Controls"},
	{"name": "ItemList", "class": "ItemList", "icon": "ItemList", "scene": "ItemList.tscn", "group": "Controls"},
	{"name": "Tree", "class": "Tree", "icon": "Tree", "scene": "Tree.tscn", "group": "Controls"},
	{"name": "TabContainer", "class": "TabContainer", "icon": "TabContainer", "scene": "TabContainer.tscn", "group": "Controls"},
	{"name": "TabBar", "class": "TabBar", "icon": "TabBar", "scene": "TabBar.tscn", "group": "Controls"},
	{"name": "MenuBar", "class": "MenuBar", "icon": "MenuBar", "scene": "MenuBar.tscn", "group": "Controls"},
	{"name": "VideoPlayer", "class": "VideoStreamPlayer", "icon": "VideoStreamPlayer", "scene": "VideoStreamPlayer.tscn", "group": "Controls"},
	{"name": "GraphEdit", "class": "GraphEdit", "icon": "GraphEdit", "scene": "GraphEdit.tscn", "group": "Controls"},
	{"name": "ReferenceRect", "class": "ReferenceRect", "icon": "ReferenceRect", "scene": "ReferenceRect.tscn", "group": "Controls"},
	{"name": "HSeparator", "class": "HSeparator", "icon": "HSeparator", "scene": "HSeparator.tscn", "group": "Controls"},
	{"name": "VSeparator", "class": "VSeparator", "icon": "VSeparator", "scene": "VSeparator.tscn", "group": "Controls"},
	{"name": "ColorPicker", "class": "ColorPickerButton", "icon": "ColorPickerButton", "scene": "ColorPickerButton.tscn", "group": "Controls"},
	{"name": "LinkButton", "class": "LinkButton", "icon": "LinkButton", "scene": "LinkButton.tscn", "group": "Controls"},
	{"name": "TextureButton", "class": "TextureButton", "icon": "TextureButton", "scene": "TextureButton.tscn", "group": "Controls"},
	{"name": "TextureProgressBar", "class": "TextureProgressBar", "icon": "TextureProgressBar", "scene": "TextureProgressBar.tscn", "group": "Controls"},
	# ── Containers ──
	{"name": "HBox", "class": "HBoxContainer", "icon": "HBoxContainer", "scene": "HBoxContainer.tscn", "group": "Containers"},
	{"name": "VBox", "class": "VBoxContainer", "icon": "VBoxContainer", "scene": "VBoxContainer.tscn", "group": "Containers"},
	{"name": "Grid", "class": "GridContainer", "icon": "GridContainer", "scene": "GridContainer.tscn", "group": "Containers"},
	{"name": "Margin", "class": "MarginContainer", "icon": "MarginContainer", "scene": "MarginContainer.tscn", "group": "Containers"},
	{"name": "PanelContainer", "class": "PanelContainer", "icon": "PanelContainer", "scene": "PanelContainer.tscn", "group": "Containers"},
	{"name": "ScrollContainer", "class": "ScrollContainer", "icon": "ScrollContainer", "scene": "ScrollContainer.tscn", "group": "Containers"},
	{"name": "HSplit", "class": "HSplitContainer", "icon": "HSplitContainer", "scene": "HSplitContainer.tscn", "group": "Containers"},
	{"name": "VSplit", "class": "VSplitContainer", "icon": "VSplitContainer", "scene": "VSplitContainer.tscn", "group": "Containers"},
	{"name": "SubViewport", "class": "SubViewportContainer", "icon": "SubViewportContainer", "scene": "SubViewportContainer.tscn", "group": "Containers"},
	{"name": "Center", "class": "CenterContainer", "icon": "CenterContainer", "scene": "CenterContainer.tscn", "group": "Containers"},
	{"name": "Flow", "class": "FlowContainer", "icon": "FlowContainer", "scene": "FlowContainer.tscn", "group": "Containers"},
	{"name": "AspectRatio", "class": "AspectRatioContainer", "icon": "AspectRatioContainer", "scene": "AspectRatioContainer.tscn", "group": "Containers"},
	# ── Layers ──
	{"name": "CanvasLayer", "class": "CanvasLayer", "icon": "CanvasLayer", "scene": "CanvasLayer.tscn", "group": "Layers"},
	# ── Physics ──
	{"name": "Area2D", "class": "Area2D", "icon": "Area2D", "scene": "Area2D.tscn", "group": "Physics"},
	{"name": "StaticBody2D", "class": "StaticBody2D", "icon": "StaticBody2D", "scene": "StaticBody2D.tscn", "group": "Physics"},
	{"name": "CharacterBody2D", "class": "CharacterBody2D", "icon": "CharacterBody2D", "scene": "CharacterBody2D.tscn", "group": "Physics"},
	{"name": "RigidBody2D", "class": "RigidBody2D", "icon": "RigidBody2D", "scene": "RigidBody2D.tscn", "group": "Physics"},
	# ── Audio ──
	{"name": "Audio2D", "class": "AudioStreamPlayer2D", "icon": "AudioStreamPlayer2D", "scene": "AudioStreamPlayer2D.tscn", "group": "Audio"},
	# ── Other nodes ──
	{"name": "Timer", "class": "Timer", "icon": "Timer", "scene": "Timer.tscn", "group": "Nodes"},
	{"name": "AudioStreamPlayer", "class": "AudioStreamPlayer", "icon": "AudioStreamPlayer", "scene": "AudioStreamPlayer.tscn", "group": "Nodes"},
	{"name": "VisibleNotifier2D", "class": "VisibleOnScreenNotifier2D", "icon": "VisibleOnScreenNotifier2D", "scene": "VisibleOnScreenNotifier2D.tscn", "group": "Nodes"},
	{"name": "RemoteTransform2D", "class": "RemoteTransform2D", "icon": "RemoteTransform2D", "scene": "RemoteTransform2D.tscn", "group": "Nodes"},
]

const GODOT_3D_TOOLS: Array[Dictionary] = [
	{"name": "Pointer", "class": "", "icon": "ToolSelect", "scene": "", "group": "Meshes"},
	{"name": "Box", "class": "MeshInstance3D", "icon": "BoxMesh", "scene": "Box.tscn", "group": "Meshes"},
	{"name": "Sphere", "class": "MeshInstance3D", "icon": "SphereMesh", "scene": "Sphere.tscn", "group": "Meshes"},
	{"name": "Capsule", "class": "MeshInstance3D", "icon": "CapsuleMesh", "scene": "Capsule.tscn", "group": "Meshes"},
	{"name": "Cylinder", "class": "MeshInstance3D", "icon": "CylinderMesh", "scene": "Cylinder.tscn", "group": "Meshes"},
	{"name": "OmniLight3D", "class": "OmniLight3D", "icon": "OmniLight3D", "scene": "Light.tscn", "group": "Lights"},
	{"name": "DirectionalLight3D", "class": "DirectionalLight3D", "icon": "DirectionalLight3D", "scene": "DirectionalLight3D.tscn", "group": "Lights"},
	{"name": "SpotLight3D", "class": "SpotLight3D", "icon": "SpotLight3D", "scene": "SpotLight3D.tscn", "group": "Lights"},
	{"name": "Camera3D", "class": "Camera3D", "icon": "Camera3D", "scene": "Camera.tscn", "group": "Camera"},
	{"name": "Area3D", "class": "Area3D", "icon": "Area3D", "scene": "Area3D.tscn", "group": "Physics"},
	{"name": "StaticBody3D", "class": "StaticBody3D", "icon": "StaticBody3D", "scene": "StaticBody3D.tscn", "group": "Physics"},
	{"name": "CharacterBody3D", "class": "CharacterBody3D", "icon": "CharacterBody3D", "scene": "CharacterBody3D.tscn", "group": "Physics"},
	{"name": "Audio3D", "class": "AudioStreamPlayer3D", "icon": "AudioStreamPlayer3D", "scene": "Sound3D.tscn", "group": "Audio"},
	{"name": "Sprite3D", "class": "Sprite3D", "icon": "Sprite3D", "scene": "Sprite3D.tscn", "group": "Other"},
	{"name": "Label3D", "class": "Label3D", "icon": "Label3D", "scene": "Text3D.tscn", "group": "Other"},
]


static func register_all(register_fn: Callable) -> void:
	for entry in GODOT_2D_TOOLS:
		var scene := BASE_2D + str(entry["scene"]) if not str(entry["scene"]).is_empty() else ""
		register_fn.call(entry["name"], entry["class"], entry["icon"], scene, "Godot 2D", entry.get("group", "Node2D"))
	for entry in GODOT_3D_TOOLS:
		var scene := BASE_3D + str(entry["scene"]) if not str(entry["scene"]).is_empty() else ""
		register_fn.call(entry["name"], entry["class"], entry["icon"], scene, "Godot 3D", entry.get("group", "Meshes"))


static func is_godot_scene_tool(category: String) -> bool:
	return category == "Godot 2D" or category == "Godot 3D" or category == "3D"


static func is_godot_native_scene_path(scene_path: String) -> bool:
	return scene_path.contains("/prototypes/godot2d/") or scene_path.contains("/prototypes/godot3d/")


static func is_form_toolbox_class(godot_class: String) -> bool:
	if godot_class.is_empty():
		return true
	return ClassDB.is_parent_class(godot_class, "Control") or godot_class == "Node" or godot_class == "Timer" or godot_class == "FileDialog"
