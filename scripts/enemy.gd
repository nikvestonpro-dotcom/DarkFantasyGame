extends CharacterBody3D
## v8.0 НЕЖИТЬ — «ПАВШИЕ РЫЦАРИ» (вместо мультяшных зомби/скелетов KayKit):
##  - «fallen»  — павший рыцарь (Knight D Pelegrini + мертвенная тонировка
##                + красные глазницы-визор): бродит по долине;
##  - «rust»    — ржавый павший (тёмно-ржавый tint, сильнее, медленнее);
##  - «crimson» — Багровый рыцарь, мини-босс (крупный, двуручный демонический
##                меч, Great Sword анимации, спин-атака);
##  - «ghost»   — призрак akai: полупрозрачный, светится бирюзой, кастует
##                магию, парит над землёй (не имеет физики ходьбы);
##  - «dummy»   — соломенное чучело для тренировки.
## Анимации — общая библиотека Mixamo (CharacterLibrary): один риг на всех.

const GRAV := 22.0

const KINDS := {
	"fallen": {"hp": 4, "dmg": 1, "walk": 2.0, "run": 3.6, "height": 1.78,
			"atk_cd": 1.15, "reach": 1.6, "scale_col": 1.0, "tint": Color(0.52, 0.50, 0.55),
			"style": "sword", "eyes": Color(1.0, 0.16, 0.05)},
	"rust": {"hp": 7, "dmg": 2, "walk": 1.6, "run": 2.9, "height": 1.84,
			"atk_cd": 1.35, "reach": 1.75, "scale_col": 1.08, "tint": Color(0.40, 0.30, 0.24),
			"style": "axe", "eyes": Color(1.0, 0.35, 0.1)},
	"crimson": {"hp": 14, "dmg": 2, "walk": 2.2, "run": 4.2, "height": 2.35,
			"atk_cd": 1.5, "reach": 2.1, "scale_col": 1.38, "tint": Color(0.45, 0.20, 0.18),
			"style": "greatsword", "eyes": Color(1.0, 0.10, 0.05)},
	"ghost": {"hp": 9, "dmg": 1, "walk": 2.4, "run": 3.8, "height": 1.80,
			"atk_cd": 2.0, "reach": 2.4, "scale_col": 1.0, "tint": Color(0.55, 0.75, 0.70),
			"style": "magic", "eyes": Color(0.4, 1.0, 0.85)},
}

var kind := "fallen"
var hp := 4
var player

var _dmg := 1
var _walk_sp := 2.0
var _run_sp := 3.6
var _reach := 1.6

var _iframes := 0.0
var _atk_cd := 0.0
var _wander_t := 0.0
var _wander_dir := Vector3.ZERO
var _dead := false
var _facing := 0.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _float_phase := 0.0
var visual: Node3D
var model_root: Node3D
var model_inst: Node3D
var anim: AnimationPlayer
var _mats: Array = []
var _eye_mats: Array = []


func setup(p_kind: String, seed_v: int) -> void:
	kind = p_kind if KINDS.has(p_kind) else "fallen"
	_rng.seed = seed_v
	_float_phase = _rng.randf() * TAU


func _ready() -> void:
	add_to_group("enemy")
	var kc: Dictionary = KINDS.get(kind, KINDS["fallen"])
	hp = kc.hp
	_dmg = kc.dmg
	_walk_sp = kc.walk
	_run_sp = kc.run
	_reach = kc.reach
	var col := CollisionShape3D.new()
	col.name = "Shape"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34 * kc.scale_col
	shape.height = 1.35 * kc.scale_col
	col.shape = shape
	col.position.y = 0.68 * kc.scale_col
	add_child(col)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	if kind == "dummy":
		_build_dummy()
	else:
		_build_undead(kc)


# ---------- ПОСТРОЕНИЕ ----------

