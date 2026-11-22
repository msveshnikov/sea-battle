shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Holographic 10x10 grid. `cells` (10x10, nearest) holds the shot state per cell:
//   r = miss, g = hit, b = sunk, a = deduced empty.  `overlay` (10x10): r = valid preview,
//   g = invalid preview, b = radar area, a = hover.  UV 0..1 over the mesh; the playable area is
//   inset by `margin` on each side so the corner brackets fit.

uniform sampler2D cells : filter_nearest;
uniform sampler2D overlay : filter_nearest;
uniform vec3 line_color : source_color = vec3(0.2, 0.95, 1.0);
uniform vec3 hit_color : source_color = vec3(1.0, 0.25, 0.1);
uniform vec3 hover_color : source_color = vec3(0.4, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float margin = 0.05;
uniform float active = 1.0;

void fragment() {
	vec2 uv = (UV - vec2(margin)) / (1.0 - 2.0 * margin);
	vec3 col = vec3(0.0);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec2 g = uv * 10.0;
	vec2 fw = fwidth(g);
	vec2 fr = abs(fract(g + 0.5) - 0.5);
	float lw = 0.035;
	float line = max(1.0 - smoothstep(lw, lw + fw.x * 1.5, fr.x), 1.0 - smoothstep(lw, lw + fw.y * 1.5, fr.y));
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0);
	col += line_color * line * inside * (0.35 + 0.4 * active) * pulse;
	col += line_color * 0.012 * inside * active;
	vec2 b = abs(uv - 0.5);
	float edge = max(b.x, b.y);
	float border = (1.0 - smoothstep(0.5, 0.508, edge)) * smoothstep(0.492, 0.5, edge);
	col += line_color * border * 1.4;
	float corner = step(0.53, b.x) * step(b.x, 0.545) * step(0.38, b.y) * step(b.y, 0.545)
		+ step(0.53, b.y) * step(b.y, 0.545) * step(0.38, b.x) * step(b.x, 0.545);
	col += line_color * clamp(corner, 0.0, 1.0) * 1.6 * pulse;
	if (inside > 0.5) {
		vec2 cuv = (floor(g) + 0.5) / 10.0;
		vec4 st = texture(cells, cuv);
		vec4 ov = texture(overlay, cuv);
		vec2 lc = fract(g) - 0.5;
		float r = length(lc);
		col += line_color * st.a * (1.0 - smoothstep(0.06, 0.09, r)) * 0.8;
		col += line_color * st.r * (smoothstep(0.17, 0.2, r) * (1.0 - smoothstep(0.24, 0.27, r))) * 0.9;
		float crs = (1.0 - smoothstep(0.03, 0.06, abs(lc.x - lc.y))) + (1.0 - smoothstep(0.03, 0.06, abs(lc.x + lc.y)));
		crs *= 1.0 - smoothstep(0.3, 0.34, r);
		col += hit_color * st.g * (0.25 + crs * 1.2) * pulse;
		col += hit_color * st.b * 0.35;
		col += vec3(0.2, 1.0, 0.45) * ov.r * 0.45;
		col += vec3(1.0, 0.15, 0.1) * ov.g * 0.5;
		col += vec3(1.0, 0.7, 0.1) * ov.b * (0.25 + 0.1 * sin(TIME * 4.0));
		float sq = 1.0 - smoothstep(0.38, 0.45, max(abs(lc.x), abs(lc.y)));
		col += hover_color * ov.a * (0.35 + 0.65 * (1.0 - sq)) * (0.8 + 0.2 * sin(TIME * 8.0));
	}
	ALBEDO = col * intensity;
}
