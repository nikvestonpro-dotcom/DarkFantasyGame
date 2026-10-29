extends Node3D
## v10.0 Деревня № 2 «Каменный Форд» у подножия замкового плато + Готическая
## башня на западной дороге. Домики из НОВЫХ текстур пака (rough_plaster_03
## штукатурка + thatch_roof_angled соломенная крыша + dark_planks брус),
## рынок с товарами (MedievalMarket), погост с оградой, фонари.
## Башня собирается из деталей Castel Pack (Tower_Doorway + Tower_Mid x3 +
## Tower_top_1 + Roof_Cone) с фиолетовым маяком и светящимися окнами.

const TEX := "res://assets/textures/"
const MDL := "res://assets/models/"
const CASTLE_KIT := preload("res://assets/models/packs/Castel Pack/Castel Pack/Castles_and_Forts.glb")
const MARKET := preload("res://assets/models/MedievalMarket/Market.glb")
const PUFF_TEX := preload("res://assets/textures/particles/puff_diff.png")

const HC := Vector2(-108.0, 122.0)
const TC := Vector2(-62.0, 52.0)

var m_plaster: StandardMaterial3D
var m_thatch: StandardMaterial3D
var m_beams: StandardMaterial3D
var m_stone: StandardMaterial3D
var m_rock: StandardMaterial3D
var m_glass_cold: StandardMaterial3D
var m_glass_warm: StandardMaterial3D
var m_door: StandardMaterial3D


func _ready() -> void:
        _make_materials()
        _build_tower()
        _build_hamlet()


func _ptex(id: String, map: String) -> Texture2D:
        return load(TEX + id + "/" + id + "_" + map + "_2k.jpg") as Texture2D


func _make_materials() -> void:
        m_plaster = StandardMaterial3D.new()
        m_plaster.albedo_texture = _ptex("rough_plaster_03", "diff")
        m_plaster.normal_enabled = true
        m_plaster.normal_texture = _ptex("rough_plaster_03", "nor_gl")
        m_plaster.albedo_color = Color(0.52, 0.50, 0.55)  # серо-стальная штукатурка
        m_plaster.roughness = 0.95
        m_plaster.uv1_scale = Vector3(0.32, 0.32, 0.32)

        m_thatch = StandardMaterial3D.new()
        m_thatch.albedo_texture = _ptex("thatch_roof_angled", "diff")
        m_thatch.normal_enabled = true
        m_thatch.normal_texture = _ptex("thatch_roof_angled", "nor_gl")
        m_thatch.albedo_color = Color(0.42, 0.36, 0.26)
        m_thatch.roughness = 1.0
        m_thatch.uv1_scale = Vector3(0.45, 0.45, 0.45)
        # скаты крыши видны и снизу (PlaneMesh односторонний)
        m_thatch.cull_mode = BaseMaterial3D.CULL_DISABLED

        m_beams = StandardMaterial3D.new()
        m_beams.albedo_texture = _ptex("dark_planks", "diff")
        m_beams.albedo_color = Color(0.42, 0.34, 0.26)
        m_beams.roughness = 0.9
        m_beams.uv1_scale = Vector3(0.3, 0.3, 0.3)

        m_stone = StandardMaterial3D.new()
        m_stone.albedo_texture = _ptex("stone_wall", "diff")
        m_stone.normal_enabled = true
        m_stone.normal_texture = _ptex("stone_wall", "nor")
        m_stone.albedo_color = Color(0.48, 0.46, 0.5)
        m_stone.roughness = 0.95
        m_stone.uv1_scale = Vector3(0.22, 0.22, 0.22)

        m_rock = StandardMaterial3D.new()
        m_rock.albedo_texture = _ptex("dark_rock", "diff")
        m_rock.normal_enabled = true
        m_rock.normal_texture = _ptex("dark_rock", "nor_gl")
        m_rock.albedo_color = Color(0.42, 0.40, 0.44)
        m_rock.roughness = 0.95
        m_rock.uv1_scale = Vector3(0.30, 0.30, 0.30)

        m_glass_cold = StandardMaterial3D.new()
        m_glass_cold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m_glass_cold.albedo_color = Color(0.55, 0.68, 0.95, 0.60)
        m_glass_cold.emission_enabled = true
        m_glass_cold.emission = Color(0.45, 0.55, 0.85)
        m_glass_cold.emission_energy_multiplier = 1.15
        m_glass_cold.roughness = 0.15

        m_glass_warm = StandardMaterial3D.new()
        m_glass_warm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m_glass_warm.albedo_color = Color(1.0, 0.72, 0.38, 0.62)
        m_glass_warm.emission_enabled = true
        m_glass_warm.emission = Color(1.0, 0.58, 0.25)
        m_glass_warm.emission_energy_multiplier = 2.0
        m_glass_warm.roughness = 0.15

        m_door = StandardMaterial3D.new()
        m_door.albedo_texture = _ptex("roof_planks", "diff")
        m_door.albedo_color = Color(0.40, 0.32, 0.24)
        m_door.roughness = 0.9
        m_door.uv1_scale = Vector3(0.3, 0.3, 0.3)


