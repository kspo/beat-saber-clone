shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color = vec4(0.9, 0.1, 0.16, 1.0);
uniform vec4 center_color : source_color = vec4(1.0);

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float core = smoothstep(0.25, 0.72, facing);
	// A readable white core without relying on an expensive bloom pass.
	ALBEDO = mix(color.rgb, vec3(1.0), core);
	EMISSION = mix(color.rgb * 1.2, vec3(1.8), core);
}
