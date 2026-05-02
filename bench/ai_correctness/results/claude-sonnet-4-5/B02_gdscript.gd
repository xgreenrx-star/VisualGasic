extends SceneTree

func _init():
	var name: String = "Alice"
	var age: int = 25
	var height: float = 1.75
	
	print("Name: " + name)
	print("Age: " + str(age))
	print("Height: " + str(height))
	
	quit()