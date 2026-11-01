extends CharacterBody3D
## Игрок v11 «Рыцарь»: модель Knight D Pelegrini (полный доспех, капюшон,
## рост ~2 м — НЕ путать с жителями). Меч — демонический двуручник из
## пака «demonic weapons», прикреплён к кисти (кулак смотрит правильно).
## Анимации — родные клипы Mixamo из пака «Great Sword Pack», запечённые
## под скелет рыцаря (tools/bake_mixamo_anims.gd): стойка, ходьба, бег,
## прыжок, три удара (рубящий, тяжёлый, вихрь), блок, урон, смерть.
## НОВОЕ v11: блок на ПКМ — урон снижен, скорость ниже.
## Логика сохранена: камера на пружине, здоровье, полёт (F), комбо ударов,
## окно хитбокса, возрождение. Рост калибруется по КОСТЯМ (не по AABB
## мешей — в v10.1 из-за меча в AABB герой висел над землёй).
##
## Движение читается ФИЗИЧЕСКИМИ клавишами (is_physical_key_pressed),
## поэтому WASD работает при любой раскладке, включая русскую.

signal died

const WALK_SPEED := 4.8
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 7.5
const GRAVITY := 20.0
const MAX_HP := 10.0

# полёт — F включает/выключает, пробел вверх, C вниз
const FLY_SPEED := 13.0
const FLY_VERT := 7.5
const FLY_CEILING := 110.0

const KNIGHT := preload("res://assets/Анимация и персонажи/Knight D Pelegrini.fbx")
const ANIMS := preload("res://assets/anims/v11_knight_anims.tres")
const SWORD := preload("res://assets/models/packs/demonic weapons pack/demonic weapons pack/greatsword/demonicgreatswordgodot.glb")

# анимации (библиотека v/ добавляется в _ready)
const A_IDLE := "v/idle"
const A_WALK := "v/walk"
const A_RUN := "v/run"
const A_JUMP := "v/jump"
const A_ATTACK1 := "v/attack1"
const A_ATTACK2 := "v/attack2"
const A_ATTACK3 := "v/attack3"
const A_HIT := "v/hit"
const A_DEATH := "v/death"
const A_BLOCK := "v/block"

const ATTACK_SPEED := 1.55    # клипы 1.27/1.20/1.87 с -> 0.82/0.77/1.21 с
const ATTACK_HIT_START := 0.34  # доля клипа: клинок проносится
const ATTACK_HIT_END := 0.62
const DEATH_SPEED := 1.1
const BLOCK_DAMAGE_MULT := 0.25   # при блоке урон режется на 75%
const BLOCK_SPEED_MULT := 0.42    # при блоке движение почти стопорится

## рост героя: рыцарь крупный, заметно выше жителей (~1.65-1.75)
const HERO_HEIGHT := 2.02
## модели Mixamo смотрят в +Z; игрок движется вперёд в -Z -> разворот
const MODEL_YAW := PI

var hp := MAX_HP
var kills := 0
var dead := false

var _attacking := false
var _attack_stage := 0        # 0,1,2: обычный, тяжёлый, вихрь (по клику)
var _attack_cd := 0.0
var _attack_t := 0.0
var _attack_len := 1.0
var _hit_started := false
var _hit_window := false
var _iframes := 0.0
var _no_damage_t := 10.0
var _pitch := 0.14
var _hurt_t := 0.0
var _cur_anim := ""
var _blocking := false
var flying := false
var _fly_key_cd := 0.0
var _fly_air_t := 0.0
var _sword_mats: Array = []

var pitch_node: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var hitbox: Area3D
var visual_root: Node3D
var anim: AnimationPlayer


func _ready() -> void:
	add_to_group("player")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.87
	add_child(col)
	_build_body()
	_build_camera()
	_build_hitbox()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- ТЕЛО: рыцарь + демонический двуручник ----------

