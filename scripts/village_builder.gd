extends Node3D
## Средневековая деревня в PBR-текстурах Poly Haven CC0:
## таверна «Пьяный грифон», фахверковые дома, колодец, костёр, фонари,
## заборы, указатель, руины на холме и реквизит (сено, бочки, ящики).
## Плюс импортные CC0-модели: дом (Quaternius), колодец и мельница
## (Kenney), костровище и лавка (Poly Haven) — в текстурах Poly Haven.

const GY := GameWorld.VILLAGE_HEIGHT
const TEX := "res://assets/textures/"
const MDL := "res://assets/models/"

var rng := RandomNumberGenerator.new()
var m_plaster: StandardMaterial3D
var m_plaster_warm: StandardMaterial3D
var m_beam: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_wall_light: StandardMaterial3D
var m_roof_wood: StandardMaterial3D
var m_roof_straw: StandardMaterial3D
var m_roof_tile: StandardMaterial3D
var m_stone: StandardMaterial3D
var m_ruin: StandardMaterial3D
var m_window: StandardMaterial3D
var m_lantern_glass: StandardMaterial3D
var m_door: StandardMaterial3D


func _ready() -> void:
        rng.seed = 1313
        _make_materials()
        _build_tavern()
        _build_houses()
        _build_well()
        _build_campfire()
        _build_lanterns()
        _build_banners()
        _build_fences()
        _build_signpost()
        _build_smithy()
        _build_gardens()
        _build_barn()
        _build_woodshed()
        _build_palissade()
        _build_ruins()
        _build_props()
        _build_imported()


# ---------- МАТЕРИАЛЫ ----------

func _ptex(id: String, map: String) -> Texture2D:
        return load(TEX + id + "/" + id + "_" + map + "_2k.jpg")


func _pmat(id: String, tint: Color, scale: float, rough := 0.95,
                nrm := 1.0) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_texture = _ptex(id, "diff")
        m.albedo_color = tint
        m.roughness = rough
        m.normal_enabled = true
        m.normal_texture = _ptex(id, "nor")
        m.normal_scale = nrm
        m.uv1_triplanar = true
        m.uv1_scale = Vector3(scale, scale, scale)
        return m


func _cmap(col: Color, rough := 0.95) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_color = col
        m.roughness = rough
        return m


func _make_materials() -> void:
        # v10.1 «дарк-фентези»: вся палитра деревни затемнена и состарена —
        # копоть на штукатурке, выгоревшее дерево, гнилая солома, холодный
        # камень. Тёплыми остаются только тусклые свечи в окнах.
        m_plaster = _cmap(Color(0.30, 0.27, 0.25))
        m_plaster_warm = _cmap(Color(0.25, 0.21, 0.18))
        m_beam = _pmat("dark_planks", Color(0.26, 0.21, 0.17), 0.55, 0.95, 1.1)
        m_wall = _pmat("wood_plank_wall", Color(0.40, 0.34, 0.28), 0.5, 0.95)
        m_wall_light = _pmat("wood_plank_wall", Color(0.46, 0.39, 0.31), 0.5, 0.95)
        m_roof_wood = _pmat("roof_planks", Color(0.28, 0.24, 0.22), 0.55, 0.95)
        m_roof_straw = _pmat("roof_planks", Color(0.34, 0.27, 0.15), 0.75, 1.0, 0.8)
        m_roof_tile = _pmat("clay_roof_tiles_02", Color(0.27, 0.25, 0.27), 0.6, 0.9)
        m_stone = _pmat("stone_wall", Color(0.38, 0.38, 0.44), 0.5, 0.95)
        m_ruin = _pmat("castle_wall_varriation", Color(0.34, 0.35, 0.40), 0.45, 0.95)
        m_window = _cmap(Color(0.05, 0.03, 0.02))
        m_window.emission_enabled = true
        m_window.emission = Color(1.0, 0.45, 0.14)
        # v10.1: тусклый больной огонь — тёплые окна остались, но злее
        m_window.emission_energy_multiplier = 1.15
        # Стекло уличных фонарей — тусклее окон: фонарь близко к игроку
        # и не должен «выжигать» кадр белым квадратом
        m_lantern_glass = _cmap(Color(0.07, 0.05, 0.03))
        m_lantern_glass.emission_enabled = true
        m_lantern_glass.emission = Color(1.0, 0.55, 0.25)
        m_lantern_glass.emission_energy_multiplier = 1.2
        m_door = _pmat("dark_planks", Color(0.22, 0.14, 0.09), 0.7, 0.95)


# ---------- ПОМОЩНИКИ ----------

func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material,
                rot := Vector3.ZERO) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = size
        mi.mesh = bm
        mi.material_override = m
        mi.position = pos
        mi.rotation = rot
        parent.add_child(mi)
        return mi


func _cyl(parent: Node3D, rb: float, rt: float, h: float, pos: Vector3,
                m: Material, seg := 12) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = rt
        cm.bottom_radius = rb
        cm.height = h
        cm.radial_segments = seg
        mi.mesh = cm
        mi.material_override = m
        mi.position = pos
        parent.add_child(mi)
        return mi


func _roof_mesh(parent: Node3D, w: float, d: float, base_y: float, h: float,
                m: Material, overhang := 1.3) -> void:
        var roof := MeshInstance3D.new()
        var pm := PrismMesh.new()
        pm.size = Vector3(d + overhang, h, w + overhang)
        pm.left_to_right = 0.5
        roof.mesh = pm
        roof.material_override = m
        roof.position = Vector3(0, base_y + h * 0.5, 0)
        roof.rotation_degrees.y = 90
        parent.add_child(roof)
        # Конёк
        var ridge := _cyl(parent, 0.09, 0.09, w + overhang - 0.3,
                Vector3(0, base_y + h - 0.02, 0), m_beam, 8)
        ridge.rotation_degrees.z = 90


func _collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
        var body := StaticBody3D.new()
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        body.add_child(col)
        body.position = pos
        parent.add_child(body)


func _window(parent: Node3D, pos: Vector3, rot_y := 0.0, w := 0.72, h := 0.95,
                shutters := true) -> void:
        # Наличник
        _box(parent, Vector3(w + 0.22, h + 0.22, 0.14), pos, m_beam, Vector3(0, rot_y, 0))
        # Подоконник
        var dir := Vector3(sin(rot_y), 0.0, cos(rot_y))
        _box(parent, Vector3(w + 0.3, 0.08, 0.22), pos + dir * 0.08 - Vector3(0, h * 0.5 + 0.04, 0),
                m_beam, Vector3(0, rot_y, 0))
        # Светящееся стекло
        _box(parent, Vector3(w, h, 0.12), pos + dir * 0.04, m_window, Vector3(0, rot_y, 0))
        # Переплёт — v5.0
        _box(parent, Vector3(0.05, h, 0.17), pos + dir * 0.07, m_beam, Vector3(0, rot_y, 0))
        _box(parent, Vector3(w, 0.05, 0.17), pos + dir * 0.07, m_beam, Vector3(0, rot_y, 0))
        # Ставни / v10.1: часть окон заколочена крест-накрест тёмными досками
        if shutters:
                var side := Vector3(dir.z, 0.0, -dir.x)
                if rng.randf() < 0.38:
                        # заколоченное окно: две крестовые доски поверх стёкол
                        for sgn in [1.0, -1.0]:
                                var bnp := _box(parent, Vector3(w + 0.34, 0.16, 0.1),
                                                pos + dir * 0.09, m_door)
                                bnp.rotation = Vector3(0, rot_y, sgn * 0.62)
                        # тусклая щель света между досками
                        _box(parent, Vector3(w * 0.9, 0.05, 0.02),
                                        pos + dir * 0.12 - Vector3(0, h * 0.28, 0), m_window,
                                        Vector3(0, rot_y, 0))
                else:
                        for s in [-1.0, 1.0]:
                                var sf: float = s
                                var open := rng.randf() < 0.5
                                var sx: float = sf * (w * 0.5 + 0.16)
                                var shutter := _box(parent, Vector3(0.09, h + 0.1, w * 0.42),
                                                pos + dir * 0.1 + side * sx, m_wall_light)
                                shutter.rotation.y = rot_y + (sf * (0.95 if open else 0.0))
                                shutter.position += side * (sf * 0.14 if open else 0.0)


const PUFF_TEX := preload("res://assets/textures/particles/puff_diff.png")


