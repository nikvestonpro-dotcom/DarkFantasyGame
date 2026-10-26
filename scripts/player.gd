extends CharacterBody3D
## v8.0 ИГРОК — ПАЛАДИН (Mixamo «Paladin WProp J Nordstrom», CC0):
##  - анимации Pro Sword and Shield Pack: 51-анимационный набор
##  - ЛКМ — 3-ударное комбо (slash 1/2/3, каждый сильнее), ПКМ — блок,
##    Q — удар ногой (отталкивает), Shift — бег, Space — прыжок
##  - в правой руке — ДЕМОНИЧЕСКИЙ МЕЧ (demonic weapons pack, CC0),
##    фирменный проп-меч паладина скрыт, щит оставлен (анимации под щит)
##  - светящиеся глаза-визор (тёплые) — фирменная деталь стиля @elder.void
##  - камера на пружине, здоровье, полёт (F), смерть и возрождение — из v7.0

signal died

const WALK_SPEED := 4.8
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 7.5
const GRAVITY := 20.0
const MAX_HP := 10.0

# Комбо: [анимация, игровой урон, длительность в игре, кулдаун после]
const COMBO := [
        ["slash1", 1, 0.62, 0.16],
        ["slash2", 1, 0.60, 0.16],
        ["slash3", 2, 0.78, 0.42],
]
const COMBO_WINDOW := 0.55   # окно продолжения комбо после удара
const KICK_TIME := 0.5
const BLOCK_DAMAGE_SCALE := 0.25

# v5.0: полёт — F включает/выключает, пробел вверх, C вниз
const FLY_SPEED := 13.0
const FLY_VERT := 7.5
const FLY_CEILING := 110.0

const MODEL_HEIGHT := 1.82
# Mixamo-модели смотрят вдоль +Z, «вперёд» Godot — это -Z
const FACING_FIX := PI

const SWORD_ROT := Vector3(-80.0, 0.0, 0.0)
const SWORD_POS := Vector3(0.0, 0.0, 0.0)
const SWORD_SCALE := 1.0

var hp := MAX_HP
var kills := 0
var dead := false

# --- бой ---
var _combo_idx := -1
var _combo_reset_t := 0.0
var _attacking := false
var _attack_t := 0.0
var _attack_len := 1.0
var _attack_dmg := 1
var _hit_started := false
var _hit_window := false
var _blocking := false
var _kick_t := 0.0
var _iframes := 0.0
var _no_damage_t := 10.0
var _pitch := -0.18
var _hurt_t := 0.0
var flying := false
var _fly_key_cd := 0.0
var _fly_air_t := 0.0

var pitch_node: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var hitbox: Area3D
var visual_root: Node3D
var model_inst: Node3D
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


# ---------- ТЕЛО (паладин Mixamo) ----------

