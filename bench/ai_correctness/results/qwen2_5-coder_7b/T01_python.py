class TrafficLight:
    RED = 0
    GREEN = 1
    YELLOW = 2

    def __init__(self):
        self.state = self.RED

    def advance(self):
        if self.state == self.RED:
            self.state = self.GREEN
        elif self.state == self.GREEN:
            self.state = self.YELLOW
        else:
            self.state = self.RED

if __name__ == '__main__':
    traffic_light = TrafficLight()
    for _ in range(7):
        print(TrafficLight.__dict__[traffic_light.state])
        traffic_light.advance()