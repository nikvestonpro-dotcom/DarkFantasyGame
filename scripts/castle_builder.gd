extends Node3D
## v5.0: ГОТИЧЕСКИЙ ЗАМОК на юго-западном плато. Стены с зубцами,
## четыре угловые башни со шпилями и штандартами, надвратная с стрельчатой
## аркой и решёткой, донжон с тронным залом (колонны, люстра, трон,
## роза-окно), часовня-крипта с саркофагами и боссом, ведьмин огонь.
## Все текстуры — Poly Haven CC0 (камень, кладка, черепица, тёмные доски).

const EnemyScript := preload("res://scripts/enemy.gd")
const NpcScript := preload("res://scripts/npc.gd")
const M_GHOST := preload("res://assets/models/kay_Mage.glb")
const TEX := "res://assets/textures/"

const GY: float = GameWorld.CASTLE_HEIGHT

var rng := RandomNumberGenerator.new()
var m_stone: StandardMaterial3D
var m_stone_dark: StandardMaterial3D
var m_masonry: StandardMaterial3D
var m_trim: StandardMaterial3D
var m_roof: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_door: StandardMaterial3D
var m_iron: StandardMaterial3D
var m_banner: StandardMaterial3D
var m_banner_gold: StandardMaterial3D
var m_glass_cold: StandardMaterial3D
var m_glass_warm: StandardMaterial3D
var m_carpet: StandardMaterial3D
var m_throne: StandardMaterial3D
var m_gold: StandardMaterial3D
var m_bone: StandardMaterial3D


func _ready() -> void:
        add_to_group("castle")
        rng.seed = 777888
        _make_materials()
        var c: Vector2 = GameWorld.CASTLE_CENTER
        var to_village: Vector2 = (GameWorld.VILLAGE_CENTER - c).normalized()
        rotation.y = atan2(to_village.x, to_village.y)
        position = Vector3(c.x, GY, c.y)
        _build_walls()
        _build_gatehouse()
        _build_towers()
        _build_keep()
        _build_chapel()
        _build_courtyard()
        _spawn_castle_enemies()
        _spawn_ghost()


# ---------- МАТЕРИАЛЫ ----------

func _make_materials() -> void:
        m_stone = _tex_mat("stone_wall", Color(0.78, 0.79, 0.84), 0.45)
        m_stone_dark = _tex_mat("stone_wall", Color(0.5, 0.52, 0.58), 0.5)
        m_masonry = _tex_mat("castle_wall_varriation", Color(0.72, 0.73, 0.78), 0.42)
        m_trim = _tex_mat("castle_wall_varriation", Color(0.55, 0.56, 0.62), 0.6)
        m_roof = _tex_mat("roof_planks", Color(0.42, 0.44, 0.5), 0.6)
        m_wood = _tex_mat("dark_planks", Color(0.5, 0.42, 0.34), 0.55)
        m_door = _tex_mat("dark_planks", Color(0.4, 0.3, 0.22), 0.7)
        m_iron = StandardMaterial3D.new()
        m_iron.albedo_color = Color(0.13, 0.13, 0.14)
        m_iron.metallic = 0.65
        m_iron.roughness = 0.45
        m_banner = StandardMaterial3D.new()
        m_banner.albedo_color = Color(0.42, 0.08, 0.1)
        m_banner.roughness = 0.9
        m_banner_gold = StandardMaterial3D.new()
        m_banner_gold.albedo_color = Color(0.85, 0.68, 0.25)
        m_banner_gold.metallic = 0.5
        m_banner_gold.roughness = 0.4
        m_glass_cold = StandardMaterial3D.new()
        m_glass_cold.albedo_color = Color(0.5, 0.7, 1.0, 0.9)
        m_glass_cold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m_glass_cold.emission_enabled = true
        m_glass_cold.emission = Color(0.45, 0.65, 1.0)
        m_glass_cold.emission_energy_multiplier = 2.0
        m_glass_warm = StandardMaterial3D.new()
        m_glass_warm.albedo_color = Color(1.0, 0.72, 0.35, 0.9)
        m_glass_warm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m_glass_warm.emission_enabled = true
        m_glass_warm.emission = Color(1.0, 0.65, 0.25)
        m_glass_warm.emission_energy_multiplier = 2.6
        m_carpet = StandardMaterial3D.new()
        m_carpet.albedo_color = Color(0.4, 0.07, 0.08)
        m_carpet.roughness = 1.0
        m_throne = StandardMaterial3D.new()
        m_throne.albedo_color = Color(0.15, 0.14, 0.16)
        m_throne.metallic = 0.3
        m_throne.roughness = 0.6
        m_gold = StandardMaterial3D.new()
        m_gold.albedo_color = Color(0.9, 0.72, 0.25)
        m_gold.metallic = 0.8
        m_gold.roughness = 0.35
        m_bone = StandardMaterial3D.new()
        m_bone.albedo_color = Color(0.8, 0.78, 0.7)
        m_bone.roughness = 0.85


