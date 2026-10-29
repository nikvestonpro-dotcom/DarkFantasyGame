shader_type spatial;
render_mode cull_disabled, unshaded, fog_disabled;
// Небесный купол v10.0 «Фиолетовая ночь»: глубокое сине-фиолетовое небо,
// ПУРПУРНО-СИНИЕ ТУМАННОСТИ (domain-warped fbm), яркие звёзды 4 слоя,
// цветные звёзды, усиленный Млечный Путь, БЕЛАЯ луна по текстуре.
// Референс: ночные небеса Dark Fantasy (пурпурная дымка, туманности).

uniform sampler2D moon_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 moon_dir = vec3(-0.557, 0.476, -0.688);
uniform float moon_radius = 0.047;
uniform float moon_brightness = 1.5;
uniform float halo_tight = 0.16;
uniform float halo_wide = 0.004;
uniform vec3 zenith_col : source_color = vec3(0.007, 0.006, 0.024);
uniform vec3 horizon_col : source_color = vec3(0.034, 0.016, 0.055);
uniform float star_gain = 1.35;
uniform float mw_gain = 1.3;
uniform float nebula_gain = 1.0;

varying vec3 v_dir;

void vertex() {
        v_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
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

float fbm(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 4; i++) {
                v += a * vnoise(p);
                p *= 2.03;
                a *= 0.5;
        }
        return v;
}

float fbm5(vec2 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 5; i++) {
                v += a * vnoise(p);
                p *= 2.11;
                a *= 0.5;
        }
        return v;
}

// Слой звёзд: ячейка -> может быть звезда; круглая, яркость mag^4
float star_layer(vec2 uv, float cells, float thr, float size, float seed) {
        vec2 g = uv * cells;
        vec2 id = floor(g);
        vec2 f = fract(g);
        float rnd = h21(id + seed);
        float on = step(thr, rnd);
        vec2 pos = vec2(h21(id + seed + 17.31), h21(id + seed + 43.77)) * 0.72 + 0.14;
        float dist = length(f - pos);
        float mag = h21(id + seed + 91.13);
        float bright = pow(mag, 4.0);
        float core = smoothstep(size * (0.55 + 0.9 * mag), 0.0, dist);
        float glow = bright * 0.06 * smoothstep(size * 2.2, 0.0, dist);
        return on * (core + glow) * bright;
}

