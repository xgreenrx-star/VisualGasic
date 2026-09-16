shader_type canvas_item;

// Geometry Dash–inspired neon grid: dark base, cyan/magenta grid, horizon pulse.
uniform float scroll : hint_range(0.0, 200.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 grid_a : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform vec4 grid_b : source_color = vec4(1.0, 0.15, 0.85, 1.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	vec3 bg = mix(vec3(0.015, 0.02, 0.05), vec3(0.06, 0.0, 0.10), uv.y);
	bg += vec3(0.04, 0.02, 0.08) * (1.0 - uv.y);

	float gx = fract(uv.x * 28.0 - scroll * 0.004 - t * 0.35);
	float gy = fract(uv.y * 16.0);
	float line = max(step(0.965, gx), step(0.965, gy) * step(uv.y, 0.78));

	vec3 gc = mix(grid_a.rgb, grid_b.rgb, sin(t * 1.8 + uv.y * 8.0) * 0.5 + 0.5);
	bg += gc * line * (0.28 + pulse * 0.55);

	float horizon = exp(-abs(uv.y - 0.74) * 22.0);
	bg += vec3(0.15, 0.45, 1.0) * horizon * (0.45 + pulse * 0.5);

	float vign = smoothstep(1.2, 0.25, length(uv - vec2(0.5, 0.5)));
	bg *= vign;

	COLOR = vec4(bg, 1.0);
}
