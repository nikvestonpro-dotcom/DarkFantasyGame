extends Node3D
## Атмосфера v9.0: небесный купол (полное разрешение экрана, БЕЛАЯ луна
## по текстуре, круглые звёзды, Млечный Путь), лунный свет без пересвета,
## подсветка теневых сторон MoonFill, объёмный туман, светлячки.
##
## История: панорама HDR давала мыльную луну (кубмапа radiance 256px) и
## сверхъяркий пик 18 EV, который glow раздувал в «огромное коричневое
## пятно с чёрной аркой». Купол рисуется фрагмент-в-фрагмент — луна
## чистая белая, гало без зазора.

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
        env.background_color = Color(0.004, 0.005, 0.009)

        # Рассеянный свет ночного неба: сдержанный, чтобы ночь оставалась
        # ночью и лунный свет не «побелял» объекты (v5 давал ambient 1.7 —
        # пересвет; теперь 0.85)
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.30, 0.36, 0.52)
        env.ambient_light_energy = 0.85

        env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
        env.tonemap_exposure = 0.72
        env.glow_enabled = true
        env.glow_intensity = 0.45
        env.glow_bloom = 0.07
        # Порог 1.8: луна (яркость до ~2.4) НЕ накрывается bloom-вуалью —
        # моря и кратеры остаются читаемыми; костёр и окна цветут мягко
        env.glow_hdr_threshold = 1.8
        # ADDITIVE: SOFTLIGHT давал тёмные кольца вокруг ярких пятен
        env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

        env.ssao_enabled = true
        env.ssao_intensity = 1.3
        env.ssao_radius = 1.5

        # Объёмный туман: лёгкая лунная дымка (не «подводный мир»)
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = 0.0058
        env.volumetric_fog_albedo = Color(0.50, 0.56, 0.72)
        env.volumetric_fog_anisotropy = 0.6
        env.volumetric_fog_length = 160.0
        env.volumetric_fog_ambient_inject = 0.55
        env.volumetric_fog_gi_inject = 0.0

        # Дымка для дали
        env.fog_enabled = true
        env.fog_light_color = Color(0.30, 0.36, 0.50)
        env.fog_density = 0.0016
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
        # v9: 2.4 -> 1.15: прошлые значения «белили» деревья и крыши
        light.light_color = Color(0.72, 0.78, 0.95)
        light.light_energy = 1.15
        light.light_angular_distance = 1.2
        light.shadow_enabled = true
        light.shadow_blur = 1.3
        light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
        add_child(light)

        # Мягкая подсветка теневых сторон (иначе ночная сцена выглядит
        # «чёрные прямоугольники на светлых») — без теней, слабая.
        # Источник — противоположный луне азимут, низко над горизонтом.
        var fill := DirectionalLight3D.new()
        fill.name = "MoonFill"
        var fill_dir := Vector3(0.72, 0.18, -0.66).normalized()
        fill.basis = Basis.looking_at(-fill_dir, Vector3.UP)
        fill.light_color = Color(0.45, 0.52, 0.70)
        fill.light_energy = 0.38
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
