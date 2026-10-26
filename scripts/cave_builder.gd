extends Node3D
## v5.0: ПЕЩЕРА И ПОДЗЕМЕЛЬЕ. Скальный массив на северо-востоке долины:
## вход-грот с кристаллами, тёмный коридор, большой грот со сталактитами
## и светящимися кристаллами, далее — подземелье: камеры, саркофаги,
## сундуки, кости и босс «Матёрый слизень». Пещерные слизни охраняют грот.
## Всё построено на примитивах с PBR-камнем Poly Haven (CC0).

const EnemyScript := preload("res://scripts/enemy.gd")
const TEX := "res://assets/textures/"

var rng := RandomNumberGenerator.new()
var m_rock: StandardMaterial3D
var m_rock_dark: StandardMaterial3D
var m_masonry: StandardMaterial3D
var m_floor: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_iron: StandardMaterial3D
var m_gold: StandardMaterial3D
var m_bone: StandardMaterial3D

var floor_y := 0.0
var crystal_mats: Array = []


func _ready() -> void:
        add_to_group("cave")
        rng.seed = 424242
        _make_materials()
        var c: Vector2 = GameWorld.CAVE_CENTER
        floor_y = _flat_floor_y(c, 13.0)
        # Разворачиваем входом к деревне
        var to_village: Vector2 = (GameWorld.VILLAGE_CENTER - c).normalized()
        rotation.y = atan2(-to_village.x, -to_village.y)
        position = Vector3(c.x, 0, c.y)
        _build_exterior()
        _build_entrance_corridor()
        _build_cavern()
        _build_dungeon_tunnel()
        _build_dungeon()
        _spawn_cave_enemies()


func _flat_floor_y(c: Vector2, r: float) -> float:
        # v5.0: пол всей пещеры — один уровень, ВЫШЕ рельефа в любой точке
        # маршрута (вход, грот, тоннель, данж), иначе рельеф «протыкает» пол.
        var to_village: Vector2 = (GameWorld.VILLAGE_CENTER - c).normalized()
        var side := Vector2(-to_village.y, to_village.x)
        var top := -1e9
        for zi in 18:
                var lz := -18.0 + float(zi) * 4.0  # локальный z: -18..50
                var wp := c - to_village * lz
                for xi in 5:
                        var lx := -8.0 + float(xi) * 4.0
                        var p := wp + side * lx
                        top = maxf(top, GameWorld.terrain_height(p.x, p.y))
        return top + 0.4


# ---------- МАТЕРИАЛЫ ----------

func _make_materials() -> void:
        # v7.0: пещера — мокрый тёмный камень
        m_rock = _tex_mat("dark_rock", Color(0.52, 0.54, 0.62), 0.32)
        m_rock_dark = _tex_mat("dark_rock", Color(0.26, 0.27, 0.33), 0.4)
        m_masonry = _tex_mat("rocky_terrain_03", Color(0.48, 0.49, 0.55), 0.5)
        m_floor = _tex_mat("rocky_terrain_03", Color(0.20, 0.20, 0.24), 0.55)
        m_wood = _tex_mat("dark_planks", Color(0.42, 0.34, 0.27), 0.6)
        m_iron = StandardMaterial3D.new()
        m_iron.albedo_color = Color(0.16, 0.15, 0.15)
        m_iron.metallic = 0.6
        m_iron.roughness = 0.5
        m_gold = StandardMaterial3D.new()
        m_gold.albedo_color = Color(1.0, 0.8, 0.25)
        m_gold.metallic = 0.8
        m_gold.roughness = 0.3
        m_gold.emission_enabled = true
        m_gold.emission = Color(0.9, 0.65, 0.15)
        m_gold.emission_energy_multiplier = 1.2
        m_bone = StandardMaterial3D.new()
        m_bone.albedo_color = Color(0.82, 0.8, 0.72)
        m_bone.roughness = 0.8


func _tex_mat(id: String, tint: Color, scale: float) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_texture = load(TEX + id + "/" + id + "_diff_2k.jpg")
        m.albedo_color = tint
        m.normal_enabled = true
        # v7.0: у новых наборов нормаль nor_gl, у старых — nor
        var p_gl := TEX + id + "/" + id + "_nor_gl_2k.jpg"
        var p_nor := TEX + id + "/" + id + "_nor_2k.jpg"
        if ResourceLoader.exists(p_gl):
                m.normal_texture = load(p_gl)
        else:
                m.normal_texture = load(p_nor)
        m.roughness = 0.96
        m.uv1_triplanar = true
        m.uv1_scale = Vector3(scale, scale, scale)
        return m


