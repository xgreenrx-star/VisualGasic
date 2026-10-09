shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float seed = 0.0;
uniform float falling = 0.0;

void vertex() {
	// Rotate only the drawn sprite; collision remains on the unchanged VG grid.
	float angle = sin(clock * mix(2.3, 17.0, falling) + seed) * mix(0.012, 0.045, falling);
	float c = cos(angle);
	float s = sin(angle);
	VERTEX = vec2(c * VERTEX.x - s * VERTEX.y, s * VERTEX.x + c * VERTEX.y);
}
