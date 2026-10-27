extends CharacterBody3D
## Игрок Hollow Moon: ходьба / бег / прыжок + режим полёта, камера 3-го/1-го лица.
## WASD — движение (физическая раскладка, работает и на русской);
## Мышь — камера; Shift — бег (в полёте — ускорение); Space — прыжок
## (в полёте — вверх); C — вниз в полёте; F — полёт вкл/выкл;
## V — вид от 1-го/3-го лица; ESC — показать курсор.

const WALK_SPEED := 4.0
const RUN_SPEED := 7.0
const FLY_SPEED := 12.0
const FLY_FAST_SPEED := 22.0
const JUMP_VELOCITY := 4.6
const GRAVITY := 12.0
const MOUSE_SENS := 0.003
const PITCH_MIN := -1.35
const PITCH_MAX := 1.35

var flying := false
var first_person := false
var _pitch := -0.2

@onready var pivot: Node3D = $CameraPivot
@onready var spring: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $KayKnight
var anim: AnimationPlayer = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring.add_excluded_object(get_rid())
	anim = _find_animation_player()
	if anim != null:
		anim.play("Idle")


func _find_animation_player() -> AnimationPlayer:
	var stack: Array = [$KayKnight]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer:
			return node
		stack.append_array(node.get_children())
	return null


func _axis(positive: Key, negative: Key) -> float:
	return (1.0 if Input.is_physical_key_pressed(positive) else 0.0) \
		- (1.0 if Input.is_physical_key_pressed(negative) else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
		spring.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F:
				flying = not flying
				velocity.y = 0.0
			KEY_V:
				first_person = not first_person
				_apply_camera_mode()


func _apply_camera_mode() -> void:
	if first_person:
		spring.spring_length = 0.05
		model.visible = false
	else:
		spring.spring_length = 3.2
		model.visible = true


func _physics_process(delta: float) -> void:
	var flat_fwd := -pivot.global_transform.basis.z
	flat_fwd.y = 0.0
	flat_fwd = flat_fwd.normalized() if flat_fwd.length() > 0.01 else Vector3.ZERO
	var flat_right := pivot.global_transform.basis.x
	flat_right.y = 0.0
	flat_right = flat_right.normalized() if flat_right.length() > 0.01 else Vector3.ZERO

	var k_run := Input.is_physical_key_pressed(KEY_SHIFT)
	var k_up := Input.is_physical_key_pressed(KEY_SPACE)
	var k_down := Input.is_physical_key_pressed(KEY_C)

	if flying:
		# Полёт: движение вдоль полного базиса камеры (включая наклон), как в spectator.
		var cam_basis := spring.global_transform.basis
		var dir3 := -cam_basis.z * _axis(KEY_W, KEY_S) + cam_basis.x * _axis(KEY_D, KEY_A)
		dir3.y += (1.0 if k_up else 0.0) - (1.0 if k_down else 0.0)
		if dir3.length() > 0.01:
			dir3 = dir3.normalized()
		var fly_speed := FLY_FAST_SPEED if k_run else FLY_SPEED
		velocity = velocity.lerp(dir3 * fly_speed, 10.0 * delta)
		# Лёгкий наклон тела по вертикальной скорости — "парение".
		model.rotation.x = lerpf(model.rotation.x, clampf(-velocity.y * 0.04, -0.45, 0.45), 6.0 * delta)
	else:
		var move := flat_fwd * _axis(KEY_W, KEY_S) + flat_right * _axis(KEY_D, KEY_A)
		if move.length() > 0.01:
			move = move.normalized()
		var speed := RUN_SPEED if k_run else WALK_SPEED
		velocity.x = lerpf(velocity.x, move.x * speed, 12.0 * delta)
		velocity.z = lerpf(velocity.z, move.z * speed, 12.0 * delta)
		if is_on_floor() and k_up:
			velocity.y = JUMP_VELOCITY
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		model.rotation.x = lerpf(model.rotation.x, 0.0, 6.0 * delta)

	move_and_slide()
	_face_movement(delta)
	_update_animation()


func _face_movement(delta: float) -> void:
	var h := Vector2(velocity.x, velocity.z)
	if h.length() > 0.6:
		var target := atan2(velocity.x, velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, 8.0 * delta)


func _update_animation() -> void:
	if anim == null:
		return
	var target := "Idle"
	var h := Vector2(velocity.x, velocity.z).length()
	if flying:
		target = "Idle"
	elif not is_on_floor():
		target = "Jump_Idle"
	elif h > 5.4:
		target = "Running_A"
	elif h > 0.4:
		target = "Walking_A"
	if anim.current_animation != target:
		anim.play(target)
