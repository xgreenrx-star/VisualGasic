shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float yard_haze = 0.0;
uniform vec3 interior_tint = vec3(1.0);
uniform vec3 spill_color = vec3(0.008, 0.05, 0.075);
uniform float depth_fog = 0.0;
uniform vec3 fog_color = vec3(0.0);
uniform vec3 sun_pos = vec3(0.0);
uniform vec3 sun_color = vec3(0.0);
// B13 fake point lights (train headlights, plaza screen spill): xyz + range, rgb + gain.
uniform int pl_count = 0;
uniform vec4 pl_pos[6];
uniform vec4 pl_col[6];
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
	vec3 satin = COLOR.rgb * interior_tint * (0.38 + key * 0.75);
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
	satin += spill_color * spill * max(n.y, 0.0);
	vec3 to_sun = sun_pos - world_point;
	float sun_d = max(length(to_sun), 0.001);
	float sun_key = max(dot(n, to_sun / sun_d), 0.0);
	satin += sun_color * (0.04 + sun_key * 0.32) / (1.0 + sun_d * sun_d / 12100.0);
	for (int i = 0; i < pl_count; i++) {
		vec3 to_l = pl_pos[i].xyz - world_point;
		float ld = max(length(to_l), 0.001);
		float fall = 1.0 - clamp(ld / pl_pos[i].w, 0.0, 1.0);
		// Floors take the pool of light. Walls only light when the lamp is close, so a street
		// search light cannot brighten the inside of a building through the shell.
		float lit_face = step(0.35, n.y);
		if (fall > 0.55) {
			lit_face = 1.0;
		}
		satin += pl_col[i].rgb * pl_col[i].a * fall * fall * (0.25 + 0.75 * max(dot(n, to_l / ld), 0.0)) * lit_face;
	}
	float haze = 1.0 - exp(-length(VERTEX) * 0.0018);
	vec3 surface_color = mix(satin, vec3(0.065, 0.065, 0.12), haze);
	float fog_distance = max(distance(CAMERA_POSITION_WORLD, world_point) - 28.0, 0.0) / 155.0;
	float fog = (1.0 - exp(-fog_distance * fog_distance)) * yard_haze;
	vec3 lit = mix(surface_color, vec3(0.18, 0.20, 0.29), fog);
	float deep = 1.0 - exp(-distance(CAMERA_POSITION_WORLD, world_point) * depth_fog);
	ALBEDO = mix(lit, fog_color, deep);
}
