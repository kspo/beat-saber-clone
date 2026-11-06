// Additive streak for CPU particle sparks. Particles align their local Y with
// velocity, so the +Y end is the hot white head and the tail fades out.
// The per-particle colour (COLOR) carries the colour ramp: white -> tint -> black.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float half_length = 0.06;
uniform float head_whiteness = 0.85;

varying float along;

void vertex() {
	along = clamp(VERTEX.y / half_length * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	float body = along * along;
	vec3 c = mix(COLOR.rgb, vec3(max(max(COLOR.r, COLOR.g), COLOR.b)), head_whiteness * body);
	ALBEDO = c * (0.12 + 1.6 * body);
}
