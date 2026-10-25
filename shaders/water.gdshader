shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
// Озеро: волны, двухслойная рябь, фрезнель, глубинное затемнение, пена у берега
// и лунная дорожка.

uniform vec4 shallow_color : source_color = vec4(0.10, 0.24, 0.26, 0.42);
uniform vec4 deep_color : source_color = vec4(0.016, 0.05, 0.10, 0.96);
uniform vec4 foam_color : source_color = vec4(0.72, 0.80, 0.80, 1.0);
uniform vec3 sky_reflect : source_color = vec3(0.14, 0.20, 0.34);
uniform vec3 moon_dir = vec3(0.6988, 0.5016, 0.5100);
uniform vec3 moon_tint : source_color = vec3(0.85, 0.9, 1.0);
uniform sampler2D ripple_nor : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
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

        vec3 base = mix(shallow_color.rgb, deep_color.rgb, deep_fade);
        base = mix(base, sky_reflect, fres * 0.75);

        // Лунная дорожка
        vec3 lview = normalize((VIEW_MATRIX * vec4(moon_dir, 0.0)).xyz);
        float spec = pow(max(dot(reflect(-lview, NORMAL), vdir), 0.0), 180.0);

        // Пена на мелководье
        float n = texture(ripple_nor, wpos.xz * 0.09 + vec2(TIME * 0.02, 0.0)).r;
        float foam_mask = 1.0 - smoothstep(0.0, 0.55, diff);
        float foam = foam_mask * smoothstep(0.48, 0.75, n + foam_mask * 0.4);

        ALBEDO = mix(base, foam_color.rgb, foam * 0.7);
        EMISSION = moon_tint * spec * 2.2 + foam_color.rgb * foam * 0.25;
        ALPHA = clamp(mix(shallow_color.a, deep_color.a, deep_fade) + fres * 0.18 + foam * 0.5, 0.0, 0.97);
        ROUGHNESS = 0.06;
        SPECULAR = 0.7;
        NORMAL = (VIEW_MATRIX * vec4(wnorm, 0.0)).xyz;
}
