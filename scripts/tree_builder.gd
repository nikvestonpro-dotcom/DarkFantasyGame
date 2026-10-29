extends Node3D
## Лес: ели и сосны — ствол и скелет ветвей в PBR-коре Poly Haven (CC0),
## крона из фотограмметрических карточек хвои Poly Haven с ветром.
## Живой декор Poly Haven: камни, пни, сухие стволы, кусты.
## Брёвна и фоновые валуны — процедурные.

const NeedlesShader := preload("res://shaders/needles.gdshader")

const TEX := "res://assets/textures/"
const MDL := "res://assets/models/"

## Плотные участки атласов хвои — выбраны по карте альфы и доминирующему
## цвету (зелёные клетки с частичным покрытием = фото-хвоя на прозрачном фоне).
const FIR_RECTS := [
        [0.25, 0.75, 0.375, 0.875], [0.75, 0.75, 0.875, 0.875],
        [0.5, 0.625, 0.625, 0.75], [0.75, 0.625, 0.875, 0.75],
        [0.375, 0.375, 0.5, 0.5], [0.375, 0.25, 0.5, 0.375],
        [0.75, 0.25, 0.875, 0.375], [0.5, 0.375, 0.625, 0.5],
        [0.625, 0.25, 0.75, 0.375], [0.125, 0.75, 0.25, 0.875],
]
const PINE_RECTS := [
        [0.0, 0.5, 0.125, 0.625], [0.125, 0.5, 0.25, 0.625],
        [0.625, 0.5, 0.75, 0.625], [0.75, 0.5, 0.875, 0.625],
        [0.75, 0.625, 0.875, 0.75], [0.625, 0.375, 0.75, 0.5],
        [0.75, 0.25, 0.875, 0.375], [0.25, 0.0, 0.375, 0.125],
        [0.0, 0.625, 0.125, 0.75], [0.125, 0.625, 0.25, 0.75],
]

var rng := RandomNumberGenerator.new()
var _bark_fir: StandardMaterial3D
var _bark_pine: StandardMaterial3D
var _bark_dead: StandardMaterial3D
var _stone: StandardMaterial3D


func _ready() -> void:
        rng.seed = 777
        _make_materials()
        _scatter_forest()
        _scatter_snags()
        _scatter_logs()
        _scatter_rocks()
        _scatter_ph_decor()


# ---------- МАТЕРИАЛЫ ----------

func _ph_mat(folder: String, tint: Color, uv_scale: Vector3, nrm := 1.4) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        var base := TEX + folder + "/"
        m.albedo_texture = load(base + "bark_diff_1k.jpg")
        m.albedo_color = tint
        m.normal_enabled = true
        m.normal_texture = load(base + "bark_nor_1k.jpg")
        m.normal_scale = nrm
        m.roughness = 1.0
        m.roughness_texture = load(base + "bark_arm_1k.jpg")
        m.uv1_scale = uv_scale
        return m


func _make_materials() -> void:
        _bark_fir = _ph_mat("fir_tree_01", Color(0.88, 0.85, 0.8),
                Vector3(1.5, 2.2, 1.0), 1.4)
        _bark_pine = _ph_mat("pine_tree_01", Color(0.92, 0.87, 0.82),
                Vector3(1.7, 2.4, 1.0), 1.4)
        _bark_dead = _ph_mat("pine_tree_01", Color(0.5, 0.46, 0.42),
                Vector3(1.6, 2.0, 1.0), 1.2)
        var id := "rock_wall_02"
        _stone = StandardMaterial3D.new()
        _stone.albedo_texture = load(TEX + id + "/" + id + "_diff_2k.jpg")
        _stone.albedo_color = Color(0.85, 0.9, 1.05)
        _stone.normal_enabled = true
        _stone.normal_texture = load(TEX + id + "/" + id + "_nor_2k.jpg")
        _stone.roughness = 0.92
        _stone.uv1_triplanar = true
        _stone.uv1_scale = Vector3(0.35, 0.35, 0.35)


