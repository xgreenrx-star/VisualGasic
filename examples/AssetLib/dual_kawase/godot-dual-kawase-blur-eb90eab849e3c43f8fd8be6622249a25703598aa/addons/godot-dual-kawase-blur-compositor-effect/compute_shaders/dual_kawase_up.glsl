#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(push_constant, std430) uniform Params {
	float offset_multiplier;
} params;

layout(set = 0, binding = 0, rgba32f) uniform image2D OUTPUT_TEXTURE;
layout(set = 0, binding = 1) uniform sampler2D INPUT_TEXTURE;

void main() {
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(OUTPUT_TEXTURE);
    if (texel.x >= size.x || texel.y >= size.y) {
    	return;
    }
    vec2 uv = (vec2(texel) + 0.5) / size;
    vec2 o = 0.5 / size * params.offset_multiplier;

	vec4 color = vec4(0.0);
	
	/* Sample 4 edge centers with 1x weight each */
	color += texture(INPUT_TEXTURE, uv + vec2(-o.x * 2.0, 0.0)); /* left */
	color += texture(INPUT_TEXTURE, uv + vec2( o.x * 2.0, 0.0)); /* right */
	color += texture(INPUT_TEXTURE, uv + vec2(0.0, -o.y * 2.0)); /* bottom */
	color += texture(INPUT_TEXTURE, uv + vec2(0.0,  o.y * 2.0)); /* top */
	
	/* Sample 4 diagonal corners with 2x weight each */
	color += texture(INPUT_TEXTURE, uv + vec2(-o.x,  o.y)) * 2.0; /* top-left */
	color += texture(INPUT_TEXTURE, uv + vec2( o.x,  o.y)) * 2.0; /* top-right */
	color += texture(INPUT_TEXTURE, uv + vec2(-o.x, -o.y)) * 2.0; /* bottom-left */
	color += texture(INPUT_TEXTURE, uv + vec2( o.x, -o.y)) * 2.0; /* bottom-right */

	color /= 12.0;

	imageStore(OUTPUT_TEXTURE, texel, color);
}
