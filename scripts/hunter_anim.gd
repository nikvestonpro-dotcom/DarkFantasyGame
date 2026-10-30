extends RefCounted
## Печка анимаций охотника (DEAD OATH HUNTER, скелет Mixamo).
## Используется ТОЛЬКО офлайн-инструментом tools/bake_anims.gd:
##  1) нарезка демо-таймлайна «Todo» (43 сек) на игровые клипы;
##  2) ретаргет анимаций KayKit (Idle, Walking_A) на скелет Mixamo —
##     спокойная ходьба для игрока и жителей.
##
## Математика ретаргета: для каждой кости приёмника j с донором i
##   C  = G_r_rest(j) * inv(G_s_rest(i))      (донор -> приёмник)
##   M  = G_s_anim(i) * inv(G_s_rest(i))      (движение донора в мире)
##   M' = C * M * inv(C)                      (то же движение в системе приёмника)
##   G_r_anim(j) = lerp(I, M', вес) * G_r_rest(j)
## C сама содержит разворот «лицом» и разницу стоек, поэтому дельты
## переносятся корректно без ручного выравнивания. Незамапленные кости
## (пальцы, меч Cube.002) наследуют M' ближайшего замапленного предка —
## меч едет вместе с кистью. Позиции: трек только у таза (кости rigid).


const HUNTER_PATH := "res://мобы/DEAD OATH HUNTER  PSX Bounty Hunter Character/DEAD OATH HUNTER.fbx"
const DONOR_PATH := "res://assets/models/kay_Rogue.glb"

## Срезы таймлайна «Todo»: имя -> [начало, конец, цикл]
const SLICES := {
        "idle": [0.7, 3.2, true],
        "attack": [11.0, 15.0, false],
        "attack2": [16.3, 19.8, false],
        "jump": [19.8, 21.6, false],
        "hit": [35.0, 36.9, false],
        "death": [35.0, 40.6, false],
        "run": [28.1, 29.9, true],
}

## Полное соответствие костей (донор KayKit -> приёмник Mixamo)
const BONE_MAP := {
        "hips": "mixamorig_Hips",
        "spine": "mixamorig_Spine",
        "chest": "mixamorig_Spine1",
        "head": "mixamorig_Head",
        "upperarm.l": "mixamorig_LeftArm",
        "lowerarm.l": "mixamorig_LeftForeArm",
        "wrist.l": "mixamorig_LeftHand",
        "upperleg.l": "mixamorig_LeftUpLeg",
        "lowerleg.l": "mixamorig_LeftLeg",
        "foot.l": "mixamorig_LeftFoot",
        "toes.l": "mixamorig_LeftToeBase",
        "upperarm.r": "mixamorig_RightArm",
        "lowerarm.r": "mixamorig_RightForeArm",
        "wrist.r": "mixamorig_RightHand",
        "upperleg.r": "mixamorig_RightUpLeg",
        "lowerleg.r": "mixamorig_RightLeg",
        "foot.r": "mixamorig_RightFoot",
        "toes.r": "mixamorig_RightToeBase",
}

## Частичные кости приёмника: кость -> [кость-донор, вес 0..1]
const BONE_PARTIAL := {
        "mixamorig_Spine2": ["chest", 1.0],
        "mixamorig_Neck": ["head", 0.45],
        "mixamorig_LeftShoulder": ["upperarm.l", 0.3],
        "mixamorig_RightShoulder": ["upperarm.r", 0.3],
}

const FPS := 30.0


## Нарезать «Todo» на клипы и вернуть библиотеку (экземпляр должен
## уже висеть в дереве — для вычисления путей треков).
static func slice_library(hunter_inst: Node) -> AnimationLibrary:
        var lib := AnimationLibrary.new()
        var ap := _find_ap(hunter_inst)
        var todo: Animation = ap.get_animation("Todo")
        for clip_name in SLICES:
                var s: Array = SLICES[clip_name]
                lib.add_animation(clip_name, _slice(todo, s[0], s[1], s[2]))
        return lib


## Ретаргет одного клипа донора. Оба экземпляра должны быть в дереве.
static func retarget_clip(donor_inst: Node, recv_inst: Node,
                donor_clip: String) -> Animation:
        var d_skel := donor_inst.find_child("Skeleton3D", true, false) as Skeleton3D
        var r_skel := recv_inst.find_child("Skeleton3D", true, false) as Skeleton3D
        var d_ap := _find_ap(donor_inst)
        var src: Animation = d_ap.get_animation(donor_clip)
        return _bake(donor_inst, d_skel, recv_inst, r_skel, src)


# ============================================================
#  НАРЕЗКА «TODO»
# ============================================================

