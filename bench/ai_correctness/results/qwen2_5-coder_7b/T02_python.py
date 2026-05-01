class DoorStateMachine:
    def __init__(self):
        self.state = 'CLOSED'

    def open(self):
        if self.state == 'CLOSED':
            self.state = 'OPENING'
            print('OPENING')
        elif self.state == 'CLOSING':
            self.state = 'OPENING'
            print('OPENING')

    def close(self):
        if self.state == 'OPEN':
            self.state = 'CLOSING'
            print('CLOSING')
        elif self.state == 'OPENING':
            self.state = 'CLOSING'
            print('CLOSING')

    def tick(self):
        if self.state == 'OPENING':
            self.state = 'OPEN'
            print('OPEN')
        elif self.state == 'CLOSING':
            self.state = 'CLOSED'
            print('CLOSED')

if __name__ == '__main__':
    door = DoorStateMachine()
    events = ['open', 'tick', 'close', 'tick']
    for event in events:
        if event == 'open':
            door.open()
        elif event == 'close':
            door.close()
        elif event == 'tick':
            door.tick()