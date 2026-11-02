shader_type canvas_item;
render_mode unshaded;

// Full-screen CRT pass for the boot terminal. boot_terminal.vg drives every
// uniform; at crt_amt = 0, static_amt = 0, squeeze = 1 and reveal >= 1 (or
// push >= 1) it is a pass-through, so the node can be freed without a visible pop.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float time_s = 0.0;
uniform float crt_amt = 1.0;
uniform float static_amt = 0.12;
uniform float tear = 0.0;
uniform float squeeze_x = 1.0;
uniform float squeeze_y = 1.0;
uniform float reveal = -1.0;
// -1 = off; 0..1 = the face video breaking through the static, brightest lines first.
uniform float push = -1.0;
uniform float fade = 1.0;
uniform vec2 aspect = vec2(1.7778, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 grab(vec2 uv) {
	return texture(screen_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	// Tube curvature.
	vec2 bent = c * (1.0 + crt_amt * 0.24 * dot(c, c));
	// Power-off collapse: squeeze the picture into a line, then a dot.
	vec2 pc = vec2(bent.x / max(squeeze_x, 0.0005), bent.y / max(squeeze_y, 0.0005));
	float row = floor(uv.y * 135.0);
	float slice = floor(time_s * 24.0);
	float torn = step(0.72, hash(vec2(row * 0.37, floor(time_s * 12.0))));
	pc.x += (hash(vec2(row, slice)) - 0.5) * tear * torn;
	pc.x += crt_amt * 0.0012 * sin(uv.y * 38.0 + time_s * 5.0);
	vec2 suv = pc + 0.5;
	float inside = step(abs(pc.x), 0.5) * step(abs(pc.y), 0.5);

	float ca = 0.0016 * crt_amt;
	vec3 col = vec3(grab(suv + vec2(ca, 0.0)).r, grab(suv).g, grab(suv - vec2(ca, 0.0)).b);
	// Cheap phosphor bloom.
	vec3 bloom = grab(suv + vec2(0.003, 0.0)) + grab(suv - vec2(0.003, 0.0)) + grab(suv + vec2(0.0, 0.005)) + grab(suv - vec2(0.0, 0.005));
	col += bloom * 0.09 * crt_amt;

	float scan = 0.74 + 0.26 * sin(uv.y * 540.0 * 3.14159);
	col *= mix(1.0, scan, crt_amt);
	float band = smoothstep(0.0, 0.08, fract(uv.y * 0.6 - time_s * 0.22)) * (1.0 - smoothstep(0.08, 0.16, fract(uv.y * 0.6 - time_s * 0.22)));
	col += vec3(0.02, 0.06, 0.03) * band * crt_amt;
	col *= 1.0 - 0.035 * crt_amt * hash(vec2(floor(time_s * 30.0), 1.0));

	float n0 = hash(floor(FRAGCOORD.xy * 0.5) + floor(time_s * 50.0) * vec2(5.0, 11.0));
	if (push >= 0.0) {
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		float th = 0.85 - push * 1.25;
		float gate = smoothstep(th, th + 0.2, clamp(lum * 4.0, 0.0, 1.0) * 0.8 + n0 * 0.3 * (1.0 - push));
		vec3 phos = vec3(lum * 0.55, lum * 1.3, lum * 0.7);
		col = mix(phos, col, push) * gate;
		col = mix(col, vec3(0.35, 0.52, 0.4) * n0, (1.0 - gate) * static_amt * 0.9);
	}

	float n = hash(floor(FRAGCOORD.xy * 0.5) + vec2(floor(time_s * 50.0) * 17.0, floor(time_s * 50.0) * 3.0));
	col = mix(col, vec3(0.4, 0.58, 0.46) * n, static_amt * 0.5);
	col += vec3(0.08, 0.12, 0.09) * (n - 0.5) * (0.35 + static_amt);
	col += vec3(0.55, 0.8, 0.6) * step(1.0 - static_amt * static_amt * 0.02, n);

	float vig = 1.0 - 0.55 * pow(clamp(length(c) * 1.35, 0.0, 1.0), 2.6);
	col *= mix(1.0, vig, crt_amt);
	col *= inside;

	// The collapsing line and the final dot glow brighter as they shrink.
	float line_glow = (1.0 - squeeze_y) * exp(-abs(c.y) * 140.0) * step(abs(pc.x), 0.5);
	col = mix(col, vec3(0.75, 1.0, 0.82), pow(clamp(1.0 - squeeze_y, 0.0, 1.0), 6.0) * 0.85 * inside);
	col += vec3(0.5, 1.0, 0.65) * line_glow * 0.5;
	float dot_glow = (1.0 - squeeze_x) * exp(-length(c * aspect) * 38.0);
	col += vec3(0.7, 1.0, 0.8) * dot_glow;

	if (reveal >= 0.0) {
		float d = length(c * aspect);
		float edge = reveal * 1.15;
		float mask = 1.0 - smoothstep(edge - 0.025, edge, d);
		float ring = exp(-abs(d - edge) * 55.0) * (1.0 - reveal);
		col = col * mask + vec3(0.55, 1.0, 0.8) * ring * 0.9;
		col += vec3(0.7, 1.0, 0.8) * exp(-d * 38.0) * (1.0 - reveal) * (1.0 - reveal);
	}
	COLOR = vec4(col * fade, 1.0);
}