static func _slice(src: Animation, t0: float, t1: float, loop: bool) -> Animation:
        var out := Animation.new()
        out.length = t1 - t0
        out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
        out.step = 0.0
        for i in src.get_track_count():
                var path: NodePath = src.track_get_path(i)
                var tt: int = src.track_get_type(i)
                var ni: int = out.add_track(tt)
                out.track_set_path(ni, path)
                out.track_set_interpolation_type(ni, src.track_get_interpolation_type(i))
                var n := src.track_get_key_count(i)
                var inserted_zero := false
                for k in n:
                        var kt: float = src.track_get_key_time(i, k)
                        if kt < t0 - 1e-4:
                                continue
                        if kt > t1 + 1e-4:
                                break
                        var kv = src.track_get_key_value(i, k)
                        var local_t: float = kt - t0
                        if local_t < 1e-4:
                                inserted_zero = true
                        out.track_insert_key(ni, local_t, kv)
                # ключ в начале клипа: если нет — интерполируем значение на t0
                if not inserted_zero and out.track_get_key_count(ni) > 0:
                        var v = _interp_track(src, i, tt, t0)
                        if v != null:
                                out.track_insert_key(ni, 0.0, v)
        return out


static func _interp_track(a: Animation, idx: int, tt: int, t: float):
        match tt:
                Animation.TYPE_POSITION_3D:
                        return a.position_track_interpolate(idx, t)
                Animation.TYPE_ROTATION_3D:
                        return a.rotation_track_interpolate(idx, t)
                Animation.TYPE_SCALE_3D:
                        return a.scale_track_interpolate(idx, t)
        return null


# ============================================================
#  РЕТАРГЕТ
# ============================================================

static func _bake(donor_inst: Node, d_skel: Skeleton3D,
                recv_inst: Node, r_skel: Skeleton3D, src: Animation) -> Animation:
        var d_bones := d_skel.get_bone_count()
        var r_bones := r_skel.get_bone_count()

        # --- rest-позы (локальные) ---
        var d_rest: Array = []
        for i in d_bones:
                d_rest.append(d_skel.get_bone_pose(i))
        var r_rest: Array = []
        for i in r_bones:
                r_rest.append(r_skel.get_bone_pose(i))

        # --- rest-глобали (обход иерархии вручную) ---
        var d_rg := _chain(d_skel, d_rest)
        var r_rg := _chain(r_skel, r_rest)

        # --- треки донора по именам костей ---
        var d_tracks := {}
        for i in src.get_track_count():
                var bn := String(src.track_get_path(i)).get_slice(":", 1)
                if not d_tracks.has(bn):
                        d_tracks[bn] = {}
                match src.track_get_type(i):
                        Animation.TYPE_POSITION_3D:
                                d_tracks[bn]["pos"] = i
                        Animation.TYPE_ROTATION_3D:
                                d_tracks[bn]["rot"] = i

        # --- соответствие: кость приёмника -> [кость донора, вес] ---
        var map_of := {}
        for donor_bone in BONE_MAP.keys():
                var r_i := r_skel.find_bone(BONE_MAP[donor_bone])
                var d_i := d_skel.find_bone(donor_bone)
                if r_i >= 0 and d_i >= 0:
                        map_of[r_i] = [d_i, 1.0]
        for r_bone in BONE_PARTIAL.keys():
                var r_i := r_skel.find_bone(r_bone)
                var donor_bone: String = BONE_PARTIAL[r_bone][0]
                var d_i := d_skel.find_bone(donor_bone)
                if r_i >= 0 and d_i >= 0 and not map_of.has(r_i):
                        map_of[r_i] = [d_i, BONE_PARTIAL[r_bone][1]]
        # m_prime[r_i] = [C, донорский индекс, вес] для замапленных;
        # порядок «родители раньше детей»
        var order := _parent_order(r_skel)
        var m_prime := {}
        for r_i in order:
                if map_of.has(r_i):
                        var d_i: int = map_of[r_i][0]
                        var w: float = map_of[r_i][1]
                        var c: Transform3D = r_rg[r_i] * d_rg[d_i].affine_inverse()
                        m_prime[r_i] = [c, d_i, w]
        # незамапленные кости наследуют ближайшего замапленного предка
        for r_i in order:
                if not m_prime.has(r_i):
                        var p := r_skel.get_bone_parent(r_i)
                        while p >= 0:
                                if m_prime.has(p):
                                        m_prime[r_i] = m_prime[p]
                                        break
                                p = r_skel.get_bone_parent(p)

        # --- hips: коэффициент масштаба смещения ---
        var r_hips := r_skel.find_bone("mixamorig_Hips")
        var d_hips := d_skel.find_bone("hips")
        var height_k := 1.0
        if d_hips >= 0 and r_hips >= 0:
                height_k = _skel_height(r_skel, r_rg) / maxf(_skel_height(d_skel, d_rg), 1e-6)

        # --- выходная анимация ---
        var skel_rel := _skel_rel_path(recv_inst, r_skel)
        var out := Animation.new()
        out.length = src.length
        out.loop_mode = src.loop_mode
        out.step = 0.0
        var rot_tr := {}
        var pos_tr := {}

        var steps := int(ceil(src.length * FPS)) + 1
        for k in steps:
                var t: float = minf(k / FPS, src.length)

                # 1) локальные позы донора из треков
                var d_cur: Array = []
                d_cur.resize(d_bones)
                for i in d_bones:
                        d_cur[i] = d_rest[i]
                for bone in d_tracks.keys():
                        var bi := d_skel.find_bone(bone)
                        if bi < 0:
                                continue
                        var tr: Dictionary = d_tracks[bone]
                        var xf: Transform3D = d_cur[bi]
                        if tr.has("pos"):
                                xf.origin = src.position_track_interpolate(tr["pos"], t)
                        if tr.has("rot"):
                                xf.basis = Basis(src.rotation_track_interpolate(tr["rot"], t))
                        d_cur[bi] = xf
                var root_i := d_skel.find_bone("root")
                if root_i >= 0:
                        d_cur[root_i] = d_rest[root_i]

                # 2) глобали донора
                var d_ag := _chain(d_skel, d_cur)

                # 3) M' и глобали приёмника (родители раньше детей)
                var r_ag: Array = []
                r_ag.resize(r_bones)
                for r_i in order:
                        var rest_g: Transform3D = r_rg[r_i]
                        var xf: Transform3D = rest_g
                        if m_prime.has(r_i) and m_prime[r_i] != null:
                                var c: Transform3D = m_prime[r_i][0]
                                var d_i: int = m_prime[r_i][1]
                                var w: float = m_prime[r_i][2]
                                var m: Transform3D = d_ag[d_i] * d_rg[d_i].affine_inverse()
                                var mp: Transform3D = c * m * c.affine_inverse()
                                # вес: тянем к тождественному преобразованию
                                var q := Quaternion.IDENTITY.slerp(
                                                mp.basis.get_rotation_quaternion(), w)
                                var o := mp.origin * w
                                if r_i == r_hips and d_hips >= 0:
                                        o += (d_ag[d_hips].origin - d_rg[d_hips].origin) * height_k * w
                                xf = Transform3D(Basis(q), o) * rest_g
                        r_ag[r_i] = xf

                # 4) локали и ключи
                for r_i in order:
                        var p := r_skel.get_bone_parent(r_i)
                        var local: Transform3D
                        if p < 0:
                                local = r_ag[r_i]
                        else:
                                local = r_ag[p].affine_inverse() * r_ag[r_i]
                        var bname := r_skel.get_bone_name(r_i)
                        var rq := local.basis.get_rotation_quaternion()
                        var restq: Quaternion = r_rest[r_i].basis.get_rotation_quaternion()
                        if not rq.is_equal_approx(restq) or rot_tr.has(r_i):
                                if not rot_tr.has(r_i):
                                        var tt := out.add_track(Animation.TYPE_ROTATION_3D)
                                        out.track_set_path(tt, NodePath(skel_rel + ":" + bname))
                                        rot_tr[r_i] = tt
                                out.track_insert_key(rot_tr[r_i], t, rq)
                        if r_i == r_hips:
                                if not pos_tr.has(r_i):
                                        var tt2 := out.add_track(Animation.TYPE_POSITION_3D)
                                        out.track_set_path(tt2, NodePath(skel_rel + ":" + bname))
                                        pos_tr[r_i] = tt2
                                out.track_insert_key(pos_tr[r_i], t, local.origin)
        return out


