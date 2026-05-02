interface Label {
  text: string;
}

interface Timer {
  interval: number;
  enabled: boolean;
  onTimer: (() => void) | null;
}

declare const Timer1: Timer;
declare const lblTime: Label;

let counter: number = 0;

function updateTime(): void {
  counter++;
  lblTime.text = counter.toString();
  console.log(counter);
}

Timer1.interval = 1000;
Timer1.onTimer = updateTime;
Timer1.enabled = true;