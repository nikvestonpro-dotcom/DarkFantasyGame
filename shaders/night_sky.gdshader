shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
// Ночное небо Hollow Moon — по фото-референсам: глубокий индиго, огромная
// бледная луна с "морями" и ореолом, мерцающие звёзды, фиолетово-зелёная
// туманность у горизонта. Полностью процедурное, без текстур.

uniform vec3 moon_dir = vec3(-0.3505, 0.4506, -0.8211); // должен совпадать с MoonLight
uniform vec4 sky_top : source_color = vec4(0.027, 0.02, 0.071, 1.0);      // зенит #070512
uniform vec4 sky_horizon : source_color = vec4(0.075, 0.055, 0.145, 1.0); // = цвет тумана
uniform vec4 moon_color : source_color = vec4(0.91, 0.957, 1.0, 1.0);     // #E8F4FF
uniform vec4 moon_mare_color : source_color = vec4(0.55, 0.6, 0.68, 1.0);
uniform vec4 star_color : source_color = vec4(0.85, 0.88, 1.0, 1.0);
uniform vec4 nebula_violet : source_color = vec4(0.36, 0.1, 0.55, 1.0);
uniform vec4 nebula_green : source_color = vec4(0.06, 0.42, 0.24, 1.0);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);

	// Градиент: тёплый фиолет у горизонта -> почти чёрный индиго в зените.
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, pow(h, 0.45));
	// Ниже горизонта — цвет тумана, чтобы стык с землёй не светился.
	col = mix(col, sky_horizon.rgb, smoothstep(0.05, -0.1, dir.y));

	// Туманность: наклонная полоса fbm-шума, фиолет -> зелёная аврора.
	vec3 band_n = normalize(vec3(0.55, 0.35, -0.75));
	float band = exp(-pow(dot(dir, band_n) - 0.18, 2.0) * 7.0);
	float neb = fbm(dir * 3.0 + vec3(0.0, 0.0, TIME * 0.008));
	float neb2 = fbm(dir * 5.0 + 7.3);
	vec3 nebula = mix(nebula_violet.rgb, nebula_green.rgb, clamp(neb2 * 1.4 - 0.2, 0.0, 1.0));
	col += nebula * band * clamp(neb * 1.6 - 0.25, 0.0, 1.0) * 0.5;
	col += nebula_green.rgb * band * 0.03; // постоянная зелёная дымка в полосе

	// Звёзды: 3D-сетка, в ~1.5% ячеек точка-звезда; редкие яркие; мерцание.
	vec3 sp = dir * 90.0;
	vec3 cell = floor(sp);
	vec3 f = fract(sp);
	float rnd = hash13(cell);
	if (rnd > 0.985) {
		vec3 star_pos = vec3(hash13(cell + 11.1), hash13(cell + 27.7), hash13(cell + 43.3)) * 0.7 + 0.15;
		float d = length(f - star_pos);
		float big = step(0.9965, rnd);
		float size = mix(0.10, 0.16, big);
		float star = smoothstep(size, 0.0, d) * mix(0.6, 1.2, big);
		star *= 0.65 + 0.35 * sin(TIME * (1.5 + rnd * 40.0) + rnd * 60.0);
		star *= smoothstep(0.02, 0.15, dir.y);
		col += star_color.rgb * star;
	}

	// Луна: огромная (радиус ~6.2°), бледная, с "морями" и мягким ореолом.
	float d_moon = dot(dir, moon_dir);
	float disc = smoothstep(0.99416, 0.99487, d_moon);
	float halo = pow(clamp(d_moon, 0.0, 1.0), 240.0) * 0.28 + pow(clamp(d_moon, 0.0, 1.0), 60.0) * 0.10;
	if (disc > 0.0) {
		vec3 t1 = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)));
		vec3 t2 = cross(t1, moon_dir);
		vec2 uv2 = vec2(dot(dir, t1), dot(dir, t2)) * 9.0;
		float mare = fbm(vec3(uv2 * 0.55, 3.7));
		float mare_mask = smoothstep(0.42, 0.62, mare);
		vec3 moon_surface = mix(moon_color.rgb, moon_mare_color.rgb, mare_mask * 0.8);
		moon_surface *= 0.85 + 0.15 * fbm(vec3(uv2 * 1.8, 9.2));
		col = mix(col, moon_surface, disc);
	}
	col += moon_color.rgb * halo * (1.0 - disc * 0.6);

	ALBEDO = col;
}
