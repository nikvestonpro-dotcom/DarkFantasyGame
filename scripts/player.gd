extends CharacterBody3D
## Игрок v10.0 «Монах»: тёмный монах-крестоносец из пака (PSX low-poly,
## статичная модель — анимации ПРОЦЕДУРНЫЕ: покачивание, шаг, замах,
## падение). Меч — отдельная модель в правой руке. Камера на пружине,
## здоровье, смерть и возрождение.
##
## Движение читается ФИЗИЧЕСКИМИ клавишами (is_physical_key_pressed),
## поэтому WASD работает при любой раскладке, включая русскую.

signal died

const WALK_SPEED := 4.8
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 7.5
const GRAVITY := 20.0
const MAX_HP := 10.0
const ATTACK_TIME := 0.85

# v5.0: полёт — F включает/выключает, пробел вверх, C вниз
const FLY_SPEED := 13.0
const FLY_VERT := 7.5
const FLY_CEILING := 110.0

const MONK := preload("res://assets/models/chars/monk_player.glb")
const SWORD := preload("res://assets/models/chars/monk_sword.glb")

# Модель монаха уже экспортирована ростом 1.80 м, ноги на y=0
const MODEL_HEIGHT := 1.80

var hp := MAX_HP
var kills := 0
var dead := false

var _attacking := false
var _attack_cd := 0.0
var _attack_t := 0.0
var _attack_len := 1.0
var _hit_started := false
var _hit_window := false
var _iframes := 0.0
var _no_damage_t := 10.0
var _pitch := 0.14
var _hurt_t := 0.0
var _walk_phase := 0.0
var _t := 0.0
var _death_rot := 0.0
var flying := false
var _fly_key_cd := 0.0
var _fly_air_t := 0.0

var pitch_node: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var hitbox: Area3D
var visual_root: Node3D
var body_pivot: Node3D
var hand: Node3D
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


# ---------- ТЕЛО (монах, процедурная анимация) ----------

func _build_body() -> void:
        visual_root = Node3D.new()
        visual_root.name = "VisualRoot"
        add_child(visual_root)

        # body_pivot — узел для наклонов/падения (на высоте пояса)
        body_pivot = Node3D.new()
        body_pivot.name = "BodyPivot"
        body_pivot.position.y = 0.95
        visual_root.add_child(body_pivot)

        var monk := MONK.instantiate()
        # модель стоит ногами на 0 — смещаем внутрь pivot (пояс на 0.95)
        monk.position.y = -0.95
        body_pivot.add_child(monk)

        # материалы: копии для вспышки урона
        for mi in monk.find_children("*", "MeshInstance3D", true, false):
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

        # меч в правой руке (руки опущены, кисть ~ (0.44, 0.80, 0.05))
        hand = Node3D.new()
        hand.name = "Hand"
        hand.position = Vector3(0.40, -0.16, 0.10)
        body_pivot.add_child(hand)
        var sword := SWORD.instantiate()
        # меч вертикально, остриём вверх, чуть наклонён наружу
        sword.rotation.z = -0.18
        sword.position.y = -0.12
        hand.add_child(sword)
        for mi in sword.find_children("*", "MeshInstance3D", true, false):
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
                # Полёт: пробел — вверх, C — вниз, без гравитации.
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
                _proc_anim(dt, false)
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

        _proc_anim(dt, jumped)

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


# ---------- ПРОЦЕДУРНЫЕ АНИМАЦИИ ----------

