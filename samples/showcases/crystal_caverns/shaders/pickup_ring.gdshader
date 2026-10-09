shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// progress expands the ring and fades it over the same short interval.
	float radius = length(UV - vec2(0.5));
	float ring = exp(-pow((radius - mix(0.08, 0.43, progress)) * 35.0, 2.0));
	COLOR = vec4(0.35, 1.0, 0.82, ring * (1.0 - progress) * 0.65);
}
