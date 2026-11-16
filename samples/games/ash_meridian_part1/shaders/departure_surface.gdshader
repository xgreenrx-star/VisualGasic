shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(0.16, 0.18, 0.2, 1.0);
uniform int surface_kind = 0;
varying vec3 local_position;

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

float terrain(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 6; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec3(1.4, 3.7, 0.9);
		amplitude *= 0.55;
	}
	return value;
}

float veins(vec3 p) {
	vec3 cell = floor(p);
	vec3 offset = fract(p);
	float nearest = 20.0;
	float second = 20.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 feature = vec3(hash(cell + neighbor), hash(cell + neighbor + 17.0), hash(cell + neighbor + 43.0));
				vec3 delta = neighbor + feature - offset;
				float distance = dot(delta, delta);
				if (distance < nearest) {
					second = nearest;
					nearest = distance;
				} else {
					second = min(second, distance);
				}
			}
		}
	}
	return 1.0 - smoothstep(0.0, 0.035, sqrt(second) - sqrt(nearest));
}

void vertex() {
	if (surface_kind == 4) {
		VERTEX.y += sin(VERTEX.z * 28.0 + sin(VERTEX.x * 17.0)) * 0.012;
	}
	local_position = VERTEX;
}

void fragment() {
	float grain = noise(local_position * 3.0);
	ALBEDO = tint.rgb * mix(0.94, 1.04, grain);
	ROUGHNESS = 0.45 + grain * 0.25;
	METALLIC = 0.55;
	if (surface_kind == 1) {
		vec3 p = normalize(local_position);
		vec3 warped = p + vec3(terrain(p * 2.2), terrain(p * 2.2 + 19.0), terrain(p * 2.2 + 37.0)) * 0.35;
		float detail = terrain(warped * 9.0);
		vec3 base = mix(vec3(0.2, 0.13, 0.075), vec3(0.5, 0.37, 0.23), smoothstep(0.35, 0.7, detail));
		ALBEDO = mix(base, vec3(0.08, 0.045, 0.025), veins(warped * 5.0) * 0.75);
		ROUGHNESS = 0.93;
		METALLIC = 0.0;
	} else if (surface_kind == 2) {
		vec2 panels = UV * vec2(256.0, 7.0);
		vec2 cell = fract(panels);
		float seam = step(0.025, cell.x) * step(0.04, cell.y);
		float plate = hash(vec3(floor(panels), 3.0));
		ALBEDO = mix(vec3(0.035, 0.045, 0.055), vec3(0.14, 0.17, 0.18), plate) * mix(0.25, 1.0, seam);
		vec2 windows = UV * vec2(1800.0, 34.0);
		vec2 w = fract(windows);
		float lit = step(0.82, hash(vec3(floor(windows), 7.0)));
		lit *= step(0.2, w.x) * step(w.x, 0.65) * step(0.3, w.y) * step(w.y, 0.57);
		EMISSION = vec3(1.0, 0.58, 0.22) * lit * 2.0;
		ROUGHNESS = 0.7;
	} else if (surface_kind == 3) {
		vec2 panel_uv = fract(UV * vec2(6.0, 12.0));
		float seam = step(0.018, panel_uv.x) * step(0.018, panel_uv.y);
		ALBEDO *= mix(0.35, 1.0, seam);
		ROUGHNESS = 0.72;
		METALLIC = 0.3;
	} else if (surface_kind == 4) {
		ROUGHNESS = 0.98;
		METALLIC = 0.0;
	}
}
