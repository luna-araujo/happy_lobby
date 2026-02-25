shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, specular_disabled, shadows_disabled;

uniform float outline_width_px : hint_range(0.5, 12.0) = 2.0;
uniform vec3 outline_color : source_color = vec3(0.03, 0.03, 0.03);

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float width = max(fwidth(ndv) * outline_width_px, 1e-5);
	float edge = 1.0 - smoothstep(0.0, width, ndv);

	if (edge <= 0.001) {
		discard;
	}
	ALBEDO = outline_color;
}
