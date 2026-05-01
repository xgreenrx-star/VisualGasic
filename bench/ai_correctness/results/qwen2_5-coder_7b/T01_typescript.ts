enum TrafficLight {
  RED,
  GREEN,
  YELLOW
}

function advanceTrafficLight(currentState: TrafficLight): TrafficLight {
  switch (currentState) {
    case TrafficLight.RED:
      return TrafficLight.GREEN;
    case TrafficLight.GREEN:
      return TrafficLight.YELLOW;
    case TrafficLight.YELLOW:
      return TrafficLight.RED;
    default:
      throw new Error("Invalid traffic light state");
  }
}

let currentState: TrafficLight = TrafficLight.RED;

for (let i = 0; i < 7; i++) {
  console.log(currentState);
  currentState = advanceTrafficLight(currentState);
}