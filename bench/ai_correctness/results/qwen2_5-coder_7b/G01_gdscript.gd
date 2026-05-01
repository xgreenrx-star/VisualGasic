extends SceneTree

func _ready():
    pass

func _on_Button_pressed():
    lblStatus.text += "\nButton clicked at " + str(OS.get_datetime())