func _build_body() -> void:
        visual_root = Node3D.new()
        visual_root.name = "VisualRoot"
        add_child(visual_root)

        model_inst = CharacterLibrary.instantiate_model(CharacterLibrary.PALADIN)
        if model_inst == null:
                push_warning("Паладин не загрузился!")
                return
        visual_root.add_child(model_inst)
        model_inst.rotation.y = FACING_FIX

        var skel := model_inst.find_child("Skeleton3D", true, false) as Skeleton3D
        var fit := CharacterLibrary.fit_height(model_inst, MODEL_HEIGHT)
        var s := 1.0
        var feet := 0.0
        if fit != null:
                s = fit[0]
                feet = fit[1]
        model_inst.scale = Vector3(s, s, s)
        model_inst.position = Vector3(0.0, -feet * s, 0.0)

        # Анимации: локомоция зациклена, атаки/смерть — once
        if skel != null:
                anim = CharacterLibrary.build_anim_player(model_inst, skel,
                        ["idle", "walk", "run", "slash1", "slash2", "slash3",
                         "block", "block_idle", "kick", "jump", "death", "impact"],
                        ["idle", "walk", "run", "block_idle"])
                if anim != null:
                        anim.playback_default_blend_time = 0.12
                        anim.play("idle")

        # Материалы: латунно-стальной доспех, чуть теплее в лунном свете;
        # глаза-визор — тёплое свечение
        for mi in model_inst.find_children("*", "MeshInstance3D", true, false):
                var mesh: Mesh = (mi as MeshInstance3D).mesh
                if mesh is ArrayMesh:
                        for i in mesh.get_surface_count():
                                var m := mesh.surface_get_material(i)
                                if m is StandardMaterial3D:
                                        var dup := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
                                        _style_paladin_material(dup, (mi as MeshInstance3D).name.to_lower()
                                                        + " " + dup.resource_name.to_lower())
                                        mesh.surface_set_material(i, dup)
                                        _mats.append(dup)

        # Скрываем фирменный МЕЧ паладина (заменяем демоническим), щит — оставляем
        _hide_prop(model_inst, "sword", false)

        # Демонический меч в правую кисть
        if skel != null:
                _attach_weapon(skel, CharacterLibrary.DEMONIC_SWORD,
                                ["mixamorig_RightHand", "RightHand", "Hand_R"], SWORD_ROT, SWORD_POS, SWORD_SCALE)


func _style_paladin_material(m: StandardMaterial3D, nm: String) -> void:
        # Латы паладина — светлее, чем у стражи: он «белый рыцарь» сцены,
        # контрастный против пурпурной ночи (как на референсах @elder.void)
        if "eye" in nm or "glow" in nm or "emiss" in nm:
                m.emission_enabled = true
                m.emission = Color(1.0, 0.75, 0.35)
                m.emission_energy_multiplier = 2.2
                return
        var is_metal := "armor" in nm or "plate" in nm or "metal" in nm or "chain" in nm
        if is_metal:
                m.albedo_color = Color(0.68, 0.70, 0.76)
                m.metallic = 1.0
                m.roughness = 0.28
        elif "leather" in nm or "boot" in nm or "belt" in nm:
                m.albedo_color = Color(0.24, 0.17, 0.12)
                m.roughness = 0.8
                m.metallic = 0.0
        elif "cloth" in nm or "cape" in nm or "tabard" in nm or "skirt" in nm:
                m.albedo_color = Color(0.30, 0.22, 0.16)
                m.roughness = 0.92
        # Вспышка урона (разгоняется в take_damage)
        m.emission_enabled = true
        m.emission = Color(1.0, 0.1, 0.05)
        m.emission_energy_multiplier = 0.0


func _hide_prop(inst: Node, what: String, hide: bool) -> void:
        for node in inst.find_children("*", "Node", true, false):
                var n := (node as Node).name.to_lower()
                if what in n and not "shield" in n:
                        (node as Node).visible = not hide


## Крепит GLB-оружие к кости. Контр-масштаб юнитов FBX обязателен —
## иначе оружие растягивается в гигантский проп.
func _attach_weapon(skel: Skeleton3D, weapon_path: String, bone_candidates: Array,
                rot_deg: Vector3, pos: Vector3, extra_scale: float) -> void:
        var bone_idx := CharacterLibrary.find_bone(skel, bone_candidates)
        if bone_idx < 0:
                push_warning("Кость руки не найдена — оружие не прикреплено")
                return
        var ba := BoneAttachment3D.new()
        ba.name = "WeaponAttachment"
        ba.bone_name = skel.get_bone_name(bone_idx)
        skel.add_child(ba)

        var holder := Node3D.new()
        holder.name = "Weapon"
        if ResourceLoader.exists(weapon_path):
                var wps := load(weapon_path) as PackedScene
                if wps != null:
                        var w := wps.instantiate()
                        holder.add_child(w)
                        # Подгон длины меча под рост паладина (~1.15 м клинок)
                        var box := CharacterLibrary._subtree_aabb(w)
                        if box.size.y > 0.05:
                                var k := 1.15 / box.size.y * extra_scale
                                w.scale = Vector3(k, k, k)
                                w.position = Vector3(-box.position.x * k, -box.position.y * k, -box.position.z * k)
        holder.rotation_degrees = rot_deg
        holder.position = pos
        # Контр-масштаб кости (FBX-юниты!)
        var bs: Vector3 = skel.get_bone_global_pose(bone_idx).basis.get_scale().abs()
        var ss: Vector3 = skel.global_transform.basis.get_scale().abs()
        holder.scale = Vector3(
                1.0 / maxf(ss.x * bs.x, 0.0001),
                1.0 / maxf(ss.y * bs.y, 0.0001),
                1.0 / maxf(ss.z * bs.z, 0.0001))
        ba.add_child(holder)


