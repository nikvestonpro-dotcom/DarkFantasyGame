extends SceneTree
## Пекарня v11: запекает анимации из паков «Анимация и персонажи»
## (Mixamo, скелет Paladin'а) в библиотеки под каждый скелет игры.
##
## Что делает с каждым клипом:
##  1) копирует треки (вращения костей совместимы — у всех Mixamo-скелетов
##     одинаковые имена костей и rest-позы);
##  2) переписывает пути треков под структуру сцены приёмника
##     (охотник: "Bounty hunter/Armature_002/Skeleton3D:" -> "Skeleton3D:");
##  3) выкидывает треки костей, которых нет у приёмника (пальцы и пр.) —
##     иначе AnimationPlayer сыплет ошибками кэша;
##  4) РЕТАРГЕТ ПОЗИЦИИ ТАЗА: pos' = rest_приёмника + (pos - rest_донора) * k,
##     k = размах скелета приёмника / размах донора. Без этого высокий
##     рыцарь «сжимается» до роста паладина (проверено замером).
##
## Запуск: godot --headless --path . -s tools/bake_mixamo_anims.gd

const GS := "res://assets/Анимация и персонажи/Great Sword Pack/"
const MS := "res://assets/Анимация и персонажи/Magic Spell Pack/"

## Источники клипов: имя в библиотеке -> [путь FBX, цикл]
const SOURCES := {
        # герой (двуручник)
        "idle": [GS + "great sword idle.fbx", true],
        "walk": [GS + "great sword walk.fbx", true],
        "run": [GS + "great sword run.fbx", true],
        "jump": [GS + "great sword jump.fbx", false],
        "attack1": [GS + "great sword slash.fbx", false],
        "attack2": [GS + "great sword attack.fbx", false],
        "attack3": [GS + "great sword high spin attack.fbx", false],
        "hit": [GS + "great sword impact.fbx", false],
        "death": [GS + "two handed sword death.fbx", false],
        "block": [GS + "great sword blocking.fbx", true],
        # жители (спокойные)
        "idle_calm": [MS + "standing idle.fbx", true],
}

## Приёмники: имя -> [путь модели, набор клипов]
const TARGETS := {
        "knight": ["res://assets/Анимация и персонажи/Knight D Pelegrini.fbx",
                ["idle", "walk", "run", "jump", "attack1", "attack2", "attack3", "hit", "death", "block"]],
        "hunter": ["res://мобы/DEAD OATH HUNTER  PSX Bounty Hunter Character/DEAD OATH HUNTER.fbx",
                ["idle", "walk", "run", "idle_calm"]],
        "akai": ["res://assets/Анимация и персонажи/akai_e_espiritu.fbx",
                ["walk", "idle_calm"]],
        "arissa": ["res://assets/Анимация и персонажи/Arissa.fbx",
                ["walk", "idle_calm"]],
        "paladin": ["res://assets/Анимация и персонажи/Paladin WProp J Nordstrom.fbx",
                ["idle", "walk", "run", "idle_calm"]],
}


func _init() -> void:
        call_deferred("_boot")


