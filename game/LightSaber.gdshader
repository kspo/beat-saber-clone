shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color = vec4(0.9, 0.1, 0.16, 1.0);
uniform vec4 center_color : source_color = vec4(1.0);

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// Wide white-hot core with a thin saturated rim; the halo pass adds the glow.
	float core = smoothstep(0.12, 0.55, facing);
	vec3 rim = mix(color.rgb, vec3(1.0), 0.15) * 1.3;
	ALBEDO = mix(rim, center_color.rgb, core);
}