func _tex_mat(id: String, tint: Color, scale: float) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_texture = load(TEX + id + "/" + id + "_diff_2k.jpg")
        m.albedo_color = tint
        m.normal_enabled = true
        m.normal_texture = load(TEX + id + "/" + id + "_nor_2k.jpg")
        m.roughness = 0.95
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
                seg := 12) -> MeshInstance3D:
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


## Зубцы вдоль стены от a до b (вдоль оси axis)
func _crenellate(a: Vector2, b: Vector2, y: float, m: Material) -> void:
        var length := a.distance_to(b)
        var n := int(length / 2.4)
        var dir := (b - a).normalized()
        for i in n + 1:
                var p := a + dir * (length * float(i) / float(maxf(n, 1)))
                _box(Vector3(1.4, 1.25, 2.5), Vector3(p.x, y + 0.62, p.y), m,
                                Vector3(0, -atan2(dir.y, dir.x) + PI * 0.5, 0))


## Стрельчатое готическое окно: тёплое или холодное стекло
func _gothic_window(pos: Vector3, rot_y: float, w: float, h: float,
                cold := true) -> void:
        var b := Node3D.new()
        b.position = pos
        b.rotation.y = rot_y
        add_child(b)
        var glass: StandardMaterial3D = m_glass_cold if cold else m_glass_warm
        # Стекло: прямоугольник + два наклонных сегмента к стрельчатой вершине
        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(w, h * 0.62, 0.1)
        body.mesh = bm
        body.material_override = glass
        body.position.y = h * 0.31
        b.add_child(body)
        var top_len: float = h * 0.52
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                var seg := MeshInstance3D.new()
                var sm := BoxMesh.new()
                sm.size = Vector3(w * 0.55, top_len, 0.1)
                seg.mesh = sm
                seg.material_override = glass
                seg.position = Vector3(sf * w * 0.24, h * 0.62 + top_len * 0.32, 0)
                seg.rotation.z = -sf * 0.55
                b.add_child(seg)
        # Каменное обрамление
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                var jam := MeshInstance3D.new()
                var jm := BoxMesh.new()
                jm.size = Vector3(0.22, h * 0.66, 0.26)
                jam.mesh = jm
                jam.material_override = m_trim
                jam.position = Vector3(sf * (w * 0.5 + 0.12), h * 0.33, 0.02)
                b.add_child(jam)
        # Переплёт
        var mull := MeshInstance3D.new()
        var mm := BoxMesh.new()
        mm.size = Vector3(0.05, h * 0.62, 0.13)
        mull.mesh = mm
        mull.material_override = m_iron
        mull.position.y = h * 0.31
        b.add_child(mull)


## Бра с ведьмин огнём
func _brazier(pos: Vector3, green := true) -> void:
        _cyl(0.32, 0.2, 0.9, pos + Vector3(0, 0.45, 0), m_iron, 8)
        _cyl(0.42, 0.3, 0.24, pos + Vector3(0, 0.95, 0), m_iron, 10)
        var flame := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.0
        cm.bottom_radius = 0.24
        cm.height = 0.75
        cm.radial_segments = 8
        flame.mesh = cm
        var fm := StandardMaterial3D.new()
        fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        fm.albedo_color = Color(0.45, 1.0, 0.4, 0.85) if green else Color(1.0, 0.6, 0.2, 0.85)
        fm.emission_enabled = true
        fm.emission = Color(0.35, 0.9, 0.3) if green else Color(1.0, 0.5, 0.12)
        fm.emission_energy_multiplier = 3.0
        flame.material_override = fm
        flame.position = pos + Vector3(0, 1.4, 0)
        add_child(flame)
        var l := OmniLight3D.new()
        l.light_color = Color(0.5, 1.0, 0.45) if green else Color(1.0, 0.65, 0.3)
        l.light_energy = 2.6
        l.omni_range = 10.0
        l.position = pos + Vector3(0, 1.7, 0)
        add_child(l)


