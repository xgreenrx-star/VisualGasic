shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, blend_mix;

// Security cycle breakup: hashed shards spin and fly apart as `burst` goes 0..1.
uniform vec4 tint : source_color = vec4(1.0, 0.16, 0.14, 1.0);
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float energy = 4.6;

varying vec3 model_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = vec3(
		dot(p, vec3(127.1, 311.7, 74.7)),
		dot(p, vec3(269.5, 183.3, 246.1)),
		dot(p, vec3(113.5, 271.9, 124.6))
	);
	return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

void vertex() {
	model_pos = VERTEX;
	vec3 cell = floor(VERTEX * 5.4);
	float h = hash13(cell + 2.7);
	vec3 dir = normalize(hash33(cell + 8.1) + NORMAL * 0.55 + vec3(0.001, 0.12, 0.001));
	float spin = burst * (5.5 + h * 11.0);
	float c = cos(spin);
	float s = sin(spin);
	vec3 p = VERTEX;
	vec3 spun = vec3(p.x * c - p.z * s, p.y * (1.0 + burst * 0.35) + p.x * s * 0.25, p.x * s + p.z * c);
	spun += dir * burst * (2.8 + h * 9.5);
	spun.y += burst * burst * (1.6 + h * 5.5);
	float mix_amt = smoothstep(0.0, 0.12, burst);
	VERTEX = mix(VERTEX, spun, mix_amt);
}

void fragment() {
	vec3 cell = floor(model_pos * 5.4);
	float h = hash13(cell + 2.7);
	float cracks = abs(fract(model_pos.x * 11.0 + h * 4.0) - 0.5);
	cracks = min(cracks, abs(fract(model_pos.y * 9.0 + h) - 0.5));
	cracks = min(cracks, abs(fract(model_pos.z * 10.0 - h) - 0.5));
	float shard = step(0.04 + burst * 0.16, cracks);
	float fade = 1.0 - smoothstep(0.52, 1.0, burst);
	if (shard * fade < 0.08) {
		discard;
	}
	float hot = 1.0 - burst;
	vec3 col = mix(tint.rgb, vec3(1.0, 0.82, 0.32), hot * 0.72 + h * 0.12);
	ALBEDO = col * energy * (1.15 + hot * 2.8) * fade;
	ALPHA = fade;
}
