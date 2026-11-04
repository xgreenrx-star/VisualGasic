shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

// Tower windows: one MultiMesh quad per tower face, the window grid is procedural.
// INSTANCE_CUSTOM: x columns, y rows, z seed. COLOR: the tower's window tint.
// Most windows are lit, some flicker, a few hold a silhouette that comes and goes,
// and a rare green terminal glows on its own even while the grid is dead.
uniform float power = 0.0;
uniform vec3 wave_origin = vec3(-23.0, 6.0, 135.0);
uniform float wave_radius = 100000.0;
varying vec4 info;
varying vec3 tint;
varying vec3 world_point;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	info = INSTANCE_CUSTOM;
	tint = COLOR.rgb;
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = vec2(max(info.x, 1.0), max(info.y, 1.0));
	vec2 cell = floor(UV * grid);
	vec2 f = fract(UV * grid);
	float pane = step(0.2, f.x) * step(f.x, 0.8) * step(0.22, f.y) * step(f.y, 0.85);
	if (pane < 0.5) discard;
	float r = h(cell + info.z * 13.7);
	float r2 = h(cell.yx + info.z * 5.1 + 7.0);
	float reached = smoothstep(wave_radius + 2.0, wave_radius - 4.0, distance(world_point.xz, wave_origin.xz) + r * 6.0);
	float lit = power * reached * step(0.42, r);
	vec3 col = tint * (0.7 + 0.6 * r2);
	if (r > 0.42 && r < 0.5) {
		lit *= 0.2 + 0.8 * step(0.2, h(vec2(floor(TIME * 8.0), r2 * 50.0)));
	}
	if (r < 0.025) {
		lit = 0.65 + 0.35 * step(0.5, fract(TIME * 1.7 + r2));
		float row = step(0.5, fract(f.y * 7.0)) * step(fract(f.x * 3.0 + r2), 0.7);
		col = vec3(0.15, 1.0, 0.45) * (0.35 + 0.65 * row);
	}
	if (r > 0.9) {
		float slot = floor(TIME / 23.0 + r2 * 9.0);
		if (h(vec2(slot, r)) > 0.45) {
			float x = 0.5 + 0.22 * sin(TIME * 0.05 + r2 * 40.0);
			vec2 q = vec2(f.x - x, 0.85 - f.y);
			float head = step(length((q - vec2(0.0, 0.47)) * vec2(1.0, 1.15)), 0.075);
			float body = step(abs(q.x), 0.12 - q.y * 0.08) * step(q.y, 0.38);
			col *= 1.0 - max(head, body) * 0.95;
		}
	}
	col *= 0.6 + 0.4 * smoothstep(0.85, 0.22, f.y);
	ALBEDO = mix(vec3(0.004, 0.006, 0.01), col, lit);
}