func _gy(x: float, z: float) -> float:
        return GameWorld.terrain_height(x, z)


# ---------- ГОТИЧЕСКАЯ БАШНЯ ----------

func _build_tower() -> void:
        var gy := _gy(TC.x, TC.y)
        var root := Node3D.new()
        root.position = Vector3(TC.x, gy - 0.25, TC.y)
        add_child(root)

        var kit := CASTLE_KIT.instantiate()
        # Имена деталей в корне сцены кита
        var S := 1.15  # масштаб башни
        var door := _take_piece(kit, "Tower_Doorway")
        var mid1 := _take_piece(kit, "Tower_Mid")
        var mid2 := _take_piece(kit, "Tower_mid_hollow")
        # третий ярус — обветшалый (в ките он один, придаёт башне возраст)
        var mid3 := _take_piece(kit, "Tower_mid_hollow_ruined")
        var top := _take_piece(kit, "Tower_top_1")
        var cone := _take_piece(kit, "Roof_Cone")

        # цилиндры кита — пивот в центре; ставим ярусами (высота яруса 2м)
        door.position = Vector3(0, 1.0 * S, 0)
        mid1.position = Vector3(0, 3.0 * S, 0)
        mid2.position = Vector3(0, 5.0 * S, 0)
        mid3.position = Vector3(0, 7.0 * S, 0)
        top.position = Vector3(0, 9.08 * S, 0)
        cone.position = Vector3(0, 11.05 * S, 0)
        for p in [door, mid1, mid2, mid3, top, cone]:
                if p == null:
                        continue
                p.rotation = Vector3.ZERO
                p.scale = Vector3.ONE * S
                root.add_child(p)
        kit.queue_free()

        # Разворот дверью на восток — к дороге
        root.rotation.y = PI * 0.5

        # Окна: тусклые проёмы по спирали (без пересвета)
        for i in 5:
                var ang := PI * 0.25 + i * 1.05
                var wy := (2.2 + i * 1.55) * S
                var w := MeshInstance3D.new()
                var bm := BoxMesh.new()
                bm.size = Vector3(0.05, 0.85, 0.45)
                w.mesh = bm
                var wm := StandardMaterial3D.new()
                wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                if i % 2 == 0:
                        wm.albedo_color = Color(0.5, 0.6, 0.9, 0.55)
                        wm.emission_enabled = true
                        wm.emission = Color(0.35, 0.45, 0.75)
                        wm.emission_energy_multiplier = 0.9
                else:
                        wm.albedo_color = Color(1.0, 0.72, 0.38, 0.55)
                        wm.emission_enabled = true
                        wm.emission = Color(1.0, 0.58, 0.25)
                        wm.emission_energy_multiplier = 1.5
                w.material_override = wm
                var r := 1.02 * S
                w.position = Vector3(cos(ang) * r, wy, sin(ang) * r)
                w.rotation.y = -ang
                root.add_child(w)
        # Фиолетовый маяк НАД вершиной конуса (конус 11.05*S+1.28 = 13.98)
        var beacon := OmniLight3D.new()
        beacon.light_color = Color(0.55, 0.30, 0.95)
        beacon.light_energy = 3.0
        beacon.omni_range = 26.0
        beacon.position = Vector3(0, 14.6, 0)
        beacon.add_to_group("tower_beacon")
        root.add_child(beacon)
        # светящаяся точка маяка
        var tip := MeshInstance3D.new()
        var tm := SphereMesh.new()
        tm.radius = 0.26
        tm.height = 0.52
        tm.radial_segments = 10
        tm.rings = 6
        tip.mesh = tm
        var tmam := StandardMaterial3D.new()
        tmam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        tmam.albedo_color = Color(0.85, 0.6, 1.0)
        tmam.emission_enabled = true
        tmam.emission = Color(0.8, 0.5, 1.0)
        tmam.emission_energy_multiplier = 3.5
        tip.material_override = tmam
        tip.position = Vector3(0, 14.4, 0)
        root.add_child(tip)

        var doorlight := OmniLight3D.new()
        doorlight.light_color = Color(1.0, 0.55, 0.25)
        doorlight.light_energy = 1.8
        doorlight.omni_range = 8.0
        doorlight.position = Vector3(1.2 * S, 1.4 * S, 0)
        root.add_child(doorlight)

        # Кольцо крупных камней у подножия кургана
        for i in 12:
                var ang := TAU * i / 12.0 + 0.2
                var rr := 3.6 + 0.4 * sin(i * 2.3)
                var sp := TC + Vector2(cos(ang), sin(ang)) * rr
                var st := MeshInstance3D.new()
                var sm := SphereMesh.new()
                sm.radius = 0.34 + 0.14 * (absf(sin(i * 1.7)))
                sm.height = sm.radius * 1.7
                sm.radial_segments = 6
                sm.rings = 4
                st.mesh = sm
                st.material_override = m_rock
                st.position = Vector3(sp.x, _gy(sp.x, sp.y) + 0.18, sp.y)
                st.rotation = Vector3(0.2 * sin(i), ang, 0.15 * cos(i))
                add_child(st)


