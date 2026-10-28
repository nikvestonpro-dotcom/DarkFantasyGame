extends CharacterBody3D
## Слизень (враг с ИИ): желейное тело с шейдером дрожания, внутреннее ядро,
## глаза, squash-and-stretch при прыжках. Урон наносит меч игрока.
## Манекен — соломенное чучело для тренировки.

const SlimeShader := preload("res://shaders/slime.gdshader")

const GRAV := 22.0

var kind := "slime"
var hp := 3
var player

var _iframes := 0.0
var _atk_cd := 0.0
var _hop_cd := 0.0
var _wander_t := 0.0
var _wander_dir := Vector3.ZERO
var _dead := false
var _was_on_floor := true
var _squash_t := 0.0
var _rng := RandomNumberGenerator.new()
var visual: Node3D
var _mat: ShaderMaterial
var _core_mat: StandardMaterial3D


func setup(p_kind: String, seed_v: int) -> void:
	kind = p_kind
	_rng.seed = seed_v


func _ready() -> void:
	add_to_group("enemy")
	var col := CollisionShape3D.new()
	col.name = "Shape"
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	col.position.y = 0.5
	add_child(col)
	visual = Node3D.new()
	visual.name = "Visual"
	visual.position.y = 0.5
	add_child(visual)
	if kind == "slime" or kind == "cave" or kind == "brute":
		_build_slime()
	else:
		_build_dummy()


func _matc(col: Color, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


func _build_slime() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SlimeShader
	var hue_shift := _rng.randf_range(-0.05, 0.08)
	if kind == "cave":
		# Пещерный слизень: фиолетовая желеобразная плоть
		hp = 6
		_mat.set_shader_parameter("jelly_color", Color(0.34, 0.16, 0.52, 0.88))
		_mat.set_shader_parameter("glow_color", Color(0.45, 0.2, 0.7))
	elif kind == "brute":
		# Матёрый слизень: босс подземелья, крупный и живучий
		hp = 12
		_mat.set_shader_parameter("jelly_color", Color(0.45, 0.10, 0.30, 0.9))
		_mat.set_shader_parameter("glow_color", Color(0.8, 0.15, 0.35))
	else:
		_mat.set_shader_parameter("jelly_color",
			Color(0.15 + hue_shift * 0.4, 0.44 + hue_shift, 0.20, 0.85))
		_mat.set_shader_parameter("glow_color",
			Color(0.10 + hue_shift * 0.3, 0.5 + hue_shift * 0.5, 0.18))

	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 10
	body.mesh = sm
	body.scale.y = 0.74
	body.material_override = _mat
	visual.add_child(body)
	# Крупные виды: масштаб тела и коллизии
	var k_scale := 1.0
	if kind == "cave":
		k_scale = 1.3
	elif kind == "brute":
		k_scale = 1.75
	if k_scale != 1.0:
		visual.scale = Vector3(k_scale, k_scale, k_scale)
		var sh := get_node_or_null("Shape") as CollisionShape3D
		if sh != null:
			sh.shape.radius = 0.5 * k_scale
			sh.position.y = 0.5 * k_scale
		visual.position.y = 0.5 * k_scale

	# Внутреннее ядро
	_core_mat = _matc(Color(0.05, 0.16, 0.07), 0.4)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(0.12, 0.45, 0.16)
	_core_mat.emission_energy_multiplier = 1.4
	var core := MeshInstance3D.new()
	var csm := SphereMesh.new()
	csm.radius = 0.20
	csm.height = 0.40
	csm.radial_segments = 12
	csm.rings = 8
	core.mesh = csm
	core.material_override = _core_mat
	core.position = Vector3(0, -0.05, 0.08)
	visual.add_child(core)

	# Пузырьки в желе
	for i in 4:
		var bub := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = _rng.randf_range(0.04, 0.08)
		bs.height = _rng.randf_range(0.08, 0.16)
		bs.radial_segments = 8
		bs.rings = 5
		bub.mesh = bs
		bub.material_override = _core_mat
		bub.position = Vector3(
			_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.15, 0.15),
			_rng.randf_range(-0.2, 0.2))
		visual.add_child(bub)

	# Глаза
	var eye_mat := _matc(Color(0.02, 0.02, 0.02), 0.3)
	for sx in [-0.16, 0.16]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.075
		em.height = 0.15
		em.radial_segments = 10
		em.rings = 6
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(sx, 0.14, -0.42)
		visual.add_child(eye)
		var glint := MeshInstance3D.new()
		var gm := SphereMesh.new()
		gm.radius = 0.02
		gm.height = 0.04
		gm.radial_segments = 6
		gm.rings = 4
		glint.mesh = gm
		glint.material_override = _matc(Color(0.9, 0.95, 1.0), 0.1)
		glint.position = Vector3(sx - 0.02, 0.17, -0.49)
		visual.add_child(glint)


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


