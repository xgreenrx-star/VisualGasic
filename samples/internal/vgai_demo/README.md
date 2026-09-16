# VGAI Demo

A minimal VisualGasic project demonstrating the `GDAI`/VGAI integration.

## How to use

1. Open this folder as a Godot project.
2. Configure GDAI under Project Properties → GDAI.
3. Run `main.tscn`.
4. Press **Ask VGAI** to send a completion request.

## Notes

- The demo uses `GDAI.initialize_from_project_settings()` so you can set provider, API key, endpoint, and model from the project settings UI.
- If GDAI is not configured, the button remains disabled.