func _take_piece(kit: Node, piece_name: String) -> Node3D:
        for child in kit.get_children():
                if child.name == piece_name and child is Node3D:
                        var p := child as Node3D
                        kit.remove_child(p)
                        return p
        return null


# ---------- ДЕРЕВНЯ «КАМЕННЫЙ ФОРД» ----------

func _build_hamlet() -> void:
        # Главная улица повторяет дорогу (СВ -> СЗ). Домики по обе стороны.
        _build_hamlet_house(Vector2(-100.0, 115.0), 6.4, 5.2, 3.0, -PI * 0.75)
        _build_hamlet_house(Vector2(-113.0, 117.5), 5.6, 4.6, 2.8, PI * 0.3)
        _build_hamlet_house(Vector2(-101.5, 128.0), 5.8, 5.0, 2.9, -PI * 0.8)
        _build_hamlet_house(Vector2(-115.0, 130.5), 6.6, 5.4, 3.0, PI * 0.25)
        _build_hamlet_house(Vector2(-106.0, 138.5), 5.2, 4.4, 2.7, PI * 0.9)
        _build_market()
        _build_graveyard()
        _build_hamlet_props()


func _build_hamlet_house(pos: Vector2, w: float, dep: float, wall_h: float, yaw: float) -> void:
        var b := Node3D.new()
        b.position = Vector3(pos.x, _gy(pos.x, pos.y), pos.y)
        b.rotation.y = yaw
        add_child(b)

        # цоколь
        _box(b, Vector3(w + 0.5, 0.6, dep + 0.5), Vector3(0, 0.28, 0), m_stone)
        # стены (штукатурка)
        _box(b, Vector3(w, wall_h, dep), Vector3(0, 0.6 + wall_h * 0.5, 0), m_plaster)
        # угловые балки + пояс (фахверк, тёмный брус)
        for cx in [-w * 0.5 - 0.07, w * 0.5 + 0.07]:
                for cz in [-dep * 0.5 - 0.07, dep * 0.5 + 0.07]:
                        _box(b, Vector3(0.16, wall_h, 0.16),
                                        Vector3(cx, 0.6 + wall_h * 0.5, cz), m_beams)
        _box(b, Vector3(w + 0.2, 0.14, dep + 0.2), Vector3(0, 0.6 + wall_h - 0.08, 0), m_beams)
        _box(b, Vector3(w + 0.2, 0.14, dep + 0.2), Vector3(0, 0.6 + 0.1, 0), m_beams)
        # раскосы на фасаде
        var fz := dep * 0.5 + 0.05
        for cx in [-w * 0.22, w * 0.22]:
                _box(b, Vector3(1.8, 0.1, 0.08), Vector3(cx, 0.6 + wall_h * 0.5, fz),
                                m_beams, Vector3(0, 0, 0.6))
        # двускатная соломенная крыша
        var roof_h := maxf(1.7, w * 0.38)
        var eave := 0.85
        for sgn in [1.0, -1.0]:
                var slope := MeshInstance3D.new()
                var pm := PlaneMesh.new()
                pm.size = Vector2(w + 1.6, sqrt((dep * 0.5 + eave) * (dep * 0.5 + eave) + roof_h * roof_h))
                pm.subdivide_width = 2
                pm.subdivide_depth = 2
                slope.mesh = pm
                slope.material_override = m_thatch
                slope.position = Vector3(0, 0.6 + wall_h + roof_h * 0.5, sgn * (dep * 0.5 + eave) * 0.5)
                slope.rotation.x = sgn * atan2(roof_h, dep * 0.5 + eave)
                # PlaneMesh смотрит вверх — наклоняем в скат
                b.add_child(slope)
        # фронтоны (тёс): треугольники через SurfaceTool
        for sgn in [1.0, -1.0]:
                var gable := MeshInstance3D.new()
                gable.mesh = _gable_mesh(w, roof_h)
                gable.material_override = m_beams
                gable.position = Vector3(0, 0.6 + wall_h, sgn * dep * 0.5)
                b.add_child(gable)
        # конёк
        var ridge := MeshInstance3D.new()
        var rcm := CylinderMesh.new()
        rcm.top_radius = 0.09
        rcm.bottom_radius = 0.11
        rcm.height = w + 1.7
        rcm.radial_segments = 7
        ridge.mesh = rcm
        ridge.material_override = m_beams
        ridge.position = Vector3(0, 0.6 + wall_h + roof_h + 0.05, 0)
        ridge.rotation.z = PI / 2.0
        b.add_child(ridge)

        # дверь на «южном» фасаде (к дороге)
        _box(b, Vector3(0.82, 1.62, 0.09), Vector3(0, 0.6 + 0.82, fz), m_door)
        _box(b, Vector3(0.94, 0.1, 0.14), Vector3(0, 0.6 + 1.66, fz), m_beams)
        # окна: тёплое и холодное
        _window(b, Vector3(-w * 0.28, 0.6 + wall_h * 0.55, fz), 0.0, true)
        _window(b, Vector3(w * 0.3, 0.6 + wall_h * 0.6, fz), 0.0, false)
        _window(b, Vector3(w * 0.5 + 0.05, 0.6 + wall_h * 0.6, 0.0), PI / 2.0, false)

        # труба + дым
        var chim := MeshInstance3D.new()
        var cc := BoxMesh.new()
        cc.size = Vector3(0.55, 1.3, 0.55)
        chim.mesh = cc
        chim.material_override = m_stone
        chim.position = Vector3(w * 0.24, 0.6 + wall_h + roof_h * 0.6, -dep * 0.18)
        b.add_child(chim)
        _smoke(b, chim.position + Vector3(0, 0.75, 0))

        # коллайдер
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(w, wall_h + 2.0, dep)
        col.shape = shape
        col.position = Vector3(0, 0.6 + (wall_h + 2.0) * 0.5, 0)
        b.add_child(col)
        var static_body := StaticBody3D.new()
        # NOTE: CollisionShape должен висеть на StaticBody
        b.remove_child(col)
        static_body.add_child(col)
        b.add_child(static_body)