func _needles_mat(species: String, tree_h: float) -> ShaderMaterial:
        var m := ShaderMaterial.new()
        m.shader = NeedlesShader
        var folder := "fir_tree_01" if species == "fir" else "pine_tree_01"
        var base := TEX + folder + "/"
        m.set_shader_parameter("albedo_tex", load(base + "twig_diff_rgba_1k.png"))
        m.set_shader_parameter("nor_tex", load(base + "twig_nor_1k.jpg"))
        m.set_shader_parameter("tree_height", tree_h)
        if species == "fir":
                # v9.0: тёмно-зелёная хвоя — при ночном лунном свете читается
                # как ель, а не как «побелевшая новогодняя ёлка»
                m.set_shader_parameter("tint", Vector3(0.62, 0.80, 0.52))
                m.set_shader_parameter("wind_strength", 0.42)
        else:
                # сосновая хвоя на фото желтоватая — сдвигаем в зелёный
                m.set_shader_parameter("tint", Vector3(0.52, 0.72, 0.45))
                m.set_shader_parameter("wind_strength", 0.5)
        return m


# ---------- ГЕОМЕТРИЯ ДЕРЕВЬЕВ ----------

func _add_cyl(st: SurfaceTool, rb: float, rt: float, h: float, seg: int,
                xf: Transform3D, cap := true) -> void:
        var cyl := CylinderMesh.new()
        cyl.top_radius = rt
        cyl.bottom_radius = rb
        cyl.height = h
        cyl.radial_segments = seg
        cyl.rings = 0
        cyl.cap_top = rt > 0.01 and cap
        cyl.cap_bottom = rb > 0.01 and cap
        var arrays := cyl.get_mesh_arrays()
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
        var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        for i in idx.size():
                var k: int = idx[i]
                var v: Vector3 = xf * verts[k]
                var nrm: Vector3 = (xf.basis * norms[k]).normalized()
                st.set_normal(nrm)
                st.set_uv(uvs[k])
                st.add_vertex(v)


func _dir_basis(dir: Vector3) -> Basis:
        var y := dir.normalized()
        var x := Vector3.UP.cross(y)
        if x.length() < 0.001:
                x = Vector3.RIGHT
        else:
                x = x.normalized()
        var z := x.cross(y).normalized()
        return Basis(x, y, z)


func _card(st: SurfaceTool, center: Vector3, a1: Vector3, a2: Vector3,
                w: float, hgt: float, rect: Array) -> void:
        # Квадро-карточка: оси a1/a2, случайный под-прямоугольник атласа
        var rw: float = rng.randf_range(0.62, 1.0)
        var rh: float = rng.randf_range(0.62, 1.0)
        var uw: float = rw * 0.115
        var vh: float = rh * 0.115
        var u0: float = clampf(lerpf(float(rect[0]), float(rect[2]), rng.randf() * 0.35),
                0.0, 1.0 - 0.13)
        var v0: float = clampf(lerpf(float(rect[1]), float(rect[3]), rng.randf() * 0.35),
                0.0, 1.0 - 0.13)
        u0 = minf(u0, float(rect[2]) - uw)
        v0 = minf(v0, float(rect[3]) - vh)
        u0 = maxf(u0, 0.0)
        v0 = maxf(v0, 0.0)
        var hw := w * 0.5
        var hh := hgt * 0.5
        var nrm: Vector3 = (a1.cross(a2)).normalized()
        var pts := [
                center - a1 * hw - a2 * hh,
                center + a1 * hw - a2 * hh,
                center + a1 * hw + a2 * hh,
                center - a1 * hw + a2 * hh,
        ]
        var uvps := [
                Vector2(u0, v0), Vector2(u0 + uw, v0),
                Vector2(u0 + uw, v0 + vh), Vector2(u0, v0 + vh),
        ]
        var order := [0, 1, 2, 0, 2, 3]
        if rng.randf() < 0.5:
                order = [0, 2, 1, 0, 3, 2]
        for o in order:
                st.set_normal(nrm)
                st.set_uv(uvps[o])
                st.add_vertex(pts[o])


