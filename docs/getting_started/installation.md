# Installation

Visual Gasic is distributed as a **GDExtension**. This means it adds functionality to Godot using native C++ code without requiring you to recompile the engine itself.

## Prerequisites

*   **Godot Engine 4.1 or newer**.
*   A created Godot project.

## Installing via GitHub / ZIP

If you have downloaded the release ZIP file (e.g. `visual_gasic_v1.0.zip`):

1.  **Extract the ZIP file**. You should see a folder named `addons`.
2.  **Copy the folder**. Drag and drop the `addons` folder into your Godot project's root directory.
    *   If you already have an `addons` folder, merge them (copy `addons/visual_gasic` into `your_project/addons/visual_gasic`).
3.  **Restart Godot**. GDExtensions are loaded when the editor starts.
4.  **Verify Setup**. In the FileSystem dock, verify that `addons/visual_gasic` exists. You can now create a **VisualGasic** script by right-clicking in the FileSystem -> New Resource -> VisualGasic.

## Troubleshooting

### "Unable to load GDExtension"
Ensure you downloaded the correct version for your operating system (Windows, Linux, or macOS).

### "VisualGasic resource not found"
Try restarting the editor one more time. Sometimes the resource cache needs a full reload to detect new classes.
