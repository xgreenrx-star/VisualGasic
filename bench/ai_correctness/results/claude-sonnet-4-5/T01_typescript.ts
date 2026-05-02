type TrafficLightState = 'RED' | 'GREEN' | 'YELLOW';

class TrafficLight {
  private state: TrafficLightState;

  constructor() {
    this.state = 'RED';
  }

  getState(): TrafficLightState {
    return this.state;
  }

  advance(): void {
    switch (this.state) {
      case 'RED':
        this.state = 'GREEN';
        break;
      case 'GREEN':
        this.state = 'YELLOW';
        break;
      case 'YELLOW':
        this.state = 'RED';
        break;
    }
  }
}

const light = new TrafficLight();
console.log(light.getState());

for (let i = 0; i < 7; i++) {
  light.advance();
  console.log(light.getState());
}