func _window(parent: Node3D, pos: Vector3, rot_y: float, warm: bool) -> void:
        var glass := m_glass_warm if warm else m_glass_cold
        var fr := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.72, 0.9, 0.07)
        fr.mesh = bm
        fr.material_override = m_beams
        fr.position = pos
        fr.rotation.y = rot_y
        parent.add_child(fr)
        var gl := MeshInstance3D.new()
        var gm := BoxMesh.new()
        gm.size = Vector3(0.58, 0.76, 0.09)
        gl.mesh = gm
        gl.material_override = glass
        gl.position = pos + Vector3(0, 0, 0.0)
        gl.rotation.y = rot_y
        parent.add_child(gl)
        # ставни
        for sgn in [1.0, -1.0]:
                var sh := MeshInstance3D.new()
                var sm := BoxMesh.new()
                sm.size = Vector3(0.26, 0.8, 0.05)
                sh.mesh = sm
                sh.material_override = m_beams
                sh.position = pos + Vector3(sgn * 0.48, 0, 0.02).rotated(Vector3.UP, rot_y)
                sh.rotation.y = rot_y
                parent.add_child(sh)


func _build_market() -> void:
        # Рыночная площадь: навес с товарами (MedievalMarket), фонарь, бочки
        var pos := Vector2(-104.0, 123.5)
        var m := MARKET.instantiate()
        var gy := _gy(pos.x, pos.y)
        m.position = Vector3(pos.x, gy, pos.y)
        m.rotation.y = -PI * 0.7
        m.scale = Vector3(1.15, 1.15, 1.15)
        add_child(m)
        # тёплый свет под навесом
        var light := OmniLight3D.new()
        light.light_color = Color(1.0, 0.6, 0.3)
        light.light_energy = 1.6
        light.omni_range = 10.0
        light.position = Vector3(pos.x, gy + 2.6, pos.y)
        add_child(light)
        # бочки рядом
        var barrel := load(MDL + "barrel_03.glb") as PackedScene
        if barrel != null:
                for i in 3:
                        var bl := barrel.instantiate()
                        var bp := pos + Vector2(2.6 + i * 0.9, -1.2 + 0.4 * i)
                        bl.position = Vector3(bp.x, _gy(bp.x, bp.y), bp.y)
                        bl.rotation.y = i * 1.3
                        bl.scale = Vector3.ONE * (1.5 + 0.1 * i)
                        add_child(bl)


