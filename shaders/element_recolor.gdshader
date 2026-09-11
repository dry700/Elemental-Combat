shader_type canvas_item;

// Set per-instance from GDScript (see ElementIndicator.apply_element_tint)
// — never hardcoded per-element here, so one shader covers all five.
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	// Original pixel's luminance becomes a pure brightness mask — this
	// keeps the arc's existing bright-at-peak/dim-at-tips shape exactly
	// as drawn; only WHICH color carries that brightness changes.
	float luminance = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	// *1.4 compensates for luminance-multiplied color naturally reading
	// darker than the source — without it every element comes out
	// muddier than the original neutral white/orange.
	COLOR.rgb = tint_color.rgb * luminance * 1.4;
	COLOR.a = tex_color.a;
}