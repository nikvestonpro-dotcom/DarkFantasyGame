extends Node3D
## Рельеф: меш с масками покрытий в вершинных цветах, PBR-шейдер
## с трипланаром (трава/лес/песок Poly Haven + скалы на склонах),
## коллизия, вода озера, густая трава с ветром, стены по краю мира.

const TerrainShader := preload("res://shaders/terrain.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")
const GrassShader := preload("res://shaders/grass.gdshader")

const TEX := "res://assets/textures/"

var rng := RandomNumberGenerator.new()


func _ready() -> void:
        rng.seed = 555
        _build_world_floor()
        _build_terrain()
        _build_water()
        _build_grass()


## Страховка №1 от «прозрачной земли»: гигантское НЕПРОЗРАЧНОЕ дно под
## всей картой (в 6 раз шире мира, на 120 м ниже долины). Даже если
## камера найдёт щель между рельефом, горным кольцом и юбкой — за ней
## будет тёмная порода, а не небо. Физики не создаёт (только визуал).
func _build_world_floor() -> void:
        var plane := PlaneMesh.new()
        plane.size = Vector2(3200, 3200)
        var mi := MeshInstance3D.new()
        mi.name = "WorldFloor"
        mi.mesh = plane
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(0.055, 0.065, 0.09)
        m.roughness = 1.0
        mi.material_override = m
        mi.position = Vector3(0, -120, 0)
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mi)


static func _tex(path: String) -> Texture2D:
        var t := load(path)
        return t


func _build_terrain() -> void:
        var size := GameWorld.TERRAIN_SIZE
        var seg := GameWorld.TERRAIN_SEGMENTS
        var step := size / float(seg)
        var half := size * 0.5
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)

        for iz in seg + 1:
                for ix in seg + 1:
                        var x := -half + ix * step
                        var z := -half + iz * step
                        var y := GameWorld.terrain_height(x, z)
                        st.set_color(_ground_mask(x, z, y))
                        st.add_vertex(Vector3(x, y, z))

        for iz in seg:
                for ix in seg:
                        var v00 := iz * (seg + 1) + ix
                        var v10 := iz * (seg + 1) + ix + 1
                        var v01 := (iz + 1) * (seg + 1) + ix
                        var v11 := (iz + 1) * (seg + 1) + ix + 1
                        # ВАЖНО (фикс «прозрачной земли»): у Godot лицевая сторона —
                        # обход ПО ЧАСОВОЙ. Прежний порядок (v00,v01,v11) давал
                        # обратную сторону вверх, и cull_back отбрасывал все
                        # плоские участки: земля «просматривалась» насквозь,
                        # оставались видны только склоны. Разворачиваем обход:
                        st.add_index(v00)
                        st.add_index(v11)
                        st.add_index(v01)
                        st.add_index(v00)
                        st.add_index(v10)
                        st.add_index(v11)

        st.index()
        st.generate_normals()
        var mesh := st.commit()

        var mi := MeshInstance3D.new()
        mi.name = "Terrain"
        mi.mesh = mesh
        var mat := ShaderMaterial.new()
        mat.shader = TerrainShader
        # v7.0: болотистая гниль — лесная земля, палая листва, грязь, тёмный камень
        mat.set_shader_parameter("floor_diff", _tex(TEX + "forrest_ground_01/forrest_ground_01_diff_2k.jpg"))
        mat.set_shader_parameter("floor_nor", _tex(TEX + "forrest_ground_01/forrest_ground_01_nor_gl_2k.jpg"))
        mat.set_shader_parameter("leaves_diff", _tex(TEX + "forest_leaves_03/forest_leaves_03_diff_2k.jpg"))
        mat.set_shader_parameter("leaves_nor", _tex(TEX + "forest_leaves_03/forest_leaves_03_nor_gl_2k.jpg"))
        mat.set_shader_parameter("mud_diff", _tex(TEX + "brown_mud_02/brown_mud_02_diff_2k.jpg"))
        mat.set_shader_parameter("mud_nor", _tex(TEX + "brown_mud_02/brown_mud_02_nor_gl_2k.jpg"))
        mat.set_shader_parameter("mud_rough", _tex(TEX + "brown_mud_02/brown_mud_02_rough_2k.jpg"))
        mat.set_shader_parameter("rock_diff", _tex(TEX + "dark_rock/dark_rock_diff_2k.jpg"))
        mat.set_shader_parameter("rock_nor", _tex(TEX + "dark_rock/dark_rock_nor_gl_2k.jpg"))
        # Тонировка под дарк-фэнтези: серо-зелёная гниль, холодная грязь, мокрый камень
        mat.set_shader_parameter("floor_tint", Vector3(0.72, 0.78, 0.68))
        mat.set_shader_parameter("leaves_tint", Vector3(0.82, 0.76, 0.70))
        mat.set_shader_parameter("mud_tint", Vector3(0.72, 0.70, 0.74))
        mat.set_shader_parameter("rock_tint", Vector3(0.78, 0.82, 0.94))
        mat.set_shader_parameter("normal_strength", 0.85)
        mi.material_override = mat
        add_child(mi)
        _build_heightmap_collision()
        _build_edge_skirt(mat)

        # Невидимые стены по краю карты: высоты 0..130, выше гребней (~95 м)
        var wall_defs := [
                [Vector3(0, 65, -half), Vector3(size + 4.0, 130, 2)],
                [Vector3(0, 65, half), Vector3(size + 4.0, 130, 2)],
                [Vector3(-half, 65, 0), Vector3(2, 130, size + 4.0)],
                [Vector3(half, 65, 0), Vector3(2, 130, size + 4.0)],
        ]
        for wd in wall_defs:
                var body := StaticBody3D.new()
                var col := CollisionShape3D.new()
                var shape := BoxShape3D.new()
                shape.size = wd[1]
                col.shape = shape
                body.add_child(col)
                body.position = wd[0]
                add_child(body)


