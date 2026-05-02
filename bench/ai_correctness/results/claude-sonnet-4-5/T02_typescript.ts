type DoorState = 'CLOSED' | 'OPENING' | 'OPEN' | 'CLOSING';
type DoorEvent = 'open' | 'close' | 'tick';

class DoorStateMachine {
  private state: DoorState;

  constructor(initialState: DoorState = 'CLOSED') {
    this.state = initialState;
  }

  getState(): DoorState {
    return this.state;
  }

  processEvent(event: DoorEvent): void {
    switch (this.state) {
      case 'CLOSED':
        if (event === 'open') {
          this.state = 'OPENING';
        }
        break;
      case 'OPENING':
        if (event === 'tick') {
          this.state = 'OPEN';
        }
        break;
      case 'OPEN':
        if (event === 'close') {
          this.state = 'CLOSING';
        }
        break;
      case 'CLOSING':
        if (event === 'tick') {
          this.state = 'CLOSED';
        }
        break;
    }
  }
}

const door = new DoorStateMachine('CLOSED');
const events: DoorEvent[] = ['open', 'tick', 'close', 'tick'];

for (const event of events) {
  door.processEvent(event);
  console.log(door.getState());
}