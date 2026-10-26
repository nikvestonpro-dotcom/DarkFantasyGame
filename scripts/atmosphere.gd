extends Node3D
## v8.0 «Цветная ночь» (@elder.void-стиль):
##  - шейдерное небо sky_night.gdshader: фиолет->пурпур, огромная луна,
##    звёзды, зелёное сияние, фиолетовые облака
##  - ЛУННЫЙ СВЕТ направлен туда же, где рисуется диск луны в шейдере
##  - двухуровневый цветной туман: бирюзовый объёмный у земли + фиолетовая даль
##  - яркость поднята (жалоба v7.0 «слишком темно»): экспозиция, ambient, glow
##  - светлячки — зелёные колдовские, у деревни и озера

const SKY_SHADER := preload("res://shaders/sky_night.gdshader")

const MOON_COLOR := Color(1.0, 0.94, 0.82)


func _ready() -> void:
	_build_environment()
	_build_moonlight()
	_build_fireflies(Vector3(0, GameWorld.VILLAGE_HEIGHT, 30), 55.0)
	_build_fireflies(Vector3(GameWorld.LAKE_CENTER.x, GameWorld.WATER_LEVEL, GameWorld.LAKE_CENTER.y), 45.0)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()

	# --- НЕБО: шейдерный купол «цветная ночь» ---
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	# Луна стоит по MOON_DIR — туда же смотрит и DirectionalLight3D
	sky_mat.set_shader_parameter("moon_dir", GameWorld.MOON_DIR)
	sky_mat.set_shader_parameter("moon_color", Vector3(MOON_COLOR.r, MOON_COLOR.g, MOON_COLOR.b))
	sky_mat.set_shader_parameter("moon_size", 0.10)       # огромная, ~12% кадра
	sky_mat.set_shader_parameter("moon_glow", 1.8)
	sky_mat.set_shader_parameter("aurora_strength", 0.9)
	sky_mat.set_shader_parameter("star_density", 1.1)
	sky_mat.set_shader_parameter("star_brightness", 1.6)
	sky_mat.set_shader_parameter("cloud_amount", 0.32)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# --- РАССЕЯННЫЙ СВЕТ: пурпурно-синий, заметно ярче v7.0 (было 1.7) ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.47, 0.68)
	env.ambient_light_energy = 2.6

	# --- ТОНМАППИНГ: ярче (было 0.8), Filmic держит глубокие тени ---
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.18

	# --- GLOW: окна, луна, факелы и глазницы должны «гореть» ---
	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.ssao_radius = 2.0

	# --- ОБЪЁМНЫЙ ТУМАН: бирюзово-зелёный «колдовской», у самой земли ---
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.010
	env.volumetric_fog_albedo = Color(0.36, 0.60, 0.52)
	env.volumetric_fog_anisotropy = 0.85
	env.volumetric_fog_length = 200.0
	env.volumetric_fog_ambient_inject = 0.85
	env.volumetric_fog_gi_inject = 0.0

	# --- ДАЛЬНЯЯ ДЫМКА: фиолетовая, слегка подкрашивает горизонт неба ---
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.20, 0.40)
	env.fog_density = 0.0026
	env.fog_sky_affect = 0.35

	we.environment = env
	add_child(we)


func _build_moonlight() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Moonlight"
	# Светим ровно оттуда, где шейдер неба рисует диск луны
	light.basis = Basis.looking_at(-GameWorld.MOON_DIR, Vector3.UP)
	light.light_color = Color(0.88, 0.90, 1.0)
	light.light_energy = 3.0
	light.light_angular_distance = 1.2
	light.shadow_enabled = true
	light.shadow_blur = 1.3
	# v8.0 оптимизация: 2 сплита вместо 4 (жалоба «не оптимизировано»)
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 90.0
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
	# v8.0: колдовские зелёно-бирюзовые огни (в тон сиянию и туману)
	g.set_color(0, Color(0.45, 1.0, 0.75, 0.0))
	g.set_color(1, Color(0.45, 1.0, 0.75, 0.0))
	g.add_point(0.2, Color(0.45, 1.0, 0.75, 0.9))
	g.add_point(0.8, Color(0.6, 1.0, 0.85, 0.7))
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
	m.albedo_color = Color(0.5, 1.0, 0.78)
	m.emission_enabled = true
	m.emission = Color(0.45, 1.0, 0.72)
	m.emission_energy_multiplier = 3.5
	sm.material = m
	p.draw_pass_1 = sm
	add_child(p)
