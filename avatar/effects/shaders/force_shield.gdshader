shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 shield_color : source_color = vec4(0.10, 0.70, 1.00, 1.0);
uniform vec4 edge_color : source_color = vec4(0.60, 0.90, 1.00, 1.0);

uniform float base_opacity : hint_range(0.0, 2.0) = 0.22;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform float fresnel_strength : hint_range(0.0, 3.0) = 1.2;

uniform float line_density_x : hint_range(1.0, 80.0) = 28.0;
uniform float line_density_y : hint_range(1.0, 80.0) = 18.0;
uniform float line_speed_x : hint_range(-10.0, 10.0) = 1.3;
uniform float line_speed_y : hint_range(-10.0, 10.0) = -0.9;
uniform float line_intensity : hint_range(0.0, 2.0) = 0.55;

uniform float pulse_speed : hint_range(0.0, 20.0) = 3.0;
uniform float pulse_intensity : hint_range(0.0, 2.0) = 0.35;
uniform float hit_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float height_fade_start : hint_range(0.0, 1.0) = 0.0;
uniform float height_fade_end : hint_range(0.0, 1.0) = 1.0;
uniform bool height_fade_invert = false;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(dot(n, v), 0.0, 1.0);

	float fresnel = pow(1.0 - ndv, fresnel_power) * fresnel_strength;

	float line_x = sin((UV.x * line_density_x + TIME * line_speed_x) * 6.2831853) * 0.5 + 0.5;
	float line_y = sin((UV.y * line_density_y + TIME * line_speed_y) * 6.2831853) * 0.5 + 0.5;
	float grid = line_x * line_y;

	float pulse = sin(TIME * pulse_speed + UV.y * 10.0) * 0.5 + 0.5;
	pulse *= pulse_intensity;

	float hit = hit_pulse * (0.6 + fresnel * 0.4);
	float energy = base_opacity + fresnel + grid * line_intensity + pulse + hit;
	float h = clamp(UV.y, 0.0, 1.0);
	float height_fade = smoothstep(height_fade_start, height_fade_end, h);
	if (height_fade_invert) {
		height_fade = 1.0 - height_fade;
	}
	energy *= height_fade;

	vec3 col = mix(shield_color.rgb, edge_color.rgb, clamp(fresnel + hit * 0.5, 0.0, 1.0));

	ALBEDO = col * energy;
	EMISSION = col * energy * 1.6;
	ALPHA = clamp(energy * shield_color.a, 0.0, 1.0);
}
