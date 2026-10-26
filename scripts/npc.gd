extends CharacterBody3D
## v8.0 ЖИТЕЛИ — Mixamo-модели (вместо мультяшных KayKit):
##  - Арисса (трактирщица и женщины деревни), рыцарь-стража (мужские NPC
##    с разными тонировками одежды).
##  - Анимации из общей библиотеки (idle/walk); бродят по своей зоне,
##    при приближении игрока останавливаются и здороваются.

const NPC_HEIGHT := 1.72
# Mixamo-модели смотрят вдоль +Z — так и оставляем (rotation.y наводит по ходу)
const FACING_FIX := 0.0

var npc_name := "Житель"
var phrases := ["Вечер добрый, путник."]

var _waypoint := Vector3.ZERO
var _idle := 0.0
## зона блуждания (у призрака замка — двор замка)
var home_center: Vector2 = GameWorld.VILLAGE_CENTER
var home_radius := 17.0
var _speed := 1.15
var _moving := false
var _rng := RandomNumberGenerator.new()
var _cur_anim := ""

var visual: Node3D
var anim: AnimationPlayer
var model_inst: Node3D


func setup(p_name: String, p_phrases: Array, seed_v: int,
		model: PackedScene, hide_list: Array, tint := Color(1, 1, 1)) -> void:
	npc_name = p_name
	phrases = p_phrases
	_rng.seed = seed_v
	_model = model
	_hide_list = hide_list
	_tint = tint


var _model: PackedScene
var _hide_list: Array = []
var _tint := Color(1, 1, 1)


func _ready() -> void:
	add_to_group("npc")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.5
	col.shape = cap
	col.position.y = 0.75
	add_child(col)
	_build_body()


func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	model_inst = _model.instantiate()
	for wname in _hide_list:
		for node in model_inst.find_children("*", "Node", true, false):
			if node.name == wname and node is Node3D:
				node.visible = false
	visual.add_child(model_inst)
	model_inst.rotation.y = FACING_FIX

	var skel := model_inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var fit := CharacterLibrary.fit_height(model_inst, NPC_HEIGHT)
	var s := 1.0
	var feet := 0.0
	if not fit.is_empty():
		s = fit[0]
		feet = fit[1]
	model_inst.scale = Vector3(s, s, s)
	model_inst.position = Vector3(0.0, -feet * s, 0.0)

	# Тонировка одежды для повторяющихся моделей
	if _tint != Color(1, 1, 1):
		for mi in model_inst.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			if mesh is ArrayMesh:
				for i in mesh.get_surface_count():
					var m := mesh.surface_get_material(i)
					if m is StandardMaterial3D:
						var dup := m.duplicate() as StandardMaterial3D
						dup.albedo_color = Color(
							dup.albedo_color.r * _tint.r,
							dup.albedo_color.g * _tint.g,
							dup.albedo_color.b * _tint.b)
						mesh.surface_set_material(i, dup)

	# Анимации из общей библиотеки Mixamo
	if skel != null:
		anim = CharacterLibrary.build_anim_player(model_inst, skel,
			["idle", "walk"], ["idle", "walk"])
		if anim != null:
			anim.playback_default_blend_time = 0.25
			anim.play("idle")

	# Имя над головой
	var lbl := Label3D.new()
	lbl.text = npc_name
	lbl.font_size = 40
	lbl.pixel_size = 0.004
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.85, 0.55)
	lbl.outline_size = 8
	lbl.position.y = 2.05
	add_child(lbl)


func _physics_process(dt: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var d := global_position.distance_to(player.global_position)
		if d < 3.5:
			var dir := player.global_position - global_position
			dir.y = 0.0
			if dir.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 6.0 * dt)
			_moving = false
			_update_anim()
			return
	if _idle > 0.0:
		_idle -= dt
		_moving = false
		_update_anim()
		return
	var to_wp := _waypoint - global_position
	to_wp.y = 0.0
	if to_wp.length() < 0.5:
		_idle = _rng.randf_range(2.0, 6.0)
		_pick_waypoint()
	else:
		var dir2 := to_wp.normalized()
		global_position += dir2 * _speed * dt
		global_position.y = GameWorld.terrain_height(global_position.x, global_position.z)
		rotation.y = lerp_angle(rotation.y, atan2(dir2.x, dir2.z), 8.0 * dt)
	_moving = true
	_update_anim()


func _update_anim() -> void:
	if anim == null:
		return
	var target := "idle"
	if _moving:
		target = "walk"
		_speed = 1.15
	if _cur_anim == target and anim.is_playing():
		return
	_cur_anim = target
	if anim.has_animation(target):
		anim.play(target, 0.25)
	else:
		# fallback: пробуем встроенные анимации модели (вдруг есть)
		var list := PackedStringArray(anim.get_animation_list())
		for a in list:
			if "idle" in a.to_lower():
				anim.play(a, 0.25)
				break


func _pick_waypoint() -> void:
	var in_village := home_center == GameWorld.VILLAGE_CENTER
	for attempt in 8:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(4.0, home_radius)
		var p := Vector2(
			home_center.x + cos(ang) * r,
			home_center.y + sin(ang) * r)
		if in_village:
			if p.y < -9.0:
				continue  # не заходим за таверну
			if Vector2(p.x - 4.5, p.y - 3.5).length() < 1.8:
				continue  # колодец
		_waypoint = Vector3(p.x, GameWorld.terrain_height(p.x, p.y), p.y)
		return
	_waypoint = Vector3(home_center.x,
		GameWorld.terrain_height(home_center.x, home_center.y), home_center.y)


func get_dialogue() -> String:
	var idx := int(Time.get_ticks_msec() / 7000 + get_instance_id()) % phrases.size()
	return phrases[idx]
