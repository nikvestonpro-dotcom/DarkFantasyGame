shader_type sky;
// v8.0 «Цветная ночь» в стиле @elder.void:
//  - градиент: тёмно-фиолетовый зенит -> пурпурно-розовая середина -> дымка горизонта
//  - огромная тёплая луна с гало (диск занимает ~8-10% кадра, как на референсах)
//  - россыпь мерцающих звёзд и Млечный Путь
//  - зелёное «северное сияние» (аurora) — фирменная деталь референсов
//  - лёгкие фиолетовые облака-клочья
// Направление луны согласовано с DirectionalLight3D в atmosphere.gd.

uniform vec3 zenith_color : source_color = vec3(0.045, 0.018, 0.10);
uniform vec3 mid_color : source_color = vec3(0.16, 0.055, 0.22);
uniform vec3 horizon_color : source_color = vec3(0.42, 0.16, 0.34);
uniform vec3 glow_horizon : source_color = vec3(0.10, 0.16, 0.20);

uniform vec3 moon_dir = vec3(-0.696, 0.498, 0.508);
uniform vec3 moon_color : source_color = vec3(1.0, 0.93, 0.80);
uniform float moon_size : hint_range(0.02, 0.3) = 0.095;
uniform float moon_glow : hint_range(0.0, 4.0) = 1.6;

uniform vec3 aurora_color : source_color = vec3(0.10, 0.55, 0.38);
uniform float aurora_strength : hint_range(0.0, 2.0) = 0.85;

uniform float star_density : hint_range(0.0, 2.0) = 1.0;
uniform float star_brightness : hint_range(0.0, 4.0) = 1.5;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.35;

// --- хэш-шум и симплекс втч (компактная реализация) ---
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise2(p);
        p = p * 2.03 + vec2(17.13, 9.7);
        a *= 0.5;
    }
    return v;
}

