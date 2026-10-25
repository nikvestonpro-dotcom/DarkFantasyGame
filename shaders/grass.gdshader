shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Трава: пучки-лезвия, ветер с порывами, вариация цвета по мировой позиции,
// сухие травинки, затемнение у корней.

uniform vec3 base_color : source_color = vec3(0.045, 0.095, 0.038);
uniform vec3 tip_color : source_color = vec3(0.16, 0.30, 0.10);
uniform vec3 dry_color : source_color = vec3(0.31, 0.27, 0.11);
uniform float wind_strength = 0.24;
uniform float wind_speed = 1.8;
uniform float dryness = 0.30;

varying float v_h;
varying float v_rand;

void vertex() {
	vec3 ipos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = ipos.x * 0.55 + ipos.z * 0.75;
	float gust = 0.55 + 0.45 * sin(ipos.x * 0.045 + ipos.z * 0.038 + TIME * 0.4);
	float sway = sin(TIME * wind_speed + ph) * 0.65
		+ sin(TIME * wind_speed * 2.17 + ph * 1.9) * 0.35;
	float k = UV.y * UV.y;
	VERTEX.x += sway * wind_strength * gust * k;
	VERTEX.z += sway * wind_strength * 0.6 * gust * k;
	v_h = UV.y;
	v_rand = fract(sin(dot(floor(ipos.xz * 3.1), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = mix(base_color, tip_color, v_h);
	col = mix(col, dry_color, dryness * v_rand);
	col *= 0.7 + 0.6 * v_rand;
	col *= 0.72 + 0.28 * v_h;  // псевдо-AO у корней
	ALBEDO = col;
	ROUGHNESS = 0.96;
}
