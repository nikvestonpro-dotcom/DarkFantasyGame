extends Node3D
## Атмосфера: HDR-небо Poly Haven (лунная ночь со звёздами и Млечным Путём),
## лунный свет точно по диску луны на панораме, объёмный туман, свечение,
## светлячки. Яркость выверена, чтобы ночь читалась, но оставалась ночью.

const HDR_PATH := "res://assets/hdr/rogland_moonlit_night_4k.hdr"


func _ready() -> void:
	_build_environment()
	_build_moonlight()
	_build_fireflies(Vector3(0, GameWorld.VILLAGE_HEIGHT, 30), 55.0)
	_build_fireflies(Vector3(GameWorld.LAKE_CENTER.x, GameWorld.WATER_LEVEL, GameWorld.LAKE_CENTER.y), 45.0)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()

	# Небо — реальная HDR-панорама CC0 (Rogland Moonlit Night, Poly Haven)
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load(HDR_PATH)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# Рассеянный свет ночного неба (цвет — предсказуемо на любом рендерере;
	# AMBIENT_SOURCE_SKY на HDR-панораме с крошечной сверхъяркой луной
	# на некоторых системах давал пересвет всей сцены)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.46, 0.64)
	env.ambient_light_energy = 1.7

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.ssao_radius = 2.0

	# Объёмный туман
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0085
	env.volumetric_fog_albedo = Color(0.52, 0.58, 0.74)
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 180.0
	env.volumetric_fog_ambient_inject = 0.8
	env.volumetric_fog_gi_inject = 0.0

	# Лёгкая дымка для дали (горы читаются силуэтом, но не сливаются)
	env.fog_enabled = true
	env.fog_light_color = Color(0.34, 0.40, 0.56)
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.0

	we.environment = env
	add_child(we)


func _build_moonlight() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Moonlight"
	# Светим ровно оттуда, где на HDR-панораме стоит луна
	light.basis = Basis.looking_at(-GameWorld.MOON_DIR, Vector3.UP)
	light.light_color = Color(0.74, 0.80, 0.98)
	light.light_energy = 2.4
	light.light_angular_distance = 1.2
	light.shadow_enabled = true
	light.shadow_blur = 1.3
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(light)


func _build_fireflies(center: Vector3, radius: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 60
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
	pm.scale_min = 0.6
	pm.scale_max = 1.3
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
	sm.radius = 0.055
	sm.height = 0.11
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 1.0, 0.45)
	m.emission_enabled = true
	m.emission = Color(0.7, 1.0, 0.4)
	m.emission_energy_multiplier = 3.5
	sm.material = m
	p.draw_pass_1 = sm
	add_child(p)