## Юбка-обрыв за краем карты: с гребня горы, если игрок всё-таки
## заберётся на самый край, видно не пустоту, а крутой обрыв вниз.
func _build_edge_skirt(mat: ShaderMaterial) -> void:
        var half := GameWorld.TERRAIN_SIZE * 0.5
        var outer := 62.0
        var cols := 96
        var rows := 5
        var offs := [0.0, 6.0, 16.0, 34.0, outer]
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        # 4 стороны: [наружная ось, фикс координата, направление наружу]
        var sides := [
                [Vector3.AXIS_Z, -half, -1.0],
                [Vector3.AXIS_Z, half, 1.0],
                [Vector3.AXIS_X, -half, -1.0],
                [Vector3.AXIS_X, half, 1.0],
        ]
        for side in sides:
                var axis: int = side[0]
                var fix: float = side[1]
                var out_sign: float = side[2]
                for row in rows:
                        var off: float = offs[row] * out_sign
                        var drop := pow(offs[row] / outer, 1.3) * 190.0
                        for c in cols + 1:
                                var along := -half + float(c) / float(cols) * GameWorld.TERRAIN_SIZE
                                var x := along
                                var z := fix + off
                                if axis == Vector3.AXIS_X:
                                        x = fix + off
                                        z = along
                                var y := GameWorld.terrain_height(
                                                clampf(x, -half, half),
                                                clampf(z, -half, half)) - drop
                                st.set_color(Color(0.35, 0.4, 0.2))
                                st.add_vertex(Vector3(x, y, z))
        var per_side := (cols + 1) * rows
        for si in 4:
                var base_i := si * per_side
                for r in rows - 1:
                        for c in cols:
                                var i00 := base_i + r * (cols + 1) + c
                                var i10 := i00 + 1
                                var i01 := base_i + (r + 1) * (cols + 1) + c
                                var i11 := i01 + 1
                                # Тот же фикс обхода, что и у основного террейна
                                st.add_index(i00)
                                st.add_index(i11)
                                st.add_index(i01)
                                st.add_index(i00)
                                st.add_index(i10)
                                st.add_index(i11)
        st.index()
        st.generate_normals()
        var mi := MeshInstance3D.new()
        mi.name = "EdgeSkirt"
        mi.mesh = st.commit()
        mi.material_override = mat
        add_child(mi)


