shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Polar coordinates turn a circle into rotating strands around the open door.
	vec2 p = UV - vec2(0.5);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float strands = 0.5 + 0.5 * sin(angle * 4.0 - radius * 48.0 + clock * 3.0);
	float ring = exp(-pow((radius - 0.29 - sin(clock * 2.0) * 0.018) * 23.0, 2.0));
	float halo = exp(-radius * radius * 15.0) * smoothstep(0.09, 0.2, radius);
	float edge = 1.0 - smoothstep(0.38, 0.49, radius);
	vec3 light = mix(vec3(0.16, 0.18, 0.65), vec3(0.35, 0.96, 1.0), strands);
	COLOR = vec4(light, (ring * 0.7 + halo * strands * 0.5) * edge * intensity);
}