# ---------- КАМЕРА ----------

func _build_camera() -> void:
        pitch_node = Node3D.new()
        pitch_node.name = "Pitch"
        pitch_node.position.y = 1.35
        pitch_node.rotation.x = _pitch
        add_child(pitch_node)
        spring_arm = SpringArm3D.new()
        spring_arm.name = "CameraArm"
        spring_arm.spring_length = 5.2
        spring_arm.margin = 0.4
        spring_arm.collision_mask = 1
        spring_arm.position = Vector3(0, 0.35, 0.25)
        spring_arm.add_excluded_object(get_rid())
        pitch_node.add_child(spring_arm)
        camera = Camera3D.new()
        camera.fov = 72.0
        camera.far = 700.0
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
        hitbox.position = Vector3(0, 0.9, -0.9)
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
                if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.pressed:
                        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
                        return
                if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
                        _try_attack()
                elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
                        _set_block(true)
                elif not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
                        _set_block(false)


func _set_block(on: bool) -> void:
        if dead:
                _blocking = false
                return
        if on and not _blocking and not _attacking:
                _blocking = true
                _play("block", 0.12)
        elif not on and _blocking:
                _blocking = false
                _play("idle", 0.2)


# ---------- ФИЗИКА ----------

func _physics_process(dt: float) -> void:
        if _combo_reset_t > 0.0:
                _combo_reset_t -= dt
                if _combo_reset_t <= 0.0:
                        _combo_idx = -1
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
        # Q — удар ногой
        if Input.is_physical_key_pressed(KEY_Q) and not _attacking and not _blocking \
                        and not dead and is_on_floor() and _kick_t <= 0.0:
                _kick_t = KICK_TIME
                _attacking = true
                _attack_t = 0.0
                _attack_len = KICK_TIME
                _attack_dmg = 1
                _hit_started = false
                _hit_window = false
                _play("kick", 0.08)
        if _kick_t > 0.0:
                _kick_t -= dt
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

        # ФИЗИЧЕСКИЕ клавиши: работает при любой раскладке
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
        var sprint := Input.is_physical_key_pressed(KEY_SHIFT) and not _blocking
        var speed := SPRINT_SPEED if sprint else WALK_SPEED
        if _blocking:
                speed *= 0.45
        if _attacking and is_on_floor():
                speed *= 0.35   # замедление во время удара
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
                        and not _blocking and not _attacking:
                velocity.y = JUMP_VELOCITY
                jumped = true
        move_and_slide()

        _update_anim(dt, jumped)

        if _hit_window and hitbox.monitoring:
                for body in hitbox.get_overlapping_bodies():
                        if body.is_in_group("enemy"):
                                body.take_damage(_attack_dmg, global_position)
                                if _kick_t > 0.0 or _kick_t > -dt:
                                        # Пинок отталкивает сильнее обычного удара
                                        var kb := (body.global_position - global_position)
                                        kb.y = 0.0
                                        if kb.length() > 0.01:
                                                body.velocity += kb.normalized() * 7.0
        for m in _mats:
                if m.emission_energy_multiplier > 0.01:
                        m.emission_energy_multiplier = maxf(0.0,
                                        m.emission_energy_multiplier - 2.5 * dt)
        if global_position.y < -30.0:
                hp = 0.0
                _die()