# ---------- ХЕЛПЕРЫ ----------

func _box(size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = size
        mi.mesh = bm
        mi.material_override = m
        mi.position = pos
        mi.rotation = rot
        add_child(mi)
        return mi


func _cyl(rb: float, rt: float, h: float, pos: Vector3, m: Material,
                seg := 10) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = rt
        cm.bottom_radius = rb
        cm.height = h
        cm.radial_segments = seg
        mi.mesh = cm
        mi.material_override = m
        mi.position = pos
        add_child(mi)
        return mi


func _sphere(r: float, pos: Vector3, m: Material) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = r
        sm.height = r * 2.0
        sm.radial_segments = 10
        sm.rings = 6
        mi.mesh = sm
        mi.material_override = m
        mi.position = pos
        add_child(mi)
        return mi


func _collider(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
        var body := StaticBody3D.new()
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        body.add_child(col)
        body.position = pos
        body.rotation = rot
        add_child(body)


func _cyl_collider(r: float, h: float, pos: Vector3) -> void:
        var body := StaticBody3D.new()
        var col := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = r
        shape.height = h
        col.shape = shape
        body.add_child(col)
        body.position = pos
        add_child(body)


## Факел с зелёным «ведьминым» пламенем
func _torch(pos: Vector3, green := true) -> void:
        _cyl(0.05, 0.04, 0.55, pos + Vector3(0, 0.27, 0), m_wood, 6)
        var bowl := _cyl(0.14, 0.09, 0.14, pos + Vector3(0, 0.58, 0), m_iron, 8)
        var flame := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.0
        cm.bottom_radius = 0.11
        cm.height = 0.42
        cm.radial_segments = 7
        flame.mesh = cm
        var fm := StandardMaterial3D.new()
        fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        fm.albedo_color = Color(0.45, 1.0, 0.4, 0.85) if green else Color(1.0, 0.6, 0.2, 0.85)
        fm.emission_enabled = true
        fm.emission = Color(0.35, 0.9, 0.3) if green else Color(1.0, 0.5, 0.12)
        fm.emission_energy_multiplier = 2.6
        flame.material_override = fm
        flame.position = pos + Vector3(0, 0.86, 0)
        add_child(flame)
        var l := OmniLight3D.new()
        l.light_color = Color(0.5, 1.0, 0.45) if green else Color(1.0, 0.65, 0.3)
        l.light_energy = 2.2
        l.omni_range = 8.0
        l.position = pos + Vector3(0, 1.0, 0)
        add_child(l)


## Светящийся кристалл (палка-призма)
func _crystal(pos: Vector3, h: float, r: float, col: Color, tilt := 0.0) -> void:
        var cm := _cyl(r, 0.0, h, pos + Vector3(0, h * 0.5, 0), m_iron, 6)
        var mat := StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.emission_enabled = true
        mat.emission = col
        mat.emission_energy_multiplier = 2.2
        cm.material_override = mat
        cm.rotation.x = tilt
        crystal_mats.append(mat)
        var l := OmniLight3D.new()
        l.light_color = col
        l.light_energy = 2.3
        l.omni_range = 9.0
        l.position = pos + Vector3(0, h * 0.7, 0)
        add_child(l)


# ---------- ВНЕШНОСТЬ: СКАЛЬНЫЙ МАССИВ ----------

func _build_exterior() -> void:
        # Скальная гора: СПЛОШНЫЕ цилиндры-насыпи над помещениями. Низ каждого
        # цилиндра утоплен в перекрытие комнаты, поэтому оболочка никогда не
        # пересекает воздух грота/тоннеля/данжа (в отличие от сфер).
        var caps := [
                # [радиус, высота, x, низ_y, z]
                [15.5, 4.3, 0.0, 6.9, 7.0],    # грот (перекрытие на 6.8..8.0)
                [8.5, 3.0, 0.0, 7.0, -8.0],    # входной коридор (арка до 6.4)
                [7.0, 3.0, 0.0, 4.9, 23.0],    # тоннель (перекрытие 4.45..5.15)
                [13.0, 3.5, 0.0, 5.8, 39.0],   # данж (перекрытие 5.6..6.4)
                [9.0, 2.6, 0.0, 5.2, 31.0],    # стык тоннель-данж
        ]
        for cdef in caps:
                var mound := _cyl(cdef[0], cdef[0] * 0.92, cdef[1],
                                Vector3(cdef[2], cdef[3] + cdef[1] * 0.5, cdef[4]), m_rock, 18)
                mound.scale.y = rng.randf_range(0.9, 1.05)
        # Второй ярус для рельефа
        for i in 5:
                var a := -0.9 + float(i) * 0.45
                _cyl(rng.randf_range(3.0, 5.0), rng.randf_range(2.0, 3.5),
                                rng.randf_range(2.0, 3.2),
                                Vector3(cos(a) * 9.0, floor_y + 9.5 + rng.randf(), 7.0 + sin(a) * 9.0),
                                m_rock, 14)
        # Каменный фартук у входа (сглаживает стык с рельефом)
        var mouth := _local_to_world(Vector3(0, 0, -16))
        var mouth_y := GameWorld.terrain_height(mouth.x, mouth.y)
        var ramp_len := 7.0
        var dy := floor_y - mouth_y
        var apron := _box(Vector3(9.0, 0.5, ramp_len + 3.0),
                Vector3(0, (floor_y + mouth_y) * 0.5 - 0.05, -16.0 - 1.0), m_rock)
        apron.rotation.x = atan2(dy, ramp_len) * 0.9
        _collider(Vector3(9.0, 0.5, ramp_len + 3.0),
                Vector3(0, (floor_y + mouth_y) * 0.5 - 0.05, -17.0),
                Vector3(atan2(dy, ramp_len) * 0.9, 0, 0))
        # Валуны по подножию: грот — кольцом, хребет — только по бокам
        for i in 26:
                var a := TAU * float(i) / 26.0 + 0.2
                var even := i % 2 == 0
                var rr := 15.5 + rng.randf_range(-1.5, 3.5)
                var px := cos(a) * rr
                var pz := (6.0 + sin(a) * rr) if even else (26.0 + sin(a) * rr * 0.8)
                if not even and absf(cos(a)) < 0.55:
                        continue  # не заваливаем центр хребта и данж
                var y := GameWorld.terrain_height(position.x + px, position.z + pz)
                var s2 := _sphere(rng.randf_range(1.6, 3.6),
                        Vector3(px, minf(y, floor_y) - 0.3, pz), m_rock)
                s2.scale = Vector3(1.0, rng.randf_range(0.55, 0.85), 1.0)
        # Портал: два столба, арка и кристаллы у входа
        var ez := -14.0
        _box(Vector3(1.3, 6.2, 1.3), Vector3(-2.9, floor_y + 3.1, ez), m_rock)
        _box(Vector3(1.3, 6.2, 1.3), Vector3(2.9, floor_y + 3.1, ez), m_rock)
        _box(Vector3(7.2, 1.1, 1.5), Vector3(0, floor_y + 6.4, ez), m_rock)
        _box(Vector3(1.4, 0.9, 1.2), Vector3(-1.6, floor_y + 5.7, ez), m_rock,
                        Vector3(0, 0, 0.55))
        _box(Vector3(1.4, 0.9, 1.2), Vector3(1.6, floor_y + 5.7, ez), m_rock,
                        Vector3(0, 0, -0.55))
        _crystal(Vector3(-3.9, floor_y + 0.4, ez + 0.8), 1.6, 0.16,
                        Color(0.4, 0.8, 1.0), 0.2)
        _crystal(Vector3(3.9, floor_y + 0.4, ez + 0.6), 1.2, 0.14,
                        Color(0.7, 0.4, 1.0), -0.15)


func _local_to_world(lp: Vector3) -> Vector2:
        var g := global_transform * Transform3D(Basis.IDENTITY, lp)
        return Vector2(g.origin.x, g.origin.z)


# ---------- ВХОДНОЙ КОРИДОР ----------

func _build_entrance_corridor() -> void:
        # Коридор от портала (z=-14) до грота (z=-2), ширина 4.6, высота 5
        var z0 := -14.0
        var z1 := -2.0
        var length: float = z1 - z0
        var mid_z := (z0 + z1) * 0.5
        # Пол
        _box(Vector3(5.4, 0.5, absf(length) + 1.0), Vector3(0, floor_y - 0.25, mid_z), m_floor)
        _collider(Vector3(5.4, 0.5, absf(length) + 1.0), Vector3(0, floor_y - 0.25, mid_z))
        # Стены (сужаются кверху — псевдоарка)
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(0.9, 5.2, absf(length)), Vector3(sf * 2.75, floor_y + 2.6, mid_z), m_rock)
                _box(Vector3(1.7, 1.6, absf(length)),
                                Vector3(sf * 1.9, floor_y + 4.9, mid_z), m_rock,
                                Vector3(0, 0, -sf * 0.62))
        # Потолок
        _box(Vector3(5.6, 0.8, absf(length)), Vector3(0, floor_y + 5.6, mid_z), m_rock)
        # Факел в коридоре
        _torch(Vector3(1.9, floor_y + 1.4, mid_z), false)


# ---------- ГРОТ ----------

func _build_cavern() -> void:
        var r := 10.5
        var cc_z := 7.0
        var center := Vector3(0, floor_y, cc_z)
        # Плоский пол
        var fl := _cyl(r + 0.6, r + 0.6, 0.6, center + Vector3(0, -0.3, 0), m_floor, 20)
        _cyl_collider(r + 0.4, 0.6, center + Vector3(0, -0.3, 0))
        # Кольцо стен: 16 сегментов
        for i in 16:
                var a := TAU * float(i) / 16.0
                var px := cos(a) * (r + 0.55)
                var pz := cc_z + sin(a) * (r + 0.55)
                var wall := _box(Vector3(4.4, 7.0, 1.4),
                                Vector3(px, floor_y + 3.4, pz), m_rock,
                                Vector3(0, -a + PI * 0.5, 0))
        # Потолок-плита
        var ceil := _cyl(r + 1.2, r + 0.4, 1.2, center + Vector3(0, 7.4, 0), m_rock, 20)
        _cyl_collider(r + 0.8, 1.2, center + Vector3(0, 7.4, 0))
        # Сталактиты
        for i in 12:
                var a := TAU * float(i) / 12.0 + rng.randf() * 0.3
                var rr := rng.randf_range(2.0, r - 1.5)
                var hh := rng.randf_range(0.8, 2.2)
                var st := _cyl(0.05, rng.randf_range(0.25, 0.45), hh,
                                Vector3(cos(a) * rr, floor_y + 6.9 - hh * 0.5, cc_z + sin(a) * rr),
                                m_rock, 6)
                st.rotation.x = PI
        # Сталагмиты
        for i in 8:
                var a := TAU * float(i) / 8.0 + 0.4
                var rr := rng.randf_range(4.0, r - 2.0)
                var hh := rng.randf_range(0.7, 1.8)
                _cyl(rng.randf_range(0.3, 0.5), 0.04, hh,
                                Vector3(cos(a) * rr, floor_y + hh * 0.5, cc_z + sin(a) * rr),
                                m_rock, 6)
        # Кристаллы: бирюза и аметист
        _crystal(Vector3(-4.5, floor_y, cc_z - 3.0), 2.6, 0.28, Color(0.35, 0.8, 1.0))
        _crystal(Vector3(-5.4, floor_y, cc_z - 2.2), 1.7, 0.2, Color(0.35, 0.8, 1.0), 0.25)
        _crystal(Vector3(4.8, floor_y, cc_z + 4.0), 2.2, 0.24, Color(0.65, 0.4, 1.0))
        _crystal(Vector3(5.6, floor_y, cc_z + 3.2), 1.4, 0.18, Color(0.65, 0.4, 1.0), -0.2)
        _crystal(Vector3(0.0, floor_y, cc_z - 6.5), 1.9, 0.2, Color(0.5, 0.9, 1.0))
        # Подсветка грота
        var cl := OmniLight3D.new()
        cl.light_color = Color(0.45, 0.7, 1.0)
        cl.light_energy = 2.4
        cl.omni_range = 20.0
        cl.position = center + Vector3(0, 4.5, 0)
        add_child(cl)
        # Кострище в центре грота
        _torch(center + Vector3(0, 0.05, 0), false)
        for i in 6:
                var a := TAU * float(i) / 6.0
                _sphere(rng.randf_range(0.3, 0.55),
                                center + Vector3(cos(a) * 0.9, 0.15, sin(a) * 0.9), m_rock)
        # Сундук в гроте
        _chest(Vector3(-6.2, floor_y, cc_z + 1.5), -0.7)


# ---------- ТОННЕЛЬ В ПОДЗЕМЕЛЬЕ ----------

func _build_dungeon_tunnel() -> void:
        var z0 := 16.0
        var z1 := 30.0
        var mid_z := (z0 + z1) * 0.5
        var length: float = z1 - z0
        _box(Vector3(4.2, 0.5, length + 1.0), Vector3(0, floor_y - 0.25, mid_z), m_floor)
        _collider(Vector3(4.2, 0.5, length + 1.0), Vector3(0, floor_y - 0.25, mid_z))
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(0.8, 4.4, length), Vector3(sf * 2.1, floor_y + 2.2, mid_z), m_masonry)
                _box(Vector3(1.5, 1.3, length), Vector3(sf * 1.45, floor_y + 4.2, mid_z),
                                m_masonry, Vector3(0, 0, -sf * 0.58))
        _box(Vector3(4.4, 0.7, length), Vector3(0, floor_y + 4.8, mid_z), m_masonry)
        _torch(Vector3(-1.5, floor_y + 1.3, mid_z), true)