func _build_heightmap_collision() -> void:
        var seg := GameWorld.TERRAIN_SEGMENTS
        var step := GameWorld.TERRAIN_SIZE / float(seg)
        var half := GameWorld.TERRAIN_SIZE * 0.5
        var w := seg + 1
        var data := PackedFloat32Array()
        data.resize(w * w)
        for iz in w:
                for ix in w:
                        var x := -half + ix * step
                        var z := -half + iz * step
                        data[iz * w + ix] = GameWorld.terrain_height(x, z)
        var shape := HeightMapShape3D.new()
        shape.map_width = w
        shape.map_depth = w
        shape.map_data = data
        var body := StaticBody3D.new()
        body.name = "TerrainCollision"
        var col := CollisionShape3D.new()
        col.shape = shape
        # Шейп покрывает (w-1)x(w-1) "клеток" по 1 единице — масштабируем до мира
        col.scale = Vector3(step, 1.0, step)
        body.add_child(col)
        add_child(body)


## Маски покрытий в вершинный цвет: R = лесная земля (основа),
## G = палая листва (густой лес), B = грязь (деревня, тропы, берег).
func _ground_mask(x: float, z: float, y: float) -> Color:
        var leaves_k := pow(GameWorld.forest_density(x, z), 1.25) * 0.95
        var dv := Vector2(x, z).distance_to(GameWorld.VILLAGE_CENTER)
        var village_k := 1.0 - smoothstep(GameWorld.VILLAGE_RADIUS * 0.72, GameWorld.VILLAGE_RADIUS * 1.05, dv)
        var pd := GameWorld.path_distance(Vector2(x, z))
        var path_k := 1.0 - smoothstep(2.1, 4.2, pd)
        # Болото у воды (шире, чем прежний «песок» — берег квашится)
        var mud_shore := 1.0 - smoothstep(GameWorld.WATER_LEVEL - 0.3, GameWorld.WATER_LEVEL + 1.6, y)
        var mud_k := clampf(maxf(village_k, path_k) + mud_shore * 0.85, 0.0, 1.0)
        # В городе и на тропах листва не скапливается
        leaves_k *= 1.0 - clampf(maxf(village_k, path_k) * 0.85, 0.0, 1.0)
        var floor_k := 1.0 - clampf(leaves_k + mud_k, 0.0, 1.0)
        var total := floor_k + leaves_k + mud_k
        if total < 0.001:
                return Color(1, 0, 0)
        return Color(floor_k / total, leaves_k / total, mud_k / total)


func _build_water() -> void:
        var plane := PlaneMesh.new()
        plane.size = Vector2(GameWorld.LAKE_RADIUS * 2.7, GameWorld.LAKE_RADIUS * 2.7)
        plane.subdivide_width = 72
        plane.subdivide_depth = 72
        var mi := MeshInstance3D.new()
        mi.mesh = plane
        var mat := ShaderMaterial.new()
        mat.shader = WaterShader
        var n := FastNoiseLite.new()
        n.seed = 77
        n.frequency = 0.05
        var tex := NoiseTexture2D.new()
        tex.noise = n
        tex.width = 256
        tex.height = 256
        tex.seamless = true
        tex.as_normal_map = true
        mat.set_shader_parameter("ripple_nor", tex)
        mat.set_shader_parameter("moon_dir", GameWorld.MOON_DIR)
        mat.set_shader_parameter("glow_dir", GameWorld.GLOW_DIR)
        mi.material_override = mat
        mi.position = Vector3(GameWorld.LAKE_CENTER.x, GameWorld.WATER_LEVEL, GameWorld.LAKE_CENTER.y)
        add_child(mi)