func _proc_anim(dt: float, _jumped: bool) -> void:
        _t += dt
        var hspeed := Vector2(velocity.x, velocity.z).length()

        if dead:
                # Падение набок: быстрый крен с лёгким отскоком
                _death_rot = minf(_death_rot + dt * 3.4, 1.0)
                var fall := ease(_death_rot, -2.4)
                body_pivot.rotation.z = fall * 1.45
                body_pivot.rotation.x = fall * 0.10
                body_pivot.position.y = 0.95 - fall * 0.62
                hand.rotation.x = 0.0
                return

        # фаза шага от скорости
        _walk_phase += dt * clampf(hspeed * 1.55, 0.0, 13.0)

        var target_pitch := 0.0
        var target_roll := 0.0
        var target_yaw := 0.0
        var bob := 0.0
        var hand_x := 0.0
        var hand_y := 0.0

        if _attacking:
                _attack_t += dt
                if not _hit_started and _attack_t > _attack_len * 0.30:
                        _hit_started = true
                        _hit_window = true
                        hitbox.monitoring = true
                elif _hit_started and _attack_t > _attack_len * 0.62:
                        _hit_window = false
                        hitbox.monitoring = false
                var p := clampf(_attack_t / _attack_len, 0.0, 1.0)
                if p < 0.30:
                        # замах: корпус вправо-назад, меч поднят
                        var k := ease(p / 0.30, 1.6)
                        target_yaw = -0.55 * k
                        target_pitch = -0.06 * k
                        hand_x = -2.0 * k
                elif p < 0.58:
                        # удар: быстрый свайп вперёд-вниз
                        var k := ease((p - 0.30) / 0.28, 2.6)
                        target_yaw = -0.55 + 1.15 * k
                        target_pitch = 0.16 * k
                        hand_x = -2.0 + 3.1 * k
                        hand_y = 0.35 * sin(k * PI)
                else:
                        # возврат
                        var k := ease((p - 0.58) / 0.42, 1.8)
                        target_yaw = 0.60 * (1.0 - k)
                        target_pitch = 0.16 * (1.0 - k)
                        hand_x = 1.1 * (1.0 - k)
                if _attack_t >= _attack_len * 0.95:
                        _attacking = false
        elif _hurt_t > 0.0:
                # вздрогнул от урона
                var k := _hurt_t / 0.4
                target_pitch = -0.22 * k
                bob = -0.03 * k
        elif not is_on_floor() and not flying:
                # в воздухе: лёгкий наклон вперёд
                target_pitch = 0.08
        elif hspeed > 0.4:
                # шаг/бег: покачивание, наклон вперёд, крен
                var run_k := clampf(hspeed / SPRINT_SPEED, 0.0, 1.0)
                bob = absf(sin(_walk_phase)) * (0.035 + 0.045 * run_k)
                target_pitch = 0.07 + 0.10 * run_k
                target_roll = sin(_walk_phase) * (0.030 + 0.025 * run_k)
                target_yaw = sin(_walk_phase * 0.5) * 0.025
        else:
                # idle: дыхание и лёгкое покачивание
                bob = sin(_t * 2.1) * 0.011
                target_roll = sin(_t * 1.05) * 0.008
                hand_x = sin(_t * 2.1) * 0.06

        if not _attacking:
                hand_x += -0.12  # меч чуть отведён назад в покое
        # полёт: руки чуть в стороны не делаем — меч при себе
        body_pivot.rotation.x = lerpf(body_pivot.rotation.x, target_pitch, 10.0 * dt)
        body_pivot.rotation.z = lerpf(body_pivot.rotation.z, target_roll, 10.0 * dt)
        body_pivot.rotation.y = lerpf(body_pivot.rotation.y, target_yaw, 14.0 * dt)
        body_pivot.position.y = 0.95 + bob
        hand.rotation.x = lerpf(hand.rotation.x, hand_x, 16.0 * dt)
        hand.rotation.y = lerpf(hand.rotation.y, hand_y, 16.0 * dt)


# ---------- АТАКА ----------

func _try_attack() -> void:
        if _attacking or _attack_cd > 0.0 or dead:
                return
        _attacking = true
        _attack_cd = 0.72
        _attack_t = 0.0
        _attack_len = ATTACK_TIME
        _hit_started = false
        _hit_window = false


# ---------- УРОН И СМЕРТЬ ----------

func take_damage(amount: int, from_pos: Vector3) -> void:
        if dead or _iframes > 0.0:
                return
        _iframes = 0.7
        _no_damage_t = 0.0
        hp -= amount
        for m in _mats:
                m.emission_energy_multiplier = 1.2
        _hurt_t = 0.4
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
        _death_rot = 0.0


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
        _death_rot = 0.0
        body_pivot.rotation = Vector3.ZERO
        body_pivot.position.y = 0.95
