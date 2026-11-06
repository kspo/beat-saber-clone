// Analytic "light tube" halo for thin emissive beams (lasers, track lights,
// saber blades). Replaces fullscreen bloom, which is disabled on Quest.
//
// The mesh is inflated perpendicular to its long axis; each fragment then
// measures the closest distance between its view ray and the beam's centre
// line and turns it into a soft falloff. The result looks like a volumetric
// glow from any angle, is independent of the mesh's face layout, and costs
// one additive pass with no depth writes and no texture reads.
//
// Use as `next_pass` of a beam material or as a MeshInstance3D
// `material_overlay`. The mesh's local `axis` must run along the beam.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
// World-space radius at which the halo fades to zero.
uniform float glow_radius = 0.35;
// Peak additive intensity at the beam centre.
uniform float intensity = 0.9;
// Higher values concentrate the halo towards the core.
uniform float tightness = 4.0;
// Local-space cross-section multiplier; must cover glow_radius.
uniform float expand = 8.0;
uniform vec3 axis = vec3(0.0, 0.0, 1.0);
// White-hot centre line (world radius) added on top of the coloured halo.
uniform float core_radius = 0.0;
uniform float core_intensity = 1.0;
// Half length of the beam along `axis` in mesh-local units, measured from the
// mesh origin. 0 treats the beam as an infinite line.
uniform float half_length = 0.0;
// Exponential dimming with view distance, standing in for scene fog (additive
// passes cannot use regular fog without brightening towards the fog colour).
uniform float distance_fade = 0.0;

varying vec3 axis_origin_view;
varying vec3 axis_dir_view;
varying vec3 view_position;
varying float half_length_view;

void vertex() {
	float along = dot(VERTEX, axis);
	// Finite beams also grow past their ends so the halo can round off there.
	float cap = half_length > 0.0 ? sign(along) * glow_radius : 0.0;
	VERTEX = axis * (along + cap) + (VERTEX - axis * along) * expand;
	axis_origin_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 axis_view = (MODELVIEW_MATRIX * vec4(axis, 0.0)).xyz;
	axis_dir_view = normalize(axis_view);
	half_length_view = half_length * length(axis_view);
	view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ray = normalize(view_position);
	// Closest point on the beam axis to this fragment's view ray.
	float b = dot(ray, axis_dir_view);
	float denom = 1.0 - b * b;
	float s = denom > 1e-5
		? (b * dot(ray, axis_origin_view) - dot(axis_dir_view, axis_origin_view)) / denom
		: dot(view_position - axis_origin_view, axis_dir_view);
	if (half_length > 0.0) s = clamp(s, -half_length_view, half_length_view);
	vec3 p = axis_origin_view + axis_dir_view * s;
	// Distance from that point to the ray (camera sits at the view origin).
	float d = length(p - ray * max(dot(p, ray), 0.0));
	float x = clamp(d / glow_radius, 0.0, 1.0);
	float halo = exp2(-tightness * x) * (1.0 - x * x);
	vec3 c = color.rgb * color.a;
	// The core follows the light's brightness, so it dims when the light fades.
	float level = max(c.r, max(c.g, c.b));
	float hot = core_radius > 0.0 ? exp2(-d * d / (core_radius * core_radius) * 1.5) * core_intensity * level : 0.0;
	ALBEDO = (c * halo * intensity + vec3(hot)) * exp2(-distance_fade * length(p));
}
