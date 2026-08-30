shader_type sky;

// Re-entry sky — stars above, curved planet + atmosphere below.
uniform float entry_phase : hint_range(0.0, 1.0) = 0.5;
uniform float space_blend : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	// Deep space + stars (always faint; stronger when space_blend high).
	vec3 space_col = mix(vec3(0.002, 0.004, 0.02), vec3(0.04, 0.06, 0.16), y * 0.5 + 0.5);
	float stars = step(0.9983, hash3(floor(dir * 520.0))) + step(0.9991, hash3(floor(dir * 880.0 + 13.0))) * 0.5;
	space_col += vec3(0.9, 0.95, 1.0) * stars * 0.9;

	// Planet limb below — moves up as entry_phase increases (descending toward planet).
	float planet_center_y = mix(-0.55, -0.08, entry_phase);
	vec2 pd = dir.xz / max(dir.y - planet_center_y, 0.001);
	float dist = length(pd);
	float surface = smoothstep(1.02, 0.92, dist);
	float limb = smoothstep(0.95, 1.08, dist) * (1.0 - smoothstep(1.08, 1.22, dist));

	vec3 land = mix(vec3(0.04, 0.18, 0.08), vec3(0.12, 0.42, 0.22), hash(floor(pd * 4.0)) * 0.5);
	vec3 ocean = vec3(0.02, 0.12, 0.28);
	vec3 planet_col = mix(ocean, land, surface);

	// Atmosphere scatter (orange-blue rim).
	vec3 atmo = mix(vec3(0.95, 0.45, 0.12), vec3(0.35, 0.65, 1.0), smoothstep(0.0, 1.0, y + 0.2));
	float glow = limb * (1.0 + entry_phase * 0.8);
	vec3 entry_col = planet_col + atmo * glow * 1.6;

	// Day sky for city blend at horizon.
	vec3 day_zenith = vec3(0.06, 0.38, 0.92);
	vec3 day_horizon = vec3(0.42, 0.68, 0.98);
	vec3 day_col = mix(day_horizon, day_zenith, smoothstep(0.0, 0.7, y));

	float show_planet = smoothstep(0.0, 0.35, entry_phase) * (1.0 - smoothstep(0.82, 1.0, entry_phase));
	show_planet *= smoothstep(0.15, -0.05, y); // stronger below horizon

	vec3 col = mix(space_col, entry_col, show_planet);
	col = mix(col, day_col, (1.0 - show_planet) * (1.0 - space_blend) * smoothstep(-0.05, 0.35, y));
	col = mix(col, space_col, space_blend);

	COLOR = col;
}
