extends Node3D
## v10.0 Ритуальный круг культистов в лесной прогалине (референс — фото
## пользователя: фигуры в капюшонах вокруг круга, огненные чаши, пурпур).
## Шесть монахов вокруг пульсирующего рунного круга, жаровни с пламенем,
## каменный алтарь с черепом и свечами, багровый свет, искры.
## Точка интереса на восточной тропе — сюда ведёт тропа от деревни.

const MONK := preload("res://assets/models/chars/monk_player.glb")
const SKULL := preload("res://assets/models/horror/ps1_skull.fbx")
const RUNE_TEX := preload("res://assets/textures/magic/rune_circle.png")
const SOFT_DOT := preload("res://assets/textures/soft_dot.png")

const RC := Vector2(72.0, 62.0)
const GY_LAT := 0.0  # высоту берём из terrain_height

var _rune_mat: StandardMaterial3D
var _t := 0.0
var _altar_light: OmniLight3D


func _ready() -> void:
        var gy := GameWorld.terrain_height(RC.x, RC.y)
        position = Vector3(RC.x, gy, RC.y)
        _build_ground()
        _build_rune_circle()
        _build_cultists()
        _build_braziers()
        _build_altar()
        _build_embers()


func _process(dt: float) -> void:
        _t += dt
        # Пульс рун и алтарного света (ритм «сердцебиения» культа)
        var pulse := 0.5 + 0.5 * sin(_t * 1.1)
        if _rune_mat != null:
                _rune_mat.emission_energy_multiplier = 1.1 + 0.7 * pulse
        if _altar_light != null:
                _altar_light.light_energy = 1.6 + 0.6 * sin(_t * 1.1 + 0.8)


func _build_ground() -> void:
        # Утрамбованная земля прогалины
        var disc := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 8.2
        cm.bottom_radius = 8.6
        cm.height = 0.14
        cm.radial_segments = 36
        disc.mesh = cm
        var m := StandardMaterial3D.new()
        m.albedo_texture = load("res://assets/textures/brown_mud_02/brown_mud_02_diff_2k.jpg")
        m.normal_enabled = true
        m.normal_texture = load("res://assets/textures/brown_mud_02/brown_mud_02_nor_gl_2k.jpg")
        m.albedo_color = Color(0.38, 0.34, 0.33)
        m.roughness = 1.0
        m.uv1_scale = Vector3(0.14, 0.14, 0.14)
        disc.material_override = m
        disc.position.y = 0.05
        disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(disc)
        # Кольцо мелких камней по краю прогалины
        var stone_m := StandardMaterial3D.new()
        stone_m.albedo_color = Color(0.22, 0.20, 0.21)
        stone_m.roughness = 0.95
        for i in 24:
                var ang := TAU * i / 24.0
                var r := 8.0 + randf_range(-0.4, 0.5)
                var s := MeshInstance3D.new()
                var sm := SphereMesh.new()
                sm.radius = randf_range(0.16, 0.3)
                sm.height = sm.radius * 1.6
                sm.radial_segments = 6
                sm.rings = 4
                s.mesh = sm
                s.material_override = stone_m
                s.position = Vector3(cos(ang) * r, 0.1, sin(ang) * r)
                s.rotation = Vector3(randf() * 0.6, randf() * TAU, randf() * 0.6)
                add_child(s)


func _build_rune_circle() -> void:
        # Плоский квад с полной UV-развёрткой текстуры рун (купол-цилиндр
        # мапил текстуру криво — «синяя лужа»)
        var disc := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(9.6, 9.6)
        pm.subdivide_width = 2
        pm.subdivide_depth = 2
        disc.mesh = pm
        _rune_mat = StandardMaterial3D.new()
        _rune_mat.albedo_texture = RUNE_TEX
        _rune_mat.albedo_color = Color(0.85, 0.8, 0.95)
        _rune_mat.emission_enabled = true
        _rune_mat.emission_texture = RUNE_TEX
        _rune_mat.emission = Color(0.85, 0.45, 1.0)
        _rune_mat.emission_energy_multiplier = 1.6
        _rune_mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
        _rune_mat.roughness = 0.9
        disc.material_override = _rune_mat
        disc.position.y = 0.16
        disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(disc)
        # Пурпурный свет над кругом
        var light := OmniLight3D.new()
        light.light_color = Color(0.62, 0.30, 0.95)
        light.light_energy = 1.8
        light.omni_range = 14.0
        light.position = Vector3(0, 2.2, 0)
        add_child(light)


