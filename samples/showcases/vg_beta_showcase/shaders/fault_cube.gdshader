shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float explosion_factor : hint_range(0.0, 5.0) = 1.0;
uniform float u_blend : hint_range(0.0, 1.0) = 1.0;

varying vec2 v_uv;
varying vec3 v_normal;
varying float v_facet_id;

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	v_uv = UV;
	v_normal = NORMAL;
	// Each unwelded vertex gets its own explosion offset.
	float facet_id = floor(v_uv.x * 10.0) + floor(v_uv.y * 10.0) * 11.0 + dot(NORMAL, vec3(1.0, 2.0, 3.0)) * 13.0;
	v_facet_id = facet_id;
	float facet_rand = hash1(facet_id);

	vec3 face_normal = NORMAL;
	float pulse = (sin(TIME * 2.5) * 0.5 + 0.5) * explosion_factor;
	float boom = pulse * mix(0.55, 1.35, facet_rand);

	VERTEX += face_normal * boom * 2.4;
	// Slight per-facet shear so tiles visibly separate.
	vec3 tangent = normalize(cross(face_normal, vec3(0.0, 1.0, 0.01)));
	vec3 bitangent = cross(face_normal, tangent);
	VERTEX += tangent * (facet_rand - 0.5) * boom * 0.35;
	VERTEX += bitangent * (hash1(facet_id + 17.0) - 0.5) * boom * 0.35;

	float shrink_scale = max(0.15, 1.0 - pulse * 0.35);
	VERTEX *= shrink_scale;
}

void fragment() {
	float pulse = sin(TIME * 2.5) * 0.5 + 0.5;

	// Facet grid lines (procedural — no texture file).
	vec2 cell = fract(v_uv * 10.0);
	float edge = min(min(cell.x, 1.0 - cell.x), min(cell.y, 1.0 - cell.y));
	edge = smoothstep(0.02, 0.09, edge);

	float facet_rand = hash1(v_facet_id);
	vec3 dark_metal = vec3(0.08, 0.07, 0.11);
	vec3 warm_metal = vec3(0.22, 0.16, 0.12);
	vec3 plasma_hot = vec3(1.0, 0.45, 0.08);
	vec3 plasma_core = vec3(1.0, 0.85, 0.35);

	vec3 facet_base = mix(dark_metal, warm_metal, facet_rand);
	float heat = pulse * (0.35 + facet_rand * 0.65);
	vec3 facet_glow = mix(plasma_hot, plasma_core, facet_rand) * heat;

	vec3 col = mix(vec3(0.02, 0.01, 0.03), facet_base + facet_glow, edge);
	col += plasma_core * (1.0 - edge) * pulse * 0.35;

	// Face-normal tint so each cube side reads differently.
	col *= 0.85 + abs(v_normal) * 0.25;

	col *= u_blend;
	ALBEDO = col;
	EMISSION = facet_glow * edge * 0.55 * u_blend;
}
