class_name CharacterLibrary
extends RefCounted
## v8.0: общая библиотека реалистичных персонажей (Mixamo, CC0):
##  - паладин (игрок), рыцарь (стража/мобы), Арисса (NPC), akai (призрак)
##  - анимации грузятся из FBX-паков и ПЕРЕНАЗНАЧАЮТСЯ на скелет носителя:
##    у всех моделей Mixamo один и тот же риг (mixamorig:*), поэтому одна
##    библиотека анимаций подходит всем. Пути треков переписываются под
##    фактическое положение Skeleton3D в сцене носителя.
##  - оружие и пропы навешиваются BoneAttachment3D по имени кости.

const CH := "res://assets/models/characters/"
const PACKS := "res://assets/models/characters/"

const PALADIN := CH + "paladin.fbx"
const KNIGHT := CH + "knight.fbx"
const ARISSA := CH + "arissa.fbx"
const GHOST := CH + "akai_ghost.fbx"

const DEMONIC_SWORD := "res://assets/models/packs/demonic weapons pack/demonic weapons pack/sword/demonicswordgodot.glb"
const DEMONIC_GREATSWORD := "res://assets/models/packs/demonic weapons pack/demonic weapons pack/greatsword/demonicgreatswordgodot.glb"
const DEMONIC_SCYTHE := "res://assets/models/packs/demonic weapons pack/demonic weapons pack/scythe/demonicscythegodot.glb"
const DEMONIC_SPEAR := "res://assets/models/packs/demonic weapons pack/demonic weapons pack/spear/demonicspeargodot.glb"
const DEMONIC_AXE := "res://assets/models/packs/demonic weapons pack/demonic weapons pack/axe/demonicaxegodot.glb"

## Имя -> путь FBX с анимацией (Pro Sword and Shield / Great Sword / Magic)
const ANIM_FBX := {
        # --- локомоция (Pro Sword and Shield) ---
        "idle": PACKS + "Pro Sword and Shield Pack/sword and shield idle.fbx",
        "idle2": PACKS + "Pro Sword and Shield Pack/sword and shield idle (2).fbx",
        "walk": PACKS + "Pro Sword and Shield Pack/sword and shield walk.fbx",
        "walk2": PACKS + "Pro Sword and Shield Pack/sword and shield walk (2).fbx",
        "run": PACKS + "Pro Sword and Shield Pack/sword and shield run.fbx",
        "run2": PACKS + "Pro Sword and Shield Pack/sword and shield run (2).fbx",
        # --- атака: 5-ударное комбо ---
        "slash1": PACKS + "Pro Sword and Shield Pack/sword and shield slash.fbx",
        "slash2": PACKS + "Pro Sword and Shield Pack/sword and shield slash (2).fbx",
        "slash3": PACKS + "Pro Sword and Shield Pack/sword and shield slash (3).fbx",
        "slash4": PACKS + "Pro Sword and Shield Pack/sword and shield slash (4).fbx",
        "slash5": PACKS + "Pro Sword and Shield Pack/sword and shield slash (5).fbx",
        "attack": PACKS + "Pro Sword and Shield Pack/sword and shield attack.fbx",
        # --- защита и реакция ---
        "block": PACKS + "Pro Sword and Shield Pack/sword and shield block.fbx",
        "block_idle": PACKS + "Pro Sword and Shield Pack/sword and shield block idle.fbx",
        "impact": PACKS + "Pro Sword and Shield Pack/sword and shield impact.fbx",
        "impact2": PACKS + "Pro Sword and Shield Pack/sword and shield impact (2).fbx",
        # --- особые движения ---
        "kick": PACKS + "Pro Sword and Shield Pack/sword and shield kick.fbx",
        "jump": PACKS + "Pro Sword and Shield Pack/sword and shield jump.fbx",
        "death": PACKS + "Pro Sword and Shield Pack/sword and shield death.fbx",
        "power_up": PACKS + "Pro Sword and Shield Pack/sword and shield power up.fbx",
        # --- двуручный стиль (для боссов и бандитов) ---
        "gs_idle": PACKS + "Great Sword Pack/great sword idle.fbx",
        "gs_walk": PACKS + "Great Sword Pack/great sword walk.fbx",
        "gs_run": PACKS + "Great Sword Pack/great sword run.fbx",
        "gs_slash": PACKS + "Great Sword Pack/great sword slash.fbx",
        "gs_slash2": PACKS + "Great Sword Pack/great sword slash (2).fbx",
        "gs_spin": PACKS + "Great Sword Pack/great sword high spin attack.fbx",
        "gs_impact": PACKS + "Great Sword Pack/great sword impact.fbx",
        "gs_death": PACKS + "Great Sword Pack/two handed sword death.fbx",
        # --- магия (призрак, маги) ---
        "mg_idle": PACKS + "Magic Spell Pack/standing idle.fbx",
        "mg_cast": PACKS + "Magic Spell Pack/Standing 1H Magic Attack 01.fbx",
        "mg_cast2": PACKS + "Magic Spell Pack/Standing 2H Cast Spell 01.fbx",
        "mg_area": PACKS + "Magic Spell Pack/Standing 2H Magic Area Attack 01.fbx",
}

## Кэш: путь FBX -> Animation (уже отретаргеченная под СТАНДАРТНЫЙ путь
## "Skeleton3D" — при добавлении в AnimationPlayer, сидящий в корне сцены
## модели рядом со скелетом, пути совпадают автоматически).
static var _anim_cache: Dictionary = {}


