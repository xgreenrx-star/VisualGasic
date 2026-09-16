extends SceneTree

func _init():
	print("Checking ClassDB...")
	if ClassDB.class_exists("VisualGasicEditorPlugin"):
		print("SUCCESS: VisualGasicEditorPlugin class exists.")
	else:
		print("FAILURE: VisualGasicEditorPlugin class NOT found.")
	
	if ClassDB.class_exists("VisualGasicToolbox"):
		print("SUCCESS: VisualGasicToolbox class exists.")
	else:
		print("FAILURE: VisualGasicToolbox class NOT found.")
		
	quit()
