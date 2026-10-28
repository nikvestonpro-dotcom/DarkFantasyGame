shader_type spatial;
render_mode cull_back, diffuse_burley;
// Хвоя ели: покачивание ветра по высоте кроны, цвет из вершин
// (R — освещённость яруса, G — случайная вариация ветки).

uniform vec3 needle_dark : source_color = vec3(0.030, 0.062, 0.034);
uniform vec3 needle_light : source_color = vec3(0.105, 0.20, 0.088);
uniform float wind_strength = 0.38;
uniform float tree_height = 33.0;

varying vec3 v_col;
varying float v_t;

void vertex() {
	vec3 ipos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_t = clamp(VERTEX.y / tree_height, 0.0, 1.0);
	v_col = COLOR.rgb;
	float ph = ipos.x * 0.35 + ipos.z * 0.43;
	float gust = 0.55 + 0.45 * sin(ipos.x * 0.02 + ipos.z * 0.017 + TIME * 0.4);
	float sway = sin(TIME * 1.1 + ph) * 0.6 + sin(TIME * 2.3 + ph * 1.7) * 0.25;
	float k = pow(v_t, 1.6);
	VERTEX.x += sway * wind_strength * gust * k;
	VERTEX.z += sway * wind_strength * 0.7 * gust * k;
}

void fragment() {
	ALBEDO = mix(needle_dark, needle_light, clamp(v_col.r, 0.0, 1.0))
		* (0.55 + 0.65 * clamp(v_col.g, 0.0, 1.0));
	ROUGHNESS = 0.98;
}
