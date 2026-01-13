shader_type canvas_item;

uniform vec4 top_color    : source_color = vec4(1.0, 0.95, 0.70, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.78, 0.47, 0.00, 1.0);

uniform float band_top = 0.30;
uniform float band_bottom = 0.70;
uniform float banding = 0.0;

void fragment() {
    // Glyph alpha
    float a = texture(TEXTURE, UV).a;

    // Gradient factor (compressed into a band)
    float t = clamp((UV.y - band_top) / max(band_bottom - band_top, 0.0001), 0.0, 1.0);

    // Optional stepped banding
    if (banding > 0.0) {
        t = floor(t / banding) * banding;
    }

    vec3 grad = mix(top_color.rgb, bottom_color.rgb, t);

    // No return: just output transparent when alpha is 0
    COLOR = vec4(grad, a);
}
