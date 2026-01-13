shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.25, 1.0); // warm gold
uniform float softness = 2.2;   // higher = softer edges
uniform float intensity = 1.0;  // animated by script

void fragment() {
	// UV is 0..1
	vec2 p = UV * 2.0 - 1.0;              // center at (0,0)
	float r = length(p);                  // radius
	float g = pow(max(0.0, 1.0 - r), softness); // radial falloff
	g *= intensity;

	COLOR = vec4(glow_color.rgb, glow_color.a * g);
}