func _smoke(parent: Node3D, pos: Vector3) -> void:
        var p := GPUParticles3D.new()
        p.amount = 14
        p.lifetime = 4.5
        p.preprocess = 4.0
        p.position = pos
        var pm := ParticleProcessMaterial.new()
        pm.direction = Vector3(0, 1, 0)
        pm.spread = 12.0
        pm.initial_velocity_min = 0.6
        pm.initial_velocity_max = 1.1
        pm.gravity = Vector3(0, 0.35, 0)
        pm.scale_min = 0.6
        pm.scale_max = 1.2
        var g := Gradient.new()
        # v9.1: НОЧНОЙ дым — прежние 0.75 при UNSHADED светились ярче
        # всей ночной сцены («светящиеся боке-полосы» на скринах)
        g.set_color(0, Color(0.045, 0.045, 0.055, 0.0))
        g.set_color(1, Color(0.045, 0.045, 0.055, 0.0))
        g.add_point(0.25, Color(0.05, 0.05, 0.06, 0.30))
        g.add_point(0.7, Color(0.045, 0.045, 0.055, 0.14))
        var gt := GradientTexture1D.new()
        gt.gradient = g
        pm.color_ramp = gt
        p.process_material = pm
        # v9.0: мягкий круглый пуф вместо голого квадрата
        var quad := QuadMesh.new()
        quad.size = Vector2(0.6, 0.6)
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.vertex_color_use_as_albedo = true
        m.albedo_texture = PUFF_TEX
        quad.material = m
        p.draw_pass_1 = quad
        parent.add_child(p)


func _building_at(pos: Vector2, yaw := -1.0) -> Node3D:
        # v9.0: высота — по террейну в точке (плато деревни не идеально
        # плоское на периферии), разворот — явный (лицом к своей улице);
        # yaw < 0 — старое поведение «лицом к центру»
        var b := Node3D.new()
        b.position = Vector3(pos.x, GameWorld.terrain_height(pos.x, pos.y), pos.y)
        if yaw < 0.0:
                yaw = atan2(-pos.x, -pos.y)
        b.rotation.y = yaw
        add_child(b)
        return b


# ---------- ТАВЕРНА ----------

func _build_tavern() -> void:
        var b := Node3D.new()
        # v9.0: таверна замыкает главную улицу с севера, фасадом на юг
        b.position = Vector3(0, GameWorld.terrain_height(0, -14.5), -14.5)
        add_child(b)
        # Цоколь, два этажа, крыша
        _box(b, Vector3(11.6, 0.8, 8.6), Vector3(0, -0.1, 0), m_stone)
        _box(b, Vector3(11.0, 3.0, 8.0), Vector3(0, 1.8, 0), m_plaster)
        _box(b, Vector3(11.8, 2.6, 8.4), Vector3(0, 4.6, 0), m_plaster_warm)
        _roof_mesh(b, 12.4, 9.2, 5.9, 2.8, m_roof_tile, 1.4)
        # Фахверк: стойки, пояса, раскосы
        for x in [-5.4, -1.8, 1.8, 5.4]:
                _box(b, Vector3(0.24, 3.0, 0.2), Vector3(x, 1.8, 4.02), m_beam)
        _box(b, Vector3(11.1, 0.22, 0.2), Vector3(0, 3.28, 4.02), m_beam)
        _box(b, Vector3(11.9, 0.24, 0.22), Vector3(0, 3.38, 4.22), m_beam)
        for cx in [-3.6, 0.0, 3.6]:
                _box(b, Vector3(3.9, 0.18, 0.16), Vector3(cx, 2.1, 4.05), m_beam, Vector3(0, 0, 38))
                _box(b, Vector3(3.9, 0.18, 0.16), Vector3(cx, 2.1, 4.05), m_beam, Vector3(0, 0, -38))
        # Дверь и крыльцо
        _box(b, Vector3(1.5, 2.6, 0.22), Vector3(0, 1.3, 4.0), m_beam)
        _box(b, Vector3(1.3, 2.4, 0.24), Vector3(0, 1.25, 4.04), m_door)
        var knob := MeshInstance3D.new()
        var km := SphereMesh.new()
        km.radius = 0.05
        km.height = 0.1
        km.radial_segments = 8
        knob.mesh = km
        knob.material_override = _cmap(Color(0.2, 0.16, 0.1), 0.4)
        knob.position = Vector3(0.42, 1.2, 4.18)
        b.add_child(knob)
        _box(b, Vector3(1.9, 0.18, 1.1), Vector3(0, 0.08, 4.7), m_stone)
        # Окна
        _window(b, Vector3(-3.4, 1.95, 3.98))
        _window(b, Vector3(3.4, 1.95, 3.98))
        _window(b, Vector3(-3.8, 4.6, 4.18))
        _window(b, Vector3(3.8, 4.6, 4.18))
        _window(b, Vector3(0, 4.6, 4.18), 0.0, 0.72, 0.95, false)
        _window(b, Vector3(5.55, 2.0, 0), 90.0)
        _window(b, Vector3(-5.55, 2.0, 0), -90.0)
        _window(b, Vector3(-2.5, 2.0, -3.98), 180.0)
        _window(b, Vector3(2.5, 2.0, -3.98), 180.0)
        _window(b, Vector3(0, 4.6, -4.18), 180.0, 0.72, 0.95, false)
        # Вывеска на кронштейне
        _box(b, Vector3(0.08, 0.08, 1.1), Vector3(2.4, 3.15, 4.6), m_beam)
        var board := _box(b, Vector3(1.35, 0.9, 0.08), Vector3(2.4, 2.6, 5.1), m_wall_light)
        var lbl := Label3D.new()
        lbl.text = "ТАВЕРНА"
        lbl.font_size = 40
        lbl.pixel_size = 0.004
        lbl.modulate = Color(1.0, 0.8, 0.45)
        lbl.outline_size = 6
        lbl.position = Vector3(0, 0, 0.06)
        board.add_child(lbl)
        # Фонарь у входа
        var porch := OmniLight3D.new()
        porch.light_color = Color(1.0, 0.65, 0.3)
        porch.light_energy = 2.4
        porch.omni_range = 11.0
        porch.position = Vector3(0, 3.4, 5.2)
        b.add_child(porch)
        # Труба
        _box(b, Vector3(0.95, 5.6, 0.95), Vector3(-4.2, 5.0, -3.2), m_ruin)
        _box(b, Vector3(1.15, 0.25, 1.15), Vector3(-4.2, 7.9, -3.2), m_ruin)
        _smoke(b, Vector3(-4.2, 8.3, -3.2))
        _collider(b, Vector3(12.4, 7.2, 9.4), Vector3(0, 3.6, 0))


# ---------- ДОМА (v5.0: детализированные фахверковые дома) ----------

func _build_houses() -> void:
        # v9.0 «как в Скайриме»: дома рядами вдоль улиц, крыльцами к своей
        # улице — равномерно по всей территории деревни, а не «кучей по
        # кругу вокруг костра». yaw (град): 0=юг, 90=восток, -90=запад, 180=север
        var defs = [
                # западный ряд — лицом на восток (к западному проулку)
                [Vector2(-13.5, -5.5), 6.5, 5.5, 3.0, "plaster", "straw", true, 90.0],
                [Vector2(-14.0, 8.0), 7.0, 5.0, 2.8, "wood", "wood", true, 90.0],
                # восточный ряд — лицом на запад (к восточному проулку)
                [Vector2(13.5, -7.0), 6.0, 5.0, 2.9, "plaster", "tile", false, -90.0],
                # юго-восточный двор за кузницей
                [Vector2(24.0, 19.5), 6.4, 5.2, 2.8, "wood", "straw", true, -90.0],
                # северный проулок — лицом на юго-восток
                [Vector2(-16.0, -16.5), 6.8, 5.2, 2.7, "wood", "straw", true, 35.0],
                # юго-западный двор у ворот — лицом на север
                [Vector2(-14.5, 19.5), 6.2, 5.0, 2.9, "plaster", "wood", true, 180.0],
        ]
        for d in defs:
                var wall_m: StandardMaterial3D = m_plaster if d[4] == "plaster" else m_wall
                var roof_m: StandardMaterial3D = m_roof_straw if d[5] == "straw" \
                                else (m_roof_wood if d[5] == "wood" else m_roof_tile)
                _build_house(d[0], d[1], d[2], d[3], wall_m, roof_m, d[6], d[4] == "plaster", deg_to_rad(d[7]))


