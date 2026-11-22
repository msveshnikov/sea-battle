shader_type spatial;
// Ocean: summed directional waves in the vertex shader (height + analytic normal), two scrolling
// normal maps for sparkle, turquoise shallows and shore foam around islands (no depth texture, so
// it runs on the Compatibility renderer for web and phones).

uniform vec3 deep_color : source_color = vec3(0.02, 0.2, 0.3);
uniform vec3 shallow_color : source_color = vec3(0.1, 0.75, 0.72);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec4 islands[32];
uniform int island_count = 0;
uniform float wave_amp = 0.22;
uniform float flat_far = 0.0; // 1 on the far horizon plane: no displacement
uniform float sparkle = 1.0;

varying vec3 wpos;
varying float crest;

vec3 wave(vec2 p, vec2 dir, float freq, float speed, float amp) {
	float ph = dot(dir, p) * freq + TIME * speed;
	return vec3(sin(ph) * amp, cos(ph) * amp * freq * dir.x, cos(ph) * amp * freq * dir.y);
}

vec3 waves(vec2 p) {
	vec3 w = vec3(0.0);
	w += wave(p, normalize(vec2(1.0, 0.35)), 0.11, 0.9, 1.0);
	w += wave(p, normalize(vec2(-0.4, 1.0)), 0.17, 1.15, 0.55);
	w += wave(p, normalize(vec2(0.8, -0.6)), 0.29, 1.6, 0.3);
	w += wave(p, normalize(vec2(-0.9, -0.2)), 0.47, 2.1, 0.16);
	return w * wave_amp;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (flat_far < 0.5) {
		float fade = 1.0 - smoothstep(120.0, 220.0, length(wpos.xz));
		vec3 w = waves(wpos.xz) * fade;
		VERTEX.y += w.x;
		NORMAL = normalize(vec3(-w.y, 1.0, -w.z));
		crest = w.x / max(wave_amp, 0.001);
	} else {
		crest = 0.0;
	}
}

void fragment() {
	vec2 p = wpos.xz;
	float shore = 100000.0;
	for (int i = 0; i < 32; i++) {
		if (i >= island_count) {
			break;
		}
		float d = length(p - islands[i].xy) - islands[i].z;
		shore = min(shore, d);
	}
	float shallow = 1.0 - smoothstep(-2.0, 8.0, shore);
	vec3 col = mix(deep_color, shallow_color, shallow * 0.9);
	float far = smoothstep(150.0, 600.0, length(p));
	float fn = texture(foam_noise, p * 0.08 + vec2(TIME * 0.01, 0.0)).r;
	float fn2 = texture(foam_noise, p * 0.21 - vec2(0.0, TIME * 0.02)).r;
	float ring = smoothstep(1.8, 0.0, shore + (fn - 0.5) * 1.6 + sin(TIME * 1.3 + shore * 1.7) * 0.3);
	float crest_foam = smoothstep(1.55, 1.9, crest + fn2 * 0.7) * 0.35;
	float foam = clamp(ring * smoothstep(0.35, 0.6, fn2 + ring * 0.5) + crest_foam, 0.0, 1.0) * (1.0 - far);
	vec3 na = texture(normal_a, p * 0.045 + vec2(TIME * 0.012, TIME * 0.007)).rgb;
	vec3 nb = texture(normal_b, p * 0.11 - vec2(TIME * 0.016, -TIME * 0.011)).rgb;
	NORMAL_MAP = normalize(mix(na, nb, 0.5));
	NORMAL_MAP_DEPTH = mix(0.9, 0.25, far) * sparkle;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, col * 1.35 + vec3(0.03, 0.06, 0.08), fres * 0.6);
	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(0.07, 0.85, foam);
	SPECULAR = 0.65;
	METALLIC = 0.0;
}