func _tree_mesh(species: String, variant: int) -> ArrayMesh:
        var is_fir := species == "fir"
        var heights: Array
        var crowns: Array
        var tiers_n: Array
        var bare_k: float
        if is_fir:
                # v9.0: ниже прежнего (было 26-49 м — рядом с 7-метровыми
                # домами лес выглядел секвойями); теперь 17-33 м
                heights = [17.0, 22.0, 27.0, 33.0]
                crowns = [3.4, 4.2, 5.0, 5.8]
                tiers_n = [10, 12, 13, 14]
                bare_k = 0.12
        else:
                heights = [15.0, 19.0, 24.0]
                crowns = [3.4, 4.2, 5.0]
                tiers_n = [8, 10, 11]
                bare_k = 0.34
        var h: float = heights[variant]
        var cr: float = crowns[variant]
        var tiers: int = tiers_n[variant]
        var rects: Array = FIR_RECTS if is_fir else PINE_RECTS

        var mesh := ArrayMesh.new()
        var bark: StandardMaterial3D = _bark_fir if is_fir else _bark_pine

        # --- Ствол: конические сегменты с изгибом ---
        var st_trunk := SurfaceTool.new()
        st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
        var rb := 0.28 + cr * 0.08
        var trunk_top := h * (0.62 if is_fir else 0.78)
        var bend := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
        var segs := [
                [0.0, trunk_top * 0.38, rb * 1.25, rb * 0.72],
                [trunk_top * 0.38, trunk_top * 0.72, rb * 0.72, rb * 0.40],
                [trunk_top * 0.72, trunk_top, rb * 0.40, 0.07],
        ]
        for sdef in segs:
                var y0: float = sdef[0]
                var y1: float = sdef[1]
                var r0: float = sdef[2]
                var r1: float = sdef[3]
                var mid := (y0 + y1) * 0.5
                var off := bend * (mid / trunk_top) * (mid / trunk_top)
                _add_cyl(st_trunk, r0, r1, y1 - y0, 9,
                        Transform3D(Basis.IDENTITY, Vector3(off.x, mid, off.z)))
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st_trunk.commit_to_arrays())
        mesh.surface_set_material(mesh.get_surface_count() - 1, bark)

        # --- Ветви-скелет + карточки хвои ---
        var st_fol := SurfaceTool.new()
        st_fol.begin(Mesh.PRIMITIVE_TRIANGLES)
        var crown_bottom := h * (bare_k + 0.08)
        for i in tiers:
                var t := float(i) / float(tiers - 1)
                var tier_y: float = lerpf(crown_bottom, h * 0.97, t)
                var tier_r: float = maxf(cr * pow(1.0 - t, 0.78), 0.5)
                tier_r *= rng.randf_range(0.9, 1.1)
                var droop: float = lerpf(0.55 if is_fir else 0.30, 0.12 if is_fir else 0.04, t)
                var nb := int(round(lerp(9.0, 4.0, t) * rng.randf_range(0.85, 1.15)))
                nb = maxf(4, nb)
                if not is_fir:
                        nb = maxf(5, nb - 1)
                for j in nb:
                        var a := TAU * float(j) / float(nb) + rng.randf_range(-0.3, 0.3)
                        var out := Vector3(cos(a), 0.0, sin(a))
                        var dir := Vector3(out.x, -droop, out.z).normalized()
                        var bl: float = tier_r * rng.randf_range(1.05, 1.6)
                        if not is_fir:
                                bl *= 1.18
                        var br := 0.10 + bl * 0.16
                        var attach := Vector3(rng.randf_range(-0.15, 0.15), tier_y,
                                rng.randf_range(-0.15, 0.15))
                        # скелетная ветвь
                        var xf := Transform3D(_dir_basis(dir), attach + dir * bl * 0.5)
                        _add_cyl(st_fol, br, 0.02, bl, 5, xf)
                        # широкая карточка у основания ветви
                        var up := Vector3.UP.lerp(dir, 0.18).normalized()
                        var base_pt := attach + dir * bl * 0.34 + Vector3.UP * bl * 0.05
                        _card(st_fol, base_pt, dir, up, bl * 1.15, bl * 0.6,
                                rects[rng.randi() % rects.size()])
                        # карточка вдоль ветви
                        var mid_pt := attach + dir * bl * 0.62 + Vector3.UP * bl * 0.10
                        _card(st_fol, mid_pt, dir, up, bl * 1.05, bl * 0.55,
                                rects[rng.randi() % rects.size()])
                        # свисающая карточка на конце
                        var drop := Vector3.UP.lerp(-dir, 0.75).normalized()
                        var tip_pt := attach + dir * bl * 0.94 - Vector3.UP * bl * 0.06
                        _card(st_fol, tip_pt, dir, drop, bl * 0.85, bl * 0.45,
                                rects[rng.randi() % rects.size()])
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st_fol.commit_to_arrays())
        mesh.surface_set_material(mesh.get_surface_count() - 1, _needles_mat(species, h))
        return mesh