func _build_graveyard() -> void:
        # Погост за западным рядом домов: ограда, надгробия, сухое дерево
        var c := Vector2(-123.0, 127.0)
        var gy := _gy(c.x, c.y)
        var root := Node3D.new()
        root.position = Vector3(c.x, gy, c.y)
        add_child(root)
        # ограда из бруса
        for sgn in [1.0, -1.0]:
                for i in 7:
                        var px := -3.6 + i * 1.2
                        var post := MeshInstance3D.new()
                        var pm := BoxMesh.new()
                        pm.size = Vector3(0.12, 1.0, 0.12)
                        post.mesh = pm
                        post.material_override = m_beams
                        post.position = Vector3(px, 0.5, sgn * 3.6)
                        root.add_child(post)
                var rail := MeshInstance3D.new()
                var rm := BoxMesh.new()
                rm.size = Vector3(7.6, 0.08, 0.08)
                rail.mesh = rm
                rail.material_override = m_beams
                rail.position = Vector3(0, 0.85, sgn * 3.6)
                root.add_child(rail)
        for i in 6:
                var pz := -3.6 + i * 1.2
                var post := MeshInstance3D.new()
                var pm := BoxMesh.new()
                pm.size = Vector3(0.12, 1.0, 0.12)
                post.mesh = pm
                post.material_override = m_beams
                post.position = Vector3(sgn2(i) * 3.6, 0.5, pz)
                root.add_child(post)
        # надгробия (тёмный камень, наклонённые)
        var graves := [
                Vector3(-2.4, 0, -1.8), Vector3(-0.8, 0, -2.2), Vector3(0.7, 0, -1.6),
                Vector3(2.2, 0, -2.0), Vector3(-1.8, 0, 0.6), Vector3(0.4, 0, 1.0),
                Vector3(2.0, 0, 0.2),
        ]
        for gp in graves:
                var g := MeshInstance3D.new()
                var gm := BoxMesh.new()
                gm.size = Vector3(0.55, 0.85, 0.16)
                g.mesh = gm
                g.material_override = m_rock
                g.position = gp + Vector3(0, 0.38, 0)
                g.rotation = Vector3(0.06 * (gp.x + 2.0), 0.3 * sin(gp.z), 0.05 * cos(gp.x))
                root.add_child(g)
                # холмик у надгробия
                var mound := MeshInstance3D.new()
                var mm := SphereMesh.new()
                mm.radius = 0.45
                mm.height = 0.3
                mm.radial_segments = 8
                mm.rings = 4
                mound.mesh = mm
                mound.material_override = m_rock
                mound.scale = Vector3(1, 0.35, 1.2)
                mound.position = gp + Vector3(0, 0.04, 0.55)
                root.add_child(mound)
        # сухое дерево над погостом
        var dead := load(MDL + "dead_tree_trunk.glb") as PackedScene
        if dead != null:
                var dt := dead.instantiate()
                dt.position = Vector3(2.8, 0, -2.6)
                dt.rotation.y = 1.2
                dt.scale = Vector3.ONE * 2.2
                root.add_child(dt)
        # тусклый холодный свет (луна сквозь ветви)
        var gl := OmniLight3D.new()
        gl.light_color = Color(0.35, 0.38, 0.6)
        gl.light_energy = 0.5
        gl.omni_range = 7.0
        gl.position = Vector3(0, 3.0, 0)
        root.add_child(gl)