## Кластер травяных лезвий: 3 треугольных лезвия с сужением и изгибом.
func _blade_cluster_mesh() -> ArrayMesh:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var heights := [0.42, 0.55, 0.48]
        var rotations := [0.0, 2.09, 4.19]
        for bi in 3:
                var rot: float = rotations[bi]
                var dir := Vector3(cos(rot), 0.0, sin(rot))
                var side := Vector3(-dir.z, 0.0, dir.x)
                var h: float = heights[bi]
                var bend := 0.10
                # вершины лезвия: основание (2) -> середина (2) -> кончик (1)
                var base_l := side * 0.05
                var base_r := side * -0.05
                var mid_l := side * 0.024 + dir * bend * 0.3 + Vector3(0, h * 0.55, 0)
                var mid_r := side * -0.024 + dir * bend * 0.3 + Vector3(0, h * 0.55, 0)
                var tip := dir * bend + Vector3(0, h, 0)
                var up := Vector3(0, 1, 0)
                var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1)]
                var verts := [base_l, base_r, mid_l, mid_r, tip]
                for v in verts.size():
                        st.set_normal(up)
                        st.set_uv(uvs[v])
                        st.add_vertex(verts[v])
                st.add_index(bi * 5 + 0)
                st.add_index(bi * 5 + 2)
                st.add_index(bi * 5 + 1)
                st.add_index(bi * 5 + 1)
                st.add_index(bi * 5 + 2)
                st.add_index(bi * 5 + 3)
                st.add_index(bi * 5 + 2)
                st.add_index(bi * 5 + 4)
                st.add_index(bi * 5 + 3)
        st.index()
        return st.commit()


func _build_grass() -> void:
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = _blade_cluster_mesh()
        mm.instance_count = 32000
        var mat := ShaderMaterial.new()
        mat.shader = GrassShader
        # v7.0: глухая болотная трава — тёмная, мерзлая, местами седая
        mat.set_shader_parameter("base_color", Vector3(0.022, 0.050, 0.030))
        mat.set_shader_parameter("tip_color", Vector3(0.065, 0.145, 0.075))
        mat.set_shader_parameter("dry_color", Vector3(0.20, 0.175, 0.10))
        mat.set_shader_parameter("dryness", 0.46)
        var placed := 0
        var guard := 0
        while placed < 32000 and guard < 170000:
                guard += 1
                var p := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * GameWorld.TERRAIN_SIZE * 0.46
                var y := GameWorld.terrain_height(p.x, p.y)
                if y < GameWorld.WATER_LEVEL + 0.35 or y > GameWorld.WATER_LEVEL + 16.0:
                        continue
                if GameWorld.path_distance(p) < 2.4:
                        continue
                if p.distance_to(GameWorld.VILLAGE_CENTER) < 3.0:
                        continue
                # v5.0: пещера и двор замка — без травы
                if p.distance_to(GameWorld.CAVE_CENTER) < 27.0:
                        continue
                if p.distance_to(GameWorld.CASTLE_CENTER) < 23.0:
                        continue
                # Гуще на лугах, реже в глухом лесу
                var dens := 1.0 - GameWorld.forest_density(p.x, p.y) * 0.6
                if rng.randf() > dens:
                        continue
                var basis := Basis(Vector3.UP, rng.randf() * TAU)
                var s := rng.randf_range(0.75, 1.8)
                basis = basis.scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
                mm.set_instance_transform(placed, Transform3D(basis, Vector3(p.x, y - 0.03, p.y)))
                placed += 1
        mm.visible_instance_count = placed

        var mmi := MultiMeshInstance3D.new()
        mmi.name = "GrassField"
        mmi.multimesh = mm
        mmi.material_override = mat
        mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mmi)