# ---------- РАССАЕНИЕ ЛЕСА ----------

func _scatter_forest() -> void:
        var cell_size := 7.0
        var occupied := {}
        var plans := [
                ["fir", 0, 210], ["fir", 1, 185], ["fir", 2, 155], ["fir", 3, 125],
                ["pine", 0, 105], ["pine", 1, 85],
        ]
        for plan in plans:
                var mesh := _tree_mesh(plan[0], plan[1])
                var want: int = plan[2]
                var mm := MultiMesh.new()
                mm.transform_format = MultiMesh.TRANSFORM_3D
                mm.mesh = mesh
                mm.instance_count = want
                var placed := 0
                var guard := 0
                while placed < want and guard < want * 90:
                        guard += 1
                        var p := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * GameWorld.TERRAIN_SIZE * 0.48
                        var y := GameWorld.terrain_height(p.x, p.y)
                        if y < GameWorld.WATER_LEVEL + 1.0:
                                continue
                        # v9.0: чистая полоса вокруг деревни шире (частокол r30,
                        # огороды до r27 — лес отступает до 52 м)
                        if p.distance_to(GameWorld.VILLAGE_CENTER) < GameWorld.VILLAGE_RADIUS * 2.0:
                                continue
                        if p.distance_to(GameWorld.LAKE_CENTER) < GameWorld.LAKE_RADIUS * 0.98:
                                continue
                        if p.distance_to(GameWorld.HILL_CENTER) < 17.0:
                                continue
                        # v5.0: расчищаем пещеру и замок
                        if GameWorld.cave_ridge_distance(p) < 24.0:
                                continue
                        if p.distance_to(GameWorld.CASTLE_CENTER) < 48.0:
                                continue
                        # v10.0: башня, деревня № 2, ритуальная прогалина
                        if p.distance_to(GameWorld.TOWER_CENTER) < 20.0:
                                continue
                        if p.distance_to(GameWorld.HAMLET_CENTER) < GameWorld.HAMLET_RADIUS * 1.7:
                                continue
                        if p.distance_to(GameWorld.RITUAL_CENTER) < GameWorld.RITUAL_RADIUS * 1.9:
                                continue
                        # Просека у мельницы
                        if p.distance_to(Vector2(44.0, 30.0)) < 9.0:
                                continue
                        if GameWorld.path_distance(p) < 3.4:
                                continue
                        # Не сажаем на отвесных склонах
                        var h2 := GameWorld.terrain_height(p.x + 2.0, p.y + 2.0)
                        if absf(h2 - y) > 3.6:
                                continue
                        var fk := GameWorld.forest_density(p.x, p.y)
                        if rng.randf() > 0.14 + fk * 0.86:
                                continue
                        var cell := Vector2i(int(p.x / cell_size), int(p.y / cell_size))
                        if occupied.has(cell):
                                continue
                        occupied[cell] = true
                        var s := rng.randf_range(0.80, 1.18)
                        var basis := Basis(Vector3.UP, rng.randf() * TAU)
                        basis = basis * Basis(Vector3.RIGHT, rng.randf_range(-0.045, 0.045)) \
                                * Basis(Vector3.FORWARD, rng.randf_range(-0.045, 0.045))
                        basis = basis.scaled(Vector3(s, s * rng.randf_range(0.9, 1.18), s))
                        mm.set_instance_transform(placed, Transform3D(basis, Vector3(p.x, y - 0.25, p.y)))
                        placed += 1
                mm.visible_instance_count = placed
                var mmi := MultiMeshInstance3D.new()
                mmi.name = "Forest_%s%d" % [plan[0], plan[1]]
                mmi.multimesh = mm
                add_child(mmi)