## Загружает модель как экземпляр сцены и находит скелет.
static func instantiate_model(path: String) -> Node:
        if not ResourceLoader.exists(path):
                push_warning("CharacterLibrary: нет модели " + path)
                return null
        var ps := load(path) as PackedScene
        if ps == null:
                return null
        return ps.instantiate()


## Ищет кость руки по вариантам имён (Mixamo/прочие риги).
static func find_bone(skel: Skeleton3D, candidates: Array) -> int:
        if skel == null:
                return -1
        for c in candidates:
                var idx := skel.find_bone(c)
                if idx >= 0:
                        return idx
        # частичное совпадение (риги называют по-разному)
        for c in candidates:
                var short: String = String(c).replace("mixamorig_", "").to_lower()
                for i in skel.get_bone_count():
                        var bn: String = skel.get_bone_name(i).to_lower()
                        if short in bn:
                                return i
        return -1


## Достаёт анимацию из FBX и возвращает её с путями треков, совместимыми
## со сценой-носителем: префикс до Skeleton3D заменяется на фактический
## путь скелета относительно AnimationPlayer.
static func load_animation(anim_name: String, host_ap: AnimationPlayer,
                host_skel: Skeleton3D) -> Animation:
        if host_skel == null or host_ap == null:
                return null
        var path: String = ANIM_FBX.get(anim_name, "")
        if path == "":
                return null
        if not ResourceLoader.exists(path):
                push_warning("CharacterLibrary: нет анимации " + path)
                return null

        var key := path
        if _anim_cache.has(key):
                return (_anim_cache[key] as Animation).duplicate() as Animation

        var ps := load(path) as PackedScene
        if ps == null:
                return null
        var inst := ps.instantiate()
        var src_ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
        var anim: Animation = null
        if src_ap != null:
                var names := src_ap.get_animation_list()
                if names.size() > 0:
                        anim = src_ap.get_animation(names[0]).duplicate() as Animation
        inst.free()
        if anim == null:
                return null

        # --- РЕТАРГЕТ: пути треков вида "<что-то>/Skeleton3D/<кость>" ---
        # Заменяем префикс до Skeleton3D на путь скелета-носителя относительно AP.
        var skel_path: String = host_ap.get_path_to(host_skel)
        for i in anim.get_track_count():
                var p: NodePath = anim.track_get_path(i)
                var joined := p.get_concatenated_names()
                if joined.is_empty():
                        continue
                var segs: PackedStringArray = PackedStringArray(joined.split("/"))
                var skel_idx := -1
                for si in segs.size():
                        if "Skeleton3D" in segs[si]:
                                skel_idx = si
                                break
                if skel_idx < 0:
                        continue
                # всё после узла Skeleton3D — кости (виртуальные подузлы)
                var bones := ""
                for bi in range(skel_idx + 1, segs.size()):
                        if bones != "":
                                bones += "/"
                        bones += segs[bi]
                var props: String = p.get_concatenated_subnames()
                var new_path_str: String = skel_path
                if bones != "":
                        new_path_str += "/" + bones
                if props != "":
                        new_path_str += ":" + props
                var new_path := NodePath(new_path_str)
                if new_path != p:
                        anim.track_set_path(i, new_path)

        _anim_cache[key] = anim
        return anim.duplicate() as Animation


## Строит AnimationPlayer в корне модели, грузит набор анимаций.
## anims: Array[String] — имена из ANIM_FBX.
## Возвращает AnimationPlayer (уже с библиотекой "" и зацикливанием).
static func build_anim_player(host: Node, skel: Skeleton3D,
                anims: Array, loop_names: Array = []) -> AnimationPlayer:
        if host == null or skel == null:
                return null
        var ap := AnimationPlayer.new()
        ap.name = "Anim"
        host.add_child(ap)
        # root_node = сам AnimationPlayer: треки анимаций Mixamo имеют вид
        # "../Skeleton3D:mixamorig_Hips" (скелет — сиблинг AP внутри model_inst)
        ap.root_node = NodePath(".")
        var lib := AnimationLibrary.new()
        for n in anims:
                var a := load_animation(n, ap, skel)
                if a == null:
                        continue
                # Зацикливаем только локомоцию и idle; атаки/смерть играются once
                a.loop_mode = Animation.LOOP_LINEAR if loop_names.has(n) else Animation.LOOP_NONE
                lib.add_animation(n, a)
        if lib.get_animation_list().size() == 0:
                ap.free()
                return null
        ap.add_animation_library("", lib)
        return ap


## Подгонка роста по костям скелета (AABB скелетных мешей пуст).
## Возвращает [scale, feet_y] или null.
static func fit_height(inst: Node, target_height: float) -> Array:
        var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
        if skel != null and skel.get_bone_count() > 4:
                var miny := 1e9
                var maxy := -1e9
                var inv: Transform3D = inst.global_transform.affine_inverse()
                for i in skel.get_bone_count():
                        var bname: String = skel.get_bone_name(i)
                        if "IK" in bname or "control" in bname:
                                continue
                        var gp: Vector3 = (inv * skel.global_transform
                                        * skel.get_bone_global_pose(i)).origin
                        miny = minf(miny, gp.y)
                        maxy = maxf(maxy, gp.y)
                var height: float = maxf(maxy - miny, 0.05)
                return [target_height / height, miny]
        return []
        var box := _subtree_aabb(inst)
        if box.size.y < 0.05:
                return []
        return [target_height / box.size.y, box.position.y]


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
