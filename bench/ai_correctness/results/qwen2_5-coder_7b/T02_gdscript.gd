extends SceneTree

enum DoorState {
    CLOSED,
    OPENING,
    OPEN,
    CLOSING
}

var state = DoorState.CLOSED

func _ready():
    process_event_sequence()

func process_event_sequence():
    var events = ["open", "tick", "close", "tick"]
    for event in events:
        if event == "open":
            open()
        elif event == "close":
            close()
        elif event == "tick":
            tick()
        print("Current state: ", state_to_string(state))
    quit()

func open():
    match state:
        DoorState.CLOSED:
            state = DoorState.OPENING
        DoorState.CLOSING:
            state = DoorState.OPENING

func close():
    match state:
        DoorState.OPEN:
            state = DoorState.CLOSING
        DoorState.OPENING:
            state = DoorState.CLOSING

func tick():
    match state:
        DoorState.OPENING:
            if state == DoorState.OPENING:
                state = DoorState.OPEN
        DoorState.CLOSING:
            if state == DoorState.CLOSING:
                state = DoorState.CLOSED

func state_to_string(state):
    match state:
        DoorState.CLOSED: return "CLOSED"
        DoorState.OPENING: return "OPENING"
        DoorState.OPEN: return "OPEN"
        DoorState.CLOSING: return "CLOSING"