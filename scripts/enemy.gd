extends CharacterBody3D
## v6.0 НЕЖИТЬ вместо слизней (Dark Fantasy):
##  - «zombie»     — зомби с гниющей плотью (Quaternius Zombie, CC0),
##                   бродит по долине и шамблит к игроку;
##  - «cave»       — скелеты-стражи (KayKit Skeletons, CC0): воин/плут/миньон,
##                   охраняют пещеру, подземелье и замок;
##  - «bone_lord»  — Костяной владыка, босс подземелья (крупный скелет-воин);
##  - «crypt_lord» — Хозяин крипты, босс замка (крупный скелет-маг);
##  - «dummy»      — соломенное чучело для тренировки.
## Логика ИИ (преследование, атака, урон, HP) сохранена из версии со
## слизнями, но движение плавное, с анимациями Idle/Walk/Run/Attack/Death.

const M_ZOMBIE := preload("res://assets/models/quat_Zombie.fbx")
const M_SKEL_WARRIOR := preload("res://assets/models/kay_Skeleton_Warrior.glb")
const M_SKEL_ROGUE := preload("res://assets/models/kay_Skeleton_Rogue.glb")
const M_SKEL_MINION := preload("res://assets/models/kay_Skeleton_Minion.glb")
const M_SKEL_MAGE := preload("res://assets/models/kay_Skeleton_Mage.glb")

const GRAV := 22.0

const KINDS := {
	"zombie": {"hp": 3, "dmg": 1, "walk": 2.15, "run": 3.7, "height": 1.72,
			"atk_cd": 1.2, "reach": 1.5, "scale_col": 1.0},
	"cave": {"hp": 6, "dmg": 1, "walk": 2.9, "run": 4.0, "height": 1.66,
			"atk_cd": 1.2, "reach": 1.6, "scale_col": 1.0},
	"bone_lord": {"hp": 12, "dmg": 2, "walk": 2.5, "run": 3.6, "height": 2.30,
			"atk_cd": 1.4, "reach": 1.9, "scale_col": 1.45},
	"crypt_lord": {"hp": 12, "dmg": 2, "walk": 2.5, "run": 3.6, "height": 2.35,
			"atk_cd": 1.4, "reach": 1.9, "scale_col": 1.45},
}

var kind := "zombie"
var hp := 3
var player

var _dmg := 1
var _walk_sp := 2.2
var _run_sp := 3.6
var _reach := 1.5

var _iframes := 0.0
var _atk_cd := 0.0
var _wander_t := 0.0
var _wander_dir := Vector3.ZERO
var _dead := false
var _was_on_floor := true
var _facing := 0.0
var _rng := RandomNumberGenerator.new()
var visual: Node3D
var model_root: Node3D
var anim: AnimationPlayer
var _mats: Array = []
var _eye_mats: Array = []

# Разрешённые анимации (FBX-тейки могут давать полные имена)
var a_idle := ""
var a_walk := ""
var a_run := ""
var a_attack := ""
var a_death := ""
var a_hurt := ""


func setup(p_kind: String, seed_v: int) -> void:
	kind = p_kind if KINDS.has(p_kind) else "zombie"
	_rng.seed = seed_v


func _ready() -> void:
	add_to_group("enemy")
	var col := CollisionShape3D.new()
	col.name = "Shape"
	var shape := CapsuleShape3D.new()
	var kc: Dictionary = KINDS.get(kind, {})
	if kind == "dummy":
		shape.radius = 0.30
		shape.height = 1.9
		col.shape = shape
		col.position.y = 0.95
		add_child(col)
	else:
		hp = kc.hp
		_dmg = kc.dmg
		_walk_sp = kc.walk
		_run_sp = kc.run
		_reach = kc.reach
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
		_build_undead(kc.height)


# ---------- ПОСТРОЕНИЕ НЕЖИТИ ----------

