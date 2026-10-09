shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cave_screen : hint_screen_texture, repeat_disable, filter_nearest;
// VG supplies clock and effect strengths. UV is 0..1 inside this cave rectangle.
uniform float clock = 0.0;
uniform float wave : hint_range(0.0, 1.0) = 0.0;
uniform float sink : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float crt_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	// Move sampling coordinates, rather than the gameplay cells, for the wave.
	uv.x += sin(uv.y * 26.0 + clock * 8.0) * wave * 0.012;
	uv.y += cos(uv.x * 22.0 - clock * 6.0) * wave * 0.009;
	vec2 p = uv - vec2(0.5);
	// Rotate around the center, then shrink the visible cave as sink approaches 1.
	float angle = sink * 7.0 * exp(-length(p) * 2.0);
	float c = cos(angle);
	float s = sin(angle);
	uv = vec2(c * p.x - s * p.y, s * p.x + c * p.y)
		/ max(1.0 - sink, 0.04) + vec2(0.5);
	float slice = floor(uv.y * 48.0);
	// A small pickup-only horizontal offset; never a permanent flicker.
	uv.x += sin(slice * 7.1 + floor(clock * 16.0)) * glitch * 0.003;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	// Derivatives convert local UV offsets to screen UV even after resizing.
	vec2 screen_span = vec2(
		dFdx(SCREEN_UV.x) / max(abs(dFdx(UV.x)), 0.000001),
		dFdy(SCREEN_UV.y) / max(abs(dFdy(UV.y)), 0.000001));
	vec2 sample_uv = SCREEN_UV + (clamp(uv, vec2(0.0), vec2(1.0)) - UV) * screen_span;
	vec3 pixel = texture(cave_screen, sample_uv).rgb;
	float scan = 1.0 - crt_strength * 0.12 * (0.5 + 0.5 * cos(UV.y * 384.0 * 3.14159265));
	// Darken alternate rows and edges gently; leave the HUD outside this overlay.
	float vignette = 1.0 - crt_strength * 0.18 * dot(UV - vec2(0.5), UV - vec2(0.5));
	COLOR = vec4(mix(vec3(0.025, 0.035, 0.065), pixel * scan * vignette, inside * (1.0 - sink)), 1.0);
}
