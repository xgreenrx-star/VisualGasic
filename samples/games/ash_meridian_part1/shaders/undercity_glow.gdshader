shader_type spatial;
render_mode unshaded, cull_disabled;

// B13 lit geometry: the grid power-up wave spreads from the transfer station
// (everything beyond wave_radius stays at its dead glow, the front flares), and once
// live, data pulses flow outward along every lit edge.
uniform vec3 wave_origin = vec3(-23.0, 6.0, 135.0);
uniform float wave_radius = 100000.0;
uniform float pulse = 0.0;
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float d = distance(world_point.xz, wave_origin.xz);
	float reached = smoothstep(wave_radius + 2.0, wave_radius - 6.0, d);
	float waving = 1.0 - step(9999.0, wave_radius);
	float front = exp(-abs(d - wave_radius) * 0.3) * waving;
	float flow = pow(0.5 + 0.5 * sin(d * 0.3 - TIME * 3.5 + world_point.y * 0.12), 14.0);
	vec3 col = c * mix(0.12, 1.0, reached);
	col += c * flow * pulse * 0.7 * reached;
	col += (c * 1.6 + vec3(0.25, 0.3, 0.35)) * front;
	ALBEDO = col;
}
