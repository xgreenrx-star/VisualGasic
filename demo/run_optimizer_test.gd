extends MainLoop

func _initialize():
	print("=== Optimizer Test ===")
	
	var vg = load("res://addons/visual_gasic/visual_gasic.gdextension")
	
	# Create a test script with patterns the optimizer should catch
	var code = """
Option Explicit

Dim result As Integer
Dim x As Integer
Dim y As Integer

Sub Main()
    ' Constant folding: 2 + 3 should fold to 5
    result = 2 + 3
    
    ' Identity ops: x + 0, x * 1
    x = 10
    y = x + 0
    y = x * 1
    
    ' Double negation
    If Not Not (x > 5) Then
        result = 1
    End If
    
    ' Strength reduction: x * -1
    y = x * -1
    
    ' Simple loop
    Dim i As Integer
    Dim total As Integer
    total = 0
    For i = 1 To 100
        total = total + i
    Next i
    
    Print total
End Sub
"""
	
	var script_res = ClassDB.instantiate("VisualGasicScript")
	if script_res:
		script_res.set("source_code", code)
		var err = script_res.call("reload")
		print("Reload: ", err)
		
		var node = Node2D.new()
		node.set_script(script_res)
		
		var tree = Engine.get_main_loop()
		if tree is SceneTree:
			tree.root.add_child(node)
		else:
			print("Headless mode — triggering _Ready manually")
		
		print("=== Test Complete ===")
	else:
		print("FAIL: Could not create VisualGasicScript")
	
	print("Quitting...")

func _process(_delta):
	return true
