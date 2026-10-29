extends Node3D
## v10.0 Дороги: видимая каменная кладка поверх грунтовых троп
## (западная дорога деревня→башня→Каменный Форд→замок, тропа к ритуальному
## кругу), бордюрные камни и тёплые фонари вдоль западной дороги.
## Лента следует рельефу: полигон каждые ~1.1 м, камень rocky_terrain_03.

const TEX := "res://assets/textures/"

var _road_mat: StandardMaterial3D


func _ready() -> void:
        _make_materials()
        _build_road(GameWorld.WEST_ROAD, 2.3, true)
        _build_road(GameWorld.RITUAL_TRAIL, 1.7, false)


func _make_materials() -> void:
        _road_mat = StandardMaterial3D.new()
        _road_mat.albedo_texture = load(TEX + "rocky_terrain_03/rocky_terrain_03_diff_2k.jpg")
        _road_mat.normal_enabled = true
        _road_mat.normal_texture = load(TEX + "rocky_terrain_03/rocky_terrain_03_nor_gl_2k.jpg")
        _road_mat.albedo_color = Color(0.62, 0.60, 0.66)  # приглушить под ночь
        _road_mat.roughness = 0.95
        _road_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)


func _build_road(points: Array, width: float, lanterns: bool) -> void:
        # Полилиния -> плотная последовательность точек с шагом ~1.1 м
        var dense: Array = []
        var total := 0.0
        for i in points.size() - 1:
                var a: Vector2 = points[i]
                var b: Vector2 = points[i + 1]
                var seg_len := a.distance_to(b)
                var n := maxi(2, int(ceil(seg_len / 1.1)))
                for j in n:
                        var t := float(j) / float(n)
                        dense.append(a.lerp(b, t))
        dense.append(points[points.size() - 1])

        # Лента: полоса треугольников по рельефу
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var v_dist := 0.0
        for k in dense.size():
                var p: Vector2 = dense[k]
                var fwd: Vector2 = (dense[mini(k + 1, dense.size() - 1)]
                        - dense[maxi(k - 1, 0)]).normalized()
                if fwd.length_squared() < 0.5:
                        fwd = Vector2(1, 0)
                var side := Vector2(-fwd.y, fwd.x)
                var half_w := width * 0.5
                var l3 := Vector3(p.x + side.x * half_w,
                        GameWorld.terrain_height(p.x + side.x * half_w, p.y + side.y * half_w) + 0.045,
                        p.y + side.y * half_w)
                var r3 := Vector3(p.x - side.x * half_w,
                        GameWorld.terrain_height(p.x - side.x * half_w, p.y - side.y * half_w) + 0.045,
                        p.y - side.y * half_w)
                if k > 0:
                        v_dist += p.distance_to(dense[k - 1])
                var u0 := 0.0
                var u1 := 1.0
                var v := v_dist / 2.2
                st.set_uv(Vector2(u0, v))
                st.set_normal(Vector3.UP)
                st.add_vertex(l3)
                st.set_uv(Vector2(u1, v))
                st.set_normal(Vector3.UP)
                st.add_vertex(r3)
                if k > 0:
                        # два треугольника между k-1 и k
                        var i0 := k * 2 - 2
                        st.set_uv(Vector2(u0, v - 0.01))
                        st.set_normal(Vector3.UP)
                        st.add_vertex(r3)
                        st.add_index(i0)
                        st.add_index(i0 + 1)
                        st.add_index(k * 2 + 1)
                        st.add_index(i0)
                        st.add_index(k * 2 + 1)
                        st.add_index(k * 2)
        st.generate_normals()
        var mesh := st.commit()
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        mi.material_override = _road_mat
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mi)

        # Бордюрные камни по краям каждые ~2.6 м
        var stone_mat := StandardMaterial3D.new()
        stone_mat.albedo_texture = load(TEX + "stone_wall/stone_wall_diff_2k.jpg")
        stone_mat.normal_enabled = true
        stone_mat.normal_texture = load(TEX + "stone_wall/stone_wall_nor_2k.jpg")
        stone_mat.albedo_color = Color(0.55, 0.53, 0.58)
        stone_mat.roughness = 0.95
        var acc := 0.0
        for k in dense.size():
                var p: Vector2 = dense[k]
                acc += 1.1
                if acc < 2.6:
                        continue
                acc = 0.0
                var fwd: Vector2 = (dense[mini(k + 1, dense.size() - 1)]
                        - dense[maxi(k - 1, 0)]).normalized()
                var side := Vector2(-fwd.y, fwd.x)
                var half_w := width * 0.5 + 0.18
                for sgn in [1.0, -1.0]:
                        var sgn_f: float = sgn
                        var sp: Vector2 = p + side * (half_w * sgn_f)
                        var b := BoxMesh.new()
                        b.size = Vector3(0.42, 0.22, 0.30)
                        var smi := MeshInstance3D.new()
                        smi.mesh = b
                        smi.material_override = stone_mat
                        smi.position = Vector3(sp.x,
                                GameWorld.terrain_height(sp.x, sp.y) + 0.07, sp.y)
                        smi.rotation.y = atan2(fwd.x, fwd.y) + (PI / 2.0 if sgn > 0 else -PI / 2.0)
                        add_child(smi)

        # Фонари каждые ~11 м вдоль западной дороги
        if lanterns:
                var lacc := 0.0
                for k in dense.size():
                        var p: Vector2 = dense[k]
                        lacc += 1.1
                        if lacc < 11.0:
                                continue
                        lacc = 0.0
                        var fwd: Vector2 = (dense[mini(k + 1, dense.size() - 1)]
                                - dense[maxi(k - 1, 0)]).normalized()
                        var side := Vector2(-fwd.y, fwd.x)
                        var lp := p + side * (width * 0.5 + 0.75)
                        _road_lantern(lp)

        # Указательный камень в начале тропы культистов
        if not lanterns:
                _trail_marker(dense[0])


