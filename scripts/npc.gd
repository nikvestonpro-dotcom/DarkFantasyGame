extends CharacterBody3D
## Житель v11: РАЗНЫЕ модели (рыцарь-герой больше не шаблон жителя!):
## охотник, паладин со щитом, маг-отшельник Akai, охотница Arissa —
## рост и оттенок варьируются по сиду, у некоторых фонарь в руке.
## Анимации — родные клипы Mixamo (idle_calm / walk), запечённые под
## скелет каждой модели. Рост калибруется по КОСТЯМ: в v10.1 AABB
## включал меч, и жители были карликами ~0.9 м, парящими над землёй.
## Бродит по своей зоне, при приближении игрока останавливается,
## поворачивается и здоровается. Реплики — в интерфейсе.

const FACING_FIX := 0.0   # модели Mixamo смотрят в +Z, как и ждёт логика

var npc_name := "Житель"
var phrases := ["Вечер добрый, путник."]

## базовый рост жителя; варьируется по сиду
const NPC_HEIGHT := 1.72

var _waypoint := Vector3.ZERO
var _idle := 0.0
var home_center: Vector2 = GameWorld.VILLAGE_CENTER
var home_radius := 17.0
var _speed := 1.15
var _moving := false
var _rng := RandomNumberGenerator.new()
var _cur_anim := ""
var _height := NPC_HEIGHT
var _t := 0.0
var _light: OmniLight3D
var _light_phase := 0.0

var visual: Node3D
var anim: AnimationPlayer

var _model: PackedScene
var _anims: AnimationLibrary
var _tint := Color(1, 1, 1)
var _lantern := false
var _hide_list: Array = []
var _anim_lib_name := "n"
var _idle_anim := "n/idle_calm"
var _walk_anim := "n/walk"
var _facing := 0.0


func setup(p_name: String, p_phrases: Array, seed_v: int,
                model: PackedScene, anims: AnimationLibrary, opts := {}) -> void:
        npc_name = p_name
        phrases = p_phrases
        _rng.seed = seed_v
        # вариация роста: каждая копия чуть выше/ниже базовой
        var h_mult: float = opts.get("height", 1.0)
        _height = NPC_HEIGHT * _rng.randf_range(0.96, 1.04) * h_mult
        _model = model
        _anims = anims
        _tint = opts.get("tint", Color(1, 1, 1))
        _lantern = opts.get("lantern", false)
        _hide_list = opts.get("hide", [])
        home_center = opts.get("home", GameWorld.VILLAGE_CENTER)
        home_radius = opts.get("radius", 17.0)
        # своя библиотека/клипы (например, родные клипы KayKit у призрака замка)
        _anim_lib_name = opts.get("lib", "n")
        _idle_anim = opts.get("idle", "n/idle_calm")
        _walk_anim = opts.get("walk", "n/walk")
        _facing = opts.get("yaw", 0.0)


func _ready() -> void:
        add_to_group("npc")
        var col := CollisionShape3D.new()
        var cap := CapsuleShape3D.new()
        cap.radius = 0.32
        cap.height = 1.6
        col.shape = cap
        col.position.y = 0.8
        add_child(col)
        _build_body()


func _build_body() -> void:
        visual = Node3D.new()
        visual.name = "Visual"
        add_child(visual)

        var inst: Node3D = _model.instantiate()
        visual.add_child(inst)
        # прячем ненужные меши (меч охотника у мирных жителей)
        for wname in _hide_list:
                for node in inst.find_children("*", "Node", true, false):
                        if node.name == wname and node is Node3D:
                                node.visible = false
        # калибровка по костям: ступни на земле, рост ~1.72 м
        CharRig.calibrate(inst, _height, _facing)
        # оттеночная вариация (разная «одежда»)
        if _tint != Color(1, 1, 1):
                CharRig.tint(inst, _tint)
        # фонарь в кисть (тёплый свет бродит по деревне)
        if _lantern:
                var lantern: Node3D = CharRig.build_lantern()
                CharRig.attach_to_bone(inst, "mixamorig_RightHand", lantern)
                _light = lantern.get_node_or_null("LanternLight")
                _light_phase = _rng.randf() * TAU
        # анимации: запечённая под эту модель библиотека или родные клипы модели
        anim = CharRig.find_ap(inst)
        if anim != null:
                anim.playback_default_blend_time = 0.25
                if _anims != null:
                        anim.add_animation_library(_anim_lib_name, _anims)
                if anim.has_animation(_idle_anim):
                        anim.play(_idle_anim)

        # имя над головой
        var lbl := Label3D.new()
        lbl.text = npc_name
        lbl.font_size = 40
        lbl.pixel_size = 0.004
        lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        lbl.modulate = Color(1.0, 0.85, 0.55)
        lbl.outline_size = 8
        lbl.position.y = _height + 0.32
        add_child(lbl)


func _physics_process(dt: float) -> void:
        _t += dt
        # мерцание фонаря
        if _light != null:
                _light.light_energy = 1.6 + 0.35 * sin(_t * 11.0 + _light_phase) \
                                + 0.15 * sin(_t * 27.0 + _light_phase * 2.0)
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
        var target := _idle_anim
        if _moving:
                target = _walk_anim
                _speed = 1.15
        if _cur_anim == target and anim.is_playing():
                return
        _cur_anim = target
        if anim.has_animation(target):
                anim.play(target, 0.25)


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
