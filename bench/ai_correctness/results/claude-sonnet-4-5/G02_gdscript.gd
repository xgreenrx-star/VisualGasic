extends SceneTree

var counter = 0
var timer = null
var label = null

func _init():
	var root = Root.new()
	get_root().add_child(root)
	
	timer = Timer.new()
	timer.name = "Timer1"
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	root.add_child(timer)
	
	label = Label.new()
	label.name = "lblTime"
	root.add_child(label)
	
	timer.start()
	
	await get_root().create_timer(5.0).timeout
	
	print("Final counter value: " + str(counter))
	print("Final label text: " + label.text)
	quit()

func _on_timer_timeout():
	counter += 1
	label.text = str(counter)
	print("Counter: " + str(counter))

class Root extends Node:
	pass