func _build_house(pos: Vector2, w: float, dep: float, wall_h: float,
                wall_m: Material, roof_m: Material, chimney: bool, timber: bool,
                yaw := -1.0) -> void:
        var b := _building_at(pos, yaw)
        var up_h: float = wall_h * 0.85       # высота второго этажа
        var up_y: float = 0.7 + wall_h        # низ второго этажа (над цоколем)
        var top_y: float = up_y + up_h        # верх стен (линия низа крыши)
        var eave := 1.15                      # v10.1: нависающие тёмные свесы
        var over := 0.9                       # свес крыши по фронтонам
        # v10.1: крутая готическая крыша — раньше было w*0.4 (полого, уютно)
        var roof_h: float = maxf(2.7, w * 0.62)
        # v10.1: мёртвая трава в ящиках вместо зелёных цветников
        var leaf_m := _cmap(Color(0.16, 0.13, 0.08))
        var iron_m := _cmap(Color(0.12, 0.11, 0.10), 0.45)
        var log_m := _pmat("dark_planks", Color(0.34, 0.27, 0.20), 0.35)

        # --- Каменный цоколь с угловыми квадрами и ступенькой ---
        _box(b, Vector3(w + 0.7, 0.85, dep + 0.7), Vector3(0, 0.28, 0), m_stone)
        for cx in [-w * 0.5 - 0.16, w * 0.5 + 0.16]:
                for cz in [-dep * 0.5 - 0.16, dep * 0.5 + 0.16]:
                        _box(b, Vector3(0.44, 0.95, 0.44), Vector3(cx, 0.34, cz), m_stone)
        _box(b, Vector3(1.5, 0.22, 0.9), Vector3(w * 0.12, 0.06, dep * 0.5 + 0.5), m_stone)

        # --- Первый этаж ---
        _box(b, Vector3(w, wall_h, dep), Vector3(0, 0.7 + wall_h * 0.5 - 0.02, 0), wall_m)
        # --- Второй этаж с выпуском (свесом) по всем четырём сторонам ---
        _box(b, Vector3(w + 0.8, up_h, dep + 0.8), Vector3(0, up_y + up_h * 0.5, 0), wall_m)
        # Опорные балки выпуска по периметру
        for cz in [-dep * 0.5 - 0.36, dep * 0.5 + 0.36]:
                _box(b, Vector3(w + 0.9, 0.18, 0.18), Vector3(0, up_y + 0.1, cz), m_beam)
        for cx in [-w * 0.5 - 0.36, w * 0.5 + 0.36]:
                _box(b, Vector3(0.18, 0.18, dep + 0.9), Vector3(cx, up_y + 0.1, 0), m_beam)
        # Кронштейны под свесом
        for cx in [-w * 0.32, w * 0.32]:
                _box(b, Vector3(0.14, 0.52, 0.14), Vector3(cx, up_y - 0.24, dep * 0.5 + 0.3),
                                m_beam, Vector3(0.5, 0, 0))
                _box(b, Vector3(0.14, 0.52, 0.14), Vector3(cx, up_y - 0.24, -dep * 0.5 - 0.3),
                                m_beam, Vector3(-0.5, 0, 0))

        # --- Фахверк: стойки, пояса, раскосы (перед/бок) ---
        if timber:
                var fz := dep * 0.5 + 0.04
                for cx in [-w * 0.5 + 0.12, 0.0, w * 0.5 - 0.12]:
                        _box(b, Vector3(0.2, wall_h, 0.15), Vector3(cx, 0.7 + wall_h * 0.5, fz), m_beam)
                _box(b, Vector3(w, 0.15, 0.15), Vector3(0, 0.7 + 0.09, fz), m_beam)
                _box(b, Vector3(w, 0.15, 0.15), Vector3(0, 0.7 + wall_h - 0.09, fz), m_beam)
                for cx in [-w * 0.27, w * 0.27]:
                        _box(b, Vector3(2.1, 0.12, 0.11), Vector3(cx, 0.7 + wall_h * 0.52, fz),
                                        m_beam, Vector3(0, 0, 0.68))
                        _box(b, Vector3(2.1, 0.12, 0.11), Vector3(cx, 0.7 + wall_h * 0.52, fz),
                                        m_beam, Vector3(0, 0, -0.68))
                # Второй этаж: пояса + стойки + диагонали
                var uz := dep * 0.5 + 0.44
                _box(b, Vector3(w + 0.9, 0.17, 0.15), Vector3(0, up_y + 0.1, uz), m_beam)
                _box(b, Vector3(w + 0.9, 0.17, 0.15), Vector3(0, up_y + up_h - 0.1, uz), m_beam)
                for cx in [-w * 0.5 - 0.29, -w * 0.18, w * 0.18, w * 0.5 + 0.29]:
                        _box(b, Vector3(0.16, up_h, 0.15), Vector3(cx, up_y + up_h * 0.5, uz), m_beam)
                for cx in [-w * 0.34, w * 0.34]:
                        _box(b, Vector3(2.6, 0.12, 0.11), Vector3(cx, up_y + up_h * 0.5, uz),
                                        m_beam, Vector3(0, 0, 0.62))
                # Боковые стороны: угловые стойки на всю высоту
                var sx := w * 0.5 + 0.44
                for czz in [-dep * 0.5 + 0.12, 0.0, dep * 0.5 - 0.12]:
                        _box(b, Vector3(0.16, wall_h + up_h, 0.16),
                                        Vector3(sx, 0.7 + (wall_h + up_h) * 0.5, czz), m_beam)
                _box(b, Vector3(0.16, 0.15, dep), Vector3(sx, 0.7 + wall_h - 0.1, 0), m_beam)

        # --- Дверь: рама, полотно с тёсом, петли, кольцо-ручка ---
        var dz := dep * 0.5 + 0.05
        _box(b, Vector3(1.4, 2.45, 0.14), Vector3(w * 0.12, 0.7 + 1.2, dz), m_beam)
        _box(b, Vector3(1.12, 2.18, 0.16), Vector3(w * 0.12, 0.7 + 1.06, dz + 0.02), m_door)
        for dy in [0.55, 1.72]:
                _box(b, Vector3(0.34, 0.09, 0.05),
                                Vector3(w * 0.12 - 0.3, 0.7 + dy, dz + 0.12), iron_m)
        var ring := MeshInstance3D.new()
        var rm := TorusMesh.new()
        rm.inner_radius = 0.05
        rm.outer_radius = 0.09
        ring.mesh = rm
        ring.material_override = iron_m
        ring.position = Vector3(w * 0.12 + 0.32, 1.35, dz + 0.13)
        b.add_child(ring)
        # Фонарь у входа
        _box(b, Vector3(0.08, 0.08, 0.6), Vector3(w * 0.12 + 1.1, 2.6, dz + 0.2), m_beam)
        _box(b, Vector3(0.24, 0.3, 0.24), Vector3(w * 0.12 + 1.1, 2.38, dz + 0.44), m_window)
        # v10.1: рогатый череп над дверью (оберег от нечисти) — мелкая
        # тёмная пластина с двумя рогами-шипами
        var skull_z := dz + 0.14
        _box(b, Vector3(0.30, 0.22, 0.07), Vector3(w * 0.12, 2.78, skull_z), m_wall_light)
        for hs in [-1.0, 1.0]:
                var hf: float = hs
                var horn := MeshInstance3D.new()
                var hm := PrismMesh.new()
                hm.size = Vector3(0.07, 0.42, 0.07)
                hm.left_to_right = 0.5
                horn.mesh = hm
                horn.material_override = m_beam
                horn.position = Vector3(w * 0.12 + hf * 0.16, 2.95, skull_z)
                horn.rotation.z = hf * 0.5
                b.add_child(horn)

        # --- Окна: нижний этаж с цветниками, верхний — со ставнями ---
        _window(b, Vector3(-w * 0.26, 0.7 + wall_h * 0.55, dep * 0.5 + 0.03))
        _window(b, Vector3(w * 0.38, 0.7 + wall_h * 0.55, dep * 0.5 + 0.03))
        _window(b, Vector3(-w * 0.5 - 0.44, up_y + up_h * 0.5, 0), 90.0, 0.62, 0.8)
        _window(b, Vector3(w * 0.5 + 0.44, up_y + up_h * 0.5, 0), 90.0, 0.62, 0.8)
        _window(b, Vector3(-w * 0.3, up_y + up_h * 0.55, dep * 0.5 + 0.44), 0.0, 0.66, 0.9, false)
        _window(b, Vector3(w * 0.3, up_y + up_h * 0.55, dep * 0.5 + 0.44), 0.0, 0.66, 0.9, false)
        _window(b, Vector3(-w * 0.24, up_y + up_h * 0.55, -dep * 0.5 - 0.44), 180.0, 0.66, 0.9, false)
        # v10.1: ящики с высохшей травой под нижними окнами
        for wx in [-w * 0.26, w * 0.38]:
                _box(b, Vector3(1.0, 0.24, 0.28), Vector3(wx, 0.7 + wall_h * 0.55 - 0.72,
                                dep * 0.5 + 0.14), m_beam)
                _box(b, Vector3(0.92, 0.12, 0.22), Vector3(wx, 0.7 + wall_h * 0.55 - 0.55,
                                dep * 0.5 + 0.14), leaf_m)
                # пучки сухой травы, свисающие из ящика
                for tg in [-0.3, 0.05, 0.35]:
                        var tuft := _box(b, Vector3(0.07, 0.3, 0.05),
                                        Vector3(wx + tg, 0.7 + wall_h * 0.55 - 0.62,
                                                        dep * 0.5 + 0.24), leaf_m)
                        tuft.rotation.z = tg * 0.4

        # --- Крыша: два ската с свесами, ветровые доски, конёк, фронтоны ---
        var span := w * 0.5 + eave
        var slope_len: float = sqrt(span * span + roof_h * roof_h)
        var ang: float = atan2(roof_h, span)
        for sgn in [1.0, -1.0]:
                var sf: float = sgn
                _box(b, Vector3(slope_len + 0.15, 0.18, dep + 2.0 * over),
                                Vector3(sf * span * 0.5, top_y + roof_h * 0.5 + 0.03, 0),
                                roof_m, Vector3(0, 0, -sf * ang))
                # Ветровая доска по кромке ската
                _box(b, Vector3(0.12, 0.26, dep + 2.0 * over + 0.1),
                                Vector3(sf * (span + 0.02), top_y - 0.02, 0), m_beam)
        # Фронтоны (треугольники) с опорными брусьями
        for sgn in [1.0, -1.0]:
                var sf: float = sgn
                var gable := MeshInstance3D.new()
                var pm := PrismMesh.new()
                pm.size = Vector3(w, roof_h, 0.22)
                pm.left_to_right = 0.5
                gable.mesh = pm
                gable.material_override = wall_m
                gable.position = Vector3(0, top_y + roof_h * 0.5, sf * (dep * 0.5 + 0.03))
                b.add_child(gable)
                var gspan := w * 0.5 + 0.08
                var glen: float = sqrt(gspan * gspan + roof_h * roof_h)
                for gs in [1.0, -1.0]:
                        var gf: float = gs
                        _box(b, Vector3(glen, 0.15, 0.15),
                                        Vector3(gf * gspan * 0.5, top_y + roof_h * 0.5,
                                                        sf * (dep * 0.5 + 0.16)),
                                        m_beam, Vector3(0, 0, -gf * atan2(roof_h, gspan)))
        # Конёк
        var ridge := _cyl(b, 0.1, 0.1, dep + 2.0 * over - 0.3,
                        Vector3(0, top_y + roof_h + 0.03, 0), m_beam, 8)
        ridge.rotation_degrees.x = 90
        # v10.1: готические шпили на коньке — злой силуэт крыши
        for sgn in [1.0, -1.0]:
                var sf: float = sgn
                var spike := MeshInstance3D.new()
                var pm2 := PrismMesh.new()
                pm2.size = Vector3(0.34, 1.15, 0.34)
                pm2.left_to_right = 0.5
                spike.mesh = pm2
                spike.material_override = m_beam
                spike.position = Vector3(0, top_y + roof_h + 0.62,
                                sf * (dep * 0.5 + over - 0.45))
                b.add_child(spike)
                # кованое кольцо под шпилем
                var ring2 := MeshInstance3D.new()
                var rm2 := TorusMesh.new()
                rm2.inner_radius = 0.06
                rm2.outer_radius = 0.11
                ring2.mesh = rm2
                ring2.material_override = iron_m
                ring2.position = Vector3(0, top_y + roof_h + 0.16,
                                sf * (dep * 0.5 + over - 0.45))
                b.add_child(ring2)
        # Чердачное окно и подъёмная балка на переднем фронтоне
        _window(b, Vector3(0, top_y + roof_h * 0.42, dep * 0.5 + 0.16), 0.0, 0.5, 0.6, false)
        _box(b, Vector3(0.09, 0.09, 1.2), Vector3(0.9, top_y + roof_h - 0.18,
                        dep * 0.5 + 0.55), m_beam)

        # --- Труба с дымом ---
        if chimney:
                var ch_h: float = top_y + roof_h + 1.1
                _box(b, Vector3(0.85, ch_h, 0.85), Vector3(w * 0.3, ch_h * 0.5, -dep * 0.22), m_ruin)
                _box(b, Vector3(1.06, 0.26, 1.06), Vector3(w * 0.3, ch_h + 0.1, -dep * 0.22), m_ruin)
                _smoke(b, Vector3(w * 0.3, ch_h + 0.45, -dep * 0.22))

        # --- Дрова и бочка у стены ---
        var lx := -w * 0.5 - 0.62
        for i in 6:
                var row := 0.22 if i > 2 else 0.0
                var log := _cyl(b, 0.09, 0.11, 0.95,
                                Vector3(lx + (0.2 if i > 2 else 0.0), 0.7 + 0.11 + row,
                                                -dep * 0.28 + (i % 3) * 0.25), log_m, 7)
                log.rotation_degrees.z = 90
        var bar := _cyl(b, 0.34, 0.31, 0.9, Vector3(w * 0.5 + 0.75, 0.7 + 0.45,
                        dep * 0.15), log_m, 12)

        _collider(b, Vector3(w + 0.9, top_y + roof_h * 0.7, dep + 0.9),
                        Vector3(0, (top_y + roof_h * 0.7) * 0.5, 0))

