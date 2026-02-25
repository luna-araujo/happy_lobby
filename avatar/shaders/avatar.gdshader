shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_disabled, shadows_disabled;

uniform vec4 base_color : source_color = vec4(0.75, 0.65, 0.55, 1.0);

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.45;
uniform float mid_strength : hint_range(0.0, 1.0) = 0.15;
uniform float light_strength : hint_range(0.0, 1.0) = 0.25;

uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.25;
uniform float light_threshold : hint_range(0.0, 1.0) = 0.65;

uniform float rim_threshold : hint_range(0.0, 1.0) = 0.70;
uniform float rim_lighten : hint_range(0.0, 1.0) = 0.30;
uniform float hit_glow : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = base_color.rgb;
	EMISSION = base_color.rgb * hit_glow * 2.0;
}

void light() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(LIGHT);
	vec3 v = normalize(VIEW);
	float ndl = max(dot(n, l), 0.0);
	float ndv = max(dot(n, v), 0.0);

	vec3 shadow_tone = base_color.rgb * (1.0 - shadow_strength);
	vec3 mid_tone = base_color.rgb * (1.0 - mid_strength);
	vec3 light_tone = mix(base_color.rgb * (1.0 + light_strength), vec3(1.0), rim_lighten);

	vec3 toon_color = mid_tone;
	if (ndl < shadow_threshold) {
		toon_color = shadow_tone;
	} else if (ndl >= light_threshold) {
		toon_color = light_tone;
	}

	if ((1.0 - ndv) >= rim_threshold) {
		toon_color = light_tone;
	}

	vec3 glow_add = base_color.rgb * hit_glow * 0.8;
	vec3 glow_lit = mix(toon_color, vec3(1.0), hit_glow * 0.35);
	DIFFUSE_LIGHT += (glow_lit + glow_add) * LIGHT_COLOR;
}