func _build_cultists() -> void:
        # Восемь монахов-культистов вокруг круга, лицом к центру
        for i in 8:
                var ang := TAU * i / 8.0 + 0.25
                var r := 5.6
                var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
                var inst := MONK.instantiate()
                # лёгкий разброс масштаба/поворота — толпа живых людей
                inst.scale = Vector3.ONE * randf_range(0.94, 1.04)
                inst.position = pos
                # лицом к центру (модель смотрит в +Z после FACING_FIX-подобного
                # поворота внутри игрока; тут просто повернуть на центр)
                inst.rotation.y = -ang + PI / 2.0
                # затемняющий фиолетовый отлив — ряса культиста слегка
                # светится в темноте (иначе фигуры не читались вообще)
                for mi in inst.find_children("*", "MeshInstance3D", true, false):
                        var mesh: Mesh = (mi as MeshInstance3D).mesh
                        if mesh is ArrayMesh:
                                for s in mesh.get_surface_count():
                                        var m := mesh.surface_get_material(s)
                                        if m is StandardMaterial3D:
                                                var dup := m.duplicate() as StandardMaterial3D
                                                dup.albedo_color = Color(0.80, 0.74, 0.92)
                                                dup.emission_enabled = true
                                                dup.emission = Color(0.45, 0.20, 0.65)
                                                dup.emission_energy_multiplier = 0.55
                                                mesh.surface_set_material(s, dup)
                add_child(inst)


func _build_braziers() -> void:
        # Четыре жаровни между культистами: тренога, чаша, угли, пламя, свет
        var metal := StandardMaterial3D.new()
        metal.albedo_color = Color(0.13, 0.11, 0.10)
        metal.roughness = 0.6
        metal.metallic = 0.7
        for i in 4:
                var ang := TAU * i / 4.0 + 0.55
                var r := 4.9
                var b := Node3D.new()
                b.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
                add_child(b)
                # тренога
                for leg in 3:
                        var la := TAU * leg / 3.0
                        var rod := MeshInstance3D.new()
                        var rm := CylinderMesh.new()
                        rm.top_radius = 0.045
                        rm.bottom_radius = 0.055
                        rm.height = 1.15
                        rm.radial_segments = 6
                        rod.mesh = rm
                        rod.material_override = metal
                        rod.position = Vector3(cos(la) * 0.28, 0.55, sin(la) * 0.28)
                        rod.rotation = Vector3(cos(la) * 0.32, 0, -sin(la) * 0.32)
                        b.add_child(rod)
                # чаша
                var bowl := MeshInstance3D.new()
                var bm := CylinderMesh.new()
                bm.top_radius = 0.42
                bm.bottom_radius = 0.24
                bm.height = 0.34
                bm.radial_segments = 12
                bowl.mesh = bm
                bowl.material_override = metal
                bowl.position.y = 1.18
                b.add_child(bowl)
                # угли (излучающие)
                var ember := MeshInstance3D.new()
                var em := CylinderMesh.new()
                em.top_radius = 0.34
                em.bottom_radius = 0.30
                em.height = 0.10
                em.radial_segments = 10
                ember.mesh = em
                var ember_m := StandardMaterial3D.new()
                ember_m.albedo_color = Color(0.25, 0.05, 0.02)
                ember_m.emission_enabled = true
                ember_m.emission = Color(1.0, 0.35, 0.08)
                ember_m.emission_energy_multiplier = 1.6
                ember.material_override = ember_m
                ember.position.y = 1.36
                b.add_child(ember)
                # пламя
                for j in 2:
                        var flame := MeshInstance3D.new()
                        var cm := CylinderMesh.new()
                        cm.top_radius = 0.0
                        cm.bottom_radius = 0.24 - j * 0.07
                        cm.height = 0.62 - j * 0.18
                        cm.radial_segments = 8
                        flame.mesh = cm
                        var fm := StandardMaterial3D.new()
                        fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                        fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                        fm.albedo_color = Color(1.0, 0.5 - j * 0.1, 0.12, 0.85)
                        fm.emission_enabled = true
                        fm.emission = Color(1.0, 0.38, 0.08)
                        fm.emission_energy_multiplier = 2.0
                        flame.material_override = fm
                        flame.position.y = 1.44 + j * 0.24
                        flame.add_to_group("campfire_flame")
                        b.add_child(flame)
                var light := OmniLight3D.new()
                light.light_color = Color(1.0, 0.5, 0.18)
                light.light_energy = 2.6
                light.omni_range = 12.0
                light.position = Vector3(0, 1.7, 0)
                light.add_to_group("campfire_light")
                b.add_child(light)