func _flag(pos: Vector3, h: float) -> void:
        _cyl(0.06, 0.05, h, pos + Vector3(0, h * 0.5, 0), m_iron, 6)
        _box(Vector3(1.5, 0.9, 0.06), pos + Vector3(0.78, h - 0.75, 0), m_banner)
        _box(Vector3(1.5, 0.14, 0.08), pos + Vector3(0.78, h - 1.22, 0), m_banner_gold)


# ---------- СТЕНЫ ----------

func _build_walls() -> void:
        var hx := 20.0
        var hz := 17.0
        var wh := 8.0
        var th := 2.2
        # Передняя стена (z=+hz) с проёмом ворот 4.6 м
        var seg_w: float = hx - 2.3
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                var cx := sf * (2.3 + seg_w * 0.5)
                _box(Vector3(seg_w, wh, th), Vector3(cx, wh * 0.5, hz), m_masonry)
                _collider(Vector3(seg_w, wh, th), Vector3(cx, wh * 0.5, hz))
        # Задняя и боковые
        _box(Vector3(hx * 2.0, wh, th), Vector3(0, wh * 0.5, -hz), m_masonry)
        _collider(Vector3(hx * 2.0, wh, th), Vector3(0, wh * 0.5, -hz))
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(th, wh, hz * 2.0), Vector3(sf * hx, wh * 0.5, 0), m_masonry)
                _collider(Vector3(th, wh, hz * 2.0), Vector3(sf * hx, wh * 0.5, 0))
        # Пешеходная кромка поверх стен
        _box(Vector3(hx * 2.0 + th, 0.25, th + 0.7), Vector3(0, wh + 0.12, -hz), m_trim)
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(th + 0.7, 0.25, hz * 2.0 - 2.0), Vector3(sf * hx, wh + 0.12, 0), m_trim)
                for zseg in [-1.0, 1.0]:
                        var zf: float = zseg
                        var wall_len: float = seg_w if zf > 0.0 else hx * 2.0
                        var wall_cx: float = (sf * (2.3 + seg_w * 0.5)) if zf > 0.0 else 0.0
                        _box(Vector3(wall_len, 0.25, th + 0.7),
                                        Vector3(wall_cx, wh + 0.12, zf * hz), m_trim)
        # Зубцы по всем стенам
        _crenellate(Vector2(-hx, -hz - th * 0.3), Vector2(hx, -hz - th * 0.3), wh + 0.25, m_trim)
        _crenellate(Vector2(-hx, hz - th * 0.3), Vector2(-2.3, hz - th * 0.3), wh + 0.25, m_trim)
        _crenellate(Vector2(2.3, hz - th * 0.3), Vector2(hx, hz - th * 0.3), wh + 0.25, m_trim)
        _crenellate(Vector2(-hx - th * 0.3, -hz + 1.0), Vector2(-hx - th * 0.3, hz - 1.0), wh + 0.25, m_trim)
        _crenellate(Vector2(hx + th * 0.3, -hz + 1.0), Vector2(hx + th * 0.3, hz - 1.0), wh + 0.25, m_trim)
        # Стрельчатые окна-бойницы на стенах (холодное свечение)
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _gothic_window(Vector3(sf * 8.0, 4.6, hz - th * 0.5 - 0.02), PI, 0.8, 2.4)
                _gothic_window(Vector3(sf * 14.0, 4.6, -hz + th * 0.5 + 0.02), 0.0, 0.8, 2.4)
                _gothic_window(Vector3(sf * (hx - th * 0.5 - 0.02), 4.6, 6.0), PI * 0.5, 0.8, 2.4)
                _gothic_window(Vector3(sf * (hx - th * 0.5 - 0.02), 4.6, -6.0), PI * 0.5, 0.8, 2.4)


# ---------- НАДВРАТНАЯ ----------

