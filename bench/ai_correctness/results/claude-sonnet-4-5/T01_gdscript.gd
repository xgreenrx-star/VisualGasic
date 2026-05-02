extends SceneTree

enum State { RED, GREEN, YELLOW }

var current_state = State.RED

func _init():
    print_state()
    for i in range(7):
        advance_state()
        print_state()
    quit()

func advance_state():
    match current_state:
        State.RED:
            current_state = State.GREEN
        State.GREEN:
            current_state = State.YELLOW
        State.YELLOW:
            current_state = State.RED

func print_state():
    match current_state:
        State.RED:
            print("RED")
        State.GREEN:
            print("GREEN")
        State.YELLOW:
            print("YELLOW")