# ---------- ПОДЗЕМЕЛЬЕ ----------

func _build_dungeon() -> void:
        var cx := 0.0
        var cz := 39.0
        var wx := 8.5
        var wz := 7.5
        var h := 5.6
        # Пол и потолок
        _box(Vector3(wx * 2.0 + 2.0, 0.5, wz * 2.0 + 2.0), Vector3(cx, floor_y - 0.25, cz), m_floor)
        _collider(Vector3(wx * 2.0 + 2.0, 0.5, wz * 2.0 + 2.0), Vector3(cx, floor_y - 0.25, cz))
        _box(Vector3(wx * 2.0 + 2.0, 0.8, wz * 2.0 + 2.0), Vector3(cx, floor_y + h + 0.4, cz), m_masonry)
        _collider(Vector3(wx * 2.0 + 2.0, 0.8, wz * 2.0 + 2.0), Vector3(cx, floor_y + h + 0.5, cz))
        # Стены (проём в стороне -Z под тоннель шириной 4.4)
        _box(Vector3(wx * 2.0 + 1.2, h, 1.0), Vector3(cx, floor_y + h * 0.5, cz + wz + 0.5), m_masonry)
        _collider(Vector3(wx * 2.0 + 1.2, h, 1.0), Vector3(cx, floor_y + h * 0.5, cz + wz + 0.5))
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(1.0, h, wz * 2.0 + 1.0), Vector3(cx + sf * (wx + 0.5), floor_y + h * 0.5, cz), m_masonry)
                _collider(Vector3(1.0, h, wz * 2.0 + 1.0), Vector3(cx + sf * (wx + 0.5), floor_y + h * 0.5, cz))
        # Передняя стена с проёмом
        var seg_w: float = wx - 2.2
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(seg_w, h, 1.0),
                                Vector3(cx + sf * (2.2 + seg_w * 0.5), floor_y + h * 0.5, cz - wz - 0.5), m_masonry)
                _collider(Vector3(seg_w, h, 1.0),
                                Vector3(cx + sf * (2.2 + seg_w * 0.5), floor_y + h * 0.5, cz - wz - 0.5))
        _box(Vector3(4.4, 1.5, 1.0), Vector3(cx, floor_y + h - 0.75, cz - wz - 0.5), m_masonry)
        _collider(Vector3(4.4, 1.5, 1.0), Vector3(cx, floor_y + h - 0.75, cz - wz - 0.5))
        # Колонны 2x2
        for px in [-4.5, 4.5]:
                for pz in [-3.5, 3.5]:
                        _cyl(0.55, 0.6, h, Vector3(cx + px, floor_y + h * 0.5, cz + pz), m_masonry, 10)
                        _cyl_collider(0.62, h, Vector3(cx + px, floor_y + h * 0.5, cz + pz))
        # Камеры с решётками вдоль правой стены
        for i in 3:
                var bz := cz - 4.5 + float(i) * 4.5
                for k in 7:
                        var bar := _cyl(0.06, 0.06, 3.2,
                                        Vector3(cx + wx - 1.6, floor_y + 1.6, bz - 1.8 + float(k) * 0.6), m_iron, 6)
                _box(Vector3(0.12, 3.6, 0.14), Vector3(cx + wx - 1.6, floor_y + 1.8, bz - 2.1), m_iron)
                _box(Vector3(0.12, 3.6, 0.14), Vector3(cx + wx - 1.6, floor_y + 1.8, bz + 2.1), m_iron)
        # Саркофаг с отодвинутой крышкой
        var sar := Vector3(cx - 4.8, floor_y, cz + 4.6)
        _box(Vector3(2.4, 1.1, 1.1), sar + Vector3(0, 0.55, 0), m_masonry)
        _box(Vector3(2.5, 0.25, 1.2), sar + Vector3(0.5, 1.2, 0.1), m_masonry,
                        Vector3(0, 0.3, 0.06))
        # Алтарь с аметистовым кристаллом
        _box(Vector3(2.4, 1.0, 1.3), Vector3(cx, floor_y + 0.5, cz + wz - 1.6), m_masonry)
        _crystal(Vector3(cx, floor_y + 1.0, cz + wz - 1.6), 1.4, 0.18, Color(0.7, 0.4, 1.0))
        # Сундуки
        _chest(Vector3(cx + 3.0, floor_y, cz - 4.8), 0.4)
        _chest(Vector3(cx + 5.2, floor_y, cz - 2.6), -1.2)
        # Кости
        for i in 9:
                var a := rng.randf() * TAU
                var rr := rng.randf_range(1.0, 6.5)
                var bone_y := floor_y + 0.08
                if rng.randf() < 0.5:
                        var bone := _cyl(0.05, 0.06, rng.randf_range(0.4, 0.8),
                                        Vector3(cx + cos(a) * rr, bone_y, cz + sin(a) * rr), m_bone, 6)
                        bone.rotation_degrees = Vector3(90, rng.randf() * 360, 0)
                else:
                        _sphere(rng.randf_range(0.09, 0.16),
                                        Vector3(cx + cos(a) * rr, bone_y + 0.05, cz + sin(a) * rr), m_bone)
        # Факелы подземелья
        _torch(Vector3(cx - 2.6, floor_y + 1.35, cz - wz - 0.1), true)
        _torch(Vector3(cx + 2.6, floor_y + 1.35, cz - wz - 0.1), true)
        _torch(Vector3(cx - wx + 0.75, floor_y + 1.35, cz + 5.5), true)
        _torch(Vector3(cx - wx + 0.75, floor_y + 1.35, cz - 5.5), true)


