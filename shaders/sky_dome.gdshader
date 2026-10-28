shader_type spatial;
render_mode cull_disabled, unshaded, fog_disabled;
// Небесный купол v9.0: полное экранное разрешение (не кубмапа radiance!).
// Почти чёрное небо, круглые звёзды 3-слойно, Млечный Путь, БЕЛАЯ луна
// по текстуре с мягким гало без зазора (нет «чёрной арки»).
// Купол ставится в atmosphere.gd и следует за камерой.

uniform sampler2D moon_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 moon_dir = vec3(-0.557, 0.476, -0.688);
// Угловой радиус диска: 0.047 рад ~ 5.4 градуса в диаметре — заметная,
// но не гигантская (прошлая 30 градусов была «слишком большой»).
uniform float moon_radius = 0.047;
uniform float moon_brightness = 1.9;
uniform float halo_tight = 0.45;   // плотное гало вплотную к диску
uniform float halo_wide = 0.007;   // широкое слабое зарево вокруг
uniform vec3 zenith_col : source_color = vec3(0.0014, 0.0019, 0.0036);
uniform vec3 horizon_col : source_color = vec3(0.0110, 0.0150, 0.0280);
uniform float star_gain = 1.0;
uniform float mw_gain = 1.0;

varying vec3 v_dir;

void vertex() {
        // Направление из центра купола (купод центрируется на камере)
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

        // ---- База: зенит -> горизонт ----
        float h = clamp(alt, 0.0, 1.0);
        vec3 col = mix(horizon_col, zenith_col, pow(h, 0.52));
        // под горизонтом купол темнеет (страховка от щелей у кромки земли)
        col *= 0.25 + 0.75 * smoothstep(-0.09, 0.02, alt);

        // ---- Звёзды: равнопромежуточная сетка, 3 слоя ----
        vec2 sUV = vec2(atan(d.z, d.x) / TAU + 0.5,
                        acos(clamp(d.y, -1.0, 1.0)) / PI);
        // гашение звёзд у горизонта ( дымка ) и у луны ( лунный блеск )
        float mdot = dot(d, normalize(moon_dir));
        float mang = acos(clamp(mdot, -1.0, 1.0));
        float star_fade = smoothstep(0.0, 0.18, alt)
                * (1.0 - 0.75 * exp(-mang * 3.2));
        float stars = star_layer(sUV, 190.0, 0.930, 0.055, 3.7)
                + star_layer(sUV, 110.0, 0.955, 0.090, 11.9)
                + star_layer(sUV, 54.0, 0.975, 0.150, 27.3);
        col += vec3(0.82, 0.88, 1.0) * stars * star_gain * star_fade * 0.75;

        // ---- Млечный Путь: полоса вдоль большой окружности ----
        vec3 gN = normalize(vec3(0.42, 0.78, 0.46)); // «север» галактики
        float band = dot(d, gN);
        float mw = exp(-band * band * 26.0);
        float mw_n = fbm(vec2(atan(d.z, d.x) * 3.1, d.y * 6.3) + 7.7);
        mw *= 0.35 + 0.65 * mw_n;
        mw *= smoothstep(0.02, 0.22, alt) * (1.0 - 0.6 * exp(-mang * 2.2));
        col += vec3(0.62, 0.70, 0.90) * mw * 0.28 * mw_gain;

        // ---- Луна: БЕЛЫЙ диск по текстуре ----
        vec3 md = normalize(moon_dir);
        vec3 t1 = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
        vec3 t2 = cross(t1, md);
        vec2 mUV = vec2(dot(d, t1), dot(d, t2)) / moon_radius * 0.5 + 0.5;
        // мягкий край диска (перо 3%): нет ни чёрной окантовки, ни рва
        float rr = length(mUV - 0.5) * 2.0;
        float disk = 1.0 - smoothstep(0.965, 1.0, rr);
        vec3 moon_col = texture(moon_tex, clamp(mUV, vec2(0.0), vec2(1.0))).rgb;
        // белизна: текстура уже бело-серая, лёгкий холодный тон
        moon_col = mix(moon_col, vec3(1.0), 0.08);
        col += moon_col * moon_brightness * disk;

        // ---- Гало: строго СНАРУЖИ диска, без зазора (внутри не добавляем —
        // иначе моря заливаются и диск «выравнивается» в белое пятно) ----
        float out_d = max(mang - moon_radius, 0.0);
        float halo = halo_tight * exp(-out_d * 15.0)
                + halo_wide * exp(-out_d * 2.4);
        halo *= smoothstep(1.0, 1.06, rr);
        col += vec3(0.88, 0.93, 1.0) * halo;

        // ---- Лёгкая подсветка горизонта со стороны луны ----
        vec2 hdir = normalize(d.xz);
        vec2 mdir2 = normalize(md.xz);
        float hb = pow(clamp(dot(hdir, mdir2) * 0.5 + 0.5, 0.0, 1.0), 3.0);
        col += horizon_col * hb * (1.0 - h) * 1.6;

        ALBEDO = col;
}
