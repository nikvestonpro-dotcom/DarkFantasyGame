extends Node3D
## Старый погост v11 — «интересный контент» по просьбе игрока.
## Курган на восточном краю деревни: покосившиеся надгробия из тёмного
## камня, саркофаг, кованая ограда с калиткой, сухое дерево, мёртвые
## свечи (холодный огонь), приземистый туман. По погосту бродит Белая
## Дама (спавнится в main.gd). Референс — «ведьмин» погост из Готики.

const ROCK_DIFF := preload("res://assets/textures/dark_rock/dark_rock_diff_2k.jpg")
const ROCK_NOR := preload("res://assets/textures/dark_rock/dark_rock_nor_gl_2k.jpg")
const DEAD_TREE := preload("res://assets/models/dead_tree_trunk.glb")
const SKULL := preload("res://assets/models/packs/PS1 Dark Fantasy Horror Game Assets (by Stark Crafts)/PS1 Dark Fantasy Horror Game Assets (by Stark Crafts)/PS1_Skull/PS1_Skull.fbx")

const CENTER := Vector2(28.0, 26.0)
const RADIUS := 9.5

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
        _rng.seed = 20461
        _build_ground()
        _build_graves()
        _build_sarcophagus()
        _build_fence()
        _build_dead_tree()
        _build_candles()
        _build_fog()


func _ground_y(x: float, z: float) -> float:
        return GameWorld.terrain_height(x, z)


## «Поляна» погоста: тёмная земляная крошка + утоптанная тропа не нужна —
## кладбище видно с главной улицы сквозь ограду.
func _build_ground() -> void:
        var mi := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = RADIUS + 1.5
        cm.bottom_radius = RADIUS + 1.5
        cm.height = 0.06
        cm.radial_segments = 26
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.10, 0.09, 0.075)
        mat.roughness = 1.0
        mi.mesh = cm
        mi.material_override = mat
        add_child(mi)
        var y := _ground_y(CENTER.x, CENTER.y) - 0.05
        mi.position = Vector3(CENTER.x, y, CENTER.y)


## Надгробия: плиты и кресты, каждый со своим наклоном и выцветанием.
func _build_graves() -> void:
        var stone := StandardMaterial3D.new()
        stone.albedo_texture = ROCK_DIFF
        stone.texture_normal = ROCK_NOR
        stone.albedo_color = Color(0.8, 0.8, 0.83)
        stone.roughness = 0.95
        stone.uv1_scale = Vector3(0.6, 0.9, 0.6)

        var spots := [
                Vector2(-4.0, -3.5), Vector2(-2.2, -4.2), Vector2(-0.4, -3.8),
                Vector2(1.6, -4.4), Vector2(3.6, -3.6), Vector2(-4.4, -0.8),
                Vector2(-2.6, -0.4), Vector2(-0.6, -0.2), Vector2(1.4, 0.2),
                Vector2(3.4, -0.6), Vector2(4.6, 1.6), Vector2(2.4, 2.4),
                Vector2(0.4, 2.0), Vector2(-1.8, 2.6), Vector2(-3.8, 2.2),
                Vector2(-5.2, 0.8),
        ]
        for i in spots.size():
                var cross := _rng.randf() < 0.4
                var w: float = _rng.randf_range(0.55, 0.75)
                var h: float = _rng.randf_range(1.1, 1.5)
                var grp := Node3D.new()
                add_child(grp)
                var p: Vector2 = spots[i]
                grp.position = Vector3(CENTER.x + p.x, _ground_y(CENTER.x + p.x, CENTER.y + p.y), CENTER.y + p.y)
                grp.rotation.y = _rng.randf_range(-0.5, 0.5) + PI
                # покосившиеся: земля «поплыла»
                grp.rotation.z = _rng.randf_range(-0.16, 0.16)
                grp.rotation.x = _rng.randf_range(-0.1, 0.1)

                var slab := MeshInstance3D.new()
                var bm := BoxMesh.new()
                if cross:
                        bm.size = Vector3(0.14, h, 0.1)
                else:
                        bm.size = Vector3(w, h * 0.72, 0.14)
                slab.mesh = bm
                var m := stone.duplicate() as StandardMaterial3D
                # выцветание/мох у каждого камня свой
                var f := _rng.randf_range(0.75, 1.1)
                m.albedo_color = Color(0.85 * f, 0.87 * f, 0.83 * f)
                slab.material_override = m
                grp.add_child(slab)
                if cross:
                        slab.position.y = h * 0.5
                        var beam := MeshInstance3D.new()
                        var bm2 := BoxMesh.new()
                        bm2.size = Vector3(w * 0.9, 0.12, 0.1)
                        beam.mesh = bm2
                        beam.material_override = m
                        grp.add_child(beam)
                        beam.position.y = h * 0.72
                else:
                        slab.position.y = h * 0.36
                        # скруглённая «шапка» плиты
                        var cap := MeshInstance3D.new()
                        var cm := CylinderMesh.new()
                        cm.top_radius = w * 0.5
                        cm.bottom_radius = w * 0.5
                        cm.height = 0.14
                        cm.radial_segments = 8
                        cap.mesh = cm
                        cap.material_override = m
                        grp.add_child(cap)
                        cap.rotation.z = PI / 2.0
                        cap.position.y = h * 0.72
                # холмик могилы
                var mound := MeshInstance3D.new()
                var sm := SphereMesh.new()
                sm.radius = 0.5
                sm.height = 0.55
                sm.radial_segments = 10
                sm.rings = 4
                var dm := StandardMaterial3D.new()
                dm.albedo_color = Color(0.13, 0.11, 0.08)
                dm.roughness = 1.0
                mound.mesh = sm
                mound.material_override = dm
                grp.add_child(mound)
                mound.scale = Vector3(1.0, 0.28, 1.3)
                mound.position = Vector3(0, 0.02, 0.75)