# ---------- КОЛОДЕЦ (модель Kenney в текстурах Poly Haven) ----------

func _build_well() -> void:
        # v9.0: колодец — на площади, к востоку от главной улицы
        var holder := _place_model(MDL + "ken_well.fbx", Vector3(3.2, GameWorld.terrain_height(3.2, 1.2), 1.2),
                0.6, 3.3, 0.12, {
                        "grey": m_stone, "dark_grey": m_stone,
                        "brown": m_beam, "white": m_plaster,
                        "light_red": m_roof_straw,
                })
        if holder != null:
                _collider(holder, Vector3(2.6, 3.2, 2.6), Vector3(0, 1.6, 0))
                var wl := OmniLight3D.new()
                wl.light_color = Color(1.0, 0.7, 0.35)
                wl.light_energy = 1.3
                wl.omni_range = 6.0
                wl.position = Vector3(0, 2.6, 0)
                holder.add_child(wl)
        else:
                # Запасной вариант: прежний процедурный колодец
                var b := Node3D.new()
                b.position = Vector3(3.2, GameWorld.terrain_height(3.2, 1.2), 1.2)
                add_child(b)
                _cyl(b, 1.0, 1.05, 0.9, Vector3(0, 0.45, 0), m_stone, 14)
                var dark := _cmap(Color(0.02, 0.02, 0.03))
                _cyl(b, 0.8, 0.8, 0.06, Vector3(0, 0.93, 0), dark, 14)
                _box(b, Vector3(0.14, 1.7, 0.14), Vector3(0.9, 1.75, 0), m_beam)
                _box(b, Vector3(0.14, 1.7, 0.14), Vector3(-0.9, 1.75, 0), m_beam)
                _roof_mesh(b, 2.6, 2.2, 2.55, 0.7, m_roof_straw, 0.5)
                _box(b, Vector3(0.025, 0.8, 0.025), Vector3(0, 2.1, 0), m_beam)
                _box(b, Vector3(0.3, 0.3, 0.3), Vector3(0, 1.62, 0), m_beam)


# ---------- КОСТЁР ----------