func _build_undead(kc: Dictionary) -> void:
	var model_path: String = CharacterLibrary.GHOST if kind == "ghost" else CharacterLibrary.KNIGHT
	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	visual.add_child(model_root)
	model_inst = CharacterLibrary.instantiate_model(model_path)
	if model_inst == null:
		return
	model_root.add_child(model_inst)
	# Mixamo смотрит вдоль +Z; _face() наводит +Z визуала на игрока
	model_root.rotation.y = 0.0

	var skel := model_inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var fit := CharacterLibrary.fit_height(model_inst, kc.height)
	if not fit.is_empty():
		model_inst.scale = Vector3(fit[0], fit[0], fit[0])
		model_inst.position = Vector3(0.0, -fit[1] * fit[0], 0.0)

	# Анимации по стилю
	var anims: Array
	var loops: Array
	if kc.style == "greatsword":
		anims = ["gs_idle", "gs_walk", "gs_run", "gs_slash", "gs_slash2", "gs_spin", "gs_impact", "gs_death"]
		loops = ["gs_idle", "gs_walk", "gs_run"]
	elif kc.style == "magic":
		anims = ["mg_idle", "mg_cast", "mg_cast2", "mg_area"]
		loops = ["mg_idle"]
	else:
		anims = ["idle", "walk", "run", "slash1", "slash2", "slash3", "impact", "death"]
		loops = ["idle", "walk", "run"]
	if skel != null:
		anim = CharacterLibrary.build_anim_player(model_inst, skel, anims, loops)
		if anim != null:
			anim.playback_default_blend_time = 0.15
			anim.play("idle" if loops.has("idle") else loops[0] if loops.size() > 0 else "")

	_style_materials(kc)
	if kind != "ghost" and skel != null:
		_attach_undead_weapon(skel, kc)
	if anim != null:
		var first := "idle"
		if kc.style == "greatsword":
			first = "gs_idle"
		elif kc.style == "magic":
			first = "mg_idle"
		if anim.has_animation(first):
			anim.play(first)


## Мертвенная тонировка доспехов + светящиеся глазницы (стиль @elder.void)
func _style_materials(kc: Dictionary) -> void:
	var eye_energy := 4.5 if kind == "crimson" else 2.6
	var is_ghost := kind == "ghost"
	if model_inst == null:
		return
	for mi in model_inst.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m is StandardMaterial3D:
					var dup := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					var nm: String = ((mi as MeshInstance3D).name + " " + dup.resource_name).to_lower()
					if "eye" in nm or "glow" in nm or "emiss" in nm:
						dup.albedo_color = Color(0.05, 0.01, 0.0)
						dup.emission_enabled = true
						dup.emission = kc.eyes
						dup.emission_energy_multiplier = eye_energy
						_eye_mats.append(dup)
					elif is_ghost:
						# Призрак: полупрозрачная бирюза, свечение изнутри
						dup.albedo_color = Color(0.35, 0.60, 0.55, 0.55)
						dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						dup.emission_enabled = true
						dup.emission = Color(0.20, 0.65, 0.55)
						dup.emission_energy_multiplier = 0.9
						dup.roughness = 1.0
					else:
						dup.albedo_color = kc.tint
						dup.roughness = 0.75
						dup.metallic = 0.6 if ("armor" in nm or "plate" in nm or "metal" in nm) else 0.0
						_mats.append(dup)
					mesh.surface_set_material(i, dup)


## Оружие павшим: топор ржавым, двуручник — багровому боссу
func _attach_undead_weapon(skel: Skeleton3D, kc: Dictionary) -> void:
	var weapon_path := ""
	var rot := Vector3(-80.0, 0.0, 0.0)
	if kc.style == "greatsword":
		weapon_path = CharacterLibrary.DEMONIC_GREATSWORD
		rot = Vector3(-80.0, 0.0, 0.0)
	elif kc.style == "axe":
		weapon_path = CharacterLibrary.DEMONIC_AXE
		rot = Vector3(-70.0, 0.0, 0.0)
	elif kc.style == "sword":
		weapon_path = CharacterLibrary.DEMONIC_SWORD
	if weapon_path == "" or not ResourceLoader.exists(weapon_path):
		return
	var bone_idx := CharacterLibrary.find_bone(skel,
			["mixamorig_RightHand", "RightHand", "Hand_R"])
	if bone_idx < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = skel.get_bone_name(bone_idx)
	skel.add_child(ba)
	var holder := Node3D.new()
	var wps := load(weapon_path) as PackedScene
	if wps == null:
		return
	var w := wps.instantiate()
	holder.add_child(w)
	var box := CharacterLibrary._subtree_aabb(w)
	if box.size.y > 0.05:
		var k := (1.25 if kc.style != "greatsword" else 1.9) / box.size.y
		w.scale = Vector3(k, k, k)
		w.position = Vector3(-box.position.x * k, -box.position.y * k, -box.position.z * k)
	holder.rotation_degrees = rot
	var bs: Vector3 = skel.get_bone_global_pose(bone_idx).basis.get_scale().abs()
	var ss: Vector3 = skel.global_transform.basis.get_scale().abs()
	holder.scale = Vector3(
		1.0 / maxf(ss.x * bs.x, 0.0001),
		1.0 / maxf(ss.y * bs.y, 0.0001),
		1.0 / maxf(ss.z * bs.z, 0.0001))
	ba.add_child(holder)


