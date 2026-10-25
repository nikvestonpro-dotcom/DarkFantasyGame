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
	env.ambient_light_color = Color(0.23, 0.21, 0.33)
	env.ambient_light_energy = 1.25

	# --- ACES + экспозиция: кинематографичный контраст, мягкие света ---
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12
	env.tonemap_white = 6.5

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
	# и заревом (анизотропия), даёт мистические лучи между деревьями ---
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color(0.40, 0.43, 0.56)
	env.volumetric_fog_anisotropy = 0.72
	env.volumetric_fog_length = 190.0
	env.volumetric_fog_ambient_inject = 0.85
	env.volumetric_fog_gi_inject = 0.0

	# --- Дымка глубины: горы читаются силуэтами на зареве ---
	env.fog_enabled = true
	env.fog_light_color = Color(0.27, 0.21, 0.29)
	env.fog_density = 0.0030
	env.fog_sky_affect = 0.0

	we.environment = env
	add_child(we)


func _build_moonlight() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Moonlight"
	light.basis = Basis.looking_at(-GameWorld.MOON_DIR, Vector3.UP)
	light.light_color = Color(0.62, 0.68, 0.94)
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
	light.light_color = Color(0.95, 0.33, 0.10)
	light.light_energy = 0.28
	light.light_angular_distance = 6.0
	light.shadow_enabled = false
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