func _build_campfire() -> void:
        var b := Node3D.new()
        # v9.0: костёр — на западной стороне площади (не посреди улицы)
        var cf := Vector2(-3.8, 2.8)
        b.position = Vector3(cf.x, GameWorld.terrain_height(cf.x, cf.y), cf.y)
        add_child(b)
        # Костровище — фотограмметрическая модель Poly Haven
        var pit := _place_model(MDL + "stone_fire_pit.glb", Vector3(cf.x, GameWorld.terrain_height(cf.x, cf.y), cf.y),
                rng.randf() * TAU, 0.5, 0.1, {})
        if pit == null:
                for i in 9:
                        var ang := TAU * i / 9.0
                        var mi := MeshInstance3D.new()
                        var sm := SphereMesh.new()
                        sm.radius = 0.22
                        sm.height = 0.4
                        sm.radial_segments = 7
                        sm.rings = 4
                        mi.mesh = sm
                        mi.material_override = m_stone
                        mi.position = Vector3(cos(ang) * 1.0, 0.1, sin(ang) * 1.0)
                        mi.scale = Vector3(1, 0.8, 1) * rng.randf_range(0.8, 1.25)
                        b.add_child(mi)
        # Брёвна
        var log_m := _pmat("dark_planks", Color(0.5, 0.42, 0.34), 0.4)
        for i in 4:
                var ang := TAU * i / 4.0 + 0.4
                var log := MeshInstance3D.new()
                var lm := CylinderMesh.new()
                lm.top_radius = 0.09
                lm.bottom_radius = 0.11
                lm.height = 1.3
                lm.radial_segments = 8
                log.mesh = lm
                log.material_override = log_m
                log.position = Vector3(cos(ang) * 0.35, 0.22 + i * 0.06, sin(ang) * 0.35)
                log.rotation = Vector3(0, -ang, 1.15)
                b.add_child(log)
        # Пламя
        for j in 3:
                var flame := MeshInstance3D.new()
                var cm := CylinderMesh.new()
                cm.top_radius = 0.0
                cm.bottom_radius = 0.28 - j * 0.06
                cm.height = 0.7 - j * 0.15
                cm.radial_segments = 8
                flame.mesh = cm
                var fm := StandardMaterial3D.new()
                fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                fm.albedo_color = Color(1.0, 0.55 - j * 0.12, 0.15, 0.85)
                fm.emission_enabled = true
                fm.emission = Color(1.0, 0.45, 0.1)
                fm.emission_energy_multiplier = 2.2
                flame.material_override = fm
                flame.position = Vector3(0, 0.35 + j * 0.28, 0)
                flame.add_to_group("campfire_flame")
                b.add_child(flame)
        var light := OmniLight3D.new()
        light.light_color = Color(1.0, 0.6, 0.25)
        light.light_energy = 3.0
        light.omni_range = 15.0
        light.position = Vector3(0, 1.2, 0)
        light.add_to_group("campfire_light")
        b.add_child(light)
        _smoke(b, Vector3(0, 0.9, 0))
        # Искры
        var sparks := GPUParticles3D.new()
        sparks.amount = 30
        sparks.lifetime = 1.6
        sparks.preprocess = 2.0
        sparks.position = Vector3(0, 0.6, 0)
        var spm := ParticleProcessMaterial.new()
        spm.direction = Vector3(0, 1, 0)
        spm.spread = 35.0
        spm.initial_velocity_min = 1.2
        spm.initial_velocity_max = 2.6
        spm.gravity = Vector3(0, 1.2, 0)
        spm.scale_min = 0.3
        spm.scale_max = 0.7
        sparks.process_material = spm
        var sq := QuadMesh.new()
        sq.size = Vector2(0.06, 0.06)
        var sm2 := StandardMaterial3D.new()
        sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        sm2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        sm2.vertex_color_use_as_albedo = true
        sm2.albedo_color = Color(1.0, 0.65, 0.2, 0.9)
        sm2.albedo_texture = PUFF_TEX
        sq.material = sm2
        sparks.draw_pass_1 = sq
        b.add_child(sparks)


# ---------- ФОНАРИ ----------

func _build_lanterns() -> void:
        # v9.0: фонари вдоль главной улицы (чередуем стороны) + ворота,
        # крыльцо таверны, кузница и колодец
        var spots := [
                Vector3(-2.8, 0, -10.5), Vector3(2.8, 0, -3.0),
                Vector3(-2.8, 0, 5.5), Vector3(2.8, 0, 13.0),
                Vector3(-2.8, 0, 20.5), Vector3(-2.4, 0, 26.5),
                Vector3(9.8, 0, 12.5), Vector3(-9.8, 0, -10.5),
        ]
        for s in spots:
                var b := Node3D.new()
                b.position = Vector3(s.x, GameWorld.terrain_height(s.x, s.z), s.z)
                add_child(b)
                _box(b, Vector3(0.14, 3.1, 0.14), Vector3(0, 1.55, 0), m_beam)
                # Кронштейн и подвесной фонарь
                _box(b, Vector3(0.5, 0.08, 0.08), Vector3(0.2, 3.0, 0), m_beam)
                _box(b, Vector3(0.42, 0.5, 0.42), Vector3(0.4, 2.72, 0), m_lantern_glass)
                _box(b, Vector3(0.55, 0.08, 0.55), Vector3(0.4, 3.02, 0), m_beam)
                _box(b, Vector3(0.03, 0.18, 0.03), Vector3(0.4, 3.08, 0), m_beam)
                var light := OmniLight3D.new()
                light.light_color = Color(1.0, 0.68, 0.35)
                light.light_energy = 1.5
                light.omni_range = 8.5
                light.position = Vector3(0.4, 2.72, 0)
                b.add_child(light)


# ---------- ЗАБОРЫ ----------

func _fence(a: Vector3, b_end: Vector3) -> void:
        var seg := a.distance_to(b_end)
        if seg < 0.5:
                return
        var n := int(seg / 1.8) + 1
        var dir := (b_end - a).normalized()
        var yaw := atan2(dir.x, dir.z)
        var heights: Array = []
        for i in n:
                var t := float(i) / float(n - 1)
                var pt := a + dir * (seg * t)
                # v9.0: столбы и перекладины следуют рельефу
                var hy := GameWorld.terrain_height(pt.x, pt.z)
                heights.append(hy)
                var post := MeshInstance3D.new()
                var bm := BoxMesh.new()
                bm.size = Vector3(0.16, 1.1, 0.16)
                post.mesh = bm
                post.material_override = m_beam
                post.position = Vector3(pt.x, hy + 0.55, pt.z)
                add_child(post)
        for yy in [0.45, 0.85]:
                var rail := MeshInstance3D.new()
                var rm := BoxMesh.new()
                rm.size = Vector3(0.06, 0.1, seg)
                rail.mesh = rm
                rail.material_override = m_wall_light
                var mid := (a + b_end) * 0.5
                var mid_y: float = heights[n / 2]
                rail.position = Vector3(mid.x, mid_y + yy, mid.z)
                rail.rotation.y = yaw
                add_child(rail)


func _build_fences() -> void:
        # v9.0: ограда огородов (восток), малые дворы и направляющие
        # флажины у ворот — улицы читаются как улицы
        var y0 := GameWorld.terrain_height(20.0, 0.0)
        # Огород: периметр x 19.5..27.5, z -8..8, проход с запада
        _fence(Vector3(19.8, y0, -8.0), Vector3(27.2, y0, -8.0))
        _fence(Vector3(27.2, y0, -8.0), Vector3(27.2, y0, 8.0))
        _fence(Vector3(27.2, y0, 8.0), Vector3(19.8, y0, 8.0))
        _fence(Vector3(19.8, y0, -8.0), Vector3(19.8, y0, -4.5))
        _fence(Vector3(19.8, y0, 4.5), Vector3(19.8, y0, 8.0))
        # Подход к воротам
        _fence(Vector3(-4.6, 0, 23.0), Vector3(-4.6, 0, 28.5))
        _fence(Vector3(4.6, 0, 23.0), Vector3(4.6, 0, 28.5))
        # Задний двор западного ряда
        _fence(Vector3(-17.6, 0, 12.6), Vector3(-11.0, 0, 12.6))
        # Двор северного проулка
        _fence(Vector3(-19.0, 0, -14.0), Vector3(-19.0, 0, -8.5))


# ---------- УКАЗАТЕЛЬ ----------

