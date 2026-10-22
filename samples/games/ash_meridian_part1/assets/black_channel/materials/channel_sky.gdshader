shader_type sky;
render_mode use_debanding;

uniform float ascent = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

void sky() {
	vec3 ray = normalize(EYEDIR);
	vec2 uv = vec2(atan(ray.x, ray.z), asin(clamp(ray.y, -1.0, 1.0)));
	float space = smoothstep(0.25, 0.9, ascent);
	vec3 color = mix(vec3(0.018, 0.025, 0.055), vec3(0.001, 0.002, 0.009), space);
	color += vec3(0.08, 0.025, 0.12) * exp(-abs(ray.y + 0.04) * 7.0) * (1.0 - space);
	float burst = pow(max(0.0, sin(TIME * 0.7)), 48.0);
	float flash = exp(-length((ray.xy - vec2(0.48, 0.04)) * vec2(9.0, 24.0)));
	color += vec3(0.8, 0.22, 0.045) * flash * burst * (1.0 - space);
	float second_burst = pow(max(0.0, sin(TIME * 0.93 + 2.0)), 32.0);
	float third_burst = pow(max(0.0, sin(TIME * 0.51 + 4.1)), 40.0);
	float second_flash = exp(-length((ray.xy - vec2(-0.55, 0.08)) * vec2(11.0, 20.0)));
	float third_flash = exp(-length((ray.xy - vec2(0.1, -0.03)) * vec2(18.0, 30.0)));
	color += (vec3(0.15, 0.35, 0.7) * second_flash * second_burst
		+ vec3(0.65, 0.16, 0.035) * third_flash * third_burst) * (1.0 - space);

	vec2 grid = uv * 180.0;
	vec2 cell = floor(grid);
	vec2 point = vec2(hash(cell + 3.0), hash(cell + 17.0)) * 0.7 + 0.15;
	float aa = max(length(fwidth(grid)), 0.025);
	float star = 1.0 - smoothstep(0.025, 0.025 + aa, length(fract(grid) - point));
	color += vec3(0.65, 0.8, 1.0) * star * step(0.994, hash(cell)) * space;

	// A ray-sphere planet keeps its curved limb stable in the orbital hold.
	vec3 center = vec3(0.0, -2.2, -2.0);
	float radius = 2.22;
	float projected = dot(ray, center);
	float disc = projected * projected - dot(center, center) + radius * radius;
	if (disc > 0.0 && projected > 0.0) {
		float depth = projected - sqrt(disc);
		vec3 normal = normalize(ray * depth - center);
		vec2 ground = vec2(atan(normal.x, normal.z), asin(clamp(normal.y, -1.0, 1.0)));
		float land = noise(ground * 7.0) * 0.65 + noise(ground * 19.0) * 0.35;
		vec3 terrain = mix(vec3(0.008, 0.03, 0.06), vec3(0.035, 0.07, 0.09), smoothstep(0.44, 0.61, land));
		float cloud = noise(ground * vec2(31.0, 48.0) + vec2(4.0, 0.0));
		terrain = mix(terrain, vec3(0.26, 0.34, 0.42), smoothstep(0.56, 0.8, cloud) * 0.6);
		float limb = pow(1.0 - max(dot(normal, -ray), 0.0), 3.0);
		terrain += vec3(0.035, 0.24, 0.4) * limb;
		vec2 gridlines = abs(fract(ground * 52.0) - 0.5);
		float circuit = (1.0 - smoothstep(0.008, 0.025, min(gridlines.x, gridlines.y))) * step(0.62, land);
		terrain += vec3(0.01, 0.13, 0.17) * circuit;
		color = mix(color, terrain, space);
	} else if (disc > -0.15 && projected > 0.0) {
		color += vec3(0.025, 0.28, 0.55) * exp(disc * 38.0) * space;
	}
	float cloud_layer = sin(ascent * 3.14159265) * smoothstep(0.0, 0.18, ascent);
	float mist = noise(ray.xy * vec2(9.0, 16.0) + ascent * vec2(1.0, 12.0));
	color = mix(color, vec3(0.28, 0.36, 0.45), cloud_layer * (0.25 + mist * 0.55));
	COLOR = color;
}
