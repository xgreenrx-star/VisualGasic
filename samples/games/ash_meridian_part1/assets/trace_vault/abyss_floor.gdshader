shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Distant land far below the void: dark mesas, light-traced canyons and
// scattered city glow. Scenery only; it has no collision.
uniform vec3 rock_dark : source_color = vec3(0.012, 0.016, 0.03);
uniform vec3 rock_light : source_color = vec3(0.05, 0.065, 0.1);
uniform vec3 canyon_glow : source_color = vec3(0.1, 0.75, 0.95);
uniform vec3 city_glow : source_color = vec3(1.0, 0.55, 0.18);
uniform float glow_energy = 2.4;
// Matches the sky's below-horizon colour so the plane melts into it instead of
// reading as a pale fogged floor near the horizon.
uniform vec3 haze_color : source_color = vec3(0.012, 0.01, 0.026);

varying vec3 world_position;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise2(p);
		p = p * 2.02 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float terrain = fbm(p * 0.0021);
	float ridges = 1.0 - abs(fbm(p * 0.006 + 3.1) * 2.0 - 1.0);
	vec3 col = mix(rock_dark, rock_light, terrain * 0.7 + ridges * ridges * 0.5);

	// Canyons: thin luminous rivers following noise iso-lines.
	float river = abs(fbm(p * 0.0016 + 11.0) - 0.5);
	float canyon = smoothstep(0.012, 0.0, river);
	float pulse = 0.7 + 0.3 * sin(TIME * 0.6 + p.x * 0.004 + p.y * 0.003);
	col += canyon_glow * canyon * pulse * glow_energy * 0.6;

	// City lights clustered in low basins.
	float basin = smoothstep(0.42, 0.3, terrain);
	vec2 cell = floor(p / 14.0);
	float lamp = step(0.86, hash12(cell)) * basin;
	vec2 local = fract(p / 14.0) - 0.5;
	float dot_l = smoothstep(0.22, 0.0, length(local));
	float flick = 0.8 + 0.2 * sin(TIME * 3.0 + hash12(cell + 5.0) * 40.0);
	col += city_glow * lamp * dot_l * flick * glow_energy;
	col += city_glow * basin * 0.035;

	// Grid of old roads across the plain.
	vec2 g = abs(fract(p / 220.0) - 0.5);
	float road = smoothstep(0.004, 0.0, min(g.x, g.y)) * smoothstep(0.55, 0.3, terrain);
	col += canyon_glow * road * 0.35;

	float dist = length(world_position - CAMERA_POSITION_WORLD);
	col = mix(col, haze_color, smoothstep(700.0, 2600.0, dist));
	ALBEDO = col;
}
