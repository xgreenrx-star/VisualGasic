extends SceneTree

func _init():
    print("Test: Changing scene to dodge.tscn")
    change_scene_to_file("res://dodge/dodge.tscn")
    
    # Wait a bit then quit
    await create_timer(1.0).timeout
    print("Test: Run complete")
    quit()
