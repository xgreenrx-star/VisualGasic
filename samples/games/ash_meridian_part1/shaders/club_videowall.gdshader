shader_type spatial;
render_mode unshaded, cull_disabled;

// 4x4 atlas, row-major. split is a two-frame RGB offset on each cut.
uniform sampler2D atlas : source_color, filter_linear;
uniform float panel = 0.0;
uniform float split = 0.0;
uniform float energy = 1.0;
uniform float time = 0.0;
uniform float bass = 0.0;
uniform bool reduced = false;

void fragment() {
	float speed = reduced ? 0.25 : 0.7;
	vec2 p = (UV - vec2(0.5)) * vec2(1.8, 1.0);
	float radius = length(p);
	float angle = atan(p.y, p.x) + time * speed * 0.3;
	float petals = sin(angle * 6.0 + sin(radius * 9.0 - time * speed));
	float rings = 0.5 + 0.5 * cos(radius * 25.0 - time * speed * 4.0 + petals * 2.0);
	vec3 palette = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + angle * 2.0 + time * speed);
	vec2 warped = clamp((UV - vec2(0.5)) * (0.93 + 0.025 * sin(time * speed)) + vec2(0.5), vec2(0.003), vec2(0.997));
	float col = mod(panel, 4.0);
	float row = floor(panel / 4.0);
	vec2 base = (warped + vec2(col, row)) / 4.0;
	vec3 c = texture(atlas, base).rgb;
	vec2 lo = (vec2(col, row) + vec2(0.003)) / 4.0;
	vec2 hi = (vec2(col, row) + vec2(0.997)) / 4.0;
	float shift = reduced ? 0.0 : split;
	float cr = texture(atlas, clamp(base + vec2(shift, 0.0), lo, hi)).r;
	float cb = texture(atlas, clamp(base - vec2(shift, 0.0), lo, hi)).b;
	float scan = 0.92 + 0.08 * sin(UV.y * 720.0);
	vec3 out_col = (vec3(cr, c.g, cb) * 0.85 + palette * pow(rings, 3.0) * (0.45 + bass * 0.35)) * energy * scan;
	ALBEDO = out_col;
	EMISSION = out_col;
}