func _build_altar() -> void:
        var a := Node3D.new()
        a.position = Vector3(0, 0.0, 0)
        add_child(a)
        # Постамент из тёмного камня
        var stone := StandardMaterial3D.new()
        stone.albedo_texture = load("res://assets/textures/dark_rock/dark_rock_diff_2k.jpg")
        stone.normal_enabled = true
        stone.normal_texture = load("res://assets/textures/dark_rock/dark_rock_nor_gl_2k.jpg")
        stone.albedo_color = Color(0.5, 0.48, 0.52)
        stone.roughness = 0.92
        var base := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(1.15, 0.75, 0.85)
        base.mesh = bm
        base.material_override = stone
        base.position.y = 0.42
        a.add_child(base)
        var slab := MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(1.35, 0.14, 1.05)
        slab.mesh = sm
        slab.material_override = stone
        slab.position.y = 0.85
        a.add_child(slab)
        # Череп на алтаре: ВНИМАНИЕ — внутри FBX запечён scale 49.5,
        # поэтому корневой масштаб — доли единицы (итог ~0.45 м)
        var skull := SKULL.instantiate()
        skull.scale = Vector3.ONE * 0.55
        skull.position.y = 0.92
        skull.rotation.y = 0.6
        # материал: кость + лёгкое свечение глазниц
        for mi in skull.find_children("*", "MeshInstance3D", true, false):
                var mesh: Mesh = (mi as MeshInstance3D).mesh
                if mesh is ArrayMesh:
                        for s in mesh.get_surface_count():
                                var m := mesh.surface_get_material(s)
                                var dup := StandardMaterial3D.new()
                                dup.albedo_texture = load("res://assets/models/horror/ps1_skull_256x256.png")
                                dup.albedo_color = Color(0.75, 0.72, 0.68)
                                dup.roughness = 0.85
                                dup.emission_enabled = true
                                dup.emission = Color(0.55, 0.2, 0.7)
                                dup.emission_energy_multiplier = 0.10
                                mesh.surface_set_material(s, dup)
        a.add_child(skull)
        # Свечи по углам алтаря (PSX-свечи из данжен-кита)
        for corner in [Vector3(0.52, 0.92, 0.36), Vector3(-0.52, 0.92, 0.36),
                        Vector3(0.52, 0.92, -0.36), Vector3(-0.52, 0.92, -0.36)]:
                var c := MeshInstance3D.new()
                var cm := CylinderMesh.new()
                cm.top_radius = 0.035
                cm.bottom_radius = 0.04
                cm.height = 0.22
                cm.radial_segments = 6
                c.mesh = cm
                var wax := StandardMaterial3D.new()
                wax.albedo_color = Color(0.82, 0.78, 0.68)
                wax.roughness = 0.7
                c.material_override = wax
                c.position = corner
                a.add_child(c)
                var fl := MeshInstance3D.new()
                var fcm := CylinderMesh.new()
                fcm.top_radius = 0.0
                fcm.bottom_radius = 0.022
                fcm.height = 0.07
                fcm.radial_segments = 6
                fl.mesh = fcm
                var flm := StandardMaterial3D.new()
                flm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                flm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                flm.albedo_color = Color(1.0, 0.8, 0.4, 0.9)
                flm.emission_enabled = true
                flm.emission = Color(1.0, 0.65, 0.25)
                flm.emission_energy_multiplier = 2.4
                fl.material_override = flm
                fl.position = corner + Vector3(0, 0.14, 0)
                fl.add_to_group("campfire_flame")
                a.add_child(fl)
        # Багровый свет алтаря
        _altar_light = OmniLight3D.new()
        _altar_light.light_color = Color(0.85, 0.25, 0.35)
        _altar_light.light_energy = 1.6
        _altar_light.omni_range = 8.0
        _altar_light.position = Vector3(0, 1.5, 0)
        a.add_child(_altar_light)


func _build_embers() -> void:
        # Багровые искры, поднимающиеся над кругом
        var p := GPUParticles3D.new()
        p.amount = 26
        p.lifetime = 4.2
        p.preprocess = 4.0
        p.position = Vector3(0, 0.4, 0)
        var pm := ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
        pm.emission_ring_axis = Vector3(0, 1, 0)
        pm.emission_ring_height = 0.4
        pm.emission_ring_radius = 4.2
        pm.emission_ring_inner_radius = 1.5
        pm.direction = Vector3(0, 1, 0)
        pm.spread = 12.0
        pm.initial_velocity_min = 0.35
        pm.initial_velocity_max = 0.9
        pm.gravity = Vector3(0, 0.25, 0)
        pm.damping_min = 0.02
        pm.damping_max = 0.08
        pm.scale_min = 0.3
        pm.scale_max = 0.75
        var g := Gradient.new()
        g.set_color(0, Color(0.8, 0.2, 0.6, 0.0))
        g.set_color(1, Color(0.8, 0.2, 0.6, 0.0))
        g.add_point(0.25, Color(0.9, 0.3, 0.7, 0.9))
        g.add_point(0.7, Color(0.6, 0.25, 0.85, 0.6))
        var gt := GradientTexture1D.new()
        gt.gradient = g
        pm.color_ramp = gt
        p.process_material = pm
        var q := QuadMesh.new()
        q.size = Vector2(0.09, 0.09)
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.vertex_color_use_as_albedo = true
        m.albedo_color = Color(0.9, 0.3, 0.7, 0.9)
        m.albedo_texture = SOFT_DOT
        q.material = m
        p.draw_pass_1 = q
        add_child(p)
