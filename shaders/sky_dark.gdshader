shader_type sky;
render_mode use_half_res_pass;
// НЕБО «ТЁМНОЕ ФЭНТЕЗИ» (v6.0): за горами — затухающее багрово-оранжевое
// зарево кровавого заката, выше — резкий переход в глубокий ночной
// сине-фиолетовый со звёздами и тёмными слоистыми облаками, дрейфующими
// по небу. Лунный диск с холодным гало. Значения >1 дают мягкий bloom.

uniform vec3 zenith_color : source_color = vec3(0.012, 0.016, 0.045);
uniform vec3 mid_color : source_color = vec3(0.052, 0.030, 0.085);
uniform vec3 horizon_color : source_color = vec3(0.155, 0.042, 0.028);
uniform vec3 glow_color : source_color = vec3(0.98, 0.30, 0.06);
// азимут зарева (единичный вектор в плоскости XZ, над озером)
uniform vec3 glow_dir = vec3(-0.87, 0.0, -0.49);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.5;
uniform vec3 moon_dir = vec3(-0.696, 0.498, 0.508);
uniform vec3 moon_color : source_color = vec3(0.82, 0.88, 1.0);
uniform float star_amount : hint_range(0.0, 2.0) = 1.15;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.60;
uniform float cloud_darkness : hint_range(0.0, 1.0) = 0.80;

// ---------- хэши и шум ----------
float h21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float hy = dir.y;

	// 1) Ночной градиент: сине-фиолетовый зенит -> тёмная середина -> горизонт
	vec3 col = mix(mid_color, zenith_color, smoothstep(0.06, 0.55, hy));
	float hband = pow(1.0 - clamp(hy, 0.0, 1.0), 3.0);
	col = mix(col, horizon_color, hband * 0.92);

	// 2) Багрово-оранжевое зарево за горами: резко теряет силу с высотой,
	//    максимум — точно по азимуту glow_dir (над озером)
	float az = 0.0;
	if (length(dir.xz) > 1e-4) {
		az = max(dot(normalize(dir.xz), normalize(glow_dir.xz)), 0.0);
	}
	float glow = pow(az, 2.6) * pow(1.0 - clamp(hy, 0.0, 1.0), 2.3);
	col += glow_color * glow * glow_strength;
	// широкая слабая полоса по всему горизонту — «послесвечение»
	col += glow_color * 0.10 * pow(1.0 - clamp(hy, 0.0, 1.0), 4.5);

	// 3) Под горизонтом — чернильная мгла (склоны гор всё равно закрывают)
	col = mix(col, horizon_color * 0.22, smoothstep(0.0, -0.14, hy));

	// 4) Звёзды: ячейки на сфере, мерцание, гаснут в облаках и у горизонта
	float star_mask = smoothstep(0.015, 0.22, hy);
	vec3 sp = dir * 92.0;
	vec3 cell = floor(sp);
	float hstar = h31(cell);
	float star = 0.0;
	if (hstar > 0.9915) {
		vec3 fp = fract(sp) - 0.5;
		float d = length(fp);
		star = smoothstep(0.38, 0.06, d);
		float tw = 0.65 + 0.35 * sin(TIME * (1.5 + 4.0 * h31(cell + 3.0))
				+ hstar * 41.0);
		star *= (0.35 + 0.65 * h31(cell + 7.0)) * tw;
	}

	// 5) Тёмные слоистые облака: проекция направления на небесный купол,
	//    медленный дрейф, край подсвечен заревом
	float cl = 0.0;
	if (hy > 0.012) {
		vec2 cuv = dir.xz / (hy + 0.22);
		float f = fbm(cuv * 0.9 + vec2(TIME * 0.0065, TIME * 0.0042));
		f += 0.18 * fbm(cuv * 2.6 - vec2(TIME * 0.011, 0.0));
		cl = smoothstep(1.02 - cloud_coverage, 1.32 - cloud_coverage, f);
		cl *= smoothstep(0.012, 0.17, hy);
	}
	vec3 cloud_col = mix(mid_color * 0.52, glow_color * 0.55, glow * 0.9);
	cloud_col *= mix(1.0, 0.32, cloud_darkness);
	col = mix(col, cloud_col, cl * 0.9);

	// 6) Луна: холодный диск с гало (совпадает с направлением лунного света)
	vec3 md = normalize(moon_dir);
	float mdot = dot(dir, md);
	float disc = smoothstep(0.99968, 0.99988, mdot);
	float halo = pow(max(mdot, 0.0), 420.0) * 0.55
			+ pow(max(mdot, 0.0), 48.0) * 0.10;
	col += moon_color * halo * (1.0 - cl * 0.85);
	col = mix(col, moon_color * 1.9, disc * 0.92);

	// Звёзды добавляем последними: сквозь облака их не видно
	col += vec3(0.80, 0.84, 1.0) * star * star_amount * star_mask
			* (1.0 - cl * 0.95);

	COLOR = col;
}
