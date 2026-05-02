extends SceneTree

func _init():
	var button = Button.new()
	var lblStatus = Label.new()
	
	button.pressed.connect(func(): on_button_clicked(lblStatus))
	
	button.emit_signal("pressed")
	
	print(lblStatus.text)
	quit()

func on_button_clicked(lblStatus):
	lblStatus.text += "Button clicked\n"