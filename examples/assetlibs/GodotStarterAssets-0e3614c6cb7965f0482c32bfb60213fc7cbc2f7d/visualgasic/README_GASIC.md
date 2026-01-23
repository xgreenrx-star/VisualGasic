# Gasic Conversion for Godot Starter Assets

This folder contains Gasic versions of the First Person and Third Person controllers from the Godot Starter Assets project.

## Files
- first_person_controller.bas
- third_person_controller.bas

## Notes
- All variable types are explicitly defined.
- Initial logic for input handling and camera setup is included.
- Some Godot-specific features (e.g., @export, @onready) are adapted for Gasic.
- Further logic and feature mapping may be required for full parity.

## Integration
To use these scripts in Godot with the VisualGasic extension:
1. Copy the VisualGasic extension files (e.g., libvisualgasic.linux.template_debug.x86_64.so) into this project directory.
2. Add the Gasic scripts to your Godot project and set up nodes as required.
3. Test and iterate to ensure all features are supported and working.
