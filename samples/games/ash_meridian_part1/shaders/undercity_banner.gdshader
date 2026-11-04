shader_type spatial;
render_mode unshaded, cull_disabled;

// Torn cloth banners strung between towers. The top edge is held by the cable;
// the rest sways. drop runs 0 at the cable to 1 at the hem (from the local height). Ragged bottom, burnt holes, a faded alien print, lit by the nearest glow.
uniform vec3 cloth = vec3(0.32, 0.05, 0.06);
uniform vec3 print_col = vec3(0.9, 0.85, 0.6);
uniform vec3 light_col = vec3(0.0);
uniform float seed = 0.0;
uniform float power = 0.0;
uniform float half_h = 3.0;
varying float drop;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	drop = clamp((half_h - VERTEX.y) / (2.0 * half_h), 0.0, 1.0);
	float hang = drop * drop;
	VERTEX.z += sin(TIME * 1.1 + UV.x * 3.0 + seed * 5.0) * 0.45 * hang + sin(TIME * 2.3 + UV.x * 7.0) * 0.12 * hang;
	VERTEX.x += sin(TIME * 0.8 + seed) * 0.15 * hang;
}

void fragment() {
	float rag = 0.78 + n2(vec2(UV.x * 14.0, 0.0)) * 0.22 - n2(vec2(UV.x * 3.0, 4.0)) * 0.2;
	if (drop > rag) discard;
	if (n2(vec2(UV.x, drop) * vec2(9.0, 5.0) + 3.0) > 0.82) discard;
	vec2 cell = fract(vec2(UV.x, drop) * vec2(6.0, 3.0));
	vec2 id = floor(vec2(UV.x, drop) * vec2(6.0, 3.0));
	float stroke = step(0.42, abs(cell.x - 0.5)) + step(0.45, abs(cell.y - 0.5));
	stroke = clamp(stroke * step(0.35, h(id)) + step(abs(cell.y - 0.5), 0.05) * step(0.6, h(id + 9.0)), 0.0, 1.0);
	stroke *= step(0.15, drop) * step(drop, 0.62) * step(0.08, UV.x) * step(UV.x, 0.92);
	vec3 col = mix(cloth, print_col * 0.6, stroke * 0.8) * (0.55 + 0.45 * n2(vec2(UV.x, drop) * 30.0));
	col *= 0.25 + 0.75 * (1.0 - drop * 0.6);
	col += light_col * (0.35 + 0.25 * power);
	ALBEDO = col * (0.35 + 0.65 * power) + light_col * 0.15;
}
