class TrafficLight:
    def __init__(self):
        self.state = "RED"
    
    def advance(self):
        if self.state == "RED":
            self.state = "GREEN"
        elif self.state == "GREEN":
            self.state = "YELLOW"
        elif self.state == "YELLOW":
            self.state = "RED"
    
    def get_state(self):
        return self.state

if __name__ == '__main__':
    light = TrafficLight()
    print(light.get_state())
    
    for _ in range(7):
        light.advance()
        print(light.get_state())