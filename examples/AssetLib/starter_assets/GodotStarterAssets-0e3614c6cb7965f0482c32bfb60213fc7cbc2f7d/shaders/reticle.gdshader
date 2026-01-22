shader_type canvas_item;
render_mode unshaded;

/** Normalized screen space position. */
uniform vec2 target = vec2(0.5, 0.5);

/** Global scale. For pixel perfect results it should be a multiple of 2. */
uniform float scale: hint_range(0.0, 100, 1.0) = 1;

/** Angle of rotation in degrees. */
uniform float rotation: hint_range(0.0, 360.0, 0.1);

/**
Antialiasing mode.

Off: Disables antialiasing.

In: Sharp, but may cause thin lines to dissapear.

Out: Slightly blurrier, but thin lines are more stable.
*/
uniform int antialiasing: hint_enum("Off", "In", "Out") = 2;

/** Strength of the antialiasing in px. Bigger values are softer, but may make shapes blurry at lower resolutions. */
uniform int antialiasing_intensity: hint_enum("0.25 px", "0.5 px", "0.75 px", "1 px", "2 px") = 3;

/** How accurate the AA aproximation is.*/
uniform int antialiasing_quality: hint_enum("Performance", "Quality") = 1;

/** Follow Godot's built-in window stretching. Also useful for zooming in editor.*/
uniform bool use_window_stretch = true;

group_uniforms Ring;

/** Enable or disable the ring. */
uniform bool draw_ring = true;

/** The color of the ring. */
uniform vec4 ring_color : source_color = vec4(0.5, 0.5, 0.5, 0.5);

/** Diameter of the ring in px. */
uniform float ring_size: hint_range(2.0, 512.0, 2) = 16.0;

/** The thickness of the ring in px. */
uniform float ring_thickness: hint_range(2.0, 512.0, 2.0) = 2.0;

group_uniforms Cross;

/** Enable or disable the cross. */
uniform bool draw_cross = true;

/** Enable or disable the margin between the ring and the cross. */
uniform bool draw_cross_margin = true;

/** The color of the cross. */
uniform vec4 cross_color: source_color = vec4(0.5, 0.5, 0.5, 0.5);

/** Diameter of the cross in px. */
uniform float cross_size: hint_range(2.0, 512.0, 2) = 16.0;

/** The thickness of the cross in px. */
uniform float cross_thickness: hint_range(2.0, 512.0, 2) = 2.0;

/** Gap between each arm of the cross. */
uniform float cross_offset: hint_range(0.0, 512.0, 2) = 8.0;

/** The thickness of the margin between the cross and the ring. */
uniform float cross_margin: hint_range(0.0, 512.0, 2) = 4.0;

varying mat4 global_matrix;

// SDF formulas by Inigo Quilez: https://iquilezles.org/articles/distfunctions2d
// SDF AA techniques by bµg: https://blog.pkh.me/p/44-perfecting-anti-aliasing-on-signed-distance-functions.html

float sd_circle( in vec2 p, in float r ) {
	return length(p)-r;
}

float sd_box( in vec2 p, in vec2 b ){
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

float sd_cross( in vec2 p, in vec2 b, float r ) {
    p = abs(p); p = (p.y>p.x) ? p.yx : p.xy;
    vec2  q = p - b;
    float k = max(q.y,q.x);
    vec2  w = (k>0.0) ? q : vec2(b.y-p.x,-k);
    return sign(k)*length(max(w,0.0)) + r;
}

float render_sdf(in float d){
	if (antialiasing == 0){
		return d < 0.0 ? 1.0 : 0.0;
	}
	
	float ai;
	
	switch(antialiasing_intensity){
		case 0:
			ai = 0.25;
			break;
		case 1:
			ai = 0.5;
			break;
		case 2:
			ai = 0.75;
			break;
		case 3:
			ai = 1.0;
			break;
		case 4:
			ai = 2.0;
			break;
	}
	
	if (antialiasing == 1){
		if (antialiasing_quality == 0){
			return smoothstep(0.0, -fwidth(d) * ai, d);
		}
		return smoothstep(0.0, -length(vec2(dFdx(d), dFdy(d))) * ai, d);
	}else{
		if (antialiasing_quality == 0){
			return smoothstep(fwidth(d) * ai, 0.0, d);
		}
		return smoothstep(length(vec2(dFdx(d), dFdy(d))) * ai, 0.0, d); 
	}
}

void vertex(){
	global_matrix = CANVAS_MATRIX;
}

void fragment() {
	// Rotation in radians.
	float angle = radians(rotation);
	
	// Rotation matrix.
	mat2 rm  = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	
	vec2 viewport_scale = vec2(1,1);
	
	if (use_window_stretch == true){
		viewport_scale = vec2(length(global_matrix[0]), length(global_matrix[1]));
		
	}
	
	// Center point
	vec2 p = rm * ((SCREEN_UV * 2.0 - target * 2.0) / SCREEN_PIXEL_SIZE) / viewport_scale / scale;
	
	// Expensive checks restricted to the bounding circle plus 10 pixels.
	if (sd_circle(p, max(ring_size, cross_size + cross_offset) + 10.0) > 0.0 ){
		discard;
	}else{
		// Signed distances.
		float cross_sd = 0.0;
		float cross_offset_sd = 0.0;
		float ring_sd = 0.0;
		
		// Masks.
		float cross_mask = 0.0;
		float ring_mask = 0.0;
		// Cross.
		if (draw_cross == true){
			// Cross.
			cross_sd = sd_cross(p, vec2(cross_size + cross_offset, cross_thickness), 0.0);
			
			// Cross offset.
			cross_offset_sd = sd_box(p, vec2(cross_offset));
			
			float composed_cross_sdf = max(cross_sd, -cross_offset_sd);
			
			cross_mask = render_sdf(composed_cross_sdf);
		}
		
		// Ring.
		if (draw_ring == true){
			// Outer circle.
			float  oc = sd_circle(p,  ring_size);
			
			// Inner circle.
			float  ic = oc + ring_thickness;
			
			ring_sd = max(oc,  -ic);
			
			if (draw_cross && draw_cross_margin && cross_margin != 0.0){
				// Cross margin.
				float cm = cross_sd - cross_margin;
				ring_sd = max(ring_sd, -cm);
			}
			
			ring_mask = render_sdf(ring_sd);
		} 
		
		COLOR.rgb = mix(ring_mask * ring_color.rgb, cross_mask * cross_color.rgb, cross_mask);
		COLOR.a = mix(ring_mask * ring_color.a, cross_mask * cross_color.a, cross_mask);
	}
}