# ---------- СУХИЕ СТВОЛЫ (процедурные) ----------

func _snag_mesh() -> ArrayMesh:
        var mesh := ArrayMesh.new()
        var h := rng.randf_range(11.0, 22.0)
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var rb := rng.randf_range(0.28, 0.5)
        var st_basis := _dir_basis(Vector3(
                rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12)).normalized())
        var mid := Transform3D(st_basis, Vector3(0, h * 0.25, 0))
        _add_cyl(st, rb, rb * 0.55, h * 0.5, 8, mid)
        var top := Transform3D(st_basis, Vector3(0, h * 0.75, 0))
        _add_cyl(st, rb * 0.55, 0.06, h * 0.5, 8, top)
        for j in int(rng.randf_range(3, 6)):
                var a := rng.randf() * TAU
                var y := rng.randf_range(h * 0.35, h * 0.85)
                var dir := Vector3(cos(a), rng.randf_range(0.3, 0.7), sin(a)).normalized()
                var bl := rng.randf_range(0.8, 2.0)
                var xf := Transform3D(_dir_basis(dir), Vector3(0, y, 0) + dir * bl * 0.5)
                _add_cyl(st, 0.10, 0.02, bl, 5, xf)
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
        mesh.surface_set_material(0, _bark_dead)
        return mesh


func _scatter_snags() -> void:
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = _snag_mesh()
        mm.instance_count = 45
        var placed := 0
        var guard := 0
        while placed < 45 and guard < 4000:
                guard += 1
                var p := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * GameWorld.TERRAIN_SIZE * 0.47
                var y := GameWorld.terrain_height(p.x, p.y)
                if y < GameWorld.WATER_LEVEL + 1.0:
                        continue
                if p.distance_to(GameWorld.VILLAGE_CENTER) < GameWorld.VILLAGE_RADIUS * 1.6:
                        continue
                if GameWorld.path_distance(p) < 3.0:
                        continue
                if GameWorld.cave_ridge_distance(p) < 14.0:
                        continue
                if p.distance_to(GameWorld.CASTLE_CENTER) < 46.0:
                        continue
                if GameWorld.forest_density(p.x, p.y) < 0.35:
                        continue
                var basis := Basis(Vector3.UP, rng.randf() * TAU)
                var s := rng.randf_range(0.8, 1.3)
                basis = basis.scaled(Vector3(s, s, s))
                mm.set_instance_transform(placed, Transform3D(basis, Vector3(p.x, y - 0.2, p.y)))
                placed += 1
        mm.visible_instance_count = placed
        var mmi := MultiMeshInstance3D.new()
        mmi.name = "Snags"
        mmi.multimesh = mm
        add_child(mmi)


# ---------- БРЁВНА (процедурные) ----------