func _build_gatehouse() -> void:
        var gz := 17.0
        # Две фланкирующие башни
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                var tx := sf * 3.9
                _cyl(2.6, 2.7, 12.0, Vector3(tx, 6.0, gz), m_masonry, 14)
                _cyl_collider(2.7, 12.0, Vector3(tx, 6.0, gz))
                _cyl(2.9, 2.95, 0.8, Vector3(tx, 12.3, gz), m_trim, 14)
                _crenellate(Vector2(tx - 2.2, gz - 0.9), Vector2(tx + 2.2, gz - 0.9), 12.7, m_trim)
                _crenellate(Vector2(tx - 2.2, gz + 0.9), Vector2(tx + 2.2, gz + 0.9), 12.7, m_trim)
                # Шпиль
                var cone := _cyl(2.55, 0.0, 4.2, Vector3(tx, 14.8, gz), m_roof, 14)
                cone.rotation_degrees.x = 0.0
                _cyl(0.14, 0.12, 1.2, Vector3(tx, 17.4, gz), m_iron, 6)
                _box(Vector3(0.9, 0.55, 0.05), Vector3(tx + 0.5, 17.1, gz), m_banner)
        # Перемычка над воротами со стрельчатой аркой
        _box(Vector3(10.4, 2.6, 2.4), Vector3(0, 7.0, gz), m_masonry)
        _collider(Vector3(10.4, 2.6, 2.4), Vector3(0, 7.0, gz))
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(1.1, 1.9, 2.5), Vector3(sf * 1.95, 5.5, gz), m_masonry,
                                Vector3(0, 0, -sf * 0.5))
        # Свод арки
        _box(Vector3(3.6, 0.6, 2.4), Vector3(0, 5.35, gz), m_trim)
        # Поднятая решётка (видна в верхней части проёма)
        for k in 5:
                var bx := -1.6 + float(k) * 0.8
                _cyl(0.07, 0.07, 2.2, Vector3(bx, 4.4, gz), m_iron, 6)
        _cyl(0.07, 0.07, 3.6, Vector3(0, 4.55, gz - 0.9), m_iron, 6)
        # Распахнутые створки ворот
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(1.9, 4.9, 0.16), Vector3(sf * 2.55, 2.45, gz - 1.28),
                                m_door, Vector3(0, sf * 0.62, 0))
                _collider(Vector3(0.3, 4.9, 1.9), Vector3(sf * 2.9, 2.45, gz - 1.85),
                                Vector3(0, sf * 0.62, 0))
        # Факелы по сторонам ворот (снаружи)
        _brazier(Vector3(-3.6, 0, gz + 2.6), false)
        _brazier(Vector3(3.6, 0, gz + 2.6), false)


# ---------- УГЛОВЫЕ БАШНИ ----------

func _build_towers() -> void:
        var hx := 20.0
        var hz := 17.0
        for tx in [-1.0, 1.0]:
                for tz in [-1.0, 1.0]:
                        var xf: float = tx
                        var zf: float = tz
                        var pos := Vector3(xf * hx, 0, zf * hz)
                        _cyl(4.1, 4.25, 15.0, pos + Vector3(0, 7.5, 0), m_masonry, 16)
                        _cyl_collider(4.25, 15.0, pos + Vector3(0, 7.5, 0))
                        _cyl(4.5, 4.55, 0.9, pos + Vector3(0, 15.4, 0), m_trim, 16)
                        # Зубцы кольцом
                        for i in 10:
                                var a := TAU * float(i) / 10.0
                                var mx := pos.x + cos(a) * 4.35
                                var mz := pos.z + sin(a) * 4.35
                                _box(Vector3(1.5, 1.2, 1.5), Vector3(mx, 16.4, mz), m_trim,
                                                Vector3(0, -a, 0))
                        # Шпиль и флаг
                        _cyl(4.2, 0.0, 6.0, pos + Vector3(0, 18.9, 0), m_roof, 16)
                        _cyl(0.12, 0.1, 1.6, pos + Vector3(0, 22.6, 0), m_iron, 6)
                        _flag(pos + Vector3(0, 23.0, 0), 0.01 + 1.8)
                        # Окна-бойницы
                        var to_c := Vector2(-pos.x, -pos.z).normalized()
                        _gothic_window(pos + Vector3(to_c.x * 4.3, 9.0, to_c.y * 4.3),
                                        atan2(-to_c.x, -to_c.y) + PI, 0.7, 2.0)


# ---------- ДОНЖОН ----------

