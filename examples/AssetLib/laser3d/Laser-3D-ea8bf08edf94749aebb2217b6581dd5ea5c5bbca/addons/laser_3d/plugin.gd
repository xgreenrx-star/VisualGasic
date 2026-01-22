@tool
extends EditorPlugin


var main_script = preload("res://addons/laser_3d/laser_3d.gd")
var laser_result_script = preload("res://addons/laser_3d/laser_result.gd")
var icon = preload("res://addons/laser_3d/icon.svg")


func _enable_plugin() -> void:
	add_custom_type("Laser3D", "Node3D", main_script, icon)
	add_custom_type("LaserResult", "RefCounted", laser_result_script, null)


func _disable_plugin() -> void:
	remove_custom_type("Laser3D")
	remove_custom_type("LaserResult")
