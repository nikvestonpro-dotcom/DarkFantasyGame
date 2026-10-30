extends CharacterBody3D
## Игрок v10.1 «Охотник»: PSX-модель DEAD OATH HUNTER (скелет Mixamo,
## меч в правой руке — часть модели, держится ПРАВИЛЬНО). Анимации —
## полноценные: срезы демо-таймлайна «Todo» (стойка, бег, прыжок, удар,
## смерть) + ходьба, перетаргетченная со скелета KayKit.
## Игровая логика сохранена: камера на пружине, здоровье, полёт (F),
## удар с окном хитбокса, возрождение.
##
## Движение читается ФИЗИЧЕСКИМИ клавишами (is_physical_key_pressed),
## поэтому WASD работает при любой раскладке, включая русскую.

signal died

const WALK_SPEED := 4.8
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 7.5
const GRAVITY := 20.0
const MAX_HP := 10.0

# v5.0: полёт — F включает/выключает, пробел вверх, C вниз
const FLY_SPEED := 13.0
const FLY_VERT := 7.5
const FLY_CEILING := 110.0

const HUNTER := preload("res://мобы/DEAD OATH HUNTER  PSX Bounty Hunter Character/DEAD OATH HUNTER.fbx")
const SLICES := preload("res://assets/anims/hunter_slices.tres")
const RETARG := preload("res://assets/anims/hunter_retarg.tres")

# Анимации (библиотеки s/ и r/ регистрируются в _ready)
const A_IDLE := "s/idle"
const A_WALK := "r/walk"
const A_RUN := "s/run"
const A_ATTACK := "s/attack"
const A_ATTACK2 := "s/attack2"
const A_JUMP := "s/jump"
const A_HIT := "s/hit"
const A_DEATH := "s/death"

const ATTACK_SPEED := 2.6     # клип 4.0 с -> ~1.54 с на замах
const ATTACK_HIT_START := 0.48  # доля клипа: меч проносится (Todo 13.0-13.5)
const ATTACK_HIT_END := 0.64
const DEATH_SPEED := 1.4

# рост меша ~1.49 м, хотим ~1.85 м
const MODEL_SCALE := 1.85 / 1.49
# модель в скелет-пространстве смотрит в -X; поворачиваем лицом в -Z
const MODEL_YAW := -PI / 2.0

var hp := MAX_HP
var kills := 0
var dead := false

var _attacking := false
var _attack_combo := false
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
var flying := false
var _fly_key_cd := 0.0
var _fly_air_t := 0.0

var pitch_node: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var hitbox: Area3D
var visual_root: Node3D
var anim: AnimationPlayer
var _mats: Array = []


func _ready() -> void:
	add_to_group("player")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.55
	col.shape = cap
	col.position.y = 0.80
	add_child(col)
	_build_body()
	_build_camera()
	_build_hitbox()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- ТЕЛО (охотник со скелетом и анимациями) ----------

func _build_body() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	var hunter := HUNTER.instantiate()
	hunter.scale = Vector3(MODEL_SCALE, MODEL_SCALE, MODEL_SCALE)
	hunter.rotation.y = MODEL_YAW
	# AABB меша: y от -1.56 до -0.07 (в локальных единицах ~1.49 роста);
	# поднимаем так, чтобы ступни встали на 0
	hunter.position.y = 1.560223 * MODEL_SCALE + 0.06
	visual_root.add_child(hunter)

	# материалы: копии для вспышки урона
	for mi in hunter.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m is StandardMaterial3D:
					var dup := m.duplicate() as StandardMaterial3D
					dup.emission_enabled = true
					dup.emission = Color(1.0, 0.1, 0.05)
					dup.emission_energy_multiplier = 0.0
					mesh.surface_set_material(i, dup)
					_mats.append(dup)

	# анимации: срезы + ретаргет
	anim = hunter.find_child("AnimationPlayer", true, false) as AnimationPlayer
	anim.playback_default_blend_time = 0.18
	anim.add_animation_library("s", SLICES)
	anim.add_animation_library("r", RETARG)
	anim.get_animation(A_DEATH).loop_mode = Animation.LOOP_NONE
	anim.get_animation(A_ATTACK).loop_mode = Animation.LOOP_NONE
	anim.get_animation(A_JUMP).loop_mode = Animation.LOOP_NONE
	anim.get_animation(A_HIT).loop_mode = Animation.LOOP_NONE
	anim.play(A_IDLE)


# ---------- КАМЕРА ----------

func _build_camera() -> void:
	pitch_node = Node3D.new()
	pitch_node.name = "Pitch"
	pitch_node.position.y = 1.34
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
	# v9.0: 4000 — небесный купол на 2500 м должен попадать в кадр
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
	sh.radius = 1.35
	col.shape = sh
	hitbox.add_child(col)
	hitbox.position = Vector3(0, 0.9, -0.85)
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
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
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
	if flying:
		var fy := 0.0
		if Input.is_physical_key_pressed(KEY_SPACE):
			fy += 1.0
		if Input.is_physical_key_pressed(KEY_C):
			fy -= 1.0
		velocity.y = move_toward(velocity.y, fy * FLY_VERT, 26.0 * dt)
		# Мягкий потолок под невидимыми стенами карты
		if global_position.y > FLY_CEILING:
			velocity.y = minf(velocity.y, -2.0)
		# Автопосадка: мягко коснулись земли после полёта
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
	if not flying and Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jumped = true
	move_and_slide()

	_update_anim(dt, jumped)

	if _hit_window and hitbox.monitoring:
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("enemy"):
				body.take_damage(1, global_position)
	for m in _mats:
		if m.emission_energy_multiplier > 0.01:
			m.emission_energy_multiplier = maxf(0.0,
					m.emission_energy_multiplier - 2.5 * dt)
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
	elif flying:
		if hspeed > 4.0:
			_play(A_RUN, 0.9)
		else:
			_play(A_IDLE, 1.0)
	elif hspeed > WALK_SPEED + 0.8:
		# бег: темп анимации по фактической скорости
		_play(A_RUN, clampf(hspeed / SPRINT_SPEED, 0.8, 1.35))
	elif hspeed > 0.3:
		_play(A_WALK, clampf(hspeed / WALK_SPEED, 0.8, 1.3))
	else:
		_play(A_IDLE, 1.0)


# ---------- АТАКА ----------

func _try_attack() -> void:
	if _attacking or _attack_cd > 0.0 or dead or flying:
		return
	_attacking = true
	_attack_cd = 1.15
	_attack_t = 0.0
	# комбо: обычный удар -> тяжёлый замах (каждый второй клик)
	var clip := A_ATTACK2 if _attack_combo else A_ATTACK
	_attack_combo = not _attack_combo
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
	hp -= amount
	for m in _mats:
		m.emission_energy_multiplier = 1.2
	_hurt_t = 0.45
	var kb := global_position - from_pos
	kb.y = 0.0
	if kb.length() > 0.01:
		kb = kb.normalized() * 4.0
		velocity += Vector3(kb.x, 2.0, kb.z)
	if hp <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	died.emit()
	_attacking = false
	_hit_window = false
	hitbox.monitoring = false
	_cur_anim = A_DEATH
	anim.speed_scale = DEATH_SPEED
	anim.stop()
	anim.play(A_DEATH, 0.15)


func add_kill() -> void:
	kills += 1


## v5.0: включение/выключение полёта (клавиша F и тесты).
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
