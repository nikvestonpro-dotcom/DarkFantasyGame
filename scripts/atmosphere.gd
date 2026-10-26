extends Node3D
## Атмосфера v6.0 «Тёмное фэнтези»: процедурное небо с багрово-оранжевым
## заревом за горами и глубоким сине-фиолетовым зенитом со звёздами и
## тёмными облаками (шейдер sky_dark). ACES-тонмаппинг, SSAO, плотный
## объёмный туман, стелющийся по земле, SSR для металла и воды,
## лунный свет + тёплая подсветка от зарева. Стиль — Valheim / Dark Souls.

const SkyShader := preload("res://shaders/sky_dark.gdshader")


func _ready() -> void:
        _build_environment()
        _build_moonlight()
        _build_glow_fill()
        _build_fireflies(Vector3(0, GameWorld.VILLAGE_HEIGHT, 30), 55.0)
        _build_fireflies(Vector3(GameWorld.LAKE_CENTER.x, GameWorld.WATER_LEVEL, GameWorld.LAKE_CENTER.y), 45.0)


func _build_environment() -> void:
        var we := WorldEnvironment.new()
        var env := Environment.new()

        # --- НЕБО: процедурный шейдер (зарево + звёзды + облака + луна) ---
        var sky_mat := ShaderMaterial.new()
        sky_mat.shader = SkyShader
        sky_mat.set_shader_parameter("glow_dir", GameWorld.GLOW_DIR)
        sky_mat.set_shader_parameter("moon_dir", GameWorld.MOON_DIR)
        var sky := Sky.new()
        sky.sky_material = sky_mat
        sky.radiance_size = Sky.RADIANCE_SIZE_256
        env.background_mode = Environment.BG_SKY
        env.sky = sky

        # --- Рассеянный свет ночи: холодный сине-фиолетовый (предсказуемо
        # на любом рендерере; от шейдерного неба с яркой луной ambient
        # может пересвечивать сцену) ---
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.26, 0.25, 0.38)
        env.ambient_light_energy = 1.1

        # --- ACES + экспозиция: кинематографичный контраст, мягкие света ---
        env.tonemap_mode = Environment.TONE_MAPPER_ACES
        env.tonemap_exposure = 1.18
        env.tonemap_white = 6.0

        # --- v7.0: SDFGI — честное глобальное освещение ночи ---
        env.sdfgi_enabled = true
        env.sdfgi_use_occlusion = true
        env.sdfgi_bounce_feedback = 0.4
        env.sdfgi_cascades = 6
        env.sdfgi_min_cell_size = 1.6
        env.sdfgi_energy = 1.0
        env.sdfgi_probe_bias = 1.1

        # --- Свечение (bloom): зарево, луна, кристаллы, ведьмин огонь ---
        env.glow_enabled = true
        env.glow_intensity = 0.9
        env.glow_bloom = 0.14
        env.glow_hdr_threshold = 1.08
        env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

        # --- SSAO: глубокие контактные тени у домов, деревьев, стен ---
        env.ssao_enabled = true
        env.ssao_intensity = 2.6
        env.ssao_radius = 2.0
        env.ssao_power = 1.5
        env.ssao_detail = 0.5
        env.ssao_light_affect = 0.12

        # --- SSR: отражения на броне рыцаря и в воде ---
        env.ssr_enabled = true
        env.ssr_max_steps = 48
        env.ssr_fade_in = 0.15
        env.ssr_fade_out = 1.8
        env.ssr_depth_tolerance = 0.35

        # --- Объёмный туман: стелется по земле, подсвечивается луной
        # и заревом (анизотропия), даёт мистические лучи между деревьями.
        # v7.0: гуще и болотнее (серо-зелёная гниль) ---
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = 0.021
        env.volumetric_fog_albedo = Color(0.36, 0.40, 0.46)
        env.volumetric_fog_anisotropy = 0.76
        env.volumetric_fog_length = 200.0
        env.volumetric_fog_ambient_inject = 0.95
        env.volumetric_fog_gi_inject = 0.22

        # --- Дымка глубины: горы читаются силуэтами на зареве ---
        env.fog_enabled = true
        env.fog_light_color = Color(0.24, 0.20, 0.27)
        env.fog_density = 0.0034
        env.fog_sky_affect = 0.0

        we.environment = env
        add_child(we)


func _build_moonlight() -> void:
        var light := DirectionalLight3D.new()
        light.name = "Moonlight"
        light.basis = Basis.looking_at(-GameWorld.MOON_DIR, Vector3.UP)
        # v7.0: пепельно-синяя луна, ниже интенсивность — мрак гуще
        light.light_color = Color(0.52, 0.58, 0.82)
        light.light_energy = 2.3
        light.light_angular_distance = 1.2
        light.shadow_enabled = true
        light.shadow_blur = 1.2
        light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
        add_child(light)


## Тёплая боковая подсветка от зарева: риммейк на западных склонах гор,
## стенах замка и кирасе рыцаря — контраст к холодной луне.
func _build_glow_fill() -> void:
        var light := DirectionalLight3D.new()
        light.name = "GlowFill"
        # Свет идёт ОТ зарева (горизонт, без теней — это рассеянное послесвечение)
        light.basis = Basis.looking_at(-Vector3(GameWorld.GLOW_DIR.x, 0.18,
                        GameWorld.GLOW_DIR.z).normalized(), Vector3.UP)
        # v7.0: зарево — тлеющий пепел пожара, не «весёлый закат»
        light.light_color = Color(0.85, 0.26, 0.08)
        light.light_energy = 0.22
        light.light_angular_distance = 6.0
        light.shadow_enabled = false
        add_child(light)


## v7.0: болотные огни — бледно-зелёные, не «весёлые светлячки».
func _build_fireflies(center: Vector3, radius: float) -> void:
        var p := GPUParticles3D.new()
        p.amount = 40
        p.lifetime = 11.0
        p.preprocess = 9.0
        p.speed_scale = 0.5
        p.position = center + Vector3(0, 1.6, 0)
        var pm := ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        pm.emission_box_extents = Vector3(radius, 2.2, radius)
        pm.direction = Vector3(0, 1, 0)
        pm.spread = 180.0
        pm.initial_velocity_min = 0.12
        pm.initial_velocity_max = 0.38
        pm.gravity = Vector3.ZERO
        pm.damping_min = 0.05
        pm.damping_max = 0.2
        pm.scale_min = 0.5
        pm.scale_max = 1.1
        var g := Gradient.new()
        g.set_color(0, Color(0.55, 0.9, 0.6, 0.0))
        g.set_color(1, Color(0.55, 0.9, 0.6, 0.0))
        g.add_point(0.2, Color(0.55, 0.9, 0.6, 0.75))
        g.add_point(0.8, Color(0.65, 0.95, 0.7, 0.55))
        var gt := GradientTexture1D.new()
        gt.gradient = g
        pm.color_ramp = gt
        p.process_material = pm
        var sm := SphereMesh.new()
        sm.radius = 0.05
        sm.height = 0.1
        sm.radial_segments = 6
        sm.rings = 3
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.albedo_color = Color(0.60, 0.92, 0.66)
        m.emission_enabled = true
        m.emission = Color(0.5, 0.85, 0.55)
        m.emission_energy_multiplier = 2.8
        sm.material = m
        p.draw_pass_1 = sm
        add_child(p)