func _chest(pos: Vector3, yaw: float) -> void:
        var b := Node3D.new()
        b.position = pos
        b.rotation.y = yaw
        add_child(b)
        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(1.1, 0.62, 0.7)
        body.mesh = bm
        body.material_override = m_wood
        body.position.y = 0.31
        b.add_child(body)
        var lid := MeshInstance3D.new()
        var lm := BoxMesh.new()
        lm.size = Vector3(1.14, 0.22, 0.74)
        lid.mesh = lm
        lid.material_override = m_wood
        lid.position = Vector3(-0.34, 0.72, 0)
        lid.rotation.z = 1.15
        b.add_child(lid)
        var gold := MeshInstance3D.new()
        var gm := BoxMesh.new()
        gm.size = Vector3(0.7, 0.2, 0.4)
        gold.mesh = gm
        gold.material_override = m_gold
        gold.position = Vector3(0.05, 0.66, 0)
        b.add_child(gold)
        _collider(Vector3(1.2, 0.9, 0.8), b.position + Vector3(0, 0.45, 0))
        var l := OmniLight3D.new()
        l.light_color = Color(1.0, 0.8, 0.35)
        l.light_energy = 0.9
        l.omni_range = 3.5
        l.position = Vector3(0, 1.0, 0)
        b.add_child(l)


# ---------- ВРАГИ ПЕЩЕРЫ ----------

func _spawn_cave_enemies() -> void:
        var spots := [
                ["cave", Vector3(-4.0, 0, 4.0)],
                ["cave", Vector3(3.5, 0, 9.0)],
                ["cave", Vector3(0.5, 0, 12.0)],
                        ["bone_lord", Vector3(0.0, 0, 40.0)],
        ]
        for i in spots.size():
                var e := EnemyScript.new()
                e.setup(spots[i][0], 900 + i * 37)
                var lp: Vector3 = spots[i][1]
                e.position = Vector3(lp.x, floor_y + 0.7 * lp.y + 0.7, lp.z)
                add_child(e)
                if spots[i][0] == "bone_lord":
                        var lbl := Label3D.new()
                        lbl.text = "Костяной владыка"
                        lbl.font_size = 40
                        lbl.pixel_size = 0.004
                        lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
                        lbl.modulate = Color(1.0, 0.42, 0.3)
                        lbl.outline_size = 8
                        lbl.position.y = 3.4
                        e.add_child(lbl)
