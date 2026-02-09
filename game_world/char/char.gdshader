shader_type canvas_item;

// Replacement colors for parts encoded by specific alpha values.
uniform vec4 skin_color : source_color = vec4(0.95, 0.7, 0.6, 1.0);
uniform vec4 hair_color : source_color = vec4(0.2, 0.15, 0.08, 1.0);
uniform vec4 eyes_color : source_color = vec4(0.1, 0.2, 0.3, 1.0);
uniform vec4 upper_color : source_color = vec4(0.2, 0.4, 0.6, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.15, 0.2, 0.25, 1.0);
uniform vec4 shoes_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 accent_upper : source_color = vec4(0.8, 0.5, 0.2, 1.0);
uniform vec4 accent_bottom : source_color = vec4(0.6, 0.3, 0.2, 1.0);

void fragment() {
	// Sample the texture (works for Polygon2D / Sprite use)
	vec4 raw = texture(TEXTURE, UV);
	vec4 tex = raw * COLOR;

	// Decode alpha to an 8-bit integer (0..255) with exact match.
	int a8 = int(round(raw.a * 255.0));

	// Preserve grayscale (value) from texture while applying uniform hue.
	float gray = dot(raw.rgb, vec3(0.299, 0.587, 0.114));

	vec3 out_rgb = tex.rgb;
	float out_a = tex.a;
	if (a8 == 254) {
		out_rgb = skin_color.rgb * gray;
		out_a = COLOR.a;
	} else if (a8 == 253) {
		out_rgb = hair_color.rgb * gray;
		out_a = COLOR.a;
	} else if (a8 == 252) {
		out_rgb = eyes_color.rgb * gray;
		out_a = COLOR.a;
	} else if (a8 == 251) {
		out_rgb = upper_color.rgb * gray;
		out_a = COLOR.a;
	} else if (a8 == 250) {
		out_rgb = bottom_color.rgb * gray;
		out_a = COLOR.a;
	} else if (a8 == 249) {
		out_rgb = shoes_color.rgb * gray;
		out_a = COLOR.a;
	} else if (a8 == 248) {
		out_rgb = accent_upper.rgb * gray;
		out_a = COLOR.a;
	} else if (a8 == 247) {
		out_rgb = accent_bottom.rgb * gray;
		out_a = COLOR.a;
	}

	COLOR = vec4(out_rgb, out_a);
}
