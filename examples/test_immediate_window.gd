@tool
extends EditorScript

# Test script to open the Immediate Window
func _run():
	print("=== Testing Immediate Window ===")
	print("The Immediate Window should now be available at the bottom panel.")
	print("Look for the 'Immediate' tab next to Output, Debugger, etc.")
	print("")
	print("Features to test:")
	print("1. Type: 2 + 2")
	print("2. Type: Dim x As Integer = 42")
	print("3. Type: x * 2")
	print("4. Type: :vars")
	print("5. Check Variables tab")
	print("6. Try multi-line: For i = 1 To 5 (Shift+Enter), Print i (Enter)")
	print("7. Type: GetNode(\"/root\") and check Inspector tab")
	print("8. Try :watch x * 2")
	print("")
	print("Keyboard shortcuts:")
	print("- Shift+Enter: New line")
	print("- Enter: Execute")
	print("- Ctrl+Space: Auto-complete")
	print("- Ctrl+R: Repeat last")
	print("- Up/Down: History")