func _physics_process(dt: float) -> void:
	if _iframes > 0.0:
		_iframes -= dt
	if kind == "dummy" or _dead:
		return
	_atk_cd -= dt
	_hop_cd -= dt
	if not is_on_floor():
		velocity.y -= GRAV * dt
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player != null and not player.dead:
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0.0
		var dist := to_p.length()
		if dist < 10.0:
			if dist > 0.01:
				visual.basis = Basis.looking_at(to_p.normalized(), Vector3.UP)
			if dist < 1.5 and _atk_cd <= 0.0:
				player.take_damage(2 if kind == "brute" else 1, global_position)
				_atk_cd = 1.4 if kind == "brute" else 1.2
			if is_on_floor() and _hop_cd <= 0.0:
				var hop := 3.6 if kind != "slime" else 3.0
				var hv := to_p.normalized() * hop
				velocity = Vector3(hv.x, 4.2, hv.z)
				_hop_cd = 0.85
				_stretch()
		else:
			_wander(dt)
	else:
		_wander(dt)
	move_and_slide()
	# Squash при приземлении
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_squash()
	_was_on_floor = on_floor
	# Плавный возврат масштаба
	if _squash_t > 0.0:
		_squash_t = maxf(0.0, _squash_t - dt * 4.0)
		visual.scale = visual.scale.lerp(Vector3.ONE, dt * 8.0)


func _stretch() -> void:
	visual.scale = Vector3(0.82, 1.28, 0.82)
	_squash_t = 0.3


func _squash() -> void:
	visual.scale = Vector3(1.25, 0.62, 1.25)
	_squash_t = 0.3


func _wander(dt: float) -> void:
	_wander_t -= dt
	if _wander_t <= 0.0:
		_wander_t = _rng.randf_range(1.5, 3.5)
		if _rng.randf() < 0.6:
			var a := _rng.randf() * TAU
			_wander_dir = Vector3(cos(a), 0, sin(a))
		else:
			_wander_dir = Vector3.ZERO
	if _wander_dir != Vector3.ZERO and is_on_floor() and _hop_cd <= 0.0:
		velocity = Vector3(_wander_dir.x * 2.0, 3.6, _wander_dir.z * 2.0)
		_hop_cd = 0.7
		_stretch()


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
	var kb := global_position - from_pos
	kb.y = 0.0
	if kb.length() > 0.01:
		kb = kb.normalized() * 4.5
		velocity += Vector3(kb.x, 2.5, kb.z)
	if _mat != null:
		_mat.set_shader_parameter("jelly_color", Color(0.7, 0.3, 0.2, 0.85))
	if _core_mat != null:
		_core_mat.emission = Color(1.0, 0.4, 0.3)
		_core_mat.emission_energy_multiplier = 2.5
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
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.5, 0.08, 1.5), 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_burst()
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_kill"):
		pl.add_kill()
	get_tree().create_timer(1.2).timeout.connect(queue_free)


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
	m.albedo_color = Color(0.3, 0.7, 0.35, 0.9)
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.6, 0)
	add_child(p)
