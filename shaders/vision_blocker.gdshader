shader_type canvas_item;
// Full-screen darkness with a circular "reveal" hole around a given
// point, in pixel space (not UV) so the hole stays a true circle
// regardless of the viewport's aspect ratio. Used by VisionBlocker for
// Douse's steam cloud (A.2: "blocks vision") — everything inside
// reveal_radius_px is fully visible, everything past
// reveal_radius_px + falloff_px is darkened by `darkness`, with a soft
// gradient between the two. `active` is a 0/1 switch so the whole
// overlay is fully transparent (and costs nothing extra) whenever the
// player isn't standing inside a cloud.

uniform vec2 reveal_center_px = vec2(0.0, 0.0);
uniform float reveal_radius_px = 100.0;
uniform float falloff_px = 50.0;
uniform float darkness = 0.92;
uniform float active = 0.0;

void fragment() {
	vec2 screen_px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float dist = distance(screen_px, reveal_center_px);
	float alpha = smoothstep(reveal_radius_px, reveal_radius_px + falloff_px, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha * darkness * active);
}
