shader_type sky;
render_mode use_debanding;
uniform float sky_time = 0.0;

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

float cloud(vec2 p) {
	float value = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * weight;
		p = p * 2.03 + vec2(5.2, 1.7);
		weight *= 0.5;
	}
	return value;
}

vec4 moon(vec3 ray, vec3 center, float radius, vec3 tint) {
	float facing = dot(ray, center);
	vec3 offset = ray - center * facing;
	float r = length(offset) / radius;
	float aa = max(fwidth(r), 0.002);
	float disc = (1.0 - smoothstep(1.0 - aa, 1.0 + aa, r)) * step(0.0, facing);
	vec3 normal = normalize(offset / radius + center * sqrt(max(0.0, 1.0 - r * r)));
	float light = 0.12 + 0.88 * max(dot(normal, normalize(vec3(-0.65, 0.55, -0.1))), 0.0);
	float terrain = 0.68 + 0.32 * cloud(offset.xy / radius * 18.0);
	return vec4(tint * light * terrain, disc);
}

void sky() {
	vec3 ray = normalize(EYEDIR);
	vec2 uv = vec2(atan(ray.x, ray.z), asin(clamp(ray.y, -1.0, 1.0)));
	float band = exp(-abs(ray.y + 0.012) * 19.0);
	vec3 color = vec3(0.006, 0.012, 0.025) + vec3(0.21, 0.045, 0.24) * band;
	color += vec3(0.035, 0.025, 0.085) * exp(-abs(ray.y + 0.005) * 4.0);
	color = mix(color, vec3(0.18, 0.20, 0.29), exp(-abs(ray.y) * 24.0));
	float above = smoothstep(0.015, 0.23, ray.y);
	float clouds = cloud(uv * vec2(3.0, 5.0) + vec2(2.0, 4.0));
	float ribbon = exp(-pow((uv.y - 0.42 - 0.18 * sin(uv.x * 1.8)) * 4.0, 2.0));
	color += mix(vec3(0.08, 0.025, 0.17), vec3(0.025, 0.15, 0.21), clouds)
		* smoothstep(0.28, 0.78, clouds) * ribbon * above * 1.7;
	for (int layer = 0; layer < 2; layer++) {
		float scale = 155.0 + float(layer) * 95.0;
		vec2 grid = uv * scale;
		vec2 cell = floor(grid);
		float seed = hash(cell + float(layer) * 31.0);
		vec2 spot = vec2(hash(cell + 7.1), hash(cell + 19.8)) * 0.7 + 0.15;
		float d = length(fract(grid) - spot);
		float aa = max(length(fwidth(grid)), 0.025);
		float star = 1.0 - smoothstep(0.035, 0.035 + aa, d);
		float twinkle = 0.78 + 0.22 * sin(sky_time * 1.2 + seed * 60.0);
		color += mix(vec3(0.5, 0.7, 1.0), vec3(1.0, 0.8, 0.55), hash(cell + 41.0))
			* star * step(0.988, seed) * twinkle * above * 0.7;
	}
	vec4 large_moon = moon(ray, normalize(vec3(-0.45, 0.36, 1.0)), 0.078, vec3(0.68, 0.74, 0.87));
	vec4 small_moon = moon(ray, normalize(vec3(0.61, 0.29, 1.0)), 0.043, vec3(0.8, 0.44, 0.26));
	color = mix(color, large_moon.rgb, large_moon.a);
	color = mix(color, small_moon.rgb, small_moon.a);
	// One short meteor per 19-second window, with a new heading each time.
	float cycle = floor(sky_time / 19.0);
	float age = mod(sky_time, 19.0) - 7.0;
	vec2 start = vec2(mix(-0.7, 0.7, hash(vec2(cycle, 4.0))), 0.62);
	vec2 direction = normalize(vec2(1.0, -0.48));
	vec2 delta = uv - (start + direction * age * 0.48);
	float along = dot(delta, direction);
	float across = abs(dot(delta, vec2(-direction.y, direction.x)));
	float streak = exp(-across * 1100.0) * smoothstep(-0.22, 0.0, along) * step(along, 0.0);
	color += vec3(0.65, 0.85, 1.0) * streak * smoothstep(0.0, 0.12, age)
		* (1.0 - smoothstep(0.85, 1.15, age)) * above * (1.0 - large_moon.a) * (1.0 - small_moon.a);
	COLOR = color;
}
