extends CharacterBody3D
## Игрок от третьего лица: рыцарь из набора KayKit Adventurers (CC0,
## анимации Idle/Run/Attack/Death/Jump встроены в модель), камера на
## пружине, здоровье, смерть и возрождение.
##
## Движение читается ФИЗИЧЕСКИМИ клавишами (is_physical_key_pressed),
## поэтому WASD работает при любой раскладке, включая русскую.

signal died

const WALK_SPEED := 4.8
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 7.5
const GRAVITY := 20.0
const MAX_HP := 10.0
const ATTACK_TIME := 0.85  # длительность удара в игре (анимация ускорения)

# v5.0: полёт — F включает/выключает, пробел вверх, C вниз
const FLY_SPEED := 13.0
const FLY_VERT := 7.5
const FLY_CEILING := 110.0

const KNIGHT := preload("res://assets/models/kay_Knight.glb")

# Рост рыцаря в метрах (модель KayKit подгоняется к нему).
# v4.0: уменьшен с 1.85 до 1.50 — рыцарь не должен быть больше жителей
# и смотреться великаном на фоне домов.
const MODEL_HEIGHT := 1.50
# Модель KayKit смотрит вдоль +Z, а «вперёд» в Godot — это -Z
const FACING_FIX := PI

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
var _cur_anim := ""
var _hurt_t := 0.0
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
        cap.height = 1.30
        col.shape = cap
        col.position.y = 0.68
        add_child(col)
        _build_body()
        _build_camera()
        _build_hitbox()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- ТЕЛО (рыцарь KayKit) ----------

func _build_body() -> void:
        visual_root = Node3D.new()
        visual_root.name = "VisualRoot"
        add_child(visual_root)

        var knight := KNIGHT.instantiate()
        # Скрываем варианты оружия/щитов: рыцарь берёт одноручный меч
        for wname in ["1H_Sword_Offhand", "2H_Sword", "Badge_Shield",
                        "Rectangle_Shield", "Round_Shield", "Spike_Shield"]:
                for node in knight.find_children("*", "Node", true, false):
                        if node.name == wname and node is Node3D:
                                node.visible = false
        # Анимации: смерть не должна зацикливаться
        anim = knight.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
        if anim != null:
                anim.playback_default_blend_time = 0.15
                for a in ["Death_A", "Death_B", "Hit_A", "Hit_B",
                                "1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal",
                                "Jump_Full_Short", "Jump_Idle", "PickUp", "Use_Item"]:
                        if anim.has_animation(a):
                                anim.get_animation(a).loop_mode = Animation.LOOP_NONE

        # Подгоняем рост и ставим на землю. У скелетных мешей AABB пуст,
        # поэтому меряем по костям (bind-поза = стойка с руками в стороны).
        add_child(knight)
        knight.rotation.y = FACING_FIX
        var skel := knight.find_child("Skeleton3D", true, false) as Skeleton3D
        var s := 1.0
        var feet := 0.0
        if skel != null and skel.get_bone_count() > 4:
                var miny := 1e9
                var maxy := -1e9
                var inv: Transform3D = knight.global_transform.affine_inverse()
                for i in skel.get_bone_count():
                        var gp: Vector3 = (inv * skel.global_transform
                                * skel.get_bone_global_pose(i)).origin
                        if "IK" in skel.get_bone_name(i) or "control" in skel.get_bone_name(i):
                                continue
                        miny = minf(miny, gp.y)
                        maxy = maxf(maxy, gp.y)
                var height := maxf(maxy - miny, 0.05)
                s = MODEL_HEIGHT / height
                feet = miny
        else:
                var box := _subtree_aabb(knight)
                s = MODEL_HEIGHT / maxf(box.size.y, 0.001)
                feet = box.position.y
        knight.scale = Vector3(s, s, s)
        knight.position = Vector3(0.0, -feet * s, 0.0)

        # Собираем материалы для вспышки урона (копии — модель только наша)
        for mi in knight.find_children("*", "MeshInstance3D", true, false):
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

        if anim != null and anim.has_animation("Idle"):
                anim.play("Idle")


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
                box = AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 1.8, 0.8))
        return box


# ---------- КАМЕРА ----------

func _build_camera() -> void:
        pitch_node = Node3D.new()
        pitch_node.name = "Pitch"
        pitch_node.position.y = 1.22
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
        # (при far=700 небо обрезалось и игрок не видел луну со звёздами)
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
        sh.radius = 1.2
        col.shape = sh
        hitbox.add_child(col)
        hitbox.position = Vector3(0, 0.85, -0.85)
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

func _set_anim(name: String, blend := 0.2) -> void:
        if anim == null or not anim.has_animation(name):
                return
        if _cur_anim == name and anim.is_playing():
                return
        _cur_anim = name
        anim.play(name, blend)


func _update_anim(_dt: float, _jumped: bool) -> void:
        if anim == null:
                return
        if dead:
                return
        if _attacking:
                _attack_t += _dt
                if not _hit_started and _attack_t > _attack_len * 0.30:
                        _hit_started = true
                        _hit_window = true
                        hitbox.monitoring = true
                elif _hit_started and _attack_t > _attack_len * 0.62:
                        _hit_window = false
                        hitbox.monitoring = false
                if _attack_t >= _attack_len * 0.95:
                        _attacking = false
                        _cur_anim = ""
                return
        if _hurt_t > 0.0:
                return
        if flying:
                if Vector2(velocity.x, velocity.z).length() > 0.6:
                        _set_anim("Running_A", 0.2)
                else:
                        _set_anim("Jump_Idle", 0.2)
                anim.speed_scale = 0.8
                return
        if _jumped:
                _set_anim("Jump_Full_Short", 0.12)
                return
        if not is_on_floor():
                _set_anim("Jump_Idle", 0.18)
                return
        var hspeed := Vector2(velocity.x, velocity.z).length()
        if hspeed > 0.4:
                _set_anim("Running_A", 0.22)
                anim.speed_scale = clampf(hspeed / 5.6, 0.72, 1.4)
        else:
                anim.speed_scale = 1.0
                _set_anim("Idle", 0.25)


# ---------- АТАКА ----------

func _try_attack() -> void:
        if _attacking or _attack_cd > 0.0 or dead:
                return
        if anim == null or not anim.has_animation("1H_Melee_Attack_Chop"):
                return
        _attacking = true
        _attack_cd = 0.72
        _attack_t = 0.0
        _hit_started = false
        _hit_window = false
        var raw_len: float = anim.get_animation("1H_Melee_Attack_Chop").length
        # Длинные демо-анимации KayKit сжимаем до игровых 0.85 с
        anim.speed_scale = clampf(raw_len / ATTACK_TIME, 1.0, 6.0)
        _attack_len = ATTACK_TIME
        _cur_anim = ""
        _set_anim("1H_Melee_Attack_Chop", 0.06)


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
        _cur_anim = ""
        _set_anim("Hit_A", 0.1)
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
        _cur_anim = ""
        _set_anim("Death_A", 0.15)


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
        _cur_anim = ""
        _set_anim("Idle", 0.1)
