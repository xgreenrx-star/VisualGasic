shader_type sky;
void sky() {
	float y = EYEDIR.y;
	float band = exp(-abs(y + 0.012) * 19.0);
	float halo = exp(-abs(y + 0.005) * 4.0);
	vec3 sky_color = vec3(0.006, 0.012, 0.025);
	sky_color += vec3(0.21, 0.045, 0.24) * band;
	sky_color += vec3(0.035, 0.025, 0.085) * halo;
	COLOR = sky_color;
}
