@tool
extends EditorPlugin

func _enter_tree() -> void:
	call_deferred("_quit_after_scan")

func _quit_after_scan() -> void:
	await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	print("DOC-TEARDOWN: filesystem scan completed; quitting")
	get_tree().quit()