func _build_hamlet_props() -> void:
        # Колодец в центре, дрова, телега-ящики, фонари вдоль улицы
        var well := load(MDL + "ken_well.fbx") as PackedScene
        if well != null:
                var w := well.instantiate()
                var wp := Vector2(-107.0, 124.0)
                w.position = Vector3(wp.x, _gy(wp.x, wp.y), wp.y)
                w.rotation.y = 0.8
                w.scale = Vector3.ONE * 1.3
                add_child(w)
        # костровище у колодца
        var cf := Vector2(-105.2, 125.5)
        var fire := Node3D.new()
        fire.position = Vector3(cf.x, _gy(cf.x, cf.y), cf.y)
        add_child(fire)
        for j in 2:
                var flame := MeshInstance3D.new()
                var cm := CylinderMesh.new()
                cm.top_radius = 0.0
                cm.bottom_radius = 0.26 - j * 0.07
                cm.height = 0.6 - j * 0.16
                cm.radial_segments = 8
                flame.mesh = cm
                var fm := StandardMaterial3D.new()
                fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                fm.albedo_color = Color(1.0, 0.55 - j * 0.1, 0.15, 0.85)
                fm.emission_enabled = true
                fm.emission = Color(1.0, 0.45, 0.1)
                fm.emission_energy_multiplier = 2.2
                flame.material_override = fm
                flame.position = Vector3(0, 0.3 + j * 0.22, 0)
                flame.add_to_group("campfire_flame")
                fire.add_child(flame)
        var fl := OmniLight3D.new()
        fl.light_color = Color(1.0, 0.6, 0.25)
        fl.light_energy = 2.8
        fl.omni_range = 13.0
        fl.position = Vector3(0, 1.1, 0)
        fl.add_to_group("campfire_light")
        fire.add_child(fl)
        _smoke(fire, Vector3(0, 0.8, 0))

        # фонари вдоль улицы (по дороге СВ->СЗ)
        var lantern_spots := [
                Vector2(-102.0, 119.0), Vector2(-111.0, 122.5),
                Vector2(-105.0, 127.5), Vector2(-113.0, 131.0),
        ]
        for lp in lantern_spots:
                _hamlet_lantern(lp)
        # навесы дров у домов
        var wood := load(MDL + "quat_medieval_house.fbx") as PackedScene
        for wp in [Vector2(-99.0, 122.0), Vector2(-117.5, 125.0)]:
                var pile := MeshInstance3D.new()
                var pm := BoxMesh.new()
                pm.size = Vector3(1.3, 0.8, 0.7)
                pile.mesh = pm
                pile.material_override = m_beams
                pile.position = Vector3(wp.x, _gy(wp.x, wp.y) + 0.4, wp.y)
                pile.rotation.y = 0.5
                add_child(pile)