# ---------- АНИМАЦИИ ----------

func _play(name: String, blend := 0.15) -> void:
        if anim == null or not anim.has_animation(name):
                return
        anim.play(name, blend)


func _update_anim(_dt: float, _jumped: bool) -> void:
        if anim == null or dead:
                return
        if _attacking:
                _attack_t += _dt
                if not _hit_started and _attack_t > _attack_len * 0.28:
                        _hit_started = true
                        _hit_window = true
                        hitbox.monitoring = true
                elif _hit_started and _attack_t > _attack_len * 0.62:
                        _hit_window = false
                        hitbox.monitoring = false
                if _attack_t >= _attack_len * 0.96:
                        _attacking = false
                        hitbox.monitoring = false
                        if _blocking:
                                _play("block_idle", 0.15)
                        else:
                                _play("idle", 0.2)
                return
        if _hurt_t > 0.0:
                return
        if _blocking:
                var hspeed0 := Vector2(velocity.x, velocity.z).length()
                if hspeed0 > 0.4:
                        _play("block_idle", 0.2)
                else:
                        _play("block_idle", 0.25)
                return
        if flying:
                if Vector2(velocity.x, velocity.z).length() > 0.6:
                        _play("run", 0.2)
                else:
                        _play("idle", 0.2)
                anim.speed_scale = 0.8
                return
        if _jumped:
                _play("jump", 0.12)
                return
        if not is_on_floor():
                _play("jump", 0.18)
                return
        var hspeed := Vector2(velocity.x, velocity.z).length()
        if hspeed > 5.4:
                _play("run", 0.22)
                anim.speed_scale = clampf(hspeed / 7.0, 0.85, 1.35)
        elif hspeed > 0.4:
                _play("walk", 0.22)
                anim.speed_scale = clampf(hspeed / 1.8, 0.8, 1.6)
        else:
                anim.speed_scale = 1.0
                _play("idle", 0.25)


# ---------- АТАКА (комбо) ----------

func _try_attack() -> void:
        if _attacking or dead or _blocking:
                return
        if anim == null:
                return
        # Продолжение комбо, если попали в окно
        var idx := 0
        if _combo_reset_t > 0.0 and _combo_idx >= 0:
                idx = (_combo_idx + 1) % COMBO.size()
        var c: Array = COMBO[idx]
        if not anim.has_animation(c[0]):
                return
        _attacking = true
        _attack_t = 0.0
        _attack_len = c[2]
        _attack_dmg = c[1]
        _hit_started = false
        _hit_window = false
        _combo_idx = idx
        _combo_reset_t = c[2] + c[3] + COMBO_WINDOW
        anim.speed_scale = 1.0
        _play(c[0], 0.07)


# ---------- УРОН И СМЕРТЬ ----------

func take_damage(amount: int, from_pos: Vector3) -> void:
        if dead or _iframes > 0.0:
                return
        _iframes = 0.7
        _no_damage_t = 0.0
        # Блок режет урон вчетверо и гасит отскок
        if _blocking:
                amount = maxi(1, int(round(amount * BLOCK_DAMAGE_SCALE)))
                _play("block", 0.08)
        hp -= amount
        for m in _mats:
                m.emission_energy_multiplier = 1.2
        _hurt_t = 0.35
        if not _blocking:
                _cur_anim = ""
                var kb := global_position - from_pos
                kb.y = 0.0
                if kb.length() > 0.01:
                        kb = kb.normalized() * 4.0
                        velocity += Vector3(kb.x, 2.0, kb.z)
        if hp <= 0.0:
                _die()


var _cur_anim := ""


func _die() -> void:
        if dead:
                return
        dead = true
        died.emit()
        _attacking = false
        _blocking = false
        _hit_window = false
        hitbox.monitoring = false
        _play("death", 0.15)


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
        _play("idle", 0.1)