func _build_keep() -> void:
        var kz := -7.0
        var kw := 15.0
        var kd := 11.0
        var hall_h := 6.4
        # Пол зала
        _box(Vector3(kw + 1.0, 0.5, kd + 1.0), Vector3(0, 0.2, kz), m_stone_dark)
        # Стены зала (фронт с дверным проёмом 2.8)
        var back := _box(Vector3(kw, hall_h, 0.6), Vector3(0, hall_h * 0.5, kz - kd * 0.5), m_stone)
        _collider(Vector3(kw, hall_h, 0.6), Vector3(0, hall_h * 0.5, kz - kd * 0.5))
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(0.6, hall_h, kd), Vector3(sf * kw * 0.5, hall_h * 0.5, kz), m_stone)
                _collider(Vector3(0.6, hall_h, kd), Vector3(sf * kw * 0.5, hall_h * 0.5, kz))
        var fseg: float = kw * 0.5 - 1.4
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(fseg, hall_h, 0.6),
                                Vector3(sf * (1.4 + fseg * 0.5), hall_h * 0.5, kz + kd * 0.5), m_stone)
                _collider(Vector3(fseg, hall_h, 0.6),
                                Vector3(sf * (1.4 + fseg * 0.5), hall_h * 0.5, kz + kd * 0.5))
        _box(Vector3(2.8, hall_h - 4.4, 0.6), Vector3(0, 4.4 + (hall_h - 4.4) * 0.5, kz + kd * 0.5), m_stone)
        _collider(Vector3(2.8, hall_h - 4.4, 0.6), Vector3(0, 4.4 + (hall_h - 4.4) * 0.5, kz + kd * 0.5))
        # Каменный портал двери
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(0.35, 4.6, 0.8), Vector3(sf * 1.6, 2.3, kz + kd * 0.5), m_trim)
                _box(Vector3(0.9, 1.5, 0.8), Vector3(sf * 1.1, 4.9, kz + kd * 0.5), m_trim,
                                Vector3(0, 0, -sf * 0.5))
        # Верхний массив донжона
        var up_h := 8.0
        _box(Vector3(kw + 0.8, up_h, kd + 0.8), Vector3(0, hall_h + up_h * 0.5, kz), m_masonry)
        _collider(Vector3(kw + 0.8, up_h, kd + 0.8), Vector3(0, hall_h + up_h * 0.5, kz))
        # Контрфорсы по углам
        for tx in [-1.0, 1.0]:
                for tz in [-1.0, 1.0]:
                        var xf: float = tx
                        var zf: float = tz
                        _box(Vector3(1.4, 5.2, 1.4),
                                        Vector3(xf * (kw * 0.5 + 0.4), 2.6, kz + zf * (kd * 0.5 + 0.4)),
                                        m_trim, Vector3(zf * 0.1, 0, -xf * 0.1))
        # Готические окна верхнего яруса (холодные) + роза
        for wx in [-4.6, 0.0, 4.6]:
                _gothic_window(Vector3(wx, hall_h + 4.6, kz + kd * 0.5 + 0.44), 0.0, 1.1, 2.6)
                _gothic_window(Vector3(wx, hall_h + 4.6, kz - kd * 0.5 - 0.44), PI, 1.1, 2.6)
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _gothic_window(Vector3(sf * (kw * 0.5 + 0.44), hall_h + 4.6, kz), PI * 0.5, 1.1, 2.6)
        # Роза-окно над порталом
        var rose := _cyl(1.55, 1.55, 0.22, Vector3(0, hall_h + 6.3, kz + kd * 0.5 + 0.45), m_glass_warm, 20)
        rose.rotation_degrees.x = 90
        var rose_frame := _cyl(1.75, 1.75, 0.3, Vector3(0, hall_h + 6.3, kz + kd * 0.5 + 0.42), m_trim, 20)
        rose_frame.rotation_degrees.x = 90
        var rl := OmniLight3D.new()
        rl.light_color = Color(1.0, 0.7, 0.3)
        rl.light_energy = 2.0
        rl.omni_range = 10.0
        rl.position = Vector3(0, hall_h + 6.0, kz + kd * 0.5 + 1.4)
        add_child(rl)
        # Штандарты на фасаде
        for bx in [-3.2, 3.2]:
                _box(Vector3(1.05, 3.4, 0.09), Vector3(bx, hall_h + 2.6, kz + kd * 0.5 + 0.48), m_banner)
                _box(Vector3(1.05, 0.18, 0.11), Vector3(bx, hall_h + 4.15, kz + kd * 0.5 + 0.48), m_banner_gold)
        # Готическая кровля
        var span := kw * 0.5 + 1.0
        var roof_h := 5.0
        var slope_len: float = sqrt(span * span + roof_h * roof_h)
        var ang: float = atan2(roof_h, span)
        var roof_y := hall_h + up_h
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(slope_len + 0.2, 0.5, kd + 1.6),
                                Vector3(sf * span * 0.5, roof_y + roof_h * 0.5 + 0.05, kz),
                                m_roof, Vector3(0, 0, -sf * ang))
        for sz in [-1.0, 1.0]:
                var zf: float = sz
                var gable := MeshInstance3D.new()
                var pm := PrismMesh.new()
                pm.size = Vector3(kw + 0.8, roof_h, 0.3)
                pm.left_to_right = 0.5
                gable.mesh = pm
                gable.material_override = m_masonry
                gable.position = Vector3(0, roof_y + roof_h * 0.5, kz + zf * (kd * 0.5 + 0.42))
                add_child(gable)
        var ridge := _cyl(0.16, 0.16, kd + 1.8, Vector3(0, roof_y + roof_h + 0.05, kz), m_iron, 8)
        ridge.rotation_degrees.x = 90
        # Пинаклы по углам верхнего яруса
        for tx in [-1.0, 1.0]:
                for tz in [-1.0, 1.0]:
                        var xf: float = tx
                        var zf: float = tz
                        var px := xf * (kw * 0.5 + 0.35)
                        var pz := kz + zf * (kd * 0.5 + 0.35)
                        _cyl(0.28, 0.24, 2.6, Vector3(px, roof_y + 1.3, pz), m_trim, 8)
                        _cyl(0.3, 0.0, 1.1, Vector3(px, roof_y + 3.1, pz), m_roof, 8)

        # --- Тронный зал (интерьер) ---
        # Ковёр от двери к трону
        _box(Vector3(2.4, 0.06, kd - 2.0), Vector3(0, 0.48, kz + 1.2), m_carpet)
        # Помост и трон
        _box(Vector3(4.2, 0.36, 2.8), Vector3(0, 0.66, kz - kd * 0.5 + 1.6), m_stone_dark)
        _box(Vector3(3.4, 0.3, 2.2), Vector3(0, 0.99, kz - kd * 0.5 + 1.6), m_stone_dark)
        _box(Vector3(1.3, 0.55, 1.0), Vector3(0, 1.42, kz - kd * 0.5 + 1.3), m_throne)
        _box(Vector3(1.4, 2.5, 0.22), Vector3(0, 2.35, kz - kd * 0.5 + 0.85), m_throne)
        _box(Vector3(1.5, 0.16, 0.7), Vector3(0, 3.35, kz - kd * 0.5 + 0.9), m_gold)
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(0.18, 0.9, 1.0), Vector3(sf * 0.72, 1.9, kz - kd * 0.5 + 1.3), m_throne)
        # Колонны
        for px in [-4.4, 4.4]:
                for pz in [-2.6, 2.6]:
                        _cyl(0.5, 0.55, hall_h, Vector3(px, hall_h * 0.5 + 0.45, kz + pz), m_stone_dark, 12)
                        _cyl_collider(0.56, hall_h, Vector3(px, hall_h * 0.5 + 0.45, kz + pz))
        # Люстра-канделябр
        var ch := _cyl(0.09, 0.09, 1.4, Vector3(0, hall_h - 0.7, kz), m_iron, 6)
        var ring := MeshInstance3D.new()
        var rm := TorusMesh.new()
        rm.inner_radius = 1.0
        rm.outer_radius = 1.12
        ring.mesh = rm
        ring.material_override = m_iron
        ring.position = Vector3(0, hall_h - 1.35, kz)
        add_child(ring)
        for i in 6:
                var a := TAU * float(i) / 6.0
                var candle := _cyl(0.05, 0.05, 0.4,
                                Vector3(cos(a) * 1.06, hall_h - 1.05, kz + sin(a) * 1.06),
                                m_glass_warm, 6)
        var cl := OmniLight3D.new()
        cl.light_color = Color(1.0, 0.72, 0.38)
        cl.light_energy = 3.0
        cl.omni_range = 13.0
        cl.position = Vector3(0, hall_h - 1.8, kz)
        add_child(cl)
        # Гобелены на стенах зала
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(0.08, 2.6, 1.3), Vector3(sf * (kw * 0.5 - 0.42), 2.9, kz - 1.6), m_banner)
                _box(Vector3(0.1, 0.14, 1.34), Vector3(sf * (kw * 0.5 - 0.42), 4.14, kz - 1.6), m_banner_gold)
                _box(Vector3(0.08, 2.6, 1.3), Vector3(sf * (kw * 0.5 - 0.42), 2.9, kz + 1.9), m_banner)
                _box(Vector3(0.1, 0.14, 1.34), Vector3(sf * (kw * 0.5 - 0.42), 4.14, kz + 1.9), m_banner_gold)
        # Бра в зале
        _brazier(Vector3(-5.6, 0.45, kz + kd * 0.5 - 1.2), false)