func _build_signpost() -> void:
        var b := Node3D.new()
        b.position = Vector3(1.5, GY, 24)
        add_child(b)
        _box(b, Vector3(0.14, 2.6, 0.14), Vector3(0, 1.3, 0), m_beam)
        var board1 := _box(b, Vector3(1.3, 0.32, 0.08), Vector3(0.3, 2.0, 0), m_wall_light, Vector3(0, -25, 0))
        var l1 := Label3D.new()
        l1.text = "ОЗЕРО"
        l1.font_size = 30
        l1.pixel_size = 0.006
        l1.modulate = Color(0.9, 0.85, 0.7)
        l1.outline_size = 4
        l1.position = Vector3(0, 0, 0.06)
        board1.add_child(l1)
        var board2 := _box(b, Vector3(1.3, 0.32, 0.08), Vector3(-0.3, 1.55, 0), m_wall_light, Vector3(0, 40, 0))
        var l2 := Label3D.new()
        l2.text = "РУИНЫ"
        l2.font_size = 30
        l2.pixel_size = 0.006
        l2.modulate = Color(0.9, 0.85, 0.7)
        l2.outline_size = 4
        l2.position = Vector3(0, 0, 0.06)
        board2.add_child(l2)
        var board3 := _box(b, Vector3(1.3, 0.32, 0.08), Vector3(0.2, 1.12, 0), m_wall_light, Vector3(0, 48, 0))
        var l3 := Label3D.new()
        l3.text = "ЗАМОК"
        l3.font_size = 30
        l3.pixel_size = 0.006
        l3.modulate = Color(0.9, 0.85, 0.7)
        l3.outline_size = 4
        l3.position = Vector3(0, 0, 0.06)
        board3.add_child(l3)
        var board4 := _box(b, Vector3(1.3, 0.32, 0.08), Vector3(-0.2, 0.68, 0), m_wall_light, Vector3(0, -42, 0))
        var l4 := Label3D.new()
        l4.text = "ПЕЩЕРА"
        l4.font_size = 30
        l4.pixel_size = 0.006
        l4.modulate = Color(0.9, 0.85, 0.7)
        l4.outline_size = 4
        l4.position = Vector3(0, 0, 0.06)
        board4.add_child(l4)


# ---------- ЗНАМЁНА (v9.0) ----------

## Деревянные флагштоки с тёмно-багровыми знамёнами на площади и у ворот:
## читаются как «жилая деревня», а не набор домиков.
func _build_banners() -> void:
        var cloth_m := _cmap(Color(0.42, 0.10, 0.08), 0.98)
        var trim_m := _cmap(Color(0.20, 0.16, 0.12), 0.95)
        var spots := [
                [Vector3(-8.5, 0, -8.5), 0.5], [Vector3(8.5, 0, -8.5), -0.5],
                [Vector3(-8.5, 0, 5.5), -0.4], [Vector3(8.5, 0, 5.5), 0.4],
                [Vector3(-2.4, 0, 26.5), 0.25], [Vector3(2.4, 0, 26.5), -0.25],
        ]
        for sd in spots:
                var s: Vector3 = sd[0]
                var twirl: float = sd[1]
                var y := GameWorld.terrain_height(s.x, s.z)
                var b := Node3D.new()
                b.position = Vector3(s.x, y, s.z)
                add_child(b)
                _cyl(b, 0.07, 0.09, 4.2, Vector3(0, 2.1, 0), m_beam, 8)
                _cyl(b, 0.0, 0.05, 0.22, Vector3(0, 4.3, 0), trim_m, 6)
                _box(b, Vector3(0.9, 0.09, 0.09), Vector3(0.42, 4.1, 0), m_beam)
                # Полотнище: слегка повёрнутое, с каймой
                var cloth := _box(b, Vector3(0.72, 1.7, 0.05), Vector3(0.62, 3.18, 0),
                                cloth_m, Vector3(0, twirl, 0.04))
                _box(cloth, Vector3(0.72, 0.14, 0.06), Vector3(0, 0.78, 0), trim_m)
                _box(cloth, Vector3(0.72, 0.14, 0.06), Vector3(0, -0.78, 0), trim_m)
                _box(cloth, Vector3(0.14, 1.7, 0.06), Vector3(0.29, 0, 0), trim_m)
                _box(cloth, Vector3(0.14, 1.7, 0.06), Vector3(-0.29, 0, 0), trim_m)
                _box(cloth, Vector3(0.30, 0.30, 0.07), Vector3(0, 0.15, 0), trim_m)


# ---------- КУЗНИЦА (v9.0) ----------

## Двор кузнеца на юго-востоке: навес, горн с углями, наковальня,
## бочка для закалки. Тёплый отблеск горна виден с главной улицы.
func _build_smithy() -> void:
        var cx := 17.0
        var cz := 13.0
        var y := GameWorld.terrain_height(cx, cz)
        var root := Node3D.new()
        root.position = Vector3(cx, y, cz)
        root.rotation.y = deg_to_rad(-90.0)
        add_child(root)
        var post_m := _pmat("dark_planks", Color(0.40, 0.34, 0.28), 0.5, 0.95)
        for pp in [Vector3(-1.8, 0, -1.4), Vector3(1.8, 0, -1.4), Vector3(-1.8, 0, 1.6), Vector3(1.8, 0, 1.6)]:
                _cyl(root, 0.09, 0.11, 2.6, Vector3(pp.x, 1.3, pp.z), post_m, 8)
        _box(root, Vector3(4.6, 0.18, 3.8), Vector3(0, 2.7, 0), m_roof_wood)
        # Горн: каменное основание с тлеющими углями
        _box(root, Vector3(1.6, 1.0, 1.2), Vector3(-1.1, 0.5, -0.4), m_stone)
        var ember_m := _cmap(Color(0.1, 0.02, 0.0), 1.0)
        ember_m.emission_enabled = true
        ember_m.emission = Color(1.0, 0.35, 0.08)
        ember_m.emission_energy_multiplier = 1.8
        _box(root, Vector3(1.3, 0.2, 0.9), Vector3(-1.1, 1.05, -0.4), ember_m)
        var forge_light := OmniLight3D.new()
        forge_light.light_color = Color(1.0, 0.45, 0.15)
        forge_light.light_energy = 2.0
        forge_light.omni_range = 7.0
        forge_light.position = Vector3(-1.1, 1.5, -0.4)
        forge_light.add_to_group("campfire_light")
        root.add_child(forge_light)
        # Наковальня (процедурная: тело + рог + основание)
        var iron_m := _cmap(Color(0.14, 0.13, 0.14), 0.35)
        iron_m.metallic = 0.9
        _box(root, Vector3(0.55, 0.12, 0.26), Vector3(0.6, 0.92, 0.3), iron_m)
        _box(root, Vector3(0.3, 0.3, 0.24), Vector3(0.6, 0.72, 0.3), iron_m)
        _box(root, Vector3(0.44, 0.44, 0.3), Vector3(0.6, 0.22, 0.3), m_beam)
        # Бочка закалки
        _cyl(root, 0.34, 0.3, 0.9, Vector3(1.6, 0.45, 1.2), _pmat("dark_planks", Color(0.45, 0.38, 0.3), 0.5), 12)
        _collider(root, Vector3(4.6, 3.2, 3.8), Vector3(0, 1.6, 0))


# ---------- ОГОРОДЫ (v9.0) ----------

## Грядки с капустой на восточной окраине, за оградой.
func _build_gardens() -> void:
        var soil_m := _pmat("forrest_sand_01", Color(0.45, 0.38, 0.30), 0.8, 1.0, 0.9)
        var leaf_m := _cmap(Color(0.16, 0.30, 0.14), 0.95)
        for gi in 4:
                var gx := 22.0 + (gi % 2) * 4.2
                var gz := -6.0 + gi * 3.8
                var y := GameWorld.terrain_height(gx, gz)
                _box(self, Vector3(3.6, 0.3, 2.4), Vector3(gx, y + 0.14, gz), soil_m)
                for r in 5:
                        for c in 3:
                                var cab := MeshInstance3D.new()
                                var cm := SphereMesh.new()
                                cm.radius = 0.28
                                cm.height = 0.5
                                cm.radial_segments = 8
                                cm.rings = 4
                                cab.mesh = cm
                                cab.material_override = leaf_m
                                cab.position = Vector3(gx - 1.3 + c * 1.3, y + 0.42, gz - 0.8 + r * 0.4)
                                add_child(cab)


# ---------- ЧАСТОКОЛ (v9.0) ----------

## Кольцо заострённых брёвен вокруг деревни (r=30): защита от лесной
## нечисти. Южные ворота — широкий проход к дороге, северная калитка —
## тропинка к мельнице и пещере. Столбы встают ВПЛОТНУЮ — это стена,
## а не редкие колышки.
func _build_palissade() -> void:
        var log_m := _pmat("dark_planks", Color(0.52, 0.45, 0.38), 0.6, 0.95, 0.8)
        var tip_m := _cmap(Color(0.44, 0.38, 0.32), 0.98)
        var ring_r := 30.0
        var count := 460
        for i in count:
                var ang := TAU * i / count
                var deg := rad_to_deg(ang)
                # Южные ворота (юг = +Z, к спавну игрока): проход ~13 градусов
                if deg > 83.5 and deg < 96.5:
                        continue
                # Северная калитка к мельнице: ~6 градусов
                if deg > 266.0 and deg < 272.5:
                        continue
                var px := cos(ang) * ring_r
                var pz := sin(ang) * ring_r
                var y := GameWorld.terrain_height(px, pz)
                # v9.0: столбы следуют рельефу — строго только вода мешает
                if y < GameWorld.WATER_LEVEL + 0.5:
                        continue
                var log := _cyl(self, 0.17, 0.20, 3.4, Vector3(px, y + 1.7, pz), log_m, 6)
                # Остриё (не на каждом — живее)
                if i % 3 == 0:
                        var tip := _cyl(log, 0.0, 0.17, 0.45, Vector3(0, 1.92, 0), tip_m, 6)
                        tip.name = "Tip"
                log.look_at(Vector3(px * 2.0, y, pz * 2.0), Vector3.UP)


