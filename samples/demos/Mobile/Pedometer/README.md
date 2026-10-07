# Pedometer

Run `main.tscn` to print five readings. Desktop/headless results exercise the
stub API, not a physical step counter or Android permission dialog.

On Android, grant activity-recognition permission and drive `Tick()` from a
Timer for ongoing readings. The sample currently prints to the output console;
it does not include a mobile display. Validate device counts and permission
grant/denial separately.