func _matc(col: Color, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


func _build_dummy() -> void:
	var wood := _matc(Color(0.34, 0.25, 0.16))
	var straw := _matc(Color(0.62, 0.48, 0.24))
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.11
	pm.height = 2.1
	pm.radial_segments = 9
	pole.mesh = pm
	pole.material_override = wood
	pole.position.y = 1.05
	visual.add_child(pole)
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.28
	bm.bottom_radius = 0.36
	bm.height = 0.9
	bm.radial_segments = 10
	body.mesh = bm
	body.material_override = straw
	body.position.y = 1.45
	visual.add_child(body)
	var cross := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = 1.5
	cm.radial_segments = 8
	cross.mesh = cm
	cross.material_override = wood
	cross.position.y = 1.75
	cross.rotation_degrees.z = 90
	visual.add_child(cross)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.20
	hm.height = 0.40
	hm.radial_segments = 10
	hm.rings = 7
	head.mesh = hm
	head.material_override = straw
	head.position.y = 2.15
	visual.add_child(head)
	var lbl := Label3D.new()
	lbl.text = "Манекен"
	lbl.font_size = 34
	lbl.pixel_size = 0.004
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.85, 0.8, 0.6)
	lbl.outline_size = 6
	lbl.position.y = 2.7
	add_child(lbl)


# ---------- ИИ ----------

func _physics_process(dt: float) -> void:
	if _iframes > 0.0:
		_iframes -= dt
	_t += dt
	if kind == "dummy" or _dead:
		return
	_atk_cd -= dt
	var is_ghost := kind == "ghost"
	if not is_ghost and not is_on_floor():
		velocity.y -= GRAV * dt
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player != null and not player.dead:
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0.0
		var dist := to_p.length()
		if dist < 14.0:
			_chase(dt, to_p, dist)
		else:
			_wander(dt)
	else:
		_wander(dt)
	move_and_slide()
	# Призрак парит: волна высоты + лёгкое покачивание
	if is_ghost and visual != null:
		var base_y: float = 0.55
		visual.position.y = base_y + sin(_t * 1.3 + _float_phase) * 0.22
		visual.rotation.z = sin(_t * 0.7 + _float_phase) * 0.05


func _chase(dt: float, to_p: Vector3, dist: float) -> void:
	if to_p.length() > 0.01:
		_face(atan2(to_p.x, to_p.z), 7.0 * dt)
	if dist < _reach:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
		if _atk_cd <= 0.0:
			player.take_damage(_dmg, global_position)
			_atk_cd = KINDS[kind].atk_cd
			_play_attack()
		elif not _attacking_enemy:
			_set_locomotion(0.0)
	else:
		var sp := _walk_sp if dist < 6.0 else _run_sp
		var dir := to_p / maxf(dist, 0.001)
		velocity.x = dir.x * sp
		velocity.z = dir.z * sp
		_set_locomotion(sp)


func _wander(dt: float) -> void:
	_wander_t -= dt
	if _wander_t <= 0.0:
		_wander_t = _rng.randf_range(2.0, 4.5)
		if _rng.randf() < 0.55:
			var a := _rng.randf() * TAU
			_wander_dir = Vector3(cos(a), 0, sin(a))
		else:
			_wander_dir = Vector3.ZERO
	if _wander_dir != Vector3.ZERO and (is_on_floor() or kind == "ghost"):
		velocity.x = _wander_dir.x * _walk_sp * 0.38
		velocity.z = _wander_dir.z * _walk_sp * 0.38
		_face(atan2(_wander_dir.x, _wander_dir.z), 4.0 * dt)
		_set_locomotion(_walk_sp * 0.38)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * dt)
		_set_locomotion(0.0)


func _face(target_yaw: float, rate: float) -> void:
	_facing = lerp_angle(_facing, target_yaw, clampf(rate, 0.0, 1.0))
	if visual != null:
		visual.rotation.y = _facing


# ---------- АНИМАЦИИ ----------

var _cur_loco := ""

