// Additive radial flash billboard (impact bloom stand-in). Colour from COLOR.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float core = 0.18;

void vertex() {
	// Camera-facing billboard that keeps the particle's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float glow = exp2(-6.0 * r) * (1.0 - smoothstep(0.85, 1.0, r));
	float hot = 1.0 - smoothstep(0.0, core, r);
	// The hot core dims with the ramp so the flash dies out completely.
	ALBEDO = COLOR.rgb * glow * 1.4 + vec3(hot) * max(COLOR.r, max(COLOR.g, COLOR.b));
}
