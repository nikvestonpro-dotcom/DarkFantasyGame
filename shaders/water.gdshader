shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
// ОЗЕРО v6.0 «Тёмное фэнтези»: почти чёрная вода, зеркалящая сине-фиолетовое
// небо с багровым заревом (мини-градиент той же палитры, что и sky_dark),
// плюс screen-space отражение берега (сэмпл экрана со сдвигом по нормали)
// и лунная дорожка. Пена затемнена.

uniform vec4 shallow_color : source_color = vec4(0.035, 0.065, 0.075, 0.55);
uniform vec4 deep_color : source_color = vec4(0.005, 0.010, 0.020, 0.97);
uniform vec4 foam_color : source_color = vec4(0.30, 0.32, 0.36, 1.0);
// Палитра отражённого неба (должна совпадать со sky_dark.gdshader)
uniform vec3 water_zenith : source_color = vec3(0.030, 0.038, 0.10);
uniform vec3 water_horizon : source_color = vec3(0.14, 0.055, 0.05);
uniform vec3 glow_color : source_color = vec3(0.98, 0.30, 0.06);
uniform vec3 glow_dir = vec3(-0.87, 0.0, -0.49);
uniform vec3 moon_dir = vec3(0.6988, 0.5016, 0.5100);
uniform vec3 moon_tint : source_color = vec3(0.70, 0.78, 1.0);
uniform sampler2D ripple_nor : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float wave_height = 0.07;
uniform float ripple_strength = 0.55;

varying vec3 wpos;

void vertex() {
        wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        float wx = sin(TIME * 1.1 + wpos.x * 0.30) * wave_height;
        float wz = cos(TIME * 1.5 + wpos.z * 0.34) * wave_height * 0.7;
        VERTEX.y += wx + wz;
        float dx = -wave_height * 0.30 * cos(TIME * 1.1 + wpos.x * 0.30);
        float dz = -wave_height * 0.70 * 0.34 * sin(TIME * 1.5 + wpos.z * 0.34);
        NORMAL = normalize(vec3(dx, 1.0, dz));
}

void fragment() {
        // Глубина сцены под водой
        float depth_raw = textureLod(depth_tex, SCREEN_UV, 0.0).r;
        vec3 ndc = vec3(SCREEN_UV, depth_raw) * 2.0 - 1.0;
        vec4 vpos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
        vpos.xyz /= vpos.w;
        float diff = max((-vpos.z) - (-VERTEX.z), 0.0);
        float deep_fade = clamp(diff / 5.5, 0.0, 1.0);

        // Рябь: два слоя нормалей
        vec3 r1 = texture(ripple_nor, wpos.xz * 0.07 + vec2(TIME * 0.016, TIME * 0.012)).xyz * 2.0 - 1.0;
        vec3 r2 = texture(ripple_nor, wpos.xz * 0.14 - vec2(TIME * 0.021, -TIME * 0.014)).xyz * 2.0 - 1.0;
        vec2 bump = (r1.xy + r2.xy) * 0.5 * ripple_strength;
        vec3 wnorm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz + vec3(bump.x, 0.0, bump.y));

        vec3 vdir = normalize(-VERTEX);
        float fres = pow(1.0 - max(dot(vdir, NORMAL), 0.0), 3.0);

        // --- ОТРАЖЕНИЕ НЕБА: тот же градиент, что в sky_dark (в мировых
        // координатах направления отражённого луча) ---
        vec3 rdir_v = reflect(vdir, NORMAL);
        vec3 rw = normalize((INV_VIEW_MATRIX * vec4(rdir_v, 0.0)).xyz);
        float ry = clamp(rw.y, 0.0, 1.0);
        vec3 skycol = mix(water_horizon, water_zenith, smoothstep(0.0, 0.5, ry));
        float az = 0.0;
        if (length(rw.xz) > 1e-4) {
                az = max(dot(normalize(rw.xz), normalize(glow_dir.xz)), 0.0);
        }
        skycol += glow_color * pow(az, 2.4) * pow(1.0 - ry, 2.2) * 0.65;

        // --- SCREEN-SPACE REFLECTION: сэмпл экрана со сдвигом по ряби ---
        vec2 suv = SCREEN_UV + vec2(NORMAL.x, -NORMAL.y)
                        * 0.075 / max(1.0, -VERTEX.z * 0.13);
        vec3 screen_refl = texture(screen_tex, clamp(suv, vec2(0.001), vec2(0.999))).rgb;
        // Бережная маска: экранное отражение сильнее у берега (когда берег
        // и предметы реально видны на экране), вдали доминирует небо
        float ssr_w = clamp(1.0 - ry * 2.4, 0.0, 1.0) * 0.8;
        vec3 reflection = mix(skycol, screen_refl, ssr_w);

        vec3 base = mix(shallow_color.rgb, deep_color.rgb, deep_fade);
        base = mix(base, reflection, clamp(fres * 0.92, 0.0, 0.95));

        // Лунная дорожка (холодная, приглушённая)
        vec3 lview = normalize((VIEW_MATRIX * vec4(moon_dir, 0.0)).xyz);
        float spec = pow(max(dot(reflect(-lview, NORMAL), vdir), 0.0), 180.0);

        // Багровый отблеск зарева на воде: виден, когда смотришь в сторону зарева
        vec3 cam_world = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        vec2 to_frag = wpos.xz - cam_world.xz;
        float gaze = 0.0;
        if (length(to_frag) > 1e-3) {
                gaze = max(dot(normalize(to_frag), normalize(glow_dir.xz)), 0.0);
        }
        float gspec = pow(gaze, 3.0) * fres * 0.10;

        // Пена на мелководье
        float n = texture(ripple_nor, wpos.xz * 0.09 + vec2(TIME * 0.02, 0.0)).r;
        float foam_mask = 1.0 - smoothstep(0.0, 0.55, diff);
        float foam = foam_mask * smoothstep(0.48, 0.75, n + foam_mask * 0.4);

        ALBEDO = mix(base, foam_color.rgb, foam * 0.6);
        EMISSION = moon_tint * spec * 1.5 + glow_color * gspec
                        + foam_color.rgb * foam * 0.15;
        ALPHA = clamp(mix(shallow_color.a, deep_color.a, deep_fade) + fres * 0.18 + foam * 0.5, 0.0, 0.97);
        ROUGHNESS = 0.05;
        SPECULAR = 0.7;
        NORMAL = (VIEW_MATRIX * vec4(wnorm, 0.0)).xyz;
}
