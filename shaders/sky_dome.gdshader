shader_type spatial;
render_mode cull_disabled, unshaded, fog_disabled;
// Небесный купол v10.1 «Фиолетовая ночь» (фикс швов): весь шум
// переведён на 3D value-noise по НАПРАВЛЕНИЮ d — у направления на сфере
// нет разрывов, поэтому туманности, Млечный Путь и звёзды стали
// ПОЛНОСТЬЮ БЕСШОВНЫМИ (раньше atan(d.z,d.x) давал вертикальный шов,
// из-за которого небо выглядело «из разных текстур»).
// Палитра и композиция v10 сохранены: пурпурная туманность на севере,
// синее зарево на юго-востоке, 5 слоёв звёзд, фиолетовый Млечный Путь,
// белая луна по текстуре.

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

// ---------- 3D-шум (по направлению — без швов на сфере) ----------

float h31(vec3 p) {
        p = fract(p * 0.1031);
        p += dot(p, p.zyx + 31.32);
        return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
        vec3 i = floor(p);
        vec3 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = h31(i);
        float b = h31(i + vec3(1.0, 0.0, 0.0));
        float c = h31(i + vec3(0.0, 1.0, 0.0));
        float d = h31(i + vec3(1.0, 1.0, 0.0));
        float e = h31(i + vec3(0.0, 0.0, 1.0));
        float g = h31(i + vec3(1.0, 0.0, 1.0));
        float h = h31(i + vec3(0.0, 1.0, 1.0));
        float k = h31(i + vec3(1.0, 1.0, 1.0));
        return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
                   mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm3(vec3 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 4; i++) {
                v += a * vnoise3(p);
                p *= 2.03;
                a *= 0.5;
        }
        return v;
}

float fbm5_3(vec3 p) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 5; i++) {
                v += a * vnoise3(p);
                p *= 2.11;
                a *= 0.5;
        }
        return v;
}

// ---------- Слой звёзд: 3D-ячейки по направлению ----------
// (кубическая решётка на сфере — звёзды не режутся на швах)
float star_layer3(vec3 dir, float cells, float thr, float size, float seed) {
        vec3 g = dir * cells;
        vec3 id = floor(g);
        vec3 f = fract(g);
        float rnd = h31(id + seed);
        float on = step(thr, rnd);
        vec3 pos = vec3(h31(id + seed + 17.31),
                        h31(id + seed + 43.77),
                        h31(id + seed + 71.13)) * 0.72 + 0.14;
        float dist = length(f - pos);
        float mag = h31(id + seed + 91.13);
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

        float mdot = dot(d, normalize(moon_dir));
        float mang = acos(clamp(mdot, -1.0, 1.0));

        // ---- ТУМАННОСТИ: две зоны, domain warping по 3D-шуму ----
        // Зона 1: «пурпурное облако» — северная половина неба (z > 0)
        float w1 = fbm3(d * 2.6 + vec3(3.1, 7.7, 1.9));
        float w2 = fbm3(d * 3.7 - vec3(11.3, 5.1, 6.2));
        float neb1 = fbm5_3(d * 3.4 + vec3(w1 * 1.4, w2 * 1.1, w1 * 0.9));
        neb1 = pow(smoothstep(0.42, 0.88, neb1), 1.6);
        neb1 *= smoothstep(-0.05, 0.45, d.y);
        neb1 *= 1.0 - 0.55 * exp(-mang * 2.0);
        // маска «север + центр неба»: мягкий градиент по z и высоте
        float north_mask = smoothstep(-0.35, 0.35, d.z)
                * (1.0 - 0.35 * smoothstep(0.3, 1.0, abs(d.x)));
        neb1 *= north_mask;
        vec3 neb1_col = mix(vec3(0.16, 0.05, 0.30),
                            vec3(0.42, 0.16, 0.55),
                            smoothstep(0.35, 0.9, w1));
        col += neb1_col * neb1 * 0.50 * nebula_gain;

        // Зона 2: «синее зарево» — южно-восточный квадрант (z<0, x>0)
        float w3 = fbm3(d * 3.2 + vec3(8.9, 1.3, 4.6));
        float neb2 = fbm5_3(d * 4.1 + vec3(w3 * 1.7, -w3 * 1.0, w3 * 1.3));
        neb2 = pow(smoothstep(0.50, 0.92, neb2), 1.8);
        neb2 *= smoothstep(-0.03, 0.35, d.y);
        neb2 *= 0.6 + 0.4 * smoothstep(0.2, 0.9, abs(d.y));
        float se_mask = smoothstep(0.0, 0.55, d.x) * smoothstep(0.05, 0.6, -d.z);
        neb2 *= se_mask;
        vec3 neb2_col = mix(vec3(0.05, 0.09, 0.32),
                            vec3(0.14, 0.30, 0.60),
                            smoothstep(0.3, 0.85, w3));
        col += neb2_col * neb2 * 0.38 * nebula_gain;

        // Магента-жилки поверх туманности 1 (тонкие волокна)
        float veins = fbm3(d * 6.7 + vec3(w2 * 1.9, w1 * 1.3, w3 * 1.1));
        veins = smoothstep(0.52, 0.78, veins) * neb1;
        col += vec3(0.55, 0.16, 0.50) * veins * 0.30 * nebula_gain;

        // ---- Звёзды: 5 слоёв (пыль + 3 средних + яркие), гашение у луны ----
        float star_fade = smoothstep(0.0, 0.18, alt)
                * (1.0 - 0.75 * exp(-mang * 3.2));
        float stars = star_layer3(d, 210.0, 0.918, 0.050, 3.7)
                + star_layer3(d, 122.0, 0.942, 0.085, 11.9)
                + star_layer3(d, 60.0, 0.962, 0.145, 27.3);
        col += vec3(0.82, 0.88, 1.0) * stars * star_gain * star_fade * 0.80;

        // Звёздная пыль: множество микро-звёзд (плотность фона)
        float dust = star_layer3(d, 480.0, 0.882, 0.028, 71.3);
        col += vec3(0.80, 0.86, 1.0) * dust * star_gain * star_fade * 0.55;

        // Яркие именные звёзды: крупнее, с цветом (голубые/янтарные)
        float big = star_layer3(d, 34.0, 0.960, 0.260, 53.1);
        float big_c = star_layer3(d, 34.0, 0.972, 0.300, 53.9);
        col += (vec3(0.75, 0.85, 1.0) * big + vec3(1.0, 0.80, 0.55) * big_c)
                * star_gain * star_fade * 0.95;

        // ---- Млечный Путь: полоса вдоль большой окружности, фиолетовый ----
        vec3 gN = normalize(vec3(0.42, 0.78, 0.46));
        float band = dot(d, gN);
        float mw = exp(-band * band * 26.0);
        float mw_n = fbm3(d * 5.9 + vec3(7.7, 2.4, 5.1));
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