func _boot() -> void:
        DirAccess.make_dir_recursive_absolute("res://assets/anims")

        # --- замер донора (скелет анимаций) по первому клипу ---
        var donor_path: String = SOURCES["idle"][0]
        var donor: Node3D = load(donor_path).instantiate()
        root.add_child(donor)
        await process_frame
        var d_skel := donor.find_child("Skeleton3D", true, false) as Skeleton3D
        var d_span := _skel_span(d_skel)
        var d_rest_hips := d_skel.get_bone_pose(d_skel.find_bone("mixamorig_Hips")).origin
        var d_prefix := _skel_prefix(donor, d_skel)
        print("донор: span=%.3f hips=%s prefix='%s'" % [d_span, str(d_rest_hips), d_prefix])
        donor.queue_free()
        await process_frame

        # --- грузим все клипы-источники в память ---
        var clips := {}
        for clip_name in SOURCES:
                var path: String = SOURCES[clip_name][0]
                var loop: bool = SOURCES[clip_name][1]
                var src: Node3D = load(path).instantiate()
                root.add_child(src)
                await process_frame
                var ap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
                var anim: Animation = null
                for lib in ap.get_animation_library_list():
                        for n in ap.get_animation_library(lib).get_animation_list():
                                anim = ap.get_animation_library(lib).get_animation(n)
                if anim == null:
                        print("!! нет анимации в ", path)
                        src.queue_free()
                        await process_frame
                        continue
                var dup := anim.duplicate(true)
                dup.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
                dup.step = 0.0
                clips[clip_name] = dup
                print("клип %-10s len=%.2f trk=%d  <- %s" % [clip_name, dup.length, dup.get_track_count(), path.get_file()])
                src.queue_free()
                await process_frame

        # --- печём библиотеки под каждый приёмник ---
        for t_name in TARGETS:
                var t_path: String = TARGETS[t_name][0]
                var t_list: Array = TARGETS[t_name][1]
                var inst: Node3D = load(t_path).instantiate()
                root.add_child(inst)
                await process_frame
                var t_skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
                var t_span := _skel_span(t_skel)
                var t_rest_hips := t_skel.get_bone_pose(t_skel.find_bone("mixamorig_Hips")).origin
                var t_prefix := _skel_prefix(inst, t_skel)
                var k: float = t_span / maxf(d_span, 0.001)

                # набор костей приёмника: треки с чужими костями (пальцы и
                # пр.) выкидываем, иначе AnimationPlayer сыплет ошибками кэша
                var bone_set := {}
                for bi in t_skel.get_bone_count():
                        bone_set[t_skel.get_bone_name(bi)] = true

                var lib := AnimationLibrary.new()
                for clip_name in t_list:
                        var src_anim: Animation = clips[clip_name]
                        var out := src_anim.duplicate(true)
                        var drop: Array = []
                        for i in out.get_track_count():
                                var tp := String(out.track_get_path(i))
                                var bone := tp.get_slice(":", 1)
                                if not bone_set.has(bone):
                                        drop.append(i)
                                        continue
                                out.track_set_path(i, NodePath("%s:%s" % [t_prefix, bone]))
                        drop.reverse()
                        for di in drop:
                                out.remove_track(di)
                        # ретаргет позиции таза
                        var hips_track := -1
                        for i in out.get_track_count():
                                if out.track_get_type(i) == Animation.TYPE_POSITION_3D \
                                                and String(out.track_get_path(i)).ends_with(":mixamorig_Hips"):
                                        hips_track = i
                                        break
                        if hips_track >= 0:
                                for key in out.track_get_key_count(hips_track):
                                        var v: Vector3 = out.track_get_key_value(hips_track, key)
                                        v = t_rest_hips + (v - d_rest_hips) * k
                                        out.track_set_key_value(hips_track, key, v)
                        lib.add_animation(clip_name, out)
                var err := ResourceSaver.save(lib, "res://assets/anims/v11_%s_anims.tres" % t_name)
                print("== %s: span=%.3f k=%.3f клипов=%d err=%s" % [t_name, t_span, k, lib.get_animation_list().size(), str(err)])
                inst.queue_free()
                await process_frame

        print("BAKE v11 DONE")
        quit(0)


## Размах скелета: от ступней до макушки (в мировых единицах).
func _skel_span(skel: Skeleton3D) -> float:
        var min_y := 1e9
        var max_y := -1e9
        var gt := skel.get_global_transform()
        for i in skel.get_bone_count():
                var bn := skel.get_bone_name(i)
                if "IK" in bn or bn == "root" or bn.find("control") >= 0 or bn.find("pole") >= 0:
                        continue
                var y := (gt * skel.get_bone_global_pose(i)).origin.y
                min_y = minf(min_y, y)
                max_y = maxf(max_y, y)
        return maxf(max_y - min_y, 0.001)


## Путь до Skeleton3D ОТНОСИТЕЛЬНО root_node AnimationPlayer'а
## (треки анимаций адресуются от него).
func _skel_prefix(inst: Node3D, skel: Skeleton3D) -> String:
        var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
        if ap == null:
                return "Skeleton3D"
        var root_node: Node = ap.get_node_or_null(ap.root_node)
        if root_node == null:
                root_node = ap.get_parent()
        var rel := root_node.get_path_to(skel)
        return String(rel)
