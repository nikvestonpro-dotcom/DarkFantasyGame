shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley;
// Слизень: желейное дрожание в вершинном шейдере, полупрозрачное тело
// со свечением по краю (фрезнель).

uniform vec4 jelly_color : source_color = vec4(0.15, 0.44, 0.20, 0.85);
uniform vec3 glow_color : source_color = vec3(0.10, 0.5, 0.18);
uniform float wobble_freq = 6.5;
uniform float wobble_amp = 0.055;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = wpos.x * 2.3 + wpos.z * 1.9;
	float w1 = sin(TIME * wobble_freq + ph);
	float w2 = sin(TIME * wobble_freq * 1.37 + ph * 1.3);
	VERTEX += NORMAL * w1 * wobble_amp;
	VERTEX.y += w2 * wobble_amp * 0.5;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(normalize(-VERTEX), NORMAL)), 2.0);
	vec3 col = jelly_color.rgb;
	ALBEDO = col * (0.6 + 0.4 * fres);
	EMISSION = glow_color * (0.22 + fres * 1.1);
	ALPHA = jelly_color.a;
	ROUGHNESS = 0.28;
	SPECULAR = 0.5;
}