func _scatter_logs() -> void:
        var log := CylinderMesh.new()
        log.top_radius = 0.32
        log.bottom_radius = 0.38
        log.height = 7.0
        log.radial_segments = 8
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = log
        mm.instance_count = 26
        var placed := 0
        var guard := 0
        while placed < 26 and guard < 2500:
                guard += 1
                var p := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * GameWorld.TERRAIN_SIZE * 0.46
                var y := GameWorld.terrain_height(p.x, p.y)
                if y < GameWorld.WATER_LEVEL + 1.0:
                        continue
                if p.distance_to(GameWorld.VILLAGE_CENTER) < GameWorld.VILLAGE_RADIUS * 1.5:
                        continue
                if GameWorld.path_distance(p) < 3.5:
                        continue
                if GameWorld.cave_ridge_distance(p) < 13.0:
                        continue
                if p.distance_to(GameWorld.CASTLE_CENTER) < 45.0:
                        continue
                if GameWorld.forest_density(p.x, p.y) < 0.4:
                        continue
                var s := rng.randf_range(0.6, 1.2)
                var basis := Basis(Vector3.UP, rng.randf() * TAU) \
                        * Basis(Vector3.FORWARD, rng.randf_range(1.35, 1.65))
                basis = basis.scaled(Vector3(s, s, s))
                mm.set_instance_transform(placed, Transform3D(basis, Vector3(p.x, y + 0.3, p.y)))
                placed += 1
        mm.visible_instance_count = placed
        var mmi := MultiMeshInstance3D.new()
        mmi.name = "Logs"
        mmi.multimesh = mm
        mmi.material_override = _bark_dead
        add_child(mmi)


# ---------- ФОНОВЫЕ ВАЛУНЫ (процедурные) ----------

func _scatter_rocks() -> void:
        var rock := SphereMesh.new()
        rock.radius = 1.0
        rock.height = 1.0
        rock.radial_segments = 9
        rock.rings = 4
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = rock
        mm.instance_count = 95
        var placed := 0
        var guard := 0
        while placed < 95 and guard < 5000:
                guard += 1
                var p := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * GameWorld.TERRAIN_SIZE * 0.47
                var y := GameWorld.terrain_height(p.x, p.y)
                if y < GameWorld.WATER_LEVEL - 0.5:
                        continue
                if p.distance_to(GameWorld.VILLAGE_CENTER) < GameWorld.VILLAGE_RADIUS * 1.4:
                        continue
                if GameWorld.path_distance(p) < 2.8:
                        continue
                if p.distance_to(GameWorld.CAVE_CENTER) < 26.0:
                        continue
                if p.distance_to(GameWorld.CASTLE_CENTER) < 44.0:
                        continue
                var s := rng.randf_range(0.6, 4.0)
                var basis := Basis(Vector3.UP, rng.randf() * TAU)
                basis = basis.scaled(Vector3(s, s * rng.randf_range(0.45, 0.8), s * rng.randf_range(0.7, 1.25)))
                mm.set_instance_transform(placed, Transform3D(basis, Vector3(p.x, y - s * 0.2, p.y)))
                placed += 1
        mm.visible_instance_count = placed
        var mmi := MultiMeshInstance3D.new()
        mmi.name = "Rocks"
        mmi.multimesh = mm
        mmi.material_override = _stone
        add_child(mmi)


# ---------- ДЕКОР POLY HAVEN (фотограмметрия) ----------

## Точки для PH-декора: подбираются рядом с деревней, тропами и берегом.
func _decor_points(n: int, near_village: bool, min_village_dist := 7.0,
                min_path_dist := 2.6) -> Array:
        var pts: Array = []
        var guard := 0
        while pts.size() < n and guard < n * 90:
                guard += 1
                var p: Vector2
                if near_village:
                        var ang := rng.randf() * TAU
                        var r := rng.randf_range(4.0, 24.0)
                        p = Vector2(cos(ang) * r, sin(ang) * r)
                else:
                        p = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * GameWorld.TERRAIN_SIZE * 0.44
                var y := GameWorld.terrain_height(p.x, p.y)
                if y < GameWorld.WATER_LEVEL + 0.25:
                        continue
                if GameWorld.path_distance(p) < min_path_dist and not near_village:
                        continue
                if p.distance_to(GameWorld.VILLAGE_CENTER) < min_village_dist and not near_village:
                        continue
                if p.distance_to(GameWorld.CAVE_CENTER) < 26.0:
                        continue
                if p.distance_to(GameWorld.CASTLE_CENTER) < 44.0:
                        continue
                pts.append(Vector3(p.x, y, p.y))
        return pts


