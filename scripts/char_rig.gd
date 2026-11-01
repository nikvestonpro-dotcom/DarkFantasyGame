class_name CharRig
extends RefCounted
## Утилиты скелетных персонажей v11.
##
## ГЛАВНОЕ: калибровка роста по КОСТЯМ, а не по AABB мешей. В v10.1 рост
## мерили по AABB поддерева, куда входил МЕЧ охотника, торчащий ниже
## ступней на 0.85 м — из-за этого жители были карликами ~0.9 м и висели
## над землёй. Кости (пятки/макушка) дают истинный рост тела.


## Найти скелет в инстансе модели.
static func find_skel(inst: Node) -> Skeleton3D:
        return inst.find_child("Skeleton3D", true, false) as Skeleton3D


## Найти AnimationPlayer.
static func find_ap(inst: Node) -> AnimationPlayer:
        return inst.find_child("AnimationPlayer", true, false) as AnimationPlayer


## Замер скелета в ЛОКАЛЬНОМ пространстве РОДИТЕЛЯ инстанса (inst уже
## добавлен к visual_root). Возвращает {span, toe_min, head_max}.
static func measure(inst: Node3D) -> Dictionary:
        var skel := find_skel(inst)
        if skel == null:
                return {"span": 1.7, "toe_min": 0.0, "head_max": 1.7}
        var ref := inst.get_parent() as Node3D
        var inv := Transform3D.IDENTITY
        if ref != null:
                inv = ref.get_global_transform().affine_inverse()
        var gt := skel.get_global_transform()
        var min_y := 1e9
        var max_y := -1e9
        for i in skel.get_bone_count():
                var bn := skel.get_bone_name(i)
                if _is_junk_bone(bn):
                        continue
                var y := (inv * gt * skel.get_bone_global_pose(i)).origin.y
                min_y = minf(min_y, y)
                max_y = maxf(max_y, y)
        if min_y > max_y:
                return {"span": 1.7, "toe_min": 0.0, "head_max": 1.7}
        return {"span": max_y - min_y, "toe_min": min_y, "head_max": max_y}


static func _is_junk_bone(bn: String) -> bool:
        return "IK" in bn or bn == "root" or bn.find("control") >= 0 or bn.find("pole") >= 0


## Калибровка: inst уже добавлен к visual_root. Выставить масштаб и
## смещение так, чтобы рост тела был target_height, а ступни стояли РОВНО
## на y=0 родителя. yaw — поворот лицом (модели Mixamo смотрят в +Z;
## для игрока, идущего вперёд в -Z, yaw=PI). Вызывать ДО старта анимаций
## (замер идёт по rest-позе скелета). Возвращает применённый масштаб.
static func calibrate(inst: Node3D, target_height: float, yaw := 0.0) -> float:
        var m := measure(inst)
        var s: float = target_height / m["span"]
        inst.scale = Vector3(s, s, s)
        inst.position = Vector3(0.0, -m["toe_min"] * s, 0.0)
        inst.rotation.y = yaw
        return s


## Прикрепить узел к кости (BoneAttachment3D). Возвращает узел крепления.
static func attach_to_bone(inst: Node3D, bone_name: String, child: Node3D) -> BoneAttachment3D:
        var skel := find_skel(inst)
        if skel == null:
                return null
        var att := BoneAttachment3D.new()
        att.bone_name = bone_name
        skel.add_child(att)
        att.add_child(child)
        return att


## Продублировать все StandardMaterial3D мешей (для вспышки урона/тонировки),
## вернуть список копий.
static func dup_materials(inst: Node) -> Array:
        var mats: Array = []
        for mi_n in inst.find_children("*", "MeshInstance3D", true, false):
                var mi := mi_n as MeshInstance3D
                if mi.mesh is ArrayMesh:
                        var am := mi.mesh as ArrayMesh
                        for i in am.get_surface_count():
                                var m := am.surface_get_material(i)
                                if m is StandardMaterial3D:
                                        var dup := (m as StandardMaterial3D).duplicate()
                                        mi.set_surface_override_material(i, dup)
                                        mats.append(dup)
        return mats


## Тонировка всех материалов множителем цвета (разные «одежды» у одинаковых
## моделей). Работает по дублям, не портит общий ресурс.
static func tint(inst: Node, tint: Color) -> Array:
        var mats := dup_materials(inst)
        for m in mats:
                var sm := m as StandardMaterial3D
                sm.albedo_color = Color(
                        sm.albedo_color.r * tint.r,
                        sm.albedo_color.g * tint.g,
                        sm.albedo_color.b * tint.b)
        return mats


## Уличный фонарь в руке: тёмная клетка с решёткой + яркое ядро + тёплый
## свет. Возвращает корневой узел (крепится к кисти mixamorig_RightHand).
static func build_lantern() -> Node3D:
        var root := Node3D.new()
        root.name = "Lantern"
        var metal := StandardMaterial3D.new()
        metal.albedo_color = Color(0.07, 0.065, 0.06)
        metal.roughness = 0.6
        metal.metallic = 0.55
        # корпус-решётка: крупный, читается даже в темноте
        var body := MeshInstance3D.new()
        var bm := CylinderMesh.new()
        bm.top_radius = 0.11
        bm.bottom_radius = 0.13
        bm.height = 0.24
        body.mesh = bm
        body.material_override = metal
        root.add_child(body)
        body.position = Vector3(0, -0.14, 0)
        # вертикальные прутья (силуэт «клетки»)
        for k in 4:
                var bar := MeshInstance3D.new()
                var bmesh := BoxMesh.new()
                bmesh.size = Vector3(0.016, 0.3, 0.016)
                bar.mesh = bmesh
                bar.material_override = metal
                root.add_child(bar)
                var ang := TAU * k / 4.0 + PI / 4.0
                bar.position = Vector3(cos(ang) * 0.115, -0.14, sin(ang) * 0.115)
        # коническая шапка сверху
        var cap := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.0
        cm.bottom_radius = 0.13
        cm.height = 0.09
        cm.radial_segments = 8
        cap.mesh = cm
        cap.material_override = metal
        root.add_child(cap)
        cap.position = Vector3(0, 0.005, 0)
        # ручка-дуга
        var ring := MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 0.014
        tm.outer_radius = 0.055
        tm.rings = 10
        ring.mesh = tm
        ring.material_override = metal
        root.add_child(ring)
        ring.position = Vector3(0, 0.07, 0)
        # светящееся ядро — яркое, чтобы читалось как огонь
        var core := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.07
        sm.height = 0.14
        sm.radial_segments = 8
        sm.rings = 4
        core.mesh = sm
        var cmat := StandardMaterial3D.new()
        cmat.albedo_color = Color(1.0, 0.72, 0.38)
        cmat.emission_enabled = true
        cmat.emission = Color(1.0, 0.6, 0.24)
        cmat.emission_energy_multiplier = 4.0
        cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        core.material_override = cmat
        root.add_child(core)
        core.position = Vector3(0, -0.14, 0)
        # тёплый свет
        var light := OmniLight3D.new()
        light.name = "LanternLight"
        light.light_color = Color(1.0, 0.62, 0.3)
        light.light_energy = 2.1
        light.omni_range = 8.5
        light.shadow_enabled = false
        light.add_to_group("lantern_light")
        root.add_child(light)
        light.position = Vector3(0, -0.14, 0)
        return root