# ---------- ЧАСОВНЯ-КРИПТА ----------

func _build_chapel() -> void:
        var cx := 11.5
        var cz := -10.0
        var w := 8.0
        var d := 6.5
        var h := 4.3
        # Пол
        _box(Vector3(w, 0.4, d), Vector3(cx, 0.2, cz), m_stone_dark)
        # Стены: проём на западной (x-) стороне к двору
        var seg_d: float = d - 2.4
        for sz in [-1.0, 1.0]:
                var zf: float = sz
                _box(Vector3(0.55, h, seg_d),
                                Vector3(cx - w * 0.5 - 0.27, h * 0.5, cz + zf * (1.2 + seg_d * 0.5)), m_masonry)
                _collider(Vector3(0.55, h, seg_d),
                                Vector3(cx - w * 0.5 - 0.27, h * 0.5, cz + zf * (1.2 + seg_d * 0.5)))
        _box(Vector3(0.55, h - 3.1, 2.4), Vector3(cx - w * 0.5 - 0.27, 3.1 + (h - 3.1) * 0.5, cz), m_masonry)
        _collider(Vector3(0.55, h - 3.1, 2.4), Vector3(cx - w * 0.5 - 0.27, 3.1 + (h - 3.1) * 0.5, cz))
        _box(Vector3(w, h, 0.55), Vector3(cx, h * 0.5, cz + d * 0.5), m_masonry)
        _collider(Vector3(w, h, 0.55), Vector3(cx, h * 0.5, cz + d * 0.5))
        _box(Vector3(w, h, 0.55), Vector3(cx, h * 0.5, cz - d * 0.5), m_masonry)
        _collider(Vector3(w, h, 0.55), Vector3(cx, h * 0.5, cz - d * 0.5))
        _box(Vector3(0.55, h, d), Vector3(cx + w * 0.5 + 0.27, h * 0.5, cz), m_masonry)
        _collider(Vector3(0.55, h, d), Vector3(cx + w * 0.5 + 0.27, h * 0.5, cz))
        # Стрельчатые окна часовни
        _gothic_window(Vector3(cx, 2.5, cz + d * 0.5 + 0.05), 0.0, 0.9, 2.1)
        _gothic_window(Vector3(cx + w * 0.5 + 0.05, 2.5, cz), PI * 0.5, 0.9, 2.1)
        # Кровля
        var span := w * 0.5 + 0.8
        var roof_h := 2.6
        var slope_len: float = sqrt(span * span + roof_h * roof_h)
        var ang: float = atan2(roof_h, span)
        for sx in [-1.0, 1.0]:
                var sf: float = sx
                _box(Vector3(slope_len + 0.15, 0.2, d + 1.2),
                                Vector3(cx + sf * span * 0.5, h + roof_h * 0.5, cz),
                                m_roof, Vector3(0, 0, -sf * ang))
        for sz in [-1.0, 1.0]:
                var zf: float = sz
                var gable := MeshInstance3D.new()
                var pm := PrismMesh.new()
                pm.size = Vector3(w, roof_h, 0.24)
                pm.left_to_right = 0.5
                gable.mesh = pm
                gable.material_override = m_masonry
                gable.position = Vector3(cx, h + roof_h * 0.5, cz + zf * (d * 0.5 + 0.3))
                add_child(gable)
        # Малый шпилёк
        _cyl(0.22, 0.18, 1.6, Vector3(cx, h + roof_h + 0.8, cz), m_trim, 8)
        _cyl(0.24, 0.0, 0.7, Vector3(cx, h + roof_h + 1.9, cz), m_roof, 8)
        # Саркофаги: один закрыт, второй с отодвинутой крышкой
        _box(Vector3(2.3, 0.95, 1.05), Vector3(cx - 1.4, 0.88, cz - 1.7), m_masonry)
        _box(Vector3(2.4, 0.22, 1.15), Vector3(cx - 1.4, 1.45, cz - 1.7), m_masonry)
        _box(Vector3(2.3, 0.95, 1.05), Vector3(cx + 1.8, 0.88, cz - 1.5), m_masonry)
        _box(Vector3(2.4, 0.22, 1.15), Vector3(cx + 2.4, 1.3, cz - 0.7), m_masonry, Vector3(0, 0.5, 0.12))
        # Алтарь с аметистом
        _box(Vector3(1.7, 1.0, 0.8), Vector3(cx + 2.2, 0.9, cz + 2.0), m_stone_dark)
        var gem := _cyl(0.14, 0.0, 0.9, Vector3(cx + 2.2, 2.0, cz + 2.0), m_iron, 6)
        var gm2 := StandardMaterial3D.new()
        gm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        gm2.albedo_color = Color(0.7, 0.4, 1.0, 0.85)
        gm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        gm2.emission_enabled = true
        gm2.emission = Color(0.7, 0.4, 1.0)
        gm2.emission_energy_multiplier = 2.4
        gem.material_override = gm2
        var gl := OmniLight3D.new()
        gl.light_color = Color(0.7, 0.4, 1.0)
        gl.light_energy = 1.4
        gl.omni_range = 6.0
        gl.position = Vector3(cx + 2.2, 2.3, cz + 2.0)
        add_child(gl)
        # Кости и ведьмин огонь
        for i in 6:
                var a := rng.randf() * TAU
                var rr := rng.randf_range(0.8, 2.6)
                _sphere(rng.randf_range(0.08, 0.14),
                                Vector3(cx + cos(a) * rr - 1.0, 0.45, cz + sin(a) * rr), m_bone)
        _brazier(Vector3(cx - w * 0.5 + 0.8, 0.4, cz + d * 0.5 - 0.8), true)
        _brazier(Vector3(cx + w * 0.5 - 0.8, 0.4, cz + d * 0.5 - 0.8), true)


