extends SceneTree

var stage: Node
var ending := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var resource := load("res://opening_bar_study.tscn") as PackedScene
	if resource == null:
		push_error("Cannot load bar study for movie export")
		quit(1)
		return
	stage = resource.instantiate()
	if stage.get_script() == null:
		push_error("Bar study script failed to compile")
		stage.free()
		quit(1)
		return
	root.add_child(stage)
	await process_frame
	if not stage.ready_for_review:
		stage.free()
		quit(1)
		return
	stage.set_presentation_mode()
	stage.toggle_playback()

func _process(_delta: float) -> bool:
	if not is_instance_valid(stage) or ending or not stage.finished:
		return false
	ending = true
	_finish.call_deferred()
	return false

func _finish() -> void:
	stage.free()
	await create_timer(0.2).timeout
	print("BAR_STUDY_MOVIE_COMPLETE")
	quit()
