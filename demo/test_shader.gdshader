shader_type canvas_item;

// Define a uniform color parameter that we can set from Gasic
uniform vec4 my_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    // Mix the texture color with our custom color
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Simple effect: Tint the sprite
    COLOR = tex_color * my_color;
}
