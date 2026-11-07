shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float time_s = 0.0;
uniform bool reduced_motion = false;

float noise_at(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	vec2 curved = centered * (1.0 + 0.035 * dot(centered, centered));
	vec2 sample_uv = curved * 0.5 + 0.5;
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 source = SCREEN_UV + (sample_uv - UV) * span;
	vec2 low = SCREEN_UV - UV * span;
	vec2 high = low + span;
	vec2 safe_source = clamp(source, low + SCREEN_PIXEL_SIZE, high - SCREEN_PIXEL_SIZE);
	vec3 col = texture(screen_tex, safe_source).rgb;
	vec3 glow = texture(screen_tex, clamp(safe_source + vec2(SCREEN_PIXEL_SIZE.x, 0.0), low, high)).rgb;
	glow += texture(screen_tex, clamp(safe_source - vec2(SCREEN_PIXEL_SIZE.x, 0.0), low, high)).rgb;
	col += glow * 0.055;
	col *= 0.89 + 0.11 * cos(UV.y * 540.0 * 3.14159265);
	col *= 1.0 - 0.22 * dot(centered, centered);
	float frame = reduced_motion ? 0.0 : floor(time_s * 24.0);
	float snow = noise_at(floor(UV * vec2(960.0, 540.0)) + frame * vec2(13.0, 7.0));
	if (!reduced_motion) {
		col += vec3(snow - 0.45) * 0.035;
		col += vec3(0.13) * step(0.9988, snow);
		float roll = fract(UV.y - time_s * 0.07);
		col += vec3(0.015, 0.024, 0.025) * exp(-pow((roll - 0.5) * 32.0, 2.0));
	}
	float glass = exp(-length((UV - vec2(0.27, 0.13)) * vec2(3.0, 5.0)));
	col += vec3(0.024, 0.034, 0.04) * glass;
	vec2 q = abs(curved) - vec2(0.945, 0.90);
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.075;
	float mask = 1.0 - smoothstep(-0.006, 0.006, edge);
	COLOR = vec4(mix(vec3(0.006, 0.009, 0.01), col, mask), 1.0);
}
