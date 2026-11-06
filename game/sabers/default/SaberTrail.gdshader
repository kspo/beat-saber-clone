// Swing trail ribbon. UV.x = normalized age (0 = blade now, 1 = oldest),
// UV.y = 0 at the tip, 1 at the hilt. Additive, so fading to black = fading out.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 1.0;

void fragment() {
	float age = clamp(UV.x, 0.0, 1.0);
	float fade = pow(1.0 - age, 2.6);
	// Brightest towards the tip where the blade moves fastest; soft at both edges.
	float span = mix(1.0, 0.25, smoothstep(0.0, 1.0, UV.y));
	float edges = smoothstep(0.0, 0.06, UV.y) * smoothstep(1.0, 0.85, UV.y);
	// Thin white-hot leading edge right behind the blade.
	float lead = 1.0 - smoothstep(0.0, 0.12, age);
	vec3 c = mix(color.rgb, vec3(1.0), 0.65 * lead);
	ALBEDO = c * fade * span * edges * intensity * 0.55;
}
