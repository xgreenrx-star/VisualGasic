shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform vec2 mass_uv = vec2(0.5, 0.5);
uniform vec2 pulse_uv = vec2(0.5, 0.5);
uniform vec2 gravity_vec = vec2(0.0, 1.0);
uniform float pulse_phase = 0.0;
uniform float heat_stress = 0.0;
uniform float ambient = 0.35;
uniform float hit_flash = 0.0;
uniform vec3 room_tint = vec3(0.15, 0.35, 0.55);
uniform float tint_amt = 0.06;
uniform float fx_time = 0.0;
uniform float exit_count = 0.0;
uniform vec2 exit_uv0 = vec2(-1.0, -1.0);
uniform vec2 exit_uv1 = vec2(-1.0, -1.0);
uniform vec2 exit_uv2 = vec2(-1.0, -1.0);
uniform vec2 exit_uv3 = vec2(-1.0, -1.0);
uniform vec2 exit_uv4 = vec2(-1.0, -1.0);
uniform float laser_count = 0.0;
uniform vec4 laser0 = vec4(0.0);
uniform vec4 laser1 = vec4(0.0);
uniform vec4 laser2 = vec4(0.0);
uniform vec4 laser3 = vec4(0.0);
uniform vec4 lgap0 = vec4(0.0);
uniform vec4 lgap1 = vec4(0.0);
uniform vec4 lgap2 = vec4(0.0);
uniform vec4 lgap3 = vec4(0.0);
uniform vec2 hole_uv = vec2(-1.0, -1.0);
uniform float hole_str = 0.0;
uniform float hole_rad = 0.04;
uniform float exit_prox = 0.0;
uniform float warp_flash = 0.0;

float aspect_len(vec2 d, vec2 px) {
	d.y *= px.x / px.y;
	return length(d);
}

float exit_water(vec2 uv, vec2 c, vec2 px) {
	if (c.x < 0.0) {
		return 0.0;
	}
	float r = aspect_len(uv - c, px);
	float rip = sin(r * 46.0 - fx_time * 5.2) * 0.5 + 0.5;
	float caust = sin((uv.x * 1.4 + uv.y) * 36.0 + fx_time * 2.8) * 0.5 + 0.5;
	return exp(-r * 10.5) * (0.4 + 0.6 * rip) * (0.65 + 0.35 * caust);
}

vec2 exit_warp(vec2 uv, vec2 c, vec2 px) {
	if (c.x < 0.0) {
		return vec2(0.0);
	}
	vec2 d = uv - c;
	float r = aspect_len(d, px);
	float w = exp(-r * 14.0) * 0.00012;
	return d * (sin(r * 38.0 - fx_time * 4.0) * w);
}