func _build_body() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	var knight := KNIGHT.instantiate()
	visual_root.add_child(knight)
	# калибровка по костям: ступни ровно на земле, рост 2.02 м
	CharRig.calibrate(knight, HERO_HEIGHT, MODEL_YAW)

	# демонический двуручник в правую кисть
	var sword: Node3D = SWORD.instantiate()
	sword.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	CharRig.attach_to_bone(knight, "mixamorig_RightHand", sword)
	# материалы меча: копии для вспышки урона
	for mi_n in sword.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_n as MeshInstance3D
		if mi.mesh is ArrayMesh:
			var am := mi.mesh as ArrayMesh
			for i in am.get_surface_count():
				var m := am.surface_get_material(i)
				if m is StandardMaterial3D:
					var dup := (m as StandardMaterial3D).duplicate()
					mi.set_surface_override_material(i, dup)
					_sword_mats.append(dup)
	# красноватое свечение клинка в темноте
	for m in _sword_mats:
		var sm := m as StandardMaterial3D
		sm.emission_enabled = true
		sm.emission = Color(0.55, 0.08, 0.06)
		sm.emission_energy_multiplier = 0.35

	# анимации: запечённая библиотека Mixamo
	anim = CharRig.find_ap(knight)
	anim.playback_default_blend_time = 0.18
	anim.add_animation_library("v", ANIMS)
	for a in [A_DEATH, A_ATTACK1, A_ATTACK2, A_ATTACK3, A_JUMP, A_HIT]:
		anim.get_animation(a).loop_mode = Animation.LOOP_NONE
	anim.play(A_IDLE)


# ---------- КАМЕРА ----------

func _build_camera() -> void:
	pitch_node = Node3D.new()
	pitch_node.name = "Pitch"
	pitch_node.position.y = 1.46
	pitch_node.rotation.x = _pitch
	add_child(pitch_node)
	spring_arm = SpringArm3D.new()
	spring_arm.name = "CameraArm"
	spring_arm.spring_length = 5.6
	spring_arm.margin = 0.4
	spring_arm.collision_mask = 1
	spring_arm.position = Vector3(0, 0.42, 0.25)
	spring_arm.add_excluded_object(get_rid())
	pitch_node.add_child(spring_arm)
	camera = Camera3D.new()
	camera.fov = 72.0
	# небесный купол на 2500 м должен попадать в кадр
	camera.far = 4000.0
	camera.position = Vector3.ZERO
	spring_arm.add_child(camera)
	camera.current = true


# ---------- ХИТБОКС УДАРА ----------

func _build_hitbox() -> void:
	hitbox = Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	hitbox.monitoring = false
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.45
	col.shape = sh
	hitbox.add_child(col)
	hitbox.position = Vector3(0, 1.0, -0.95)
	add_child(hitbox)


# ---------- ВВОД ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0028)
		_pitch = clampf(_pitch - event.relative.y * 0.0022, -1.05, 0.5)
		pitch_node.rotation.x = _pitch
	elif event is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_try_attack()


# ---------- ФИЗИКА ----------

func _physics_process(dt: float) -> void:
	if _attack_cd > 0.0:
		_attack_cd -= dt
	if _fly_key_cd > 0.0:
		_fly_key_cd -= dt
	if Input.is_physical_key_pressed(KEY_F) and _fly_key_cd <= 0.0:
		toggle_flight()
	if _iframes > 0.0:
		_iframes -= dt
	if _hurt_t > 0.0:
		_hurt_t -= dt
	_no_damage_t += dt
	if _no_damage_t > 5.0 and hp < MAX_HP and not dead:
		hp = minf(hp + 0.3 * dt, MAX_HP)
	# v11: блок — удержание ПКМ
	var want_block := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
			and not flying and not dead and not _attacking
	if want_block != _blocking:
		_blocking = want_block
	if flying:
		var fy := 0.0
		if Input.is_physical_key_pressed(KEY_SPACE):
			fy += 1.0
		if Input.is_physical_key_pressed(KEY_C):
			fy -= 1.0
		velocity.y = move_toward(velocity.y, fy * FLY_VERT, 26.0 * dt)
		if global_position.y > FLY_CEILING:
			velocity.y = minf(velocity.y, -2.0)
		if not is_on_floor():
			_fly_air_t += dt
		elif fy <= 0.0 and velocity.y <= 0.1 and _fly_air_t > 0.4:
			flying = false
			_fly_air_t = 0.0
	elif not is_on_floor():
		velocity.y -= GRAVITY * dt
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
		move_and_slide()
		return

	# ФИЗИЧЕСКИЕ клавиши: работают при любой раскладке (русская тоже)
	var ix := 0.0
	var iz := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		iz -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		iz += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		ix -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		ix += 1.0
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := SPRINT_SPEED if sprint else WALK_SPEED
	if _blocking:
		speed *= BLOCK_SPEED_MULT
	if flying:
		speed = FLY_SPEED if sprint else FLY_SPEED * 0.72
	var dir := Vector3(ix, 0, iz)
	if dir.length_squared() > 0.0:
		dir = (transform.basis * dir.normalized()) * speed
	else:
		dir = Vector3.ZERO
	velocity.x = dir.x
	velocity.z = dir.z
	var jumped := false
	if not flying and Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor() \
			and not _blocking:
		velocity.y = JUMP_VELOCITY
		jumped = true
	move_and_slide()

	_update_anim(dt, jumped)

	if _hit_window and hitbox.monitoring:
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("enemy"):
				body.take_damage(1, global_position)
	# пульс демонического клинка
	for m in _sword_mats:
		(m as StandardMaterial3D).emission_energy_multiplier = \
				0.3 + 0.12 * sin(Time.get_ticks_msec() * 0.0021)
	if global_position.y < -30.0:
		hp = 0.0
		_die()


