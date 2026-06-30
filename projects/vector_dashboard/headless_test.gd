extends SceneTree

func _init():
	print("HEADLESS TEST START")
	var scene = load("res://main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	print("SCENE READY", scene.name)
	print("HAS_FIRE", scene.has_method("_FireBullet"))
	print("HAS_RENDER", scene.has_method("_RenderFrame"))
	if scene.has_method("_FireBullet"):
		scene.call("_FireBullet")
		print("FIRED BULLET")
		var bullet_x_arr = scene.get("bullet_x")
		var bullet_y_arr = scene.get("bullet_y")
		var bullet_vel_x_arr = scene.get("bullet_vel_x")
		var bullet_vel_y_arr = scene.get("bullet_vel_y")
		print("BULLET_X", bullet_x_arr)
		print("BULLET_Y", bullet_y_arr)
		print("BULLET_VEL_X", bullet_vel_x_arr)
		print("BULLET_VEL_Y", bullet_vel_y_arr)
		print("BULLET_LIFE", scene.get("bullet_life"))
	if scene.has_method("_RenderFrame"):
		scene.call("_RenderFrame")
	print("score", scene.get("score"))
	if scene.has_method("_DrawCubeDemo"):
		print("CUBE_SUPPORT", true)
	for c in scene.get_children():
		print("CHILD", c.name, c.get_class())
	quit()