void fragment() {
        vec3 d = normalize(v_dir);
        float alt = d.y;

        // ---- База: зенит -> горизонт (глубокий сине-фиолетовый) ----
        float h = clamp(alt, 0.0, 1.0);
        vec3 col = mix(horizon_col, zenith_col, pow(h, 0.52));
        col *= 0.25 + 0.75 * smoothstep(-0.09, 0.02, alt);

        // координаты неба (равнопромежуточные)
        vec2 sUV = vec2(atan(d.z, d.x) / TAU + 0.5,
                        acos(clamp(d.y, -1.0, 1.0)) / PI);
        float mdot = dot(d, normalize(moon_dir));
        float mang = acos(clamp(mdot, -1.0, 1.0));

        // ---- ТУМАННОСТИ: две зоны с domain warping ----
        // Зона 1: «пурпурное облако» — северная половина неба
        vec2 np = vec2(atan(d.z, d.x) * 0.9, d.y * 1.6);
        float w1 = fbm(np * 1.7 + vec2(3.1, 7.7));
        float w2 = fbm(np * 2.4 - vec2(11.3, 5.1));
        float neb1 = fbm5(np * 2.8 + vec2(w1 * 2.2, w2 * 1.8));
        neb1 = pow(smoothstep(0.42, 0.88, neb1), 1.6);
        neb1 *= smoothstep(-0.05, 0.45, d.y);              // выше горизонта
        neb1 *= 1.0 - 0.55 * exp(-mang * 2.0);             // не заливать у луны
        vec3 neb1_col = mix(vec3(0.16, 0.05, 0.30),        // тёмно-пурпурный
                            vec3(0.42, 0.16, 0.55),        // фиолетовый
                            smoothstep(0.35, 0.9, w1));
        col += neb1_col * neb1 * 0.50 * nebula_gain;

        // Зона 2: «синее зарево» — южно-восточный квадрант
        vec2 sp = vec2(atan(d.z, d.x) * 1.1 - 2.0, d.y * 1.3);
        float w3 = fbm(sp * 2.1 + vec2(8.9, 1.3));
        float neb2 = fbm5(sp * 3.4 + vec2(w3 * 2.5, -w3 * 1.5));
        neb2 = pow(smoothstep(0.50, 0.92, neb2), 1.8);
        neb2 *= smoothstep(-0.03, 0.35, d.y);
        neb2 *= 0.6 + 0.4 * smoothstep(0.2, 0.9, abs(d.y));
        vec3 neb2_col = mix(vec3(0.05, 0.09, 0.32),        // тёмно-синий
                            vec3(0.14, 0.30, 0.60),        // лазурный
                            smoothstep(0.3, 0.85, w3));
        col += neb2_col * neb2 * 0.38 * nebula_gain;

        // Магента-жилки поверх туманности 1 (тонкие волокна)
        float veins = fbm(np * 5.5 + vec2(w2 * 3.0, w1 * 2.0));
        veins = smoothstep(0.52, 0.78, veins) * neb1;
        col += vec3(0.55, 0.16, 0.50) * veins * 0.30 * nebula_gain;

        // ---- Звёзды: 5 слоёв (пыль + 3 средних + яркие), гашение у луны ----
        float star_fade = smoothstep(0.0, 0.18, alt)
                * (1.0 - 0.75 * exp(-mang * 3.2));
        float stars = star_layer(sUV, 210.0, 0.918, 0.050, 3.7)
                + star_layer(sUV, 122.0, 0.942, 0.085, 11.9)
                + star_layer(sUV, 60.0, 0.962, 0.145, 27.3);
        col += vec3(0.82, 0.88, 1.0) * stars * star_gain * star_fade * 0.80;

        // Звёздная пыль: множество микро-звёзд (плотность фона)
        float dust = star_layer(sUV, 480.0, 0.882, 0.028, 71.3);
        col += vec3(0.80, 0.86, 1.0) * dust * star_gain * star_fade * 0.55;

        // Яркие именные звёзды: крупнее, с цветом (голубые/янтарные)
        float big = star_layer(sUV, 34.0, 0.960, 0.260, 53.1);
        float big_c = star_layer(sUV, 34.0, 0.972, 0.300, 53.9);
        col += (vec3(0.75, 0.85, 1.0) * big + vec3(1.0, 0.80, 0.55) * big_c)
                * star_gain * star_fade * 0.95;

        // ---- Млечный Путь: полоса вдоль большой окружности, фиолетовый ----
        vec3 gN = normalize(vec3(0.42, 0.78, 0.46));
        float band = dot(d, gN);
        float mw = exp(-band * band * 26.0);
        float mw_n = fbm(vec2(atan(d.z, d.x) * 3.1, d.y * 6.3) + 7.7);
        mw *= 0.35 + 0.65 * mw_n;
        mw *= smoothstep(0.02, 0.22, alt) * (1.0 - 0.6 * exp(-mang * 2.2));
        col += vec3(0.55, 0.55, 0.85) * mw * 0.30 * mw_gain;
        // фиолетовый отлив Млечного Пути
        col += vec3(0.45, 0.30, 0.70) * mw * mw_n * 0.18 * mw_gain;

        // ---- Луна: БЕЛЫЙ диск по текстуре ----
        vec3 md = normalize(moon_dir);
        vec3 t1 = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
        vec3 t2 = cross(t1, md);
        vec2 mUV = vec2(dot(d, t1), dot(d, t2)) / moon_radius * 0.5 + 0.5;
        float rr = length(mUV - 0.5) * 2.0;
        float disk = 1.0 - smoothstep(0.965, 1.0, rr);
        vec3 moon_col = texture(moon_tex, clamp(mUV, vec2(0.0), vec2(1.0))).rgb;
        moon_col = mix(moon_col, vec3(1.0), 0.08);
        col += moon_col * moon_brightness * disk;

        // ---- Гало: строго СНАРУЖИ диска, сдержанное ----
        float out_d = max(mang - moon_radius, 0.0);
        float halo = halo_tight * exp(-out_d * 15.0)
                + halo_wide * exp(-out_d * 2.4);
        halo *= smoothstep(1.0, 1.06, rr);
        col += vec3(0.88, 0.93, 1.0) * halo;

        // ---- Подсветка горизонта со стороны луны (сдержанная, индиго) ----
        vec2 hdir = normalize(d.xz + vec2(0.0001));
        vec2 mdir2 = normalize(md.xz + vec2(0.0001));
        float hb = pow(clamp(dot(hdir, mdir2) * 0.5 + 0.5, 0.0, 1.0), 3.0);
        col += horizon_col * hb * (1.0 - h) * 1.5;

        ALBEDO = col;
}
