shader_type sky;
// Gradient sky with a sun disk + glow, soft drifting clouds and stars at night.

uniform vec3 top_color : source_color = vec3(0.18, 0.42, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.86, 0.95);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 sun_dir = vec3(0.4, 0.6, 0.4); // points TOWARD the sun
uniform float sun_size = 0.9994;
uniform float stars = 0.0;
uniform float cloud_amount = 0.55;
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(horizon_color, horizon_color * 0.55, clamp(-h * 4.0, 0.0, 1.0));
	}
	vec3 sd = normalize(sun_dir);
	float sdot = dot(d, sd);
	float glow = pow(max(sdot, 0.0), 8.0) * 0.35 + pow(max(sdot, 0.0), 120.0) * 0.6;
	col += sun_color * glow;
	if (h > 0.0) {
		vec2 cuv = d.xz / (h + 0.12) * 0.35 + vec2(TIME * 0.002, TIME * 0.001);
		float c = texture(cloud_tex, cuv).r;
		float c2 = texture(cloud_tex, cuv * 2.3 + 0.37).r;
		float cl = smoothstep(1.0 - cloud_amount, 1.0, c * 0.7 + c2 * 0.45) * smoothstep(0.0, 0.18, h);
		vec3 lit = cloud_color * (0.85 + 0.35 * pow(max(sdot, 0.0), 4.0));
		col = mix(col, lit, cl * 0.85);
		if (stars > 0.0) {
			vec3 cell = floor(d * 380.0);
			float s = hash(cell);
			float tw = 0.6 + 0.4 * sin(TIME * 2.0 + s * 40.0);
			col += vec3(step(0.9975, s) * tw * stars * (1.0 - cl)) * smoothstep(0.0, 0.25, h);
		}
	}
	float disk = smoothstep(sun_size, sun_size + 0.0003, sdot);
	col = mix(col, sun_color * 3.0, disk * (1.0 - stars * 0.4));
	COLOR = col;
}