func _hamlet_lantern(p: Vector2) -> void:
        var b := Node3D.new()
        b.position = Vector3(p.x, _gy(p.x, p.y), p.y)
        add_child(b)
        _box(b, Vector3(0.13, 2.9, 0.13), Vector3(0, 1.45, 0), m_beams)
        _box(b, Vector3(0.46, 0.07, 0.07), Vector3(0.18, 2.8, 0), m_beams)
        var box := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.36, 0.44, 0.36)
        box.mesh = bm
        box.material_override = m_glass_warm
        box.position = Vector3(0.34, 2.54, 0)
        b.add_child(box)
        var light := OmniLight3D.new()
        light.light_color = Color(1.0, 0.66, 0.32)
        light.light_energy = 1.4
        light.omni_range = 8.0
        light.position = Vector3(0.34, 2.54, 0)
        b.add_child(light)


func _smoke(parent: Node3D, pos: Vector3) -> void:
        var p := GPUParticles3D.new()
        p.amount = 10
        p.lifetime = 5.0
        p.preprocess = 5.0
        p.position = pos
        var pm := ParticleProcessMaterial.new()
        pm.direction = Vector3(0.04, 1, 0.02)
        pm.spread = 6.0
        pm.initial_velocity_min = 0.35
        pm.initial_velocity_max = 0.6
        pm.gravity = Vector3(0, 0.25, 0)
        pm.damping_min = 0.04
        pm.damping_max = 0.12
        pm.scale_min = 0.6
        pm.scale_max = 1.6
        pm.angular_velocity_min = -1.2
        pm.angular_velocity_max = 1.2
        var g := Gradient.new()
        g.set_color(0, Color(0.35, 0.36, 0.42, 0.0))
        g.set_color(1, Color(0.3, 0.31, 0.38, 0.0))
        g.add_point(0.3, Color(0.36, 0.37, 0.44, 0.16))
        var gt := GradientTexture1D.new()
        gt.gradient = g
        pm.color_ramp = gt
        p.process_material = pm
        var q := QuadMesh.new()
        q.size = Vector2(0.85, 0.85)
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.vertex_color_use_as_albedo = true
        m.albedo_texture = PUFF_TEX
        q.material = m
        p.draw_pass_1 = q
        parent.add_child(p)


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material,
                rot := Vector3.ZERO) -> void:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = size
        mi.mesh = bm
        mi.material_override = m
        mi.position = pos
        mi.rotation = rot
        parent.add_child(mi)


func sgn2(i: int) -> float:
        return 1.0 if i % 2 == 0 else -1.0


func _gable_mesh(w: float, roof_h: float) -> ArrayMesh:
        ## Треугольный фронтон (двусторонний): (-w/2,0) (w/2,0) (0,roof_h)
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var hw := w * 0.5
        # лицевая сторона (+Z)
        st.set_normal(Vector3(0, 0, 1))
        st.add_vertex(Vector3(-hw, 0, 0.02))
        st.add_vertex(Vector3(hw, 0, 0.02))
        st.add_vertex(Vector3(0, roof_h, 0.02))
        # обратная сторона (-Z)
        st.set_normal(Vector3(0, 0, -1))
        st.add_vertex(Vector3(hw, 0, -0.02))
        st.add_vertex(Vector3(-hw, 0, -0.02))
        st.add_vertex(Vector3(0, roof_h, -0.02))
        return st.commit()
