# Mobile Demos — Pass 4 sensor showcase

Short, runnable VG programs that exercise the Pass 4 phone surface
(`Screen`, `Sensor`, `Joypad`, `Touch`, `Permission`, `GPS`, `Steps`,
`Vibrate`). Each demo runs on:

| Target | Behavior |
| --- | --- |
| **Android** | Live sensor / step counter / haptics |
| **Desktop** | Sensor reads return zero / stub values; demo still runs end-to-end |
| **Headless smoke** | Loops a fixed number of frames printing state — usable as a CI smoke test |

## Demos

### `TiltMaze/`
A ball rolls through an ASCII maze, accelerated by phone tilt
(`Sensor.Accel`).  Walls reflect velocity; reaching the `G` cell
prints a win.  Falls back to a synthesised tilt vector so the demo
makes visible progress on desktop / CI.

Run from the IDE: open `TiltMaze/project.godot` and press ▶.
Smoke headless: `cp main.vg ../../../test_proj/_tilt_smoke.vg`
then run the suite runner with that file.

### `Pedometer/`
Step counter against a configurable daily goal.  Uses
`Permission.Request("activity_recognition")` to surface the Android
runtime prompt, then polls `Steps.Today` / `Steps.Total`.  Celebrates
every 1,000-step milestone with `Vibrate(80)` and the daily goal with
`Vibrate(200)`.  `Permission_Granted` / `Permission_Denied` global
subs are wired and will fire once the Android plugin ships.

## Android deployment (when plugin lands)

These demos compile and dispatch every verb today.  Live sensor /
step / GPS data requires the **VisualGasic Android plugin** (JNI +
Kotlin bridge — on the roadmap).  No VG code changes will be needed:
the verbs already point at the right paths in the runtime — only the
platform side of `Sensor.Accel`, `Steps.Today`, `GPS.Lat`, and the
`Permission_Granted` signal source need backing.