# ---------- АНИМАЦИИ ----------

func _play(name: String, speed := 1.0) -> void:
	if anim == null:
		return
	if _cur_anim == name and anim.is_playing():
		anim.speed_scale = speed
		return
	_cur_anim = name
	anim.speed_scale = speed
	anim.play(name, 0.18)


func _update_anim(dt: float, _jumped: bool) -> void:
	if _attacking:
		_attack_t += dt * ATTACK_SPEED
		var p := clampf(_attack_t / _attack_len, 0.0, 1.0)
		if not _hit_started and p > ATTACK_HIT_START:
			_hit_started = true
			_hit_window = true
			hitbox.monitoring = true
		elif _hit_started and p > ATTACK_HIT_END:
			_hit_window = false
			hitbox.monitoring = false
		if _attack_t >= _attack_len:
			_attacking = false
			_hit_window = false
			hitbox.monitoring = false
		return

	if dead:
		return

	var hspeed := Vector2(velocity.x, velocity.z).length()

	if _hurt_t > 0.0:
		_play(A_HIT, 1.6)
	elif not is_on_floor() and not flying:
		_play(A_JUMP, 1.0)
	elif _blocking:
		_play(A_BLOCK, 1.0)
	elif flying:
		if hspeed > 4.0:
			_play(A_RUN, 0.9)
		else:
			_play(A_IDLE, 1.0)
	elif hspeed > WALK_SPEED + 0.8:
		# бег: темп анимации по фактической скорости
		_play(A_RUN, clampf(hspeed / SPRINT_SPEED, 0.85, 1.4))
	elif hspeed > 0.3:
		_play(A_WALK, clampf(hspeed / WALK_SPEED, 0.85, 1.35))
	else:
		_play(A_IDLE, 1.0)


# ---------- АТАКА ----------

func _try_attack() -> void:
	if _attacking or _attack_cd > 0.0 or dead or flying or _blocking:
		return
	_attacking = true
	_attack_cd = 0.95
	_attack_t = 0.0
	# серия: рубящий -> тяжёлый замах -> вихрь (каждый третий)
	var clip := A_ATTACK1
	if _attack_stage == 1:
		clip = A_ATTACK2
	elif _attack_stage == 2:
		clip = A_ATTACK3
	_attack_stage = (_attack_stage + 1) % 3
	_attack_len = anim.get_animation(clip).length / ATTACK_SPEED
	_hit_started = false
	_hit_window = false
	# удар: без плавного бленда — сразу с начала клипа
	_cur_anim = clip
	anim.speed_scale = ATTACK_SPEED
	anim.stop()
	anim.play(clip, 0.08)


# ---------- УРОН И СМЕРТЬ ----------

func take_damage(amount: int, from_pos: Vector3) -> void:
	if dead or _iframes > 0.0:
		return
	_iframes = 0.7
	_no_damage_t = 0.0
	# v11: блок режет урон на 75%
	if _blocking:
		amount = maxi(1, int(round(amount * BLOCK_DAMAGE_MULT)))
	hp -= amount
	_hurt_t = 0.45
	var kb := global_position - from_pos
	kb.y = 0.0
	if kb.length() > 0.01:
		kb = kb.normalized() * (1.2 if _blocking else 4.0)
		velocity += Vector3(kb.x, 2.0, kb.z)
	if hp <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	died.emit()
	_attacking = false
	_blocking = false
	_hit_window = false
	hitbox.monitoring = false
	_cur_anim = A_DEATH
	anim.speed_scale = DEATH_SPEED
	anim.stop()
	anim.play(A_DEATH, 0.15)


func add_kill() -> void:
	kills += 1


## полёт: включение/выключение (клавиша F и тесты)
func toggle_flight() -> void:
	_fly_key_cd = 0.3
	flying = not flying
	_fly_air_t = 0.0
	if flying:
		velocity.y = maxf(velocity.y, 1.5)


func respawn() -> void:
	hp = MAX_HP
	dead = false
	_iframes = 2.0
	velocity = Vector3.ZERO
	global_position = GameWorld.PLAYER_SPAWN
	_cur_anim = A_IDLE
	anim.speed_scale = 1.0
	anim.stop()
	anim.play(A_IDLE, 0.1)
