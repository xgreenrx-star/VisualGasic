shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform vec2 mass_uv = vec2(0.5, 0.5);
uniform vec2 gravity_vec = vec2(0.0, 1.0);
uniform float pulse_phase = 0.0;
uniform float heat_stress = 0.0;
uniform float ambient = 0.35;

void fragment() {
	vec2 uv = SCREEN_UV;
	float gmag = clamp(length(gravity_vec), 0.0, 1.0);
	float chroma = gmag * 0.004;

	vec2 grav_dir = normalize(gravity_vec + vec2(0.0001, 0.0001));
	vec2 ca = grav_dir * chroma;

	vec4 col;
	col.r = texture(screen_texture, uv + ca).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - ca).b;
	col.a = 1.0;

	col.rgb *= mix(0.58, 1.05, clamp(ambient, 0.0, 1.0));

	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig = 1.0 - dot(vig_uv, vig_uv) * 0.38;
	col.rgb *= vig;

	vec2 mdir = uv - mass_uv;
	float mdist = length(mdir);

	if (pulse_phase > 0.001) {
		float ring = mdist * 2.8 - pulse_phase * 1.15;
		float pulse = exp(-abs(ring) * 9.0) * (1.0 - pulse_phase * 0.4) * 0.72;
		col.rgb += vec3(0.15, 0.58, 0.9) * pulse;
		float core = exp(-mdist * 5.5) * pulse_phase * 0.18;
		col.rgb += vec3(0.25, 0.72, 1.0) * core;
	}

	col.rgb = mix(col.rgb, col.rgb * vec3(1.25, 0.82, 0.75), heat_stress * mdist * 0.6);

	COLOR = col;
}
