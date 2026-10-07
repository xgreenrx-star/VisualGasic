# VGAI Demo

A minimal VisualGasic project demonstrating the `GDAI`/VGAI integration.

## How to use

1. Open this folder as a Godot project.
2. Configure GDAI under Project Properties → GDAI, including endpoint and model.
   Enable `vg/gdai/enabled` only after configuration; it is disabled by default.
3. Run `main.tscn`.
4. Press **Ask VGAI** to send a completion request.

## Notes

- The demo uses `GDAI.initialize_from_project_settings()` so you can set provider, API key, endpoint, and model from the project settings UI.
- If GDAI is not configured, the button remains disabled.
- No credentials are included. Do not commit API keys into the project file.