func _ph_instances(path: String, points: Array, fit_y: bool,
                size_min: float, size_max: float, sink := 0.06) -> void:
        if points.is_empty() or not ResourceLoader.exists(path):
                return
        var ps := load(path) as PackedScene
        var inst := ps.instantiate()
        # Меши модели (без трансформов сцены — каждый как отдельный объект)
        var meshes: Array = []
        for mi in inst.find_children("*", "MeshInstance3D", true, false):
                var m: Mesh = (mi as MeshInstance3D).mesh
                if m is ArrayMesh and not meshes.has(m):
                        meshes.append(m)
        inst.free()
        if meshes.is_empty():
                return
        # Один MultiMesh на меш, точки раздаются по кругу
        var per_mesh: Array = []
        per_mesh.resize(meshes.size())
        for i in per_mesh.size():
                per_mesh[i] = []
        for i in points.size():
                per_mesh[i % meshes.size()].append(points[i])
        for mi_idx in meshes.size():
                var list: Array = per_mesh[mi_idx]
                if list.is_empty():
                        continue
                var mesh: ArrayMesh = meshes[mi_idx]
                var aabb := mesh.get_aabb()
                var mm := MultiMesh.new()
                mm.transform_format = MultiMesh.TRANSFORM_3D
                mm.mesh = mesh
                mm.instance_count = list.size()
                for k in list.size():
                        var pt: Vector3 = list[k]
                        var target := rng.randf_range(size_min, size_max)
                        var span := aabb.size.y if fit_y else maxf(aabb.size.x, aabb.size.z)
                        var s := target / maxf(span, 0.001)
                        var basis := Basis(Vector3.UP, rng.randf() * TAU) \
                                * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06)) \
                                * Basis(Vector3.FORWARD, rng.randf_range(-0.06, 0.06))
                        basis = basis.scaled(Vector3(s, s, s))
                        var pos := Vector3(pt.x, pt.y - aabb.position.y * s - sink, pt.z)
                        mm.set_instance_transform(k, Transform3D(basis, pos))
                mm.visible_instance_count = list.size()
                var mmi := MultiMeshInstance3D.new()
                mmi.name = "PH_" + path.get_file().get_basename()
                mmi.multimesh = mm
                add_child(mmi)


func _scatter_ph_decor() -> void:
        # Живые камни (фотограмметрия) — у деревни и вдоль троп
        _ph_instances(MDL + "stone_01.glb", _decor_points(7, true), false, 1.0, 2.3, 0.22)
        _ph_instances(MDL + "moon_rock_01.glb", _decor_points(9, false), false, 0.7, 1.8, 0.12)
        # Пни
        _ph_instances(MDL + "tree_stump_01.glb", _decor_points(5, false), true, 0.6, 1.15, 0.05)
        # Сухие стволы (фотореальные): запретная зона деревни x2.6 —
        # «упавшее дерево прямо на деревне» больше не случается
        _ph_instances(MDL + "dead_tree_trunk.glb", _decor_points(4, false,
                        GameWorld.VILLAGE_RADIUS * 2.6, 8.0), true, 7.0, 12.0, 0.35)
        # Кусты у деревни и на опушках
        _ph_instances(MDL + "nettle_plant.glb", _decor_points(4, true), true, 0.55, 0.95, 0.05)
        _ph_instances(MDL + "weed_plant_02.glb", _decor_points(4, true), true, 0.5, 0.85, 0.05)
        _ph_instances(MDL + "wild_rooibos_bush.glb", _decor_points(3, true), true, 0.7, 1.1, 0.06)
        _ph_instances(MDL + "periwinkle_plant.glb", _decor_points(3, false), true, 0.45, 0.8, 0.05)