func _build_undead(target_height: float) -> void:
	var model: PackedScene
	if kind == "zombie":
		model = M_ZOMBIE
	elif kind == "bone_lord":
		model = M_SKEL_WARRIOR
	elif kind == "crypt_lord":
		model = M_SKEL_MAGE
	else:
		# пещерные стражи: воин / плут / миньон — по сиду, для разнообразия
		var variants := [M_SKEL_WARRIOR, M_SKEL_ROGUE, M_SKEL_MINION]
		model = variants[_rng.randi() % variants.size()]

	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	visual.add_child(model_root)
	var inst := model.instantiate()
	model_root.add_child(inst)
	# Модели смотрят вдоль +Z; looking_at направляет -Z — разворачиваем
	model_root.rotation.y = PI

	anim = inst.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim == null:
		anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer

	var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var s := 1.0
	var feet := 0.0
	if skel != null and skel.get_bone_count() > 4:
		var miny := 1e9
		var maxy := -1e9
		var inv: Transform3D = inst.global_transform.affine_inverse()
		for i in skel.get_bone_count():
			var bname := skel.get_bone_name(i)
			if "IK" in bname or "control" in bname:
				continue
			var gp: Vector3 = (inv * skel.global_transform
					* skel.get_bone_global_pose(i)).origin
			miny = minf(miny, gp.y)
			maxy = maxf(maxy, gp.y)
		var height := maxf(maxy - miny, 0.05)
		s = target_height / height
		feet = miny
	else:
		var box := _subtree_aabb(inst)
		s = target_height / maxf(box.size.y, 0.001)
		feet = box.position.y
	inst.scale = Vector3(s, s, s)
	inst.position = Vector3(0.0, -feet * s, 0.0)

	_style_materials()
	_resolve_anims()
	if anim != null and a_idle != "":
		anim.play(a_idle)


## PBR-материалы: гниющая плоть зомби / кости и красные глазницы скелетов.
func _style_materials() -> void:
	var is_boss := kind == "bone_lord" or kind == "crypt_lord"
	var eye_energy := 4.0 if is_boss else 2.2
	var eye_color := Color(1.0, 0.14, 0.06)
	var inst: Node3D = model_root.get_child(0)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m is StandardMaterial3D:
					var dup := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					var nm: String = (dup.resource_name if dup.resource_name != "" else "").to_lower()
					if kind == "zombie":
						# Гниющая плоть: бледно-землистая, шершавая
						dup.albedo_color = Color(0.30, 0.33, 0.22)
						dup.roughness = 0.92
						dup.metallic = 0.0
						_mats.append(dup)
					elif "glow" in nm or "eye" in nm:
						# Глазницы скелетов: тлеющие угли (не участвуют во вспышке урона)
						dup.albedo_color = Color(0.05, 0.01, 0.0)
						dup.emission_enabled = true
						dup.emission = eye_color
						dup.emission_energy_multiplier = eye_energy
						_eye_mats.append(dup)
					else:
						# Кость: тёмная слоновая кость, боссы — древняя кость
						if is_boss:
							dup.albedo_color = Color(0.52, 0.49, 0.40)
						else:
							dup.albedo_color = Color(0.72, 0.70, 0.60)
						dup.roughness = 0.8
						dup.metallic = 0.0
						_mats.append(dup)
					mesh.surface_set_material(i, dup)


## Имена анимаций: FBX-тейки могут называться «Zombie|ZombieWalk» или
## «HumanArmature|Idle» — ищем по приоритету, затем по подстроке.
func _resolve_anims() -> void:
	if anim == null:
		return
	var list := PackedStringArray(anim.get_animation_list())
	if kind == "zombie":
		a_idle = _pick(["ZombieIdle", "Idle"], list)
		a_walk = _pick(["ZombieWalk", "Walking_A"], list)
		a_run = _pick(["ZombieRun", "Running_A"], list)
		a_attack = _pick(["ZombieBite", "1H_Melee_Attack_Chop"], list)
		a_death = ""
		a_hurt = ""
	else:
		a_idle = _pick(["Idle", "Idle_Combat"], list)
		a_walk = _pick(["Walking_A", "Walking"], list)
		a_run = _pick(["Running_A", "Run"], list)
		a_attack = _pick(["1H_Melee_Attack_Chop", "swordAttack"], list)
		a_death = _pick(["Death_A", "Death"], list)
		a_hurt = _pick(["Hit_A", "Hit_B"], list)
	for a in [a_death, a_attack, a_hurt]:
		if a != "" and anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_NONE


