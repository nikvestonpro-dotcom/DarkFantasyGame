shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Хвоя ели/сосны: фотограмметрические карточки Poly Haven (twig),
// alpha-scissor, ветер по высоте кроны, затемнение у ствола.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nor_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.88, 0.95, 0.82);
uniform float tree_height = 33.0;
uniform float wind_strength = 0.42;
uniform float wind_speed = 1.05;
uniform float roughness_val = 0.93;

varying float v_h;

void vertex() {
        vec3 ipos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        float ph = ipos.x * 0.31 + ipos.z * 0.47;
        float gust = 0.55 + 0.45 * sin(ipos.x * 0.021 + ipos.z * 0.017 + TIME * 0.4);
        float k = pow(clamp(VERTEX.y / tree_height, 0.0, 1.0), 1.55);
        float sway = sin(TIME * wind_speed + ph) * 0.6
                + sin(TIME * wind_speed * 2.31 + ph * 1.8) * 0.28;
        VERTEX.x += sway * wind_strength * gust * k;
        VERTEX.z += sway * wind_strength * 0.72 * gust * k;
        v_h = clamp(VERTEX.y / tree_height, 0.0, 1.0);
}

void fragment() {
        vec4 alb = texture(albedo_tex, UV);
        // Жёсткая обрезка фона карточки — работает во всех рендерерах
        if (alb.a < 0.38) {
                discard;
        }
        ALPHA_SCISSOR_THRESHOLD = 0.38;
        ALPHA = alb.a;
        vec3 n = texture(nor_tex, UV).xyz * 2.0 - 1.0;
        NORMAL_MAP = n;
        NORMAL_MAP_DEPTH = 0.85;
        // Хвоя у ствола темнее (псевдо-AO), верхние ярусы чуть светлее.
        // v9.0: диапазон 0.60..1.00 (было 0.72..1.14 — верхушки выгорали)
        ALBEDO = alb.rgb * tint * (0.60 + 0.40 * v_h);
        ROUGHNESS = roughness_val;
}
