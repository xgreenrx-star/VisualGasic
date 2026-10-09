shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float seed = 0.0;

void fragment() {
	// Sweep a narrow diagonal highlight across opaque pixels; preserve DATA alpha.
	vec4 pixel = texture(TEXTURE, UV);
	float sweep = fract(clock * 0.27 + seed);
	float band = exp(-pow((UV.x * 0.6 + UV.y * 0.4 - sweep) * 13.0, 2.0));
	COLOR = vec4(mix(pixel.rgb, vec3(0.65, 1.0, 1.0), band * 0.38), pixel.a);
}
