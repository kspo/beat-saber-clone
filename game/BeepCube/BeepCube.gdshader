shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.9, 0.1, 0.16, 1.0);
uniform float metallic = 0.08;
uniform float roughness = 0.30;
uniform float sub_emission_energy = 0.025;
uniform bool cutted = false;
uniform float cut_vanish = 0.0;
uniform float cut_white_margin = 0.018;
uniform bool is_dot = false;
uniform bool arrows_enabled = true;
uniform bool is_chain_head = false;
uniform vec3 cut_plane_normal = vec3(0.0);
uniform float cut_plane_dist = 0.0;
varying vec3 local_position;
varying vec3 local_normal;
varying float cut_interp;
varying float chain_interp;

float rounded_box_distance(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
	chain_interp = 0.1 + VERTEX.y;
	cut_interp = dot(VERTEX, cut_plane_normal) - cut_plane_dist - cut_vanish;
}

void fragment() {
	if ((cutted && cut_interp < 0.0) || (is_chain_head && chain_interp < 0.0)) discard;
	float face = smoothstep(0.84, 0.98, local_normal.z);
	vec2 icon_position = local_position.xy / 0.25;
	// Inset lacquer panel and recessed rounded frame, on all six faces.
	// The existing beveled mesh supplies the silhouette; no overlay geometry.
	vec3 n = abs(local_normal);
	vec2 panel_position = (n.z >= max(n.x, n.y) ? local_position.xy :
		(n.x > n.y ? local_position.yz : local_position.xz)) / 0.25;
	float panel_distance = rounded_box_distance(panel_position, vec2(0.82), 0.16);
	float groove = 1.0 - smoothstep(0.025, 0.075, abs(panel_distance));
	float distance_field;
	if (is_dot) {
		// Dot stays centered. Reference diameter is roughly 30% of the face.
		distance_field = length(icon_position) - 0.30;
	} else {
		// Five-sided wedge with short flat shoulders, tucked against the entry
		// edge. Rotation moves both the glyph and its offset for all directions.
		// Keep chain heads' mark in their retained (upper) part of the mesh too.
		distance_field = max(max(abs(icon_position.x) - 0.62,
			0.45 * abs(icon_position.x) - icon_position.y + 0.34), icon_position.y - 0.68);
	}
	// Derivative AA preserves the mark at different render scales and viewing distances.
	float coverage = 1.0 - smoothstep(-max(fwidth(distance_field), 0.002), max(fwidth(distance_field), 0.002), distance_field);
	float icon = coverage * face * float(is_dot || arrows_enabled);
	// Small surface halo remains visible on Quest even with bloom disabled.
	// Confined to this material: no transparent shells or fullscreen glow pass.
	float halo = exp2(-max(distance_field, 0.0) * 42.0) * (1.0 - coverage) * face * float(is_dot || arrows_enabled);
	// Body illumination comes from scene lights, not a painted front-face glow.
	float lacquer = 0.82 * (1.0 - 0.40 * groove);
	ALBEDO = mix(color.rgb * lacquer, vec3(1.0), icon);
	METALLIC = metallic * (1.0 - icon);
	ROUGHNESS = mix(roughness, 0.38, groove);
	EMISSION = color.rgb * (sub_emission_energy + 0.60 * halo) + vec3(3.2) * icon;
	if (is_chain_head) EMISSION += vec3(1.0 - smoothstep(cut_white_margin, cut_white_margin + 0.01, chain_interp));
	if (cutted) EMISSION += vec3(1.0 - smoothstep(cut_white_margin, cut_white_margin + 0.01, cut_interp));
	if (!FRONT_FACING) {
		// Cut fragments have a dark interior and a luminous rim, not a white fill.
		float cut_rim = float(cutted) * (1.0 - smoothstep(cut_white_margin, cut_white_margin + 0.01, cut_interp));
		ALBEDO = color.rgb * 0.08;
		EMISSION = mix(vec3(0.0), mix(color.rgb, vec3(1.0), 0.8) * 1.5, cut_rim);
	}
}