# ---------- ДВОР ----------

func _build_courtyard() -> void:
        # Стойка с оружием
        _box(Vector3(0.14, 1.5, 0.14), Vector3(-9.0, 0.75, 8.0), m_wood)
        _box(Vector3(0.14, 1.5, 0.14), Vector3(-7.4, 0.75, 8.0), m_wood)
        _box(Vector3(1.9, 0.12, 0.12), Vector3(-8.2, 1.35, 8.0), m_wood)
        _box(Vector3(0.08, 0.9, 0.16), Vector3(-8.0, 1.0, 8.0), m_iron)
        _box(Vector3(0.08, 0.7, 0.16), Vector3(-8.5, 1.1, 8.0), m_iron)
        # Ящики и бочки
        _box(Vector3(0.75, 0.75, 0.75), Vector3(6.5, 0.38, 10.5), m_wood, Vector3(0, 0.5, 0))
        _box(Vector3(0.65, 0.65, 0.65), Vector3(7.4, 0.33, 10.2), m_wood, Vector3(0, 1.2, 0))
        _cyl(0.34, 0.31, 0.95, Vector3(-13.5, 0.48, -6.0), m_wood, 12)
        _cyl(0.34, 0.31, 0.95, Vector3(-12.6, 0.48, -6.6), m_wood, 12)
        # Каменная клумба с тёмными цветами у донжона
        _box(Vector3(3.2, 0.5, 1.4), Vector3(-4.8, 0.25, -1.0), m_trim)


