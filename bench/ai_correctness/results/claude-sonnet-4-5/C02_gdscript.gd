extends SceneTree

func _init():
    for i in range(2, 21):
        if i % 2 == 0:
            print(i)
    quit()