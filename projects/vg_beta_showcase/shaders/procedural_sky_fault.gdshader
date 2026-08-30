shader_type sky;

// Fault-scene sky — breathes from deep void to warm plasma wash via u_pulse.

uniform float u_pulse : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	vec3 dark_zenith = vec3(0.008, 0.012, 0.045);
	vec3 dark_horizon = vec3(0.025, 0.018, 0.055);
	vec3 bright_zenith = vec3(0.98, 0.9, 0.42);
	vec3 bright_horizon = vec3(1.0, 0.94, 0.58);

	vec3 zenith = mix(dark_zenith, bright_zenith, u_pulse);
	vec3 horizon = mix(dark_horizon, bright_horizon, u_pulse);
	vec3 col = mix(horizon, zenith, smoothstep(-0.08, 0.68, y));

	vec2 swirl_uv = dir.xz / (max(abs(y), 0.06) + 0.12);
	float wisps = noise(swirl_uv * 2.4 + vec2(TIME * 0.04, -TIME * 0.025));
	wisps += noise(swirl_uv * 5.5 - vec2(TIME * 0.03, 1.7)) * 0.5;
	col += vec3(1.0, 0.72, 0.18) * wisps * u_pulse * u_pulse * 0.22;

	float rim = pow(max(1.0 - abs(y), 0.0), 3.5);
	col += mix(vec3(0.15, 0.08, 0.35), vec3(1.0, 0.82, 0.35), u_pulse) * rim * 0.18;

	COLOR = col;
}
