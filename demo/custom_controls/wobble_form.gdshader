shader_type canvas_item;

// Wobble Form Shader — applies a wavy distortion to the form background.
// Attach as a ShaderMaterial on the _FormBackground Panel node.

/// How far pixels are displaced (in pixels).
uniform float amplitude : hint_range(0.0, 20.0) = 3.0;
/// How many waves fit across the panel height.
uniform float frequency : hint_range(0.0, 20.0) = 5.0;
/// Speed of the wave animation.
uniform float speed : hint_range(0.0, 10.0) = 2.0;
/// Vertical wave strength (set to 0 for horizontal-only wobble).
uniform float vertical_amplitude : hint_range(0.0, 20.0) = 1.5;
/// Vertical wave frequency.
uniform float vertical_frequency : hint_range(0.0, 20.0) = 4.0;

void vertex() {
	// Horizontal wave: displaces X based on Y position and time
	VERTEX.x += sin(TIME * speed + VERTEX.y * frequency * 0.01) * amplitude;
	// Vertical wave: displaces Y based on X position and time (offset phase)
	VERTEX.y += sin(TIME * speed * 0.8 + VERTEX.x * vertical_frequency * 0.01 + 1.57) * vertical_amplitude;
}
