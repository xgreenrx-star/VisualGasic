shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Stasis vent fog for CPUParticles3D quads. Additive, so a puff can only add light:
// no dark sorting artefacts against the pod glass or the FEB. Wisps are procedural.
uniform vec4 tint : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform float density = 0.4;
uniform float near_fade = 0.9;

varying float cam_dist;
varying float seed;

void vertex() {
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * w;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	cam_dist = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV - 0.5;
	float r = length(uv) * 2.0;
	vec2 q = uv * 3.0 + vec2(seed * 17.0, seed * 5.0) + vec2(TIME * 0.12, -TIME * 0.07);
	float n = vnoise(q) * 0.6 + vnoise(q * 2.3 + 4.1) * 0.3 + vnoise(q * 5.1 - 2.7) * 0.1;
	float puff = smoothstep(1.0, 0.15, r) * smoothstep(0.25, 0.85, n + 0.35 * (1.0 - r));
	float near = smoothstep(0.15, near_fade, cam_dist);
	float a = puff * COLOR.a * density * near;
	ALBEDO = tint.rgb * max(COLOR.rgb, vec3(0.0)) * a;
}
