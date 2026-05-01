enum State { CLOSED, OPENING, OPEN, CLOSING }

class DoorStateMachine {
    private state: State;

    constructor() {
        this.state = State.CLOSED;
    }

    processEvent(event: string): void {
        switch (this.state) {
            case State.CLOSED:
                if (event === 'open') {
                    this.state = State.OPENING;
                    console.log('OPENING');
                } else if (event === 'close') {
                    console.log('CLOSED');
                }
                break;
            case State.OPENING:
                if (event === 'tick') {
                    this.state = State.OPEN;
                    console.log('OPEN');
                } else if (event === 'close') {
                    this.state = State.CLOSING;
                    console.log('CLOSING');
                }
                break;
            case State.OPEN:
                if (event === 'tick') {
                    console.log('OPEN');
                } else if (event === 'close') {
                    this.state = State.CLOSING;
                    console.log('CLOSING');
                }
                break;
            case State.CLOSING:
                if (event === 'tick') {
                    this.state = State.CLOSED;
                    console.log('CLOSED');
                } else if (event === 'open') {
                    this.state = State.OPENING;
                    console.log('OPENING');
                }
                break;
        }
    }
}

const door = new DoorStateMachine();
door.processEvent('open');
door.processEvent('tick');
door.processEvent('close');
door.processEvent('tick');