# ---------- МАЛЫЕ ПОСТРОЙКИ (v9.0: плотность застройки) ----------

## Амбар-сарай в северо-восточном квартале (лицом на запад, к проулку).
func _build_barn() -> void:
        var b := _building_at(Vector2(14.5, -11.5), deg_to_rad(-90.0))
        _box(b, Vector3(4.6, 2.4, 3.8), Vector3(0, 1.2, 0), m_wall)
        _roof_mesh(b, 5.2, 4.2, 2.4, 1.6, m_roof_wood, 0.7)
        _box(b, Vector3(1.2, 1.9, 0.16), Vector3(0, 1.0, 1.95), m_door)
        _box(b, Vector3(1.5, 0.2, 1.0), Vector3(0, 0.1, 2.3), m_stone)
        # Сено торчит из проёма
        _box(b, Vector3(1.0, 0.8, 0.5), Vector3(0, 0.75, 1.75), m_roof_straw)
        _collider(b, Vector3(5.2, 3.6, 4.4), Vector3(0, 1.8, 0))


## Дровяной навес в юго-западном дворе (лицом на восток).
func _build_woodshed() -> void:
        var b := _building_at(Vector2(-16.5, 14.5), deg_to_rad(90.0))
        var post_m := _pmat("dark_planks", Color(0.40, 0.34, 0.28), 0.5, 0.95)
        for pp in [Vector3(-1.5, 0, -0.9), Vector3(1.5, 0, -0.9), Vector3(-1.5, 0, 0.9), Vector3(1.5, 0, 0.9)]:
                _cyl(b, 0.08, 0.1, 2.2, Vector3(pp.x, 1.1, pp.z), post_m, 7)
        _box(b, Vector3(3.8, 0.14, 2.8), Vector3(0, 2.25, 0), m_roof_wood)
        # Поленница под навесом
        var log_m := _pmat("dark_planks", Color(0.5, 0.42, 0.34), 0.4)
        for i in 10:
                var row := 0.24 if i > 4 else 0.0
                var log := _cyl(b, 0.09, 0.1, 1.6,
                                Vector3(-0.9 + (i % 5) * 0.45, 0.24 + row, 0),
                                log_m, 6)
                log.rotation_degrees.z = 90
        _collider(b, Vector3(4.0, 2.6, 3.0), Vector3(0, 1.3, 0))


# ---------- РУИНЫ ----------

func _build_ruins() -> void:
        var c := GameWorld.HILL_CENTER
        var top_y := GameWorld.terrain_height(c.x, c.y)
        var b := Node3D.new()
        b.position = Vector3(c.x, top_y - 0.2, c.y)
        add_child(b)
        # Кольцо полуразрушенной стены с проёмами
        for i in 10:
                var ang := TAU * i / 10.0
                if i % 4 == 3:
                        continue  # проём
                var px := cos(ang) * 8.0
                var pz := sin(ang) * 8.0
                var h := rng.randf_range(1.4, 4.8)
                var wall := _box(b, Vector3(2.4, h, 0.9), Vector3(px, h * 0.5, pz), m_ruin,
                        Vector3(0, rad_to_deg(-ang) + 90.0, 0))
                wall.scale.y = 1.0
                # Зубцы на высоких секциях
                if h > 3.2:
                        var tangent := Vector3(-sin(ang), 0.0, cos(ang))
                        for t in [-0.75, 0.75]:
                                _box(b, Vector3(0.6, 0.55, 0.95),
                                        Vector3(px, h + 0.27, pz) + tangent * t, m_ruin,
                                        Vector3(0, rad_to_deg(-ang) + 90.0, 0))
        # Колонны: 3 стоящих, 1 упавшая
        for i in 4:
                var ang := TAU * i / 4.0 + 0.35
                var px := cos(ang) * 5.0
                var pz := sin(ang) * 5.0
                var col_h := rng.randf_range(3.6, 5.2)
                if i == 2:
                        # Упавшая колонна
                        var fallen := _cyl(b, 0.38, 0.42, col_h, Vector3(px * 0.7, 0.4, pz * 0.7), m_ruin, 12)
                        fallen.rotation = Vector3(0, rng.randf() * TAU, PI * 0.5 - 0.06)
                else:
                        _cyl(b, 0.42, 0.5, 0.5, Vector3(px, 0.25, pz), m_ruin, 12)
                        _cyl(b, 0.38, 0.36, col_h, Vector3(px, 0.5 + col_h * 0.5, pz), m_ruin, 12)
                        _box(b, Vector3(1.1, 0.35, 1.1), Vector3(px, 0.5 + col_h + 0.15, pz), m_ruin)
        # Арка у входа
        _box(b, Vector3(1.0, 4.6, 1.0), Vector3(-1.6, 2.3, 10.5), m_ruin)
        _box(b, Vector3(1.0, 3.4, 1.0), Vector3(1.6, 1.7, 10.5), m_ruin)
        _box(b, Vector3(4.6, 0.9, 1.2), Vector3(0, 4.8, 10.5), m_ruin, Vector3(0, 0, 3))
        # Алтарь со светящимся кристаллом
        _box(b, Vector3(2.2, 0.9, 1.4), Vector3(0, 0.45, 0), m_ruin)
        var crystal := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.0
        cm.bottom_radius = 0.35
        cm.height = 1.1
        cm.radial_segments = 6
        crystal.mesh = cm
        var cm_mat := StandardMaterial3D.new()
        cm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        cm_mat.albedo_color = Color(0.45, 0.85, 1.0, 0.9)
        cm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        cm_mat.emission_enabled = true
        cm_mat.emission = Color(0.3, 0.75, 1.0)
        cm_mat.emission_energy_multiplier = 2.6
        crystal.material_override = cm_mat
        crystal.position = Vector3(0, 1.45, 0)
        b.add_child(crystal)
        var cl := OmniLight3D.new()
        cl.light_color = Color(0.4, 0.75, 1.0)
        cl.light_energy = 2.0
        cl.omni_range = 10.0
        cl.position = Vector3(0, 1.8, 0)
        b.add_child(cl)
        # Обломки
        for i in 12:
                var ang := rng.randf() * TAU
                var r := rng.randf_range(3.0, 9.5)
                var rub := MeshInstance3D.new()
                var rm := BoxMesh.new()
                rm.size = Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.3, 0.7),
                        rng.randf_range(0.5, 1.2))
                rub.mesh = rm
                rub.material_override = m_ruin
                rub.position = Vector3(cos(ang) * r, 0.15, sin(ang) * r)
                rub.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)
                b.add_child(rub)


# ---------- РЕКВИЗИТ ----------

