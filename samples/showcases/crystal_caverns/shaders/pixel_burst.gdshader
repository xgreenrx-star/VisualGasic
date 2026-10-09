shader_type canvas_item;
render_mode unshaded;

uniform float elapsed = 0.0;
uniform vec2 velocity = vec2(0.0);

void vertex() {
	// Ballistic motion: distance = velocity * time, plus downward gravity.
	VERTEX += velocity * elapsed + vec2(0.0, 13.0 * elapsed * elapsed);
}

void fragment() {
	// Keep the original DATA tint and transparency; fade only the alpha.
	COLOR.a *= 1.0 - smoothstep(0.5, 1.15, elapsed);
}
