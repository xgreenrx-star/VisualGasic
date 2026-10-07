extends Node

func _ready() -> void:
	var instance := Node.new()
	instance.name = "VGFixture"
	instance.set_script(load("res://addons/lifecycle_test/fixture.vg"))
	add_child(instance)
	EngineDebugger.send_message("visualgasic:instances", [["lifecycle-fixture"]])