func _build_props() -> void:
        # Стога сена — у огородов и в юго-зап. двору
        var hay := _pmat("roof_planks", Color(1.1, 0.95, 0.55), 0.9, 1.0, 0.7)
        for hp in [Vector3(25.5, 0, 9.5), Vector3(-18.5, 0, 22.5), Vector3(-20.5, 0, -13.5)]:
                var stog := MeshInstance3D.new()
                var km := CylinderMesh.new()
                km.top_radius = 0.0
                km.bottom_radius = 1.5
                km.height = 2.6
                km.radial_segments = 12
                stog.mesh = km
                stog.material_override = hay
                stog.position = Vector3(hp.x, GameWorld.terrain_height(hp.x, hp.z) + 1.3, hp.z)
                add_child(stog)
        # Бочки — у таверны, кузницы, домов
        var barrel_m := _pmat("dark_planks", Color(0.6, 0.5, 0.4), 0.5)
        var hoop_m := _cmap(Color(0.16, 0.15, 0.14), 0.5)
        for bp in [Vector3(-7.4, 0, -10.2), Vector3(-8.1, 0, -9.3), Vector3(17.6, 0, 14.6),
                        Vector3(-10.2, 0, -3.4), Vector3(5.0, 0, 4.6)]:
                var y := GameWorld.terrain_height(bp.x, bp.z)
                var bar := _cyl(self, 0.36, 0.33, 0.95, Vector3(bp.x, y + 0.48, bp.z), barrel_m, 14)
                for hy in [0.15, 0.8]:
                        _cyl(bar, 0.375, 0.375, 0.06, Vector3(0, hy - 0.48, 0), hoop_m, 14)
        # Ящики
        for cp in [Vector3(4.3, 0, 4.9), Vector3(3.6, 0, -9.6), Vector3(-2.6, 0, 24.2),
                        Vector3(10.6, 0, 7.2), Vector3(15.4, 0, 14.9), Vector3(-10.6, 0, -13.8)]:
                var y := GameWorld.terrain_height(cp.x, cp.z)
                var crate := _box(self, Vector3(0.72, 0.72, 0.72), Vector3(cp.x, y + 0.36, cp.z),
                        m_wall, Vector3(0, rng.randf() * TAU, 0))
                crate.name = "Crate"
        # Поленница у таверны
        var log_m := _pmat("dark_planks", Color(0.55, 0.46, 0.36), 0.35)
        for i in 7:
                var ang := i * 0.45
                var r := 0.14
                var lx := 6.2 + cos(ang) * r * 2.2
                var lz := -11.3 + sin(ang) * r * 2.2
                var y := GameWorld.terrain_height(lx, lz)
                var log := MeshInstance3D.new()
                var lm := CylinderMesh.new()
                lm.top_radius = 0.1
                lm.bottom_radius = 0.12
                lm.height = 1.1
                lm.radial_segments = 8
                log.mesh = lm
                log.material_override = log_m
                log.position = Vector3(lx, y + 0.12 + (0.21 if i > 4 else 0.0), lz)
                log.rotation_degrees.z = 90
                log.rotation_degrees.y = rng.randf_range(-10, 10)
                add_child(log)
        # Поленница у кузницы
        for i in 5:
                var lx2 := 15.0 + (i % 3) * 0.26
                var lz2 := 11.4 + (i / 3.0) * 0.26
                var y2 := GameWorld.terrain_height(lx2, lz2)
                var log2 := MeshInstance3D.new()
                var lm2 := CylinderMesh.new()
                lm2.top_radius = 0.1
                lm2.bottom_radius = 0.12
                lm2.height = 1.0
                lm2.radial_segments = 8
                log2.mesh = lm2
                log2.material_override = log_m
                log2.position = Vector3(lx2, y2 + 0.12, lz2)
                log2.rotation_degrees.z = 90
                add_child(log2)


# ---------- ИМПОРТНЫЕ CC0-МОДЕЛИ ----------

func _build_imported() -> void:
        # v9.0: два дома-фахверка (Quaternius) — в ряды вдоль улиц:
        # один в восточный ряд (лицом на запад), другой — на северный проулок
        var house_restyle := {
                "light_ochre": m_plaster, "dark_blue": m_roof_tile,
                "brown": m_beam, "dark_brown": m_beam,
                "dark_grey": m_stone, "dark_purple": m_beam,
        }
        for hd in [[Vector2(13.5, 5.5), -90.0], [Vector2(15.5, -17.0), 180.0]]:
                var hp: Vector2 = hd[0]
                var yaw: float = deg_to_rad(hd[1])
                var holder := _place_model(MDL + "quat_medieval_house.fbx",
                        Vector3(hp.x, GameWorld.terrain_height(hp.x, hp.y), hp.y),
                        yaw, 6.4, 0.28, house_restyle)
                if holder != null:
                        _collider(holder, Vector3(8.5, 7.0, 8.5), Vector3(0, 3.5, 0))
                        # Тёплый свет у входа
                        var pl := OmniLight3D.new()
                        pl.light_color = Color(1.0, 0.65, 0.3)
                        pl.light_energy = 1.8
                        pl.omni_range = 9.0
                        pl.position = Vector3(0, 3.0, 4.2)
                        holder.add_child(pl)
                        _smoke(holder, Vector3(1.6, 6.6, -1.8))
                else:
                        _build_house(hp, 6.0, 6.0, 3.0, m_plaster, m_roof_straw, true, true, yaw)

        # Ветряная мельница (Kenney) на пригорке к северо-востоку
        var wpos := Vector2(44.0, 30.0)
        var wy := GameWorld.terrain_height(wpos.x, wpos.y)
        var base := Node3D.new()
        base.position = Vector3(wpos.x, wy, wpos.y)
        add_child(base)
        _cyl(base, 4.4, 4.8, 1.2, Vector3(0, 0.6, 0), m_stone, 18)
        var mill := _place_model(MDL + "ken_tower_windmill.fbx",
                Vector3(wpos.x, wy + 1.1, wpos.y),
                -0.5, 11.5, 0.45, {"grey": m_stone, "dark_grey": m_stone, "brown": m_beam, "dark_brown": m_beam, "light_brown": m_beam, "white": m_plaster, "black": m_ruin, "roof_black": m_roof_wood, "roofblack": m_roof_wood})
        if mill != null:
                _collider(mill, Vector3(5.0, 13.0, 5.0), Vector3(0, 6.5, 0))
                var ml := OmniLight3D.new()
                ml.light_color = Color(1.0, 0.7, 0.35)
                ml.light_energy = 1.6
                ml.omni_range = 12.0
                ml.position = Vector3(0, 3.2, 2.8)
                mill.add_child(ml)
                _smoke(mill, Vector3(0, 12.2, 0))
        else:
                base.free()

        # Лавки у костра (Poly Haven, фотограмметрия)
        for bdef in [[Vector3(-6.2, 0, 0.6), 2.2], [Vector3(-1.6, 0, 5.6), 4.4], [Vector3(-6.0, 0, 5.0), 3.1]]:
                var bench := _place_model(MDL + "painted_wooden_bench.glb",
                        Vector3(bdef[0].x, GameWorld.terrain_height(bdef[0].x, bdef[0].z), bdef[0].z),
                        bdef[1], 0.95, 0.04, {})
                if bench == null:
                        _box(self, Vector3(1.6, 0.1, 0.5), Vector3(bdef[0].x, GameWorld.terrain_height(bdef[0].x, bdef[0].z) + 0.5, bdef[0].z), m_beam,
                                Vector3(0, bdef[1], 0))

        # Живые кусты у домов (Poly Haven)
        for s in [Vector3(-10.4, 0, 0.6), Vector3(10.8, 0, -3.8), Vector3(19.0, 0, 6.0),
                        Vector3(-18.2, 0, 8.5), Vector3(-19.5, 0, -18.5), Vector3(8.2, 0, -13.2),
                        Vector3(26.8, 0, -2.0)]:
                var bush := _place_model(MDL + "wild_rooibos_bush.glb",
                        Vector3(s.x, GameWorld.terrain_height(s.x, s.z), s.z),
                        rng.randf() * TAU, rng.randf_range(0.7, 1.1), 0.05, {})
                if bush == null:
                        break


# ---------- ХЕЛПЕРЫ ИМПОРТА ----------

## AABB поддерева в локальных координатах root.
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
                return AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
        return box


## Ставит импортную модель: подгон по высоте, ось у земли, разворот к
## центру, замена материалов по подстрокам имён (restyle).
func _place_model(path: String, pos: Vector3, yaw: float, target_h: float,
                sink: float, restyle: Dictionary) -> Node3D:
        if not ResourceLoader.exists(path):
                return null
        var ps := load(path) as PackedScene
        if ps == null:
                return null
        var inst := ps.instantiate()
        var holder := Node3D.new()
        holder.add_child(inst)
        add_child(holder)
        if not restyle.is_empty():
                for mi in inst.find_children("*", "MeshInstance3D", true, false):
                        var mesh: Mesh = (mi as MeshInstance3D).mesh
                        if mesh is ArrayMesh:
                                for i in mesh.get_surface_count():
                                        var m := mesh.surface_get_material(i)
                                        if m == null:
                                                continue
                                        var key := m.resource_name.to_lower()
                                        var hit := false
                                        for sub in restyle:
                                                if String(sub) != "" and key.contains(String(sub)):
                                                        mesh.surface_set_material(i, restyle[sub])
                                                        hit = true
                                                        break
                                        if not hit and m is StandardMaterial3D:
                                                m.roughness = 0.95
        var box := _subtree_aabb(inst)
        var s := target_h / maxf(box.size.y, 0.001)
        inst.scale = Vector3(s, s, s)
        # Ставим «нижний центр» модели в начало координат holder
        inst.position = Vector3(
                -(box.position.x + box.size.x * 0.5) * s,
                -box.position.y * s,
                -(box.position.z + box.size.z * 0.5) * s)
        holder.position = Vector3(pos.x, pos.y - sink, pos.z)
        holder.rotation.y = yaw
        return holder

