shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 tint = vec3(0.62, 0.22, 1.0);
uniform float link_power = 1.0;

void fragment() {
	float ripple_time = TIME * 0.4 * link_power;
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float rings = 0.5 + 0.5 * sin(r * 28.0 - ripple_time * 4.5);
	float spoke = 0.5 + 0.5 * sin(atan(p.y, p.x) * 4.0 - ripple_time * 1.4);
	vec3 deep = vec3(0.03, 0.02, 0.08);
	vec3 col = mix(deep, tint, rings * 0.85);
	col = mix(col, vec3(0.7, 0.4, 1.0), spoke * 0.2 * rings);
	col = mix(vec3(0.04, 0.045, 0.055), col, link_power);
	float disc = smoothstep(1.05, 0.92, r);
	ALBEDO = col * disc;
	EMISSION = col * disc * 0.45 * link_power;
	ALPHA = disc;
}
