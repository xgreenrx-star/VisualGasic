shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// B13 rooftop holograms: additive, rim-lit, world-space scanlines with a rolling
// bright band and line tearing. power = 0 leaves only rare glitch flashes.
uniform vec3 tint = vec3(0.3, 0.9, 1.0);
uniform float power = 0.0;
uniform float gain = 1.0;
instance uniform float fade = 1.0;
varying vec3 world_point;
varying vec3 world_normal;

float h1(float n) {
	return fract(sin(n * 91.7) * 15731.743);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_point);
	float rim = pow(1.0 - abs(dot(normalize(world_normal), eye)), 2.0);
	float scan = 0.45 + 0.55 * step(0.0, sin(world_point.y * 14.0 - TIME * 5.0));
	float band = smoothstep(0.94, 1.0, sin(world_point.y * 0.45 - TIME * 1.8));
	float row = floor(world_point.y * 3.0);
	float tear = step(0.95, h1(floor(TIME * 9.0) + row * 0.37));
	float flick = 0.86 + 0.14 * sin(TIME * 41.0) * sin(TIME * 7.3);
	float glitch = step(0.975, h1(floor(TIME * 6.0)));
	float live = mix(glitch * 0.5, 1.0, clamp(power, 0.0, 1.0));
	vec3 col = tint * (0.16 + rim * 1.15) * scan * flick;
	col += tint * band * 0.55 + vec3(0.6, 0.9, 1.0) * tear * 0.25;
	ALBEDO = col * COLOR.rgb * gain * live * fade;
}