func _road_lantern(p: Vector2) -> void:
        var b := Node3D.new()
        var gy := GameWorld.terrain_height(p.x, p.y)
        b.position = Vector3(p.x, gy, p.y)
        add_child(b)
        var wood := StandardMaterial3D.new()
        wood.albedo_color = Color(0.16, 0.12, 0.09)
        wood.roughness = 0.95
        var beam := MeshInstance3D.new()
        var pm := CylinderMesh.new()
        pm.top_radius = 0.07
        pm.bottom_radius = 0.09
        pm.height = 3.0
        pm.radial_segments = 7
        beam.mesh = pm
        beam.material_override = wood
        beam.position.y = 1.5
        b.add_child(beam)
        var arm := MeshInstance3D.new()
        var ab := BoxMesh.new()
        ab.size = Vector3(0.44, 0.07, 0.07)
        arm.mesh = ab
        arm.material_override = wood
        arm.position = Vector3(0.18, 2.9, 0)
        b.add_child(arm)
        var glass := StandardMaterial3D.new()
        glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        glass.albedo_color = Color(1.0, 0.75, 0.42, 0.55)
        glass.emission_enabled = true
        glass.emission = Color(1.0, 0.62, 0.28)
        glass.emission_energy_multiplier = 1.35
        var box := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.30, 0.38, 0.30)
        box.mesh = bm
        box.material_override = glass
        box.position = Vector3(0.34, 2.62, 0)
        b.add_child(box)
        var light := OmniLight3D.new()
        light.light_color = Color(1.0, 0.62, 0.30)
        light.light_energy = 1.35
        light.omni_range = 9.0
        light.position = Vector3(0.34, 2.62, 0)
        b.add_child(light)


func _trail_marker(p: Vector2) -> void:
        var gy := GameWorld.terrain_height(p.x, p.y)
        var st := MeshInstance3D.new()
        var pm := BoxMesh.new()
        pm.size = Vector3(0.16, 1.1, 0.1)
        st.mesh = pm
        st.position = Vector3(p.x, gy + 0.55, p.y)
        st.rotation.z = 0.1
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(0.25, 0.22, 0.2)
        m.roughness = 0.95
        st.material_override = m
        add_child(st)
        # тусклый багровый огонёк-указатель
        var light := OmniLight3D.new()
        light.light_color = Color(0.7, 0.2, 0.3)
        light.light_energy = 0.5
        light.omni_range = 4.0
        light.position = Vector3(p.x, gy + 1.15, p.y)
        add_child(light)
