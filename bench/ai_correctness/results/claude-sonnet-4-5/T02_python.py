class DoorStateMachine:
    def __init__(self):
        self.state = "CLOSED"
    
    def process_event(self, event):
        if self.state == "CLOSED":
            if event == "open":
                self.state = "OPENING"
        elif self.state == "OPENING":
            if event == "tick":
                self.state = "OPEN"
        elif self.state == "OPEN":
            if event == "close":
                self.state = "CLOSING"
        elif self.state == "CLOSING":
            if event == "tick":
                self.state = "CLOSED"
        
        return self.state

if __name__ == '__main__':
    door = DoorStateMachine()
    events = ["open", "tick", "close", "tick"]
    
    for event in events:
        result_state = door.process_event(event)
        print(result_state)