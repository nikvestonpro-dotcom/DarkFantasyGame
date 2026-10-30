extends Node3D
## Атмосфера v10.0 «Фиолетовая ночь»: небо с пурпурно-синими туманностями
## (референс — фото пользователя), повышенная общая освещённость (было
## «слишком тёмное»), лунный свет холоднее и ярче, туман с пурпурным
## отливом, светлячки у деревни и озера.

const SkyDomeShader := preload("res://shaders/sky_dome.gdshader")

var _dome: MeshInstance3D


func _ready() -> void:
        _build_environment()
        _build_sky_dome()
        _build_moonlight()
        _build_fireflies(Vector3(0, GameWorld.VILLAGE_HEIGHT, 8), 40.0)
        _build_fireflies(Vector3(GameWorld.LAKE_CENTER.x, GameWorld.WATER_LEVEL, GameWorld.LAKE_CENTER.y), 45.0)


func _process(_dt: float) -> void:
        # Купол следует за камерой — направление на луну/звёзды стабильно
        var cam := get_viewport().get_camera_3d()
        if cam != null and _dome != null:
                _dome.global_position = cam.global_position


func _build_environment() -> void:
        var we := WorldEnvironment.new()
        var env := Environment.new()

        # Фон — тёмная подстраховка за куполом (купол закрывает всё небо)
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.006, 0.005, 0.013)

        # Рассеянный свет ночного неба: v10 — чуть ярче и с пурпурным
        # оттенком (прошлая версия 0.85 была «слишком тёмной» по отзыву;
        # пересвета не даёт, сцена остаётся ночной)
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.36, 0.33, 0.56)
        # v10.1: 1.08 -> 1.15 — деревня затемнена, чуть поднимаем подсветку,
        # чтобы силуэты домов читались и не было «грязно-чёрных» пятен
        env.ambient_light_energy = 1.15

        env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
        # v10: 0.72 -> 0.85 — пользователь просил светлее (было «всё
        # слишком тёмное»); FILMIC держит луну в белом без клипа
        env.tonemap_exposure = 0.85
        env.glow_enabled = true
        env.glow_intensity = 0.5
        env.glow_bloom = 0.08
        # Порог 1.8: луна (яркость до ~2.4) НЕ накрывается bloom-вуалью —
        # моря и кратеры остаются читаемыми; костёр и окна цветут мягко
        env.glow_hdr_threshold = 1.8
        # ADDITIVE: SOFTLIGHT давал тёмные кольца вокруг ярких пятен
        env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

        env.ssao_enabled = true
        env.ssao_intensity = 1.3
        env.ssao_radius = 1.5

        # Объёмный туман: лунная дымка с пурпурным отливом
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = 0.0062
        env.volumetric_fog_albedo = Color(0.52, 0.50, 0.74)
        env.volumetric_fog_anisotropy = 0.6
        env.volumetric_fog_length = 160.0
        env.volumetric_fog_ambient_inject = 0.62
        env.volumetric_fog_gi_inject = 0.0

        # Дымка для дали (фиолетовая ночь)
        env.fog_enabled = true
        env.fog_light_color = Color(0.34, 0.30, 0.52)
        env.fog_density = 0.0017
        env.fog_sky_affect = 0.0

        we.environment = env
        add_child(we)


func _build_sky_dome() -> void:
        _dome = MeshInstance3D.new()
        _dome.name = "SkyDome"
        var sm := SphereMesh.new()
        sm.radius = 2500.0
        sm.height = 5000.0
        sm.radial_segments = 64
        sm.rings = 32
        _dome.mesh = sm
        var mat := ShaderMaterial.new()
        mat.shader = SkyDomeShader
        mat.set_shader_parameter("moon_tex", load("res://assets/textures/moon/moon_diff.png"))
        mat.set_shader_parameter("moon_dir", GameWorld.MOON_DIR)
        _dome.material_override = mat
        _dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(_dome)
        _dome.global_position = Vector3(0, 0, 0)


func _build_moonlight() -> void:
        var light := DirectionalLight3D.new()
        light.name = "Moonlight"
        # Светим ровно оттуда, где на куполе нарисована луна
        light.basis = Basis.looking_at(-GameWorld.MOON_DIR, Vector3.UP)
        # v10: 1.15 -> 1.38, цвет холоднее с пурпурным отливом — сцена
        # читаемее в темноте, но не «побелённая» (пересвет ловили на v5)
        light.light_color = Color(0.74, 0.74, 0.98)
        light.light_energy = 1.38
        light.light_angular_distance = 1.2
        light.shadow_enabled = true
        light.shadow_blur = 1.3
        light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
        add_child(light)

        # Мягкая подсветка теневых сторон — без теней, слабая, фиолетовая
        var fill := DirectionalLight3D.new()
        fill.name = "MoonFill"
        var fill_dir := Vector3(0.72, 0.18, -0.66).normalized()
        fill.basis = Basis.looking_at(-fill_dir, Vector3.UP)
        fill.light_color = Color(0.46, 0.42, 0.68)
        fill.light_energy = 0.45
        fill.shadow_enabled = false
        add_child(fill)


func _build_fireflies(center: Vector3, radius: float) -> void:
        var p := GPUParticles3D.new()
        p.amount = 10
        p.lifetime = 9.0
        p.preprocess = 9.0
        p.speed_scale = 0.6
        p.position = center + Vector3(0, 2.0, 0)
        var pm := ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        pm.emission_box_extents = Vector3(radius, 2.5, radius)
        pm.direction = Vector3(0, 1, 0)
        pm.spread = 180.0
        pm.initial_velocity_min = 0.15
        pm.initial_velocity_max = 0.45
        pm.gravity = Vector3.ZERO
        pm.damping_min = 0.05
        pm.damping_max = 0.2
        pm.scale_min = 0.4
        pm.scale_max = 0.8
        var g := Gradient.new()
        g.set_color(0, Color(0.7, 1.0, 0.4, 0.0))
        g.set_color(1, Color(0.7, 1.0, 0.4, 0.0))
        g.add_point(0.2, Color(0.7, 1.0, 0.4, 0.9))
        g.add_point(0.8, Color(0.85, 1.0, 0.5, 0.7))
        var gt := GradientTexture1D.new()
        gt.gradient = g
        pm.color_ramp = gt
        p.process_material = pm
        var sm := SphereMesh.new()
        sm.radius = 0.035
        sm.height = 0.07
        sm.radial_segments = 6
        sm.rings = 3
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.albedo_color = Color(0.75, 1.0, 0.45)
        m.emission_enabled = true
        m.emission = Color(0.7, 1.0, 0.4)
        m.emission_energy_multiplier = 1.2
        sm.material = m
        p.draw_pass_1 = sm
        add_child(p)
