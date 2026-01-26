shader_type canvas_item;

// Color in the texture that should be considered the "skin mask".
uniform vec4 skin_mask_color : source_color = vec4(0.95, 0.7, 0.6, 1.0);
// Replacement color for the skin_mask areas.
uniform vec4 skin_color : source_color = vec4(0.95, 0.7, 0.6, 1.0);
// How different a pixel may be from the mask to still be replaced (0..1).
uniform float tolerance : hint_range(0.0, 1.0) = 0.06;
// Softness of the transition around the tolerance (0..0.5).
uniform float feather : hint_range(0.0, 0.5) = 0.02;

void fragment() {
	// Sample the texture (works for Polygon2D / Sprite use)
	vec4 tex = texture(TEXTURE, UV) * COLOR;

	// Compute color distance (ignore alpha when comparing)
	float d = distance(tex.rgb, skin_mask_color.rgb);

	// Create a smooth mask where distance <= tolerance -> replaced
	float edge0 = max(0.0, tolerance - feather);
	float edge1 = tolerance + feather;
	float replace_alpha = 1.0 - smoothstep(edge0, edge1, d);

	// If mask color has alpha < 1, scale replacement influence
	replace_alpha *= skin_mask_color.a;

	// Mix original color with replacement color according to mask
	vec3 out_rgb = mix(tex.rgb, skin_color.rgb, replace_alpha * skin_color.a);

	COLOR = vec4(out_rgb, tex.a);
}
