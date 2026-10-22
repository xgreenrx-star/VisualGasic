shader_type spatial;
render_mode unshaded;

uniform vec4 base_color : source_color = vec4(0.04, 0.06, 0.09, 1.0);
uniform bool illuminated = false;
uniform vec3 haze_color : source_color = vec3(0.12, 0.16, 0.23);
uniform float haze_start = 65.0;
uniform float haze_range = 700.0;

varying vec3 world_point;
varying vec3 world_normal;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_point);
	float key = max(dot(normal, normalize(vec3(-0.4, 0.75, 0.3))), 0.0);
	float rim = pow(1.0 - abs(dot(normal, eye)), 3.0);
	vec3 surface_color = base_color.rgb * (0.55 + 0.8 * key);
	surface_color += vec3(0.008, 0.013, 0.022) * (0.35 + 0.65 * key);
	surface_color += vec3(0.009, 0.028, 0.045) * rim;
	if (illuminated) {
		float pulse = pow(max(0.0, sin(world_point.z * 0.075 + world_point.x * 0.025 + TIME * 5.0)), 12.0);
		float flicker = 0.92 + 0.08 * sin(TIME * 19.0 + world_point.x * 0.17);
		surface_color = base_color.rgb * (1.15 + pulse * 1.5) * flicker;
	}
	float fog_distance = max(distance(CAMERA_POSITION_WORLD, world_point) - haze_start, 0.0);
	float haze = 1.0 - exp(-pow(fog_distance / haze_range, 1.5));
	float drift = sin(world_point.x * 0.018 + world_point.z * 0.009 + TIME * 0.22);
	drift *= sin(world_point.z * 0.023 - TIME * 0.31 + world_point.y * 0.06);
	float bank = smoothstep(0.1, 0.85, drift) * exp(-abs(world_point.y - CAMERA_POSITION_WORLD.y + 7.0) * 0.025);
	haze = clamp(haze + bank * smoothstep(30.0, 260.0, fog_distance) * 0.26, 0.0, 0.94);
	ALBEDO = mix(surface_color, haze_color, haze);
}
