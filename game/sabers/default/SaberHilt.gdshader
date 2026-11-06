// Procedural hilt: brushed dark metal, ribbed grip, glowing emitter ring at the
// blade end and a small pommel light. Mesh: cylinder centred on its origin.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0, 0.1, 0.2, 1.0);
uniform float half_height = 0.075;

varying float h;

void vertex() {
	h = VERTEX.y / half_height; // -1 pommel .. +1 emitter
}

void fragment() {
	float ribs = step(0.5, fract((h + 1.0) * 9.0)) * step(-0.55, h) * step(h, 0.45);
	float emitter = smoothstep(0.78, 0.86, h) * (1.0 - smoothstep(0.94, 0.99, h));
	float pommel = 1.0 - smoothstep(-0.97, -0.9, h);
	ALBEDO = mix(vec3(0.07, 0.075, 0.085), vec3(0.025), ribs);
	METALLIC = 0.9;
	ROUGHNESS = mix(0.28, 0.6, ribs);
	EMISSION = mix(color.rgb, vec3(1.0), 0.35) * (2.2 * emitter + 0.8 * pommel);
}