static func _pick(candidates: Array, list: PackedStringArray) -> String:
	for c in candidates:
		if c in list:
			return c
	for c in candidates:
		for a in list:
			if c.to_lower() in a.to_lower():
				return a
	return ""


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
	# Старый шлем
	var helm := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.22
	km.height = 0.44
	km.radial_segments = 10
	km.rings = 7
	helm.mesh = km
	helm.material_override = _matc(Color(0.30, 0.30, 0.33), 0.5)
	helm.position.y = 2.22
	helm.scale = Vector3(1.05, 0.75, 1.05)
	visual.add_child(helm)

	var lbl := Label3D.new()
	lbl.text = "Манекен"
	lbl.font_size = 34
	lbl.pixel_size = 0.004
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.85, 0.8, 0.6)
	lbl.outline_size = 6
	lbl.position.y = 2.7
	add_child(lbl)


static func _subtree_aabb(root: Node3D) -> AABB:
	var box := AABB(Vector3.ZERO, Vector3.ZERO)
	var started := false
	for vi in root.find_children("*", "VisualInstance3D", true, false):
		var vis := vi as VisualInstance3D
		if vis == null or vis.get_aabb().size == Vector3.ZERO:
			continue
		var b := vis.get_aabb()
		b = vis.global_transform * b
		b = root.global_transform.affine_inverse() * b
		if not started:
			box = b
			started = true
		else:
			box = box.merge(b)
	if not started:
		box = AABB(Vector3(-0.35, 0, -0.35), Vector3(0.7, 1.7, 0.7))
	return box


# ---------- ИИ ----------

func _physics_process(dt: float) -> void:
	if _iframes > 0.0:
		_iframes -= dt
	if kind == "dummy" or _dead:
		return
	_atk_cd -= dt
	if not is_on_floor():
		velocity.y -= GRAV * dt
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player != null and not player.dead:
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0.0
		var dist := to_p.length()
		if dist < 12.0:
			_chase(dt, to_p, dist)
		else:
			_wander(dt)
	else:
		_wander(dt)
	move_and_slide()
	_was_on_floor = is_on_floor()


func _chase(dt: float, to_p: Vector3, dist: float) -> void:
	# Поворот к игроку
	if to_p.length() > 0.01:
		_face(atan2(to_p.x, to_p.z), 7.0 * dt)
	# Атака: урон по кулдаону (логика прежних слизней), анимация кусания/удара
	if dist < _reach:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
		if _atk_cd <= 0.0:
			player.take_damage(_dmg, global_position)
			_atk_cd = KINDS[kind].atk_cd
			_play_once(a_attack)
		elif not _attacking_enemy:
			_set_locomotion(0.0)
	else:
		# Плавное преследование: шагом вблизи, бегом издалека
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
	if _wander_dir != Vector3.ZERO and is_on_floor():
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
	var target := a_idle
	if speed > _walk_sp * 0.75 and a_run != "":
		target = a_run
	elif speed > 0.25:
		target = a_walk
	if target == "":
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

func _play_once(name: String) -> void:
	if anim == null or name == "" or not anim.has_animation(name):
		return
	_attacking_enemy = true
	_attack_free_t = 0.9
	# Демо-анимации длинные — убыстряем выпад
	anim.speed_scale = 1.6
	anim.play(name, 0.12)


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
	# Вспышка боли по материалам
	for m in _mats:
		if m is StandardMaterial3D:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.25, 0.1)
			m.emission_energy_multiplier = 1.6
	# Отскок от удара
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
	if anim != null and a_death != "" and anim.has_animation(a_death):
		# Скелеты складываются по анимации смерти
		anim.speed_scale = 1.0
		anim.play(a_death, 0.15)
	else:
		# Зомби валится навзничь
		var tw := create_tween()
		tw.tween_property(visual, "rotation:x", -PI * 0.48, 0.5) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_burst()
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_kill"):
		pl.add_kill()
	get_tree().create_timer(2.0).timeout.connect(queue_free)


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
	# Пепел и тёмная пыль вместо слизи
	m.albedo_color = Color(0.30, 0.27, 0.24, 0.9)
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.9 * KINDS.get(kind, {}).get("scale_col", 1.0), 0)
	add_child(p)


func _process(dt: float) -> void:
	# Завершение однократной анимации атаки -> возврат к локомоции
	if _attacking_enemy:
		_attack_free_t -= dt
		if _attack_free_t <= 0.0:
			_attacking_enemy = false
			_cur_loco = ""
	# Затухание вспышки урона
	for m in _mats:
		if m is StandardMaterial3D and m.emission_energy_multiplier > 0.05:
			m.emission_energy_multiplier = maxf(0.0,
					m.emission_energy_multiplier - 2.2 * dt)
