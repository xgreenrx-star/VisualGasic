# Tilt Maze

Run `main.tscn` to print an ASCII maze and simulate 60 update steps.
When acceleration is near zero, the sample deliberately uses a fixed nudge.
This is a console demonstration, not a rendered or continuously running game.

On a device, drive `Step()` from a Timer and supply real sensor readings.
Desktop/headless validation does not certify accelerometer units, physical
orientation, touch input, or Android exports.