// Звёзды: ячейки на сфере (по направлению), внутри — точка со случайным сдвигом
vec3 star_field(vec3 dir) {
    // равнопромежуточная развёртка направления — достаточно для фиксированного неба
    vec2 uv = vec2(atan(dir.x, dir.z), acos(clamp(dir.y, -1.0, 1.0)));
    vec3 col = vec3(0.0);
    // три слоя разной плотности
    for (int layer = 0; layer < 3; layer++) {
        float scale = 90.0 + float(layer) * 130.0;
        vec2 g = uv * scale;
        vec2 id = floor(g);
        vec2 f = fract(g) - 0.5;
        float rnd = hash12(id + float(layer) * 77.7);
        // плотность звёзд
        if (rnd > 1.0 - 0.18 * star_density) {
            vec2 off = vec2(hash12(id + 3.1), hash12(id + 7.7)) - 0.5;
            float d = length(f - off * 0.7);
            float star = smoothstep(0.16, 0.0, d);
            // мерцание
            float tw = 0.6 + 0.4 * sin(TIME * (1.5 + rnd * 4.0) + rnd * 20.0);
            // чем выше — тем больше звёзд видно (у горизонта рвётся дымка)
            float hmask = smoothstep(0.02, 0.35, dir.y);
            col += star * tw * hmask * star_brightness * (0.5 + rnd);
        }
    }
    // Млечный Путь: полоса вдоль большого круга
    float mw = 1.0 - abs(dot(dir, normalize(vec3(0.7, 0.25, -0.65))));
    float mw_band = pow(clamp(mw * 2.2 - 0.55, 0.0, 1.0), 2.0);
    float mw_noise = fbm(uv * 6.0);
    col += vec3(0.35, 0.30, 0.45) * mw_band * mw_noise * 0.35 * smoothstep(0.05, 0.3, dir.y);
    return col;
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    float h = clamp(dir.y, -1.0, 1.0);

    // --- ОСНОВНОЙ ГРАДИЕНТ ---
    vec3 col = mix(mid_color, zenith_color, smoothstep(0.05, 0.75, h));
    col = mix(horizon_color, col, smoothstep(-0.04, 0.28, h));
    // под горизонтом — тёмная «земля»
    col = mix(col, zenith_color * 0.55, smoothstep(0.0, -0.18, h));
    // бирюзовое свечение у самого горизонта в стороне, противоположной луне
    float away = 0.5 - 0.5 * dot(normalize(dir.xz + vec2(1e-4)), normalize(-moon_dir.xz));
    col += glow_horizon * pow(away, 1.6) * pow(1.0 - clamp(abs(h) * 3.4, 0.0, 1.0), 2.0) * 0.9;

    // --- ЗВЁЗДЫ ---
    col += star_field(dir) * smoothstep(-0.02, 0.12, h);

    // --- ЛУНА: огромный тёплый диск + широкое гало ---
    float mdot = dot(dir, normalize(moon_dir));
    float ang = acos(clamp(mdot, -1.0, 1.0));
    float disk = 1.0 - smoothstep(moon_size * 0.92, moon_size, ang);
    // лёгкая «изрезанность» края луны
    float edge_noise = fbm(vec2(atan(dir.x, dir.z), dir.y) * 40.0) * 0.06;
    float disk_soft = 1.0 - smoothstep(moon_size * (0.86 + edge_noise), moon_size, ang);
    // детали поверхности луны (моря)
    float moon_tex = fbm(vec2(atan(dir.x - moon_dir.x, dir.z - moon_dir.z),
                    dir.y - moon_dir.y) * 14.0);
    vec3 moon_surf = moon_color * (0.82 + 0.22 * moon_tex);
    col = mix(col, moon_surf, clamp(disk_soft, 0.0, 1.0));
    // гало (двойное: узкое яркое + широкое мягкое)
    float halo = exp(-pow(ang / (moon_size * 3.2), 2.0)) * 0.55
                + exp(-pow(ang / (moon_size * 9.0), 2.0)) * 0.30;
    col += moon_color * halo * moon_glow * (1.0 - disk * 0.5);

    // --- СЕВЕРНОЕ СИЯНИЕ: зелёные занавеси в верхней части неба ---
    float az = atan(dir.x, dir.z);
    float curtain = fbm(vec2(az * 2.3 + TIME * 0.018, dir.y * 3.5 - TIME * 0.01));
    curtain = pow(clamp(curtain * 1.55 - 0.35, 0.0, 1.0), 1.6);
    float band = smoothstep(0.25, 0.55, h) * (1.0 - smoothstep(0.72, 0.98, h));
    // сияние смещено от луны, чтобы не спорило с ней
    float side = 0.5 + 0.5 * cos(az - atan(-moon_dir.x, -moon_dir.z) + 1.9);
    col += aurora_color * curtain * band * aurora_strength * (0.35 + 0.65 * side);
    // вторая, фиолетовая кромка сияния (как на референсах)
    col += vec3(0.24, 0.10, 0.38) * pow(curtain, 2.2) * band * aurora_strength * 0.5 * side;

    // --- ОБЛАКА: редкие фиолетовые клочья ---
    float cl = fbm(vec2(az * 1.6 + TIME * 0.006, dir.y * 5.0));
    cl = smoothstep(0.62 - cloud_amount * 0.25, 0.62 + cloud_amount * 0.3, cl);
    float cl_band = smoothstep(0.03, 0.3, h) * (1.0 - smoothstep(0.55, 0.9, h));
    vec3 cloud_col = mix(vec3(0.16, 0.09, 0.22), vec3(0.34, 0.20, 0.36),
                    smoothstep(0.0, 0.4, h));
    // облака подсвечены луной с её стороны
    float lit = 0.5 + 0.5 * dot(dir, normalize(moon_dir));
    cloud_col += moon_color * pow(lit, 3.0) * 0.35;
    col = mix(col, cloud_col, cl * cl_band * 0.55);

    COLOR = col;
}
