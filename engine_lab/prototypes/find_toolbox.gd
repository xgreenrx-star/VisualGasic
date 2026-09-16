@tool
extends EditorScript

func _run():
	var base = EditorInterface.get_base_control()
	if not base:
		print("No base control found.")
		return

	print("Searching for Toolbox in Editor UI Tree...")
	find_node_by_name(base, "Toolbox")

func find_node_by_name(node: Node, target_name: String):
	if node.name == target_name:
		print_node_info(node)
	
	for child in node.get_children():
		find_node_by_name(child, target_name)

func print_node_info(node: Node):
	print("--- FOUND NODE ---")
	print("Name: ", node.name)
	print("Class: ", node.get_class())
	print("Path: ", node.get_path())
	if node is Control:
		print("Visible: ", node.visible)
		print("Size: ", node.size)
		print("Position: ", node.position)
		print("Rect: ", node.get_global_rect())
		print("Parent: ", node.get_parent().name)
		print("Parent Class: ", node.get_parent().get_class())
