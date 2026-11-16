shader_type sky;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(vec3(0.0), vec3(1.0), fract(p));
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void sky() {
	vec3 direction = EYEDIR;
	float cloud = noise(direction * 5.0) * 0.5 + noise(direction * 13.0) * 0.3 + noise(direction * 31.0) * 0.2;
	vec3 background = vec3(0.011, 0.017, 0.023) * pow(cloud, 3.0) * 3.0;
	vec2 grid = SKY_COORDS * vec2(1800.0, 900.0);
	vec2 cell = floor(grid);
	float seed = hash(vec3(cell, 71.0));
	vec2 center = vec2(hash(vec3(cell, 1.0)), hash(vec3(cell, 2.0))) * 0.6 + 0.2;
	float size = mix(0.08, 0.23, hash(vec3(cell, 4.0)));
	float star = (1.0 - smoothstep(0.0, size, length(fract(grid) - center))) * step(0.987, seed);
	vec3 color = mix(vec3(0.60, 0.76, 0.90), vec3(1.0, 0.91, 0.78), hash(vec3(cell, 11.0)));
	COLOR = background + star * color * 2.0;
}