float laser_band(vec2 uv, vec4 box, vec4 gap) {
	if (box.z <= 0.001 || box.w <= 0.001) {
		return 0.0;
	}
	if (uv.x < box.x || uv.y < box.y || uv.x > box.x + box.z || uv.y > box.y + box.w) {
		return 0.0;
	}
	if (gap.z > 0.001 && uv.x >= gap.x && uv.y >= gap.y && uv.x <= gap.x + gap.z && uv.y <= gap.y + gap.w) {
		return 0.0;
	}
	float flicker = 0.72 + 0.28 * sin(fx_time * 28.0 + uv.x * 40.0);
	return flicker;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float gmag = clamp(length(gravity_vec), 0.0, 1.0);
	float chroma = gmag * 0.001 + warp_flash * 0.008;

	vec2 grav_dir = normalize(gravity_vec + vec2(0.0001, 0.0001));
	vec2 ca = grav_dir * chroma;

	vec2 warp = vec2(0.0);
	if (hole_str > 0.02 && hole_uv.x >= 0.0) {
		vec2 hd = uv - hole_uv;
		hd.y *= px.x / px.y;
		float hr = max(hole_rad, 0.012);
		float r = length(hd);
		if (r > hr) {
			float lens = hole_str * (hr * hr) / (r * r);
			warp -= normalize(hd + vec2(0.0001, 0.0)) * lens * 0.18;
		}
	}
	if (exit_count > 0.5) {
		warp += exit_warp(uv, exit_uv0, px);
	}
	if (exit_count > 1.5) {
		warp += exit_warp(uv, exit_uv1, px);
	}
	if (exit_count > 2.5) {
		warp += exit_warp(uv, exit_uv2, px);
	}
	if (exit_count > 3.5) {
		warp += exit_warp(uv, exit_uv3, px);
	}
	if (exit_count > 4.5) {
		warp += exit_warp(uv, exit_uv4, px);
	}
	if (warp_flash > 0.001) {
		vec2 fromC = uv - vec2(0.5);
		float spin = sin(length(fromC) * 22.0 - fx_time * 11.0);
		warp += vec2(
			sin(uv.y * 30.0 + fx_time * 16.0),
			cos(uv.x * 26.0 - fx_time * 14.0)
		) * warp_flash * 0.028;
		warp += fromC * spin * warp_flash * 0.055;
	}

	vec2 suv = uv + warp;
	vec4 col;
	col.r = texture(screen_texture, suv + ca).r;
	col.g = texture(screen_texture, suv).g;
	col.b = texture(screen_texture, suv - ca).b;
	col.a = 1.0;

	col.rgb *= mix(0.58, 1.05, clamp(ambient, 0.0, 1.0));

	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig = 1.0 - dot(vig_uv, vig_uv) * 0.38;
	col.rgb *= vig;

	vec2 mdir = uv - mass_uv;
	float mdist = length(mdir);

	vec2 pdir = uv - pulse_uv;
	pdir.y *= px.x / px.y;
	float pdist = length(pdir);

	if (pulse_phase > 0.001) {
		float ring = pdist * 2.8 - pulse_phase * 1.15;
		float pulse = exp(-abs(ring) * 9.0) * (1.0 - pulse_phase * 0.4) * 0.72;
		col.rgb += vec3(0.15, 0.58, 0.9) * pulse;
		float core = exp(-pdist * 5.5) * pulse_phase * 0.18;
		col.rgb += vec3(0.25, 0.72, 1.0) * core;
	}

	float water = 0.0;
	if (exit_count > 0.5) {
		water += exit_water(uv, exit_uv0, px);
	}
	if (exit_count > 1.5) {
		water += exit_water(uv, exit_uv1, px);
	}
	if (exit_count > 2.5) {
		water += exit_water(uv, exit_uv2, px);
	}
	if (exit_count > 3.5) {
		water += exit_water(uv, exit_uv3, px);
	}
	if (exit_count > 4.5) {
		water += exit_water(uv, exit_uv4, px);
	}
	water = clamp(water, 0.0, 1.0);
	col.rgb = mix(col.rgb, col.rgb * vec3(0.45, 0.85, 1.15) + vec3(0.08, 0.28, 0.42), water * 0.85);

	float las = 0.0;
	if (laser_count > 0.5) {
		las += laser_band(uv, laser0, lgap0);
	}
	if (laser_count > 1.5) {
		las += laser_band(uv, laser1, lgap1);
	}
	if (laser_count > 2.5) {
		las += laser_band(uv, laser2, lgap2);
	}
	if (laser_count > 3.5) {
		las += laser_band(uv, laser3, lgap3);
	}
	las = clamp(las, 0.0, 1.0);
	col.rgb += vec3(1.0, 0.12, 0.22) * las * 0.72;
	col.rgb += vec3(1.0, 0.55, 0.4) * las * 0.18;

	if (hole_str > 0.02 && hole_uv.x >= 0.0) {
		vec2 hd = uv - hole_uv;
		hd.y *= px.x / px.y;
		float hr = max(hole_rad, 0.012);
		float r = length(hd);
		if (r < hr) {
			col.rgb = vec3(0.0);
		} else {
			float ring = abs(r - hr * 1.55);
			float acc = exp(-ring * 55.0) * hole_str;
			col.rgb += vec3(1.0, 0.38, 0.08) * acc * 0.85;
			float photon = exp(-abs(r - hr * 1.08) * 90.0) * hole_str;
			col.rgb += vec3(1.0, 0.82, 0.4) * photon * 0.65;
			float fade = smoothstep(hr * 4.5, hr, r);
			col.rgb *= 1.0 - fade * 0.55 * hole_str;
		}
	}

	col.rgb = mix(col.rgb, col.rgb * vec3(1.25, 0.82, 0.75), heat_stress * mdist * 0.6);
	col.rgb += vec3(1.0, 0.86, 0.7) * clamp(hit_flash, 0.0, 1.0) * 0.55;
	col.rgb = mix(col.rgb, col.rgb * room_tint * 1.8, clamp(tint_amt, 0.0, 0.5));

	COLOR = col;
}
