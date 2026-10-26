shader_type spatial;
// Террейн v7.0 «Тёмные земли»: трипланарное PBO-текстурирование Poly Haven CC0.
// Маски в вершинных цветах: R = лесная земля (основа), G = палая листва
// (гуще в лесу), B = грязь (деревня, тропы, болотистый берег).
// На крутых склонах автоматически выступает мокрый тёмный камень.
// Полностью непрозрачный (без ALPHA) — «дыр» в земле быть не может.

uniform sampler2D floor_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D floor_nor : filter_linear_mipmap, repeat_enable;
uniform sampler2D leaves_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D leaves_nor : filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_nor : filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_nor : filter_linear_mipmap, repeat_enable;

uniform float floor_scale = 0.055;
uniform float leaves_scale = 0.085;
uniform float mud_scale = 0.07;
uniform float rock_scale = 0.045;
uniform float normal_strength = 0.78;
uniform vec3 floor_tint : source_color = vec3(1.0);
uniform vec3 leaves_tint : source_color = vec3(1.0);
uniform vec3 mud_tint : source_color = vec3(1.0);
uniform vec3 rock_tint : source_color = vec3(1.0);

varying vec3 wpos;
varying vec3 wnormal;
varying vec3 vmask;

void vertex() {
        wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
        vmask = COLOR.rgb;
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

vec3 tri_blend_w(sampler2D tex, vec3 p, vec3 b, float s) {
        return texture(tex, p.yz * s).rgb * b.x
                + texture(tex, p.xz * s).rgb * b.y
                + texture(tex, p.xy * s).rgb * b.z;
}

vec3 tri_blend_n(sampler2D tex, vec3 p, vec3 n, vec3 b, float s, float k) {
        vec3 t0 = texture(tex, p.yz * s).xyz * 2.0 - 1.0;
        vec3 t1 = texture(tex, p.xz * s).xyz * 2.0 - 1.0;
        vec3 t2 = texture(tex, p.xy * s).xyz * 2.0 - 1.0;
        vec3 wx = vec3(t0.z, t0.y, -t0.x);
        vec3 wy = vec3(t1.x, t1.z, t1.y);
        vec3 wz = vec3(-t2.x, t2.y, t2.z);
        vec3 wn = normalize(wx * b.x + wy * b.y + wz * b.z);
        return normalize(mix(n, wn, k));
}

void fragment() {
        vec3 b = pow(abs(wnormal), vec3(4.0));
        b /= (b.x + b.y + b.z);
        vec3 mask = clamp(vmask, vec3(0.0), vec3(1.0));
        float slope_rock = 1.0 - smoothstep(0.58, 0.80, wnormal.y);

        // Болотистая гниль: лесная земля + палая листва + грязь
        vec3 col =
                tri_blend_w(floor_diff, wpos, b, floor_scale) * floor_tint * mask.r
                + tri_blend_w(leaves_diff, wpos, b, leaves_scale) * leaves_tint * mask.g
                + tri_blend_w(mud_diff, wpos, b, mud_scale) * mud_tint * mask.b;

        vec3 nrm =
                tri_blend_n(floor_nor, wpos, wnormal, b, floor_scale, normal_strength) * mask.r
                + tri_blend_n(leaves_nor, wpos, wnormal, b, leaves_scale, normal_strength * 0.85) * mask.g
                + tri_blend_n(mud_nor, wpos, wnormal, b, mud_scale, normal_strength * 0.9) * mask.b;
        nrm = normalize(nrm + wnormal * 0.001);

        vec3 rock_col = tri_blend_w(rock_diff, wpos, b, rock_scale) * rock_tint;
        vec3 rock_nrm = tri_blend_n(rock_nor, wpos, wnormal, b, rock_scale, normal_strength * 1.25);
        col = mix(col, rock_col, slope_rock);
        nrm = normalize(mix(nrm, rock_nrm, slope_rock));

        // Крупные вариации яркости/оттенка (~30-80 м) ломают тайлинг текстур
        float macro = 0.80 + 0.42 * vnoise(wpos.xz * 0.014);
        float macro2 = vnoise(wpos.xz * 0.006 + 31.7);
        col *= macro;
        col = mix(col, col * vec3(0.90, 1.03, 0.88), (macro2 - 0.5) * 0.8);

        // Шероховатость: грязь местами «мокрая» (блестит в лунном свете),
        // камень на склонах — влажный камень; листва и земля — матовые.
        float mud_rough_v = tri_blend_w(mud_rough, wpos, b, mud_scale).r;
        float rough = mix(mix(0.96, 0.98, mask.g), 0.55 + 0.4 * mud_rough_v, mask.b);
        rough = mix(rough, 0.62, slope_rock * 0.6);

        ALBEDO = col;
        ROUGHNESS = rough;
        NORMAL = (VIEW_MATRIX * vec4(nrm, 0.0)).xyz;
}