func _set_locomotion(speed: float) -> void:
	if anim == null:
		return
	var style: String = KINDS[kind].style
	var idle_n := "idle"
	var walk_n := "walk"
	var run_n := "run"
	if style == "greatsword":
		idle_n = "gs_idle"
		walk_n = "gs_walk"
		run_n = "gs_run"
	elif style == "magic":
		idle_n = "mg_idle"
		walk_n = "mg_idle"
		run_n = "mg_idle"
	var target := idle_n
	if speed > _walk_sp * 0.75:
		target = run_n
	elif speed > 0.25:
		target = walk_n
	if not anim.has_animation(target):
		return
	if _cur_loco == target and anim.is_playing():
		if not _attacking_enemy:
			anim.speed_scale = clampf(speed / _walk_sp, 0.75, 1.5)
		return
	if _attacking_enemy:
		return
	_cur_loco = target
	anim.speed_scale = clampf(speed / maxf(_walk_sp, 0.1), 0.75, 1.5)
	anim.play(target, 0.2)


var _attacking_enemy := false
var _attack_free_t := 0.0

func _play_attack() -> void:
	if anim == null:
		return
	var style: String = KINDS[kind].style
	var an := "slash1"
	if style == "greatsword":
		# Босс чередует удары и спин-атаку (страшную и медленную)
		an = "gs_slash" if _rng.randf() < 0.6 else "gs_spin"
		if not anim.has_animation(an):
			an = "gs_slash"
	elif style == "magic":
		an = ["mg_cast", "mg_cast2", "mg_area"][_rng.randi() % 3]
	if not anim.has_animation(an):
		return
	_attacking_enemy = true
	_attack_free_t = 0.9
	anim.speed_scale = 1.5
	anim.play(an, 0.12)


# ---------- УРОН И СМЕРТЬ ----------

func take_damage(amount: int, from_pos: Vector3) -> void:
	if _dead or _iframes > 0.0:
		return
	_iframes = 0.35
	if kind == "dummy":
		var tw := create_tween()
		tw.tween_property(visual, "rotation:x", 0.22, 0.08)
		tw.tween_property(visual, "rotation:x", -0.12, 0.14)
		tw.tween_property(visual, "rotation:x", 0.05, 0.12)
		tw.tween_property(visual, "rotation:x", 0.0, 0.1)
		return
	hp -= amount
	for m in _mats:
		if m is StandardMaterial3D:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.25, 0.1)
			m.emission_energy_multiplier = 1.6
	var kb := global_position - from_pos
	kb.y = 0.0
	if kb.length() > 0.01:
		kb = kb.normalized() * 4.5
		velocity += Vector3(kb.x, 2.2, kb.z)
	if hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	var sh := get_node_or_null("Shape") as CollisionShape3D
	if sh != null:
		sh.disabled = true
	var death_anim := "death"
	if KINDS[kind].style == "greatsword":
		death_anim = "gs_death"
	if anim != null and anim.has_animation(death_anim):
		anim.speed_scale = 1.0
		anim.play(death_anim, 0.15)
	else:
		var tw := create_tween()
		tw.tween_property(visual, "rotation:x", -PI * 0.48, 0.5) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_burst()
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_kill"):
		pl.add_kill()
	get_tree().create_timer(2.5).timeout.connect(queue_free)


func _burst() -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 26
	p.lifetime = 0.7
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -10, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	# У призрака — бирюзовое dissolution, у рыцарей — пепел
	if kind == "ghost":
		m.albedo_color = Color(0.4, 0.9, 0.8, 0.9)
	else:
		m.albedo_color = Color(0.30, 0.27, 0.24, 0.9)
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.9 * KINDS.get(kind, {}).get("scale_col", 1.0), 0)
	add_child(p)


func _process(dt: float) -> void:
	if _attacking_enemy:
		_attack_free_t -= dt
		if _attack_free_t <= 0.0:
			_attacking_enemy = false
			_cur_loco = ""
	for m in _mats:
		if m is StandardMaterial3D and m.emission_energy_multiplier > 0.05:
			m.emission_energy_multiplier = maxf(0.0,
					m.emission_energy_multiplier - 2.2 * dt)
	# Пульс глазниц нежити (мерцают, как угли)
	for em in _eye_mats:
		em.emission_energy_multiplier = 2.6 + 0.7 * sin(_t * 5.3 + _float_phase) \
				if kind != "crimson" else 4.5 + 1.2 * sin(_t * 7.1 + _float_phase)
