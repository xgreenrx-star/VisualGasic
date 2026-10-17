shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float yard_haze = 0.0;
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
	vec3 n = normalize(world_normal);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_point);
	float key = max(dot(n, normalize(vec3(-0.4, 0.75, -0.6))), 0.0);
	float rim = pow(1.0 - abs(dot(n, eye)), 3.0);
	vec3 satin = COLOR.rgb * (0.38 + key * 0.75);
	satin += vec3(0.025, 0.065, 0.10) * rim;
	if (world_point.y < 0.01 && n.y > 0.9) {
		vec2 tile = abs(fract(world_point.xz / 7.0 - 0.5) - 0.5) * 7.0;
		float edge_distance = min(tile.x, tile.y);
		float aa = max(fwidth(edge_distance), 0.002);
		float seam = 1.0 - smoothstep(0.025 - aa, 0.025 + aa, edge_distance);
		seam *= 1.0 - smoothstep(25.0, 95.0, length(VERTEX));
		satin *= 1.0 - seam * 0.35;
		float mottling = sin(world_point.x * 9.0 + sin(world_point.z * 13.0)) * sin(world_point.z * 8.0);
		satin += vec3(0.004, 0.006, 0.008) * mottling;
	}
	float spill = exp(-abs(abs(world_point.x) - 6.5) * 0.7);
	satin += vec3(0.008, 0.05, 0.075) * spill * max(n.y, 0.0);
	float haze = 1.0 - exp(-length(VERTEX) * 0.0018);
	vec3 surface_color = mix(satin, vec3(0.065, 0.065, 0.12), haze);
	float fog_distance = max(distance(CAMERA_POSITION_WORLD, world_point) - 28.0, 0.0) / 155.0;
	float fog = (1.0 - exp(-fog_distance * fog_distance)) * yard_haze;
	ALBEDO = mix(surface_color, vec3(0.18, 0.20, 0.29), fog);
}