static func _chain(skel: Skeleton3D, locals: Array) -> Array:
        var n := skel.get_bone_count()
        var g: Array = []
        g.resize(n)
        for i in n:
                var p := skel.get_bone_parent(i)
                if p < 0:
                        g[i] = locals[i]
                else:
                        g[i] = g[p] * locals[i]
        return g


static func _parent_order(skel: Skeleton3D) -> Array:
        var n := skel.get_bone_count()
        var order: Array = []
        var seen: Array = []
        seen.resize(n)
        for i in n:
                seen[i] = false
        var stack := []
        for i in n:
                if skel.get_bone_parent(i) < 0:
                        stack.append(i)
        while not stack.is_empty():
                var i: int = stack.pop_back()
                if seen[i]:
                        continue
                seen[i] = true
                order.append(i)
                var kids := skel.get_bone_children(i)
                kids.reverse()
                for c in kids:
                        stack.append(c)
        return order


static func _skel_height(skel: Skeleton3D, globals: Array) -> float:
        var miny := 1e9
        var maxy := -1e9
        for i in skel.get_bone_count():
                var bn := skel.get_bone_name(i)
                if "IK" in bn or "control" in bn or bn == "root":
                        continue
                var y: float = globals[i].origin.y
                miny = minf(miny, y)
                maxy = maxf(maxy, y)
        if miny > maxy:
                return 1.0
        return maxy - miny


## Путь до Skeleton3D относительно root_node AnimationPlayer приёмника.
static func _skel_rel_path(recv_inst: Node, skel: Skeleton3D) -> String:
        var ap := _find_ap(recv_inst)
        if ap == null:
                return "../Skeleton3D"
        var root_node: Node = ap.get_node_or_null(ap.root_node)
        if root_node == null:
                root_node = ap.get_parent()
        var root_path := String(root_node.get_path())
        var skel_path := String(skel.get_path())
        if skel_path.begins_with(root_path + "/"):
                return skel_path.trim_prefix(root_path + "/")
        return skel_path


static func _find_ap(node: Node) -> AnimationPlayer:
        return node.find_child("AnimationPlayer", true, false) as AnimationPlayer
