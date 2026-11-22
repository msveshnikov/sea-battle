shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Foam skirt around an anchored hull: elliptical ring of animated noise.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float strength = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = texture(noise_tex, UV * vec2(1.0, 3.0) + vec2(TIME * 0.03, TIME * 0.05)).r;
	float n2 = texture(noise_tex, UV * vec2(2.0, 5.0) - vec2(TIME * 0.04, 0.0)).r;
	float ring = smoothstep(0.62, 0.82, r + (n - 0.5) * 0.25) * (1.0 - smoothstep(0.85, 1.0, r + (n2 - 0.5) * 0.2));
	float a = ring * smoothstep(0.35, 0.7, n2 + 0.25) * strength;
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = clamp(a, 0.0, 1.0) * 0.85;
}
