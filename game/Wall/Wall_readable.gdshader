shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform vec3 size = vec3(1.0);
uniform vec4 albedo_color : source_color = vec4(1.0, 0.12, 0.18, 1.0);
uniform sampler2D fracture_field : repeat_enable, filter_linear_mipmap;
varying vec3 local_position;
varying vec3 local_normal;
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 remaining = max(size * 0.5 - abs(local_position), vec3(0.0));
	vec3 n = abs(local_normal);
	// Ignore the normal axis: the other two distances describe the face border.
	vec2 face_distance = n.x > 0.5 ? remaining.yz : (n.y > 0.5 ? remaining.xz : remaining.xy);
	vec2 face_position = n.x > 0.5 ? local_position.yz : (n.y > 0.5 ? local_position.xz : local_position.xy);
	float edge_distance = min(face_distance.x, face_distance.y);
	float edge_aa = max(fwidth(edge_distance), 0.001);
	float edge = 1.0 - smoothstep(0.012 - edge_aa, 0.012 + edge_aa, edge_distance);
	float rim = 1.0 - smoothstep(0.012, 0.075, edge_distance);
	// Wider inner glow from the frame towards the centre (bloom stand-in).
	float glow = exp2(-edge_distance * 26.0);
	// One small shared, baked field: irregular electric contours instead of a
	// regular grid. A slow drift makes the contours crawl like live current.
	vec2 uv = face_position * 0.38;
	float field = texture(fracture_field, uv + vec2(0.0, TIME * 0.025)).r;
	float contour_distance = abs(field - 0.5);
	float contour_aa = max(fwidth(field), 0.002);
	float fracture = (1.0 - smoothstep(0.003, 0.003 + contour_aa * 1.5, contour_distance)) * (1.0 - rim);
	vec3 hot = mix(albedo_color.rgb, vec3(1.0), 0.6);
	// Dark smoked-glass body; light lives only in the frame, glow and contours.
	vec3 body = albedo_color.rgb * 0.06;
	ALBEDO = body + albedo_color.rgb * (glow * 0.55 + fracture * 0.9) + hot * edge * 1.4;
	ALPHA = clamp(0.42 + edge * 0.58 + glow * 0.25 + fracture * 0.35, 0.0, 1.0);
}
