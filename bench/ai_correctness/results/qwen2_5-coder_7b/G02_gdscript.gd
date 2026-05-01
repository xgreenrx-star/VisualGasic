extends SceneTree

var counter = 0

func _ready():
    Timer1.connect("timeout", self, "_on_Timer1_timeout")
    Timer1.start()

func _on_Timer1_timeout():
    counter += 1
    lblTime.text = str(counter)
    
func _process(delta):
    pass

func quit():
    get_tree().quit()