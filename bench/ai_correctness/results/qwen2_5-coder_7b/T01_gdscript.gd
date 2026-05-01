extends SceneTree

enum TrafficLightState { RED, GREEN, YELLOW }

var current_state = TrafficLightState.RED

func _init():
    for i in range(7):
        process_state()
        yield(get_tree(), "idle_frame")

func process_state():
    match current_state:
        TrafficLightState.RED:
            print("RED")
            current_state = TrafficLightState.GREEN
        TrafficLightState.GREEN:
            print("GREEN")
            current_state = TrafficLightState.YELLOW
        TrafficLightState.YELLOW:
            print("YELLOW")
            current_state = TrafficLightState.RED

func _ready():
    quit()