## Саркофаг севера погоста — «княжеская» гробница, у неё две свечи.
func _build_sarcophagus() -> void:
        var grp := Node3D.new()
        add_child(grp)
        var px := CENTER.x - 1.0
        var pz := CENTER.y + 5.6
        grp.position = Vector3(px, _ground_y(px, pz), pz)
        grp.rotation.y = 0.35

        var stone := StandardMaterial3D.new()
        stone.albedo_texture = ROCK_DIFF
        stone.texture_normal = ROCK_NOR
        stone.albedo_color = Color(0.62, 0.64, 0.68)
        stone.roughness = 0.9
        stone.uv1_scale = Vector3(1.2, 1.2, 1.2)

        var box := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.95, 0.55, 2.1)
        box.mesh = bm
        box.material_override = stone
        grp.add_child(box)
        box.position.y = 0.28
        var lid := MeshInstance3D.new()
        var lm := BoxMesh.new()
        lm.size = Vector3(1.05, 0.18, 2.25)
        lid.mesh = lm
        lid.material_override = stone
        grp.add_child(lid)
        lid.position.y = 0.64
        lid.rotation.z = 0.045
        # сдвинутая крышка у изголовья — гробницу «открывали»
        lid.position.z = -0.14


## Кованая ограда с калиткой на запад (к деревне).
func _build_fence() -> void:
        var iron := StandardMaterial3D.new()
        iron.albedo_color = Color(0.05, 0.05, 0.06)
        iron.roughness = 0.55
        iron.metallic = 0.8

        var n := 44
        for i in n:
                var ang := TAU * i / n
                # калитка: проём на запад (в сторону деревни)
                var gate_half := 0.55
                var d := absf(ang - PI)
                if d < gate_half:
                        continue
                var r: float = RADIUS + 0.6
                var x := CENTER.x + cos(ang) * r
                var z := CENTER.y + sin(ang) * r
                var picket := MeshInstance3D.new()
                var pm := CylinderMesh.new()
                pm.top_radius = 0.03
                pm.bottom_radius = 0.035
                pm.height = 1.6
                pm.radial_segments = 6
                picket.mesh = pm
                picket.material_override = iron
                add_child(picket)
                picket.position = Vector3(x, _ground_y(x, z) + 0.65, z)
                # штырь-наконечник
                var tip := MeshInstance3D.new()
                var tm := CylinderMesh.new()
                tm.top_radius = 0.0
                tm.bottom_radius = 0.03
                tm.height = 0.16
                tm.radial_segments = 4
                tip.mesh = tm
                tip.material_override = iron
                picket.add_child(tip)
                tip.position = Vector3(0, 0.75, 0)
                # горизонтальная перекладина — сегментами между пиками
                if i % 2 == 0:
                        var next_ang := TAU * ((i + 1) % n) / n
                        var mid_ang := ang + (next_ang - ang) * 0.5
                        var nx := CENTER.x + cos(next_ang) * r
                        var nz := CENTER.y + sin(next_ang) * r
                        var rail := MeshInstance3D.new()
                        var rm := BoxMesh.new()
                        rm.size = Vector3(0.05, 0.05, Vector2(nx - x, nz - z).length())
                        rail.mesh = rm
                        rail.material_override = iron
                        add_child(rail)
                        var mx := CENTER.x + cos(mid_ang) * r
                        var mz := CENTER.y + sin(mid_ang) * r
                        rail.position = Vector3(mx, _ground_y(mx, mz) + 1.0, mz)
                        rail.look_at(Vector3(nx, _ground_y(nx, nz) + 1.0, nz), Vector3.UP)


