shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Powered light-wall: an energy wave runs along the wall plus a fast mains hum.
// `power` is driven by the controller (1 = on, 0 = dark) for the shutdown blink.
uniform vec4 tint : source_color = vec4(0.25, 0.95, 1.0, 1.0);
uniform float energy = 3.6;
uniform float power = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wave = 0.5 + 0.5 * sin((world_pos.x + world_pos.z) * 0.45 - TIME * 8.0);
	float hum = 0.92 + 0.08 * sin(TIME * 31.0);
	float edge = 0.85 + 0.35 * smoothstep(0.35, 0.55, world_pos.y);
	ALBEDO = tint.rgb * energy * (0.62 + 0.5 * wave) * hum * edge * power;
}
