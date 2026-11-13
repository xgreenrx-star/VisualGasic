shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

varying vec3 sky_direction;

void vertex() {
	sky_direction = normalize(VERTEX);
}

void fragment() {
	vec3 direction = normalize(sky_direction);
	float height = max(0.0, direction.y);
	vec3 sky = mix(vec3(0.16, 0.085, 0.11), vec3(0.012, 0.018, 0.045), pow(height, 0.4));
	float bands = sin(direction.x * 7.0 + direction.z * 9.0 + sin(direction.y * 12.0));
	sky += vec3(0.022, 0.016, 0.04) * bands * bands * height;
	vec2 grid = UV * vec2(700.0, 350.0);
	vec2 cell = floor(grid);
	float seed = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float star = (1.0 - smoothstep(0.02, 0.13, length(fract(grid) - vec2(0.5)))) * step(0.992, seed);
	sky += vec3(0.65, 0.72, 0.88) * star * smoothstep(0.08, 0.35, height);
	float moon = 1.0 - smoothstep(0.075, 0.078, distance(direction, normalize(vec3(-0.4, 0.35, 0.8))));
	sky = mix(sky, vec3(0.27, 0.18, 0.21) * (0.7 + bands * 0.2), moon);
	float azimuth = atan(direction.x, direction.z);
	float ridge = 0.012 + abs(sin(azimuth * 5.0 + 1.0)) * 0.024 + abs(sin(azimuth * 13.0)) * 0.018;
	sky = mix(vec3(0.027, 0.022, 0.034), sky, smoothstep(ridge - 0.002, ridge + 0.002, direction.y));
	ALBEDO = sky;
}
