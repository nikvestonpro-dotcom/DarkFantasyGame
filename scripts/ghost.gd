extends CharacterBody3D
## «Белая Дама» v11 — призрак на старом погосте (модель Arissa в
## погребальном саване: полупрозрачная, светится холодным светом).
## Парит над землёй (не касается ступнями), медленно дрейфует между
## надгробиями, при приближении игрока замирает и шепчет фразы.
## Добавлена в группу «npc» — реплики показывает общий интерфейс.

const GHOST_HEIGHT := 1.78   # при жизни была высокой
const FACING_FIX := 0.0
const HOVER := 0.42          # высота парения над землёй
const DRIFT_SPEED := 0.55

const ARISSA := preload("res://assets/Анимация и персонажи/Arissa.fbx")
const ANIMS := preload("res://assets/anims/v11_arissa_anims.tres")

var npc_name := "Белая Дама"
var phrases := [
	"Ты видишь меня?.. Наконец-то...",
	"Я жду того, кто вернёт мне имя. Крест мой сломан, путник.",
	"Не буди холмы. Спящие здесь не любят света.",
	"Мой сын ушёл на войну под мёртвой луной... Я всё ещё жду.",
]

var home_center: Vector2 = Vector2(28.0, 26.0)
var home_radius := 9.0

var _waypoint := Vector3.ZERO
var _idle := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _cur_anim := ""
var _light: OmniLight3D
var _glow_mats: Array = []

var visual: Node3D
var anim: AnimationPlayer


func _ready() -> void:
	add_to_group("npc")
	add_to_group("ghost")
	_rng.seed = 1313
	_build_body()
	_pick_waypoint()


func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var inst: Node3D = ARISSA.instantiate()
	visual.add_child(inst)
	CharRig.calibrate(inst, GHOST_HEIGHT, FACING_FIX)
	# погребальный сават: полупрозрачность + холодное свечение
	for mi_n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh is ArrayMesh:
			var am := mi.mesh as ArrayMesh
			for i in am.get_surface_count():
				var m := am.surface_get_material(i)
				if m is StandardMaterial3D:
					var dup := (m as StandardMaterial3D).duplicate()
					dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					dup.albedo_color = Color(0.62, 0.72, 0.86, 0.42)
					dup.roughness = 1.0
					dup.metallic = 0.0
					dup.emission_enabled = true
					dup.emission = Color(0.5, 0.66, 0.9)
					dup.emission_energy_multiplier = 0.55
					dup.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
					mi.set_surface_override_material(i, dup)
					_glow_mats.append(dup)
	anim = CharRig.find_ap(inst)
	if anim != null:
		anim.playback_default_blend_time = 0.4
		anim.add_animation_library("n", ANIMS)
		anim.play("n/idle_calm")
		anim.speed_scale = 0.55

	# холодный свет вокруг призрака
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.72, 1.0)
	_light.light_energy = 1.1
	_light.omni_range = 6.5
	_light.shadow_enabled = false
	add_child(_light)
	_light.position.y = 1.2

	# имя над головой (бледное)
	var lbl := Label3D.new()
	lbl.text = npc_name
	lbl.font_size = 40
	lbl.pixel_size = 0.004
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.65, 0.8, 1.0, 0.85)
	lbl.outline_size = 8
	lbl.position.y = GHOST_HEIGHT + 0.5
	add_child(lbl)


func _physics_process(dt: float) -> void:
	_t += dt
	# пульс свечения + покачивание
	if _light != null:
		_light.light_energy = 1.0 + 0.3 * sin(_t * 1.7) + 0.1 * sin(_t * 5.3)
	var bob := 0.09 * sin(_t * 1.1)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var d := global_position.distance_to(player.global_position)
		if d < 5.0:
			# замирает и «смотрит» на игрока
			var dir := player.global_position - global_position
			dir.y = 0.0
			if dir.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 3.0 * dt)
			global_position.y = GameWorld.terrain_height(global_position.x, global_position.z) + HOVER + bob
			return
	if _idle > 0.0:
		_idle -= dt
	else:
		var to_wp := _waypoint - global_position
		to_wp.y = 0.0
		if to_wp.length() < 0.6:
			_idle = _rng.randf_range(3.0, 7.0)
			_pick_waypoint()
		else:
			var dir2 := to_wp.normalized()
			global_position += dir2 * DRIFT_SPEED * dt
			rotation.y = lerp_angle(rotation.y, atan2(dir2.x, dir2.z), 2.0 * dt)
	global_position.y = GameWorld.terrain_height(global_position.x, global_position.z) + HOVER + bob


func _pick_waypoint() -> void:
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(2.0, home_radius)
	var p := home_center + Vector2(cos(ang), sin(ang)) * r
	_waypoint = Vector3(p.x, GameWorld.terrain_height(p.x, p.y), p.y)


func get_dialogue() -> String:
	var idx := int(Time.get_ticks_msec() / 9000 + get_instance_id()) % phrases.size()
	return phrases[idx]
