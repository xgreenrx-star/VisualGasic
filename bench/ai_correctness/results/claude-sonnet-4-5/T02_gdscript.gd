extends SceneTree

enum State { CLOSED, OPENING, OPEN, CLOSING }

var current_state = State.CLOSED

func _init():
	process_event("open")
	process_event("tick")
	process_event("close")
	process_event("tick")
	quit()

func process_event(event: String):
	match current_state:
		State.CLOSED:
			if event == "open":
				current_state = State.OPENING
		State.OPENING:
			if event == "tick":
				current_state = State.OPEN
			elif event == "close":
				current_state = State.CLOSING
		State.OPEN:
			if event == "close":
				current_state = State.CLOSING
		State.CLOSING:
			if event == "tick":
				current_state = State.CLOSED
			elif event == "open":
				current_state = State.OPENING
	
	print(State.keys()[current_state])