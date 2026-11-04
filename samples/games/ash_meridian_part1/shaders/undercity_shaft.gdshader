shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// A soft additive cone: sun shafts and drone scan beams. Bright along the axis, fading
// toward the far end and when the camera is inside it.
uniform vec3 tint = vec3(1.0, 0.25, 0.1);
uniform float strength = 0.0;
uniform float len = 46.0;
varying vec3 world_point;
varying vec3 world_normal;
varying float along;

void vertex() {
	along = clamp(0.5 - VERTEX.y / len, 0.0, 1.0);
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_point);
	float face = pow(abs(dot(normalize(world_normal), eye)), 1.6);
	float fall = (1.0 - along * 0.8) * smoothstep(0.0, 0.05, along);
	float motes = 0.75 + 0.25 * sin(world_point.y * 1.3 + TIME * 0.7 + world_point.x * 0.4);
	float near = smoothstep(1.0, 8.0, distance(CAMERA_POSITION_WORLD, world_point));
	ALBEDO = tint * strength * face * fall * motes * near * 0.14;
}
