shader_type canvas_item;

// CRT Monitor / Scanlines effect — retro TV look.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_count : hint_range(50.0, 800.0) = 300.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float curvature : hint_range(0.0, 0.5) = 0.1;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	// Apply barrel distortion (CRT curvature).
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	uv *= 1.0 + curvature * dot(uv, uv);
	uv = (uv + 1.0) * 0.5;

	// Discard pixels outside the curved screen area.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 c = textureLod(screen_texture, uv, 0.0).rgb;

		// Scanlines.
		float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		c *= 1.0 - scanline_intensity * (1.0 - scanline);

		// Vignette.
		vec2 vig = uv * (1.0 - uv);
		float vignette = vig.x * vig.y * 16.0;
		vignette = pow(vignette, vignette_intensity);
		c *= vignette;

		COLOR.rgb = c;
	}
}
