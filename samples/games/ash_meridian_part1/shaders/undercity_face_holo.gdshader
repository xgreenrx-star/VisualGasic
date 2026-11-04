shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// B13 broadcast face: the opening video's Narcean mesh as a ceiling hologram.
// UV = rest point on the 1000-unit face canvas, UV2 = (jaw weight, upper-lip weight),
// COLOR.rgb = base colour, COLOR.a = part (1 line/fill, 0.5 iris, 0.25 mouth throat).
// The pose matches tools/ai_face/face.py: jaw drop, lip corners, eyelid squash, gaze.
uniform float mouth_open = 0.0;
uniform float eye_r = 1.0;
uniform float eye_l = 1.0;
uniform float gaze = 0.0;
uniform float power = 0.0;
uniform float scale = 0.0175;
uniform vec3 tint = vec3(0.45, 1.0, 1.0);
instance uniform float fade = 1.0;
varying vec2 canvas;
varying float part;
varying float iris_on;

const float MOUTH_Y = 726.0;
const float JAW_DROP = 160.0;
const float UPPER_LIFT = 22.0;
const float CORNER_PUSH = 12.0;
const vec2 IRIS_R = vec2(645.0, 463.0);
const vec2 IRIS_L = vec2(355.0, 463.0);
const vec2 MOUTH_C = vec2(500.0, 726.0);

float h1(float n) {
	return fract(sin(n * 91.7) * 15731.743);
}

float lid(vec2 p, vec2 e, float open, float y) {
	float w = exp(-pow((p.x - e.x) / 78.0, 4.0) - pow((p.y - e.y) / 46.0, 4.0));
	return e.y + (y - e.y) * (1.0 - (1.0 - open) * w);
}

void vertex() {
	vec2 p = UV;
	float lat = p.x - 500.0;
	float c = max(0.0, 1.0 - abs(abs(lat) - 75.0) / 55.0) * max(0.0, 1.0 - abs(p.y - MOUTH_Y) / 30.0);
	vec2 q = p;
	q.x += sign(lat) * CORNER_PUSH * mouth_open * c;
	q.y += JAW_DROP * mouth_open * UV2.x - UPPER_LIFT * mouth_open * UV2.y;
	part = COLOR.a;
	iris_on = 1.0;
	if (part > 0.4 && part < 0.6) {
		q.x += gaze;
		iris_on = step(0.08, lat > 0.0 ? eye_r : eye_l);
	}
	q.y = lid(q, IRIS_R, eye_r, q.y);
	q.y = lid(q, IRIS_L, eye_l, q.y);
	canvas = q;
	VERTEX = vec3((q.x - 500.0) * scale, -(q.y - 490.0) * scale, VERTEX.z);
}

void fragment() {
	float scan = 0.5 + 0.5 * step(0.0, sin(canvas.y * 0.8 - TIME * 6.0));
	float band = smoothstep(0.93, 1.0, sin(canvas.y * 0.012 - TIME * 1.6));
	float row = floor(canvas.y / 22.0);
	float tear = step(0.96, h1(floor(TIME * 9.0) + row * 0.37));
	float flick = 0.86 + 0.14 * sin(TIME * 41.0) * sin(TIME * 7.3);
	float glitch = step(0.975, h1(floor(TIME * 6.0)));
	float live = mix(glitch * 0.5, 1.0, clamp(power, 0.0, 1.0));
	vec3 col = COLOR.rgb;
	if (part < 0.3) {
		vec2 m = (canvas - (MOUTH_C + vec2(0.0, JAW_DROP * mouth_open * 0.28))) / vec2(80.0, 12.0 + 70.0 * mouth_open);
		float r = length(m);
		float a = atan(m.y, m.x);
		float rings = pow(0.5 + 0.5 * sin(log(r + 0.02) * 14.0 + TIME * 7.0 + a * 3.0), 6.0);
		col = vec3(0.2, 0.75, 1.0) * (rings * 0.9 + 0.06) * smoothstep(1.1, 0.2, r) * mouth_open;
	}
	col *= tint * scan * flick * iris_on;
	col += tint * band * 0.12 * COLOR.rgb + vec3(0.6, 0.9, 1.0) * tear * 0.08;
	ALBEDO = col * live * fade;
}
