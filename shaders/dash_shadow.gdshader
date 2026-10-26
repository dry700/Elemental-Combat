shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = vec4(shadow_color.rgb, tex_color.a * opacity);
}
