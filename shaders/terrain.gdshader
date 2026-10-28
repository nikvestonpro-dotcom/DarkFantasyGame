shader_type spatial;
// Террейн: трипланарное PBR-текстурирование Poly Haven CC0.
// Маски в вершинных цветах: R = луг, G = лесная подстилка, B = песок.
// На крутых склонах автоматически выступает скала.
// Полностью непрозрачный (без ALPHA) — «дыр» в земле быть не может.

uniform sampler2D grass_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_nor : filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_nor : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_nor : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_nor : filter_linear_mipmap, repeat_enable;

uniform float grass_scale = 0.075;
uniform float forest_scale = 0.09;
uniform float sand_scale = 0.11;
uniform float rock_scale = 0.05;
uniform float normal_strength = 0.65;
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform vec3 forest_tint : source_color = vec3(1.0);
uniform vec3 sand_tint : source_color = vec3(1.0);
uniform vec3 rock_tint : source_color = vec3(1.0);

varying vec3 wpos;
varying vec3 wnormal;
varying vec3 vmask;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vmask = COLOR.rgb;
}

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 tri_blend_w(sampler2D tex, vec3 p, vec3 b, float s) {
	return texture(tex, p.yz * s).rgb * b.x
		+ texture(tex, p.xz * s).rgb * b.y
		+ texture(tex, p.xy * s).rgb * b.z;
}

vec3 tri_blend_n(sampler2D tex, vec3 p, vec3 n, vec3 b, float s, float k) {
	vec3 t0 = texture(tex, p.yz * s).xyz * 2.0 - 1.0;
	vec3 t1 = texture(tex, p.xz * s).xyz * 2.0 - 1.0;
	vec3 t2 = texture(tex, p.xy * s).xyz * 2.0 - 1.0;
	vec3 wx = vec3(t0.z, t0.y, -t0.x);
	vec3 wy = vec3(t1.x, t1.z, t1.y);
	vec3 wz = vec3(-t2.x, t2.y, t2.z);
	vec3 wn = normalize(wx * b.x + wy * b.y + wz * b.z);
	return normalize(mix(n, wn, k));
}

void fragment() {
	vec3 b = pow(abs(wnormal), vec3(4.0));
	b /= (b.x + b.y + b.z);
	vec3 mask = clamp(vmask, vec3(0.0), vec3(1.0));
	float slope_rock = 1.0 - smoothstep(0.58, 0.80, wnormal.y);

	vec3 col =
		tri_blend_w(grass_diff, wpos, b, grass_scale) * grass_tint * mask.r
		+ tri_blend_w(forest_diff, wpos, b, forest_scale) * forest_tint * mask.g
		+ tri_blend_w(sand_diff, wpos, b, sand_scale) * sand_tint * mask.b;

	vec3 nrm =
		tri_blend_n(grass_nor, wpos, wnormal, b, grass_scale, normal_strength) * mask.r
		+ tri_blend_n(forest_nor, wpos, wnormal, b, forest_scale, normal_strength) * mask.g
		+ tri_blend_n(sand_nor, wpos, wnormal, b, sand_scale, normal_strength) * mask.b;
	nrm = normalize(nrm + wnormal * 0.001);

	vec3 rock_col = tri_blend_w(rock_diff, wpos, b, rock_scale) * rock_tint;
	vec3 rock_nrm = tri_blend_n(rock_nor, wpos, wnormal, b, rock_scale, normal_strength * 1.3);
	col = mix(col, rock_col, slope_rock);
	nrm = normalize(mix(nrm, rock_nrm, slope_rock));

	// Крупные вариации яркости/оттенка (~30-80 м) ломают тайлинг текстур
	float macro = 0.80 + 0.42 * vnoise(wpos.xz * 0.014);
	float macro2 = vnoise(wpos.xz * 0.006 + 31.7);
	col *= macro;
	col = mix(col, col * vec3(0.90, 1.03, 0.88), (macro2 - 0.5) * 0.8);

	ALBEDO = col;
	ROUGHNESS = mix(0.97, 0.90, slope_rock);
	NORMAL = (VIEW_MATRIX * vec4(nrm, 0.0)).xyz;
}
