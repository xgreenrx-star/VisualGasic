shader_type spatial;
render_mode cull_back;

// World-space grid on glossy black panels. Lines follow world axes so adjacent
// boxes line up without UVs.
uniform vec3 base_color : source_color = vec3(0.01, 0.016, 0.028);
uniform vec3 line_color : source_color = vec3(0.12, 0.82, 1.0);
uniform float minor_cell = 1.0;
uniform float major_cell = 4.0;
uniform float minor_width = 1.0;
uniform float major_width = 1.6;
uniform float minor_strength = 0.18;
uniform float line_energy = 2.4;
uniform float roughness_value = 0.22;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 p, float cell, float width) {
	vec2 g = p / cell;
	vec2 fw = max(fwidth(g), vec2(1e-4));
	vec2 d = abs(fract(g - 0.5) - 0.5) / fw;
	float line = 1.0 - clamp(min(d.x, d.y) / width, 0.0, 1.0);
	// Fade lines that shrink below a pixel so distant panels do not shimmer.
	float fade = 1.0 - clamp((max(fw.x, fw.y) - 0.25) * 2.0, 0.0, 1.0);
	return line * fade;
}

void fragment() {
	vec3 an = abs(world_normal);
	vec2 p = an.y > max(an.x, an.z) ? world_pos.xz : (an.x > an.z ? world_pos.zy : world_pos.xy);
	float minor = grid_line(p, minor_cell, minor_width) * minor_strength;
	float major = grid_line(p, major_cell, major_width);
	float glow = max(minor, major);
	ALBEDO = base_color;
	METALLIC = 0.55;
	ROUGHNESS = roughness_value;
	EMISSION = line_color * glow * line_energy;
}