# ---------- ВРАГИ И ПРИЗРАК ----------

func _spawn_castle_enemies() -> void:
        var spots := [
                ["cave", Vector3(-8.0, 0, 6.0)],
                ["cave", Vector3(9.0, 0, 2.0)],
                ["brute", Vector3(11.5, 0, -10.0)],
        ]
        for i in spots.size():
                var e := EnemyScript.new()
                e.setup(spots[i][0], 3300 + i * 51)
                var lp: Vector3 = spots[i][1]
                e.position = lp + Vector3(0, 0.7, 0)
                add_child(e)
                if spots[i][0] == "brute":
                        var lbl := Label3D.new()
                        lbl.text = "Хозяин крипты"
                        lbl.font_size = 38
                        lbl.pixel_size = 0.004
                        lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
                        lbl.modulate = Color(0.8, 0.55, 1.0)
                        lbl.outline_size = 8
                        lbl.position.y = 3.4
                        e.add_child(lbl)


func _spawn_ghost() -> void:
        var npc := NpcScript.new()
        npc.setup("Страж-призрак", [
                "Кто вы? Я стою на посту триста лет... Замок пал в ночь Кровавой Луны.",
                "В крипте под часовней бродит нечто крупное и зелёное. Меч вам пригодится.",
                "Нажмите F — и вы взлетите. Так лестниц в замке можно не искать.",
                "Сокровища донжона прокляты. Впрочем, мёртвым это не грозит... как и мне.",
        ], 4242, M_GHOST, ["Spellbook", "Spellbook_open", "1H_Wand"], Color(0.72, 0.82, 1.35))
        npc.home_center = GameWorld.CASTLE_CENTER + Vector2(0.0, 2.0)
        npc.home_radius = 10.0
        npc.position = Vector3(0, 0.1, -3.0)
        add_child(npc)