## Сухое дерево (стоячий ствол) и череп у ограды.
func _build_dead_tree() -> void:
        var tree := DEAD_TREE.instantiate()
        add_child(tree)
        var x := CENTER.x + 5.4
        var z := CENTER.y + 4.2
        var s := 0.9
        tree.scale = Vector3(s, s, s)
        # модель — бревно вдоль X: ставим вертикально
        tree.rotation = Vector3(0, _rng.randf() * TAU, PI / 2.0)
        tree.position = Vector3(x, _ground_y(x, z) + 1.3 * s, z)

        var skull: Node3D = SKULL.instantiate()
        add_child(skull)
        var sx := CENTER.x - 3.1
        var sz := CENTER.y + 6.8
        skull.position = Vector3(sx, _ground_y(sx, sz) + 0.06, sz)
        skull.rotation.y = 2.2
        var k := 0.22
        skull.scale = Vector3(k, k, k)


## «Мёртвые свечи»: холодный огонёк на могилах — путеводные огни
## (тёплых здесь нет: огонь погоста не греет).
func _build_candles() -> void:
        var spots := [
                Vector2(-1.0, -3.8), Vector2(-2.6, -0.4), Vector2(1.4, 0.2),
                Vector2(-1.0, 5.4), Vector2(4.4, 1.0),
        ]
        for i in spots.size():
                var p: Vector2 = spots[i]
                var x := CENTER.x + p.x
                var z := CENTER.y + p.y
                var y := _ground_y(x, z)
                # огонёк
                var flame := MeshInstance3D.new()
                var sm := SphereMesh.new()
                sm.radius = 0.055
                sm.height = 0.11
                sm.radial_segments = 6
                sm.rings = 3
                var fm := StandardMaterial3D.new()
                fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                fm.albedo_color = Color(0.5, 0.8, 1.0)
                fm.emission_enabled = true
                fm.emission = Color(0.4, 0.75, 1.0)
                fm.emission_energy_multiplier = 2.2
                flame.mesh = sm
                flame.material_override = fm
                flame.add_to_group("grave_flame")
                add_child(flame)
                flame.position = Vector3(x, y + 0.22, z)
                # свет
                var light := OmniLight3D.new()
                light.light_color = Color(0.45, 0.7, 1.0)
                light.light_energy = 0.9
                light.omni_range = 4.5
                light.shadow_enabled = false
                light.add_to_group("grave_light")
                add_child(light)
                light.position = Vector3(x, y + 0.35, z)


## Приземистый туман: широкие медленные «клубы» по земле погоста.
func _build_fog() -> void:
        var p := GPUParticles3D.new()
        p.amount = 26
        p.lifetime = 11.0
        p.preprocess = 11.0
        p.speed_scale = 0.32
        p.position = Vector3(CENTER.x, _ground_y(CENTER.x, CENTER.y) + 0.45, CENTER.y)
        var pm := ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
        pm.emission_box_extents = Vector3(RADIUS, 0.35, RADIUS)
        pm.direction = Vector3(1, 0, 0)
        pm.spread = 25.0
        pm.initial_velocity_min = 0.12
        pm.initial_velocity_max = 0.3
        pm.gravity = Vector3.ZERO
        pm.damping_min = 0.02
        pm.damping_max = 0.08
        pm.scale_min = 1.6
        pm.scale_max = 3.4
        p.process_material = pm
        var sm := QuadMesh.new()
        sm.size = Vector2(2.6, 1.1)
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.albedo_color = Color(0.45, 0.5, 0.62, 0.12)
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.billboard_keep_scale = false
        sm.material = m
        p.draw_pass_1 = sm
        add_child(p)


func _process(dt: float) -> void:
        # трепет мёртвых свечей
        var t := Time.get_ticks_msec() * 0.001
        var i := 0
        for l in get_tree().get_nodes_in_group("grave_light"):
                l.light_energy = 0.8 + 0.25 * sin(t * 7.3 + i * 1.9) + 0.1 * sin(t * 19.0 + i)
                i += 1
        for f in get_tree().get_nodes_in_group("grave_flame"):
                f.scale = Vector3.ONE * (1.0 + 0.22 * sin(t * 9.1 + i * 2.7))
