extends Node3D
## TWIN MOONS — Stage 1 world builder.
## Builds the whole world procedurally: terrain, night lake, moonlight,
## star sky, pine forest, mountains, fireflies. Fully deterministic.
## Also acts as cinematic shot director: run with user args  -- --shots=/abs/dir

const WORLD_SIZE := 512.0
const GRID := 160                     # terrain segments per side
const WATER_Y := 0.35
const LAKE_C := Vector2(95.0, 30.0)    # lake center (x, z)
const LAKE_SIG := 40.0                 # basin gaussian width
const PLATEAU_C := Vector2(-70.0, -50.0)  # future village site
const PLATEAU_R := 46.0
const PLATEAU_H := 4.2
const MOON_DIR := Vector3(0.765, 0.5, -0.406)  # az 62°, el 30° (matches sky texture)

var rng := RandomNumberGenerator.new()
var shot_cams: Array = []   # camera positions — scatter keeps clear zones around them

# ---------------------------------------------------------------- terrain
func _hash2(ix: int, iz: int) -> float:
        var n := ix * 374761393 + iz * 668265263
        n = (n ^ (n >> 13)) & 0x7fffffff
        n = (n * 1274126177) & 0x7fffffff
        n = n ^ (n >> 16)
        return float(n) / 2147483647.0

func _vnoise(x: float, z: float) -> float:
        var ix := floori(x)
        var iz := floori(z)
        var fx := x - float(ix)
        var fz := z - float(iz)
        fx = fx * fx * (3.0 - 2.0 * fx)
        fz = fz * fz * (3.0 - 2.0 * fz)
        var a := _hash2(ix, iz)
        var b := _hash2(ix + 1, iz)
        var c := _hash2(ix, iz + 1)
        var d := _hash2(ix + 1, iz + 1)
        return lerp(lerp(a, b, fx), lerp(c, d, fx), fz)

func _fbm(x: float, z: float, octaves: int) -> float:
        var s := 0.0
        var amp := 0.5
        var f := 1.0
        var norm := 0.0
        for _i in octaves:
                s += _vnoise(x * f, z * f) * amp
                norm += amp
                amp *= 0.5
                f *= 2.03
        return s / norm

func height_at(x: float, z: float) -> float:
        var h := 3.2 + _fbm(x * 0.009 + 13.7, z * 0.009 - 7.3, 4) * 9.5
        h += _fbm(x * 0.031 - 3.1, z * 0.031 + 5.9, 2) * 2.4
        # lake basin
        var dl := Vector2(x, z).distance_to(LAKE_C)
        h -= 12.0 * exp(-(dl * dl) / (LAKE_SIG * LAKE_SIG))
        # village plateau
        var dp := Vector2(x, z).distance_to(PLATEAU_C)
        var pinf := exp(-(dp * dp) / (34.0 * 34.0))
        h = lerpf(h, PLATEAU_H, pinf)
        # outer mountain ring on the terrain itself
        var dc := Vector2(x, z).length()
        if dc > 195.0:
                var t := clampf((dc - 195.0) / 61.0, 0.0, 1.0)
                h += pow(t, 1.5) * 30.0
        return h

func _terrain_normal(x: float, z: float) -> Vector3:
        var e := 0.7
        var hl := height_at(x - e, z)
        var hr := height_at(x + e, z)
        var hd := height_at(x, z - e)
        var hu := height_at(x, z + e)
        return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

func _build_terrain() -> void:
        var half := WORLD_SIZE * 0.5
        var step := WORLD_SIZE / float(GRID)
        var verts := PackedVector3Array()
        var norms := PackedVector3Array()
        var cols := PackedColorArray()
        var idx := PackedInt32Array()
        verts.resize((GRID + 1) * (GRID + 1))
        norms.resize((GRID + 1) * (GRID + 1))
        cols.resize((GRID + 1) * (GRID + 1))
        for gz in GRID + 1:
                for gx in GRID + 1:
                        var x := -half + gx * step
                        var z := -half + gz * step
                        var h := height_at(x, z)
                        var i := gz * (GRID + 1) + gx
                        verts[i] = Vector3(x, h, z)
                        norms[i] = _terrain_normal(x, z)
                        cols[i] = _terrain_color(x, z, h, norms[i])
        for gz in GRID:
                for gx in GRID:
                        var a := gz * (GRID + 1) + gx
                        var b := a + 1
                        var c := a + (GRID + 1)
                        var d := c + 1
                        # winding: front faces point UP (verified empirically in GL Compat 4.7)
                        idx.append_array(PackedInt32Array([a, b, c, c, b, d]))
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_NORMAL] = norms
        arrays[Mesh.ARRAY_COLOR] = cols
        arrays[Mesh.ARRAY_INDEX] = idx
        var am := ArrayMesh.new()
        am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        print("TERRAIN AABB: ", am.get_aabb(), " verts: ", verts.size())
        var mat := StandardMaterial3D.new()
        mat.vertex_color_use_as_albedo = true
        mat.roughness = 1.0
        am.surface_set_material(0, mat)
        var mi := MeshInstance3D.new()
        mi.mesh = am
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        mi.name = "Terrain"
        add_child(mi)

func _terrain_color(x: float, z: float, h: float, n: Vector3) -> Color:
        var dl := Vector2(x, z).distance_to(LAKE_C)
        var dp := Vector2(x, z).distance_to(PLATEAU_C)
        # base grass, noise-modulated
        var v := _fbm(x * 0.05 + 100.0, z * 0.05 - 40.0, 3)
        var micro := _fbm(x * 0.33 + 7.0, z * 0.33 - 11.0, 2)
        var grass := Color(0.145, 0.215, 0.12)
        var meadow := Color(0.17, 0.25, 0.125)
        var col := grass.lerp(meadow, clampf(v * 1.2 - 0.1, 0.0, 1.0))
        col = col.darkened(0.10 * (1.0 - micro)) + Color(0.008, 0.016, 0.004) * micro
        # plateau: slightly warmer, tidier grass (future village)
        col = col.lerp(Color(0.20, 0.26, 0.13), exp(-(dp * dp) / (40.0 * 40.0)) * 0.8)
        # rock on slopes
        if n.y < 0.76:
                col = col.lerp(Color(0.24, 0.225, 0.21), clampf((0.76 - n.y) * 4.0, 0.0, 1.0))
        # high ground: rocky dark
        if h > 16.0:
                col = col.lerp(Color(0.20, 0.19, 0.185), clampf((h - 16.0) / 10.0, 0.0, 0.6))
        # shore sand around the lake (wide soft blend)
        if h > -0.8 and h < 1.8 and dl < LAKE_SIG * 1.7:
                var shore := 1.0 - absf(h - 0.55) / 1.35
                col = col.lerp(Color(0.30, 0.27, 0.21), clampf(shore, 0.0, 0.72))
        # underwater mud
        if h < -0.4:
                col = col.lerp(Color(0.10, 0.105, 0.09), clampf((-0.4 - h) * 0.6, 0.0, 0.9))
        return Color(col.r, col.g, col.b, 1.0)

# ---------------------------------------------------------------- water
func _build_water() -> void:
        var pm := PlaneMesh.new()
        pm.size = Vector2(240, 240)
        pm.subdivide_width = 40
        pm.subdivide_depth = 40
        pm.center_offset = Vector3(0, 0, 0)
        var sm := ShaderMaterial.new()
        sm.shader = load("res://shaders/water.gdshader")
        sm.set_shader_parameter("deep_color", Vector3(0.016, 0.045, 0.10))
        sm.set_shader_parameter("shallow_color", Vector3(0.06, 0.15, 0.24))
        sm.set_shader_parameter("sky_tint", Vector3(0.18, 0.24, 0.44))
        sm.set_shader_parameter("moon_dir", MOON_DIR)
        sm.set_shader_parameter("wave_height", 0.05)
        sm.set_shader_parameter("streak_power", 55.0)
        sm.set_shader_parameter("streak_energy", 2.2)
        pm.material = sm
        var mi := MeshInstance3D.new()
        mi.mesh = pm
        mi.position = Vector3(LAKE_C.x, WATER_Y, LAKE_C.y)
        mi.name = "Water"
        add_child(mi)

# ---------------------------------------------------------------- sky & light
func _build_sky_dome() -> void:
        var dome_mat := ShaderMaterial.new()
        dome_mat.shader = load("res://shaders/sky_dome.gdshader")
        dome_mat.set_shader_parameter("panorama", load("res://assets/textures/sky_night_panorama.png"))
        dome_mat.set_shader_parameter("flip_u", false)
        dome_mat.set_shader_parameter("flip_v", false)
        var sphere := SphereMesh.new()
        sphere.radius = 1200.0
        sphere.height = 2400.0
        sphere.radial_segments = 48
        sphere.rings = 24
        sphere.material = dome_mat
        var dome := MeshInstance3D.new()
        dome.mesh = sphere
        dome.name = "SkyDome"
        dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(dome)

func _build_environment() -> void:
        var env := Environment.new()
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.03, 0.04, 0.09)
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.20, 0.24, 0.40)
        env.ambient_light_energy = 0.95
        env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
        env.tonemap_exposure = 1.0
        env.glow_enabled = true
        env.glow_intensity = 0.5
        env.glow_strength = 1.0
        env.glow_bloom = 0.05
        env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
        env.fog_enabled = true
        env.fog_light_color = Color(0.20, 0.24, 0.40)
        env.fog_density = 0.0040
        env.fog_sky_affect = 0.0
        var we := WorldEnvironment.new()
        we.environment = env
        add_child(we)

        var moon := DirectionalLight3D.new()
        moon.name = "Moonlight"
        moon.light_color = Color(0.72, 0.78, 1.0)
        moon.light_energy = 1.55
        # soft moonlight shadows ground the trees (no more black voids: terrain renders now)
        moon.shadow_enabled = true
        moon.directional_shadow_max_distance = 160.0
        moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
        moon.directional_shadow_fade_start = 0.6
        moon.shadow_blur = 3.0
        add_child(moon)
        moon.position = MOON_DIR * 500.0
        moon.look_at(Vector3.ZERO, Vector3.UP)

        # soft fill light from the opposite side (lifts the blacks)
        var fill := DirectionalLight3D.new()
        fill.name = "MoonFill"
        fill.light_color = Color(0.45, 0.52, 0.78)
        fill.light_energy = 0.7
        fill.shadow_enabled = false
        add_child(fill)
        fill.position = Vector3(-0.55, 0.35, 0.55).normalized() * 500.0
        fill.look_at(Vector3.ZERO, Vector3.UP)

# ---------------------------------------------------------------- scatter
func _collect_meshes(node: Node, out: Array) -> void:
        if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
                out.append(node)
        for c in node.get_children():
                _collect_meshes(c, out)

func _combined_aabb(parts: Array) -> AABB:
        var ab := AABB()
        var first := true
        for p in parts:
                var mi: MeshInstance3D = p
                var a := mi.get_aabb()
                a.position += mi.global_transform.origin if false else Vector3.ZERO
                if first:
                        ab = a
                        first = false
                else:
                        ab = ab.merge(a)
        return ab

func _scatter_variant(scene_path: String, transforms: Array, target_h: float, use_x := false, mat_override: Material = null) -> void:
        if transforms.is_empty():
                return
        var packed := load(scene_path) as PackedScene
        if packed == null:
                push_warning("missing scene: " + scene_path)
                return
        var inst := packed.instantiate()
        add_child(inst)
        inst.owner = null
        var parts: Array = []
        _collect_meshes(inst, parts)
        var ab := _combined_aabb(parts)
        var dim := ab.size.y
        if use_x:
                dim = ab.size.x
        var base_s := 1.0
        if dim > 0.001:
                base_s = target_h / dim
        for p in parts:
                var src_mi: MeshInstance3D = p
                var part_xf := src_mi.transform
                var use_mesh: Mesh = src_mi.mesh
                if mat_override != null:
                        use_mesh = src_mi.mesh.duplicate()
                        for si in use_mesh.get_surface_count():
                                use_mesh.surface_set_material(si, mat_override)
                var mm := MultiMesh.new()
                mm.transform_format = MultiMesh.TRANSFORM_3D
                mm.mesh = use_mesh
                mm.instance_count = transforms.size()
                for i in transforms.size():
                        var xf: Transform3D = transforms[i]
                        mm.set_instance_transform(i, xf * part_xf)
                var mmi := MultiMeshInstance3D.new()
                mmi.multimesh = mm
                mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
                add_child(mmi)
        inst.queue_free()

func _scatter_group(list_name: String, variants: Array, count: int, target_h: float, params: Dictionary, use_x := false, mat_override: Material = null) -> void:
        # params: min_h, max_h, min_lake_d, max_lake_d, min_plat_d, max_plat_d, slope_max, min_dist, jitter
        var occ := {}
        var out: Array = []
        var tries := 0
        var max_tries := count * 26
        while out.size() < count and tries < max_tries:
                tries += 1
                var x := rng.randf_range(-246.0, 246.0)
                var z := rng.randf_range(-246.0, 246.0)
                var h := height_at(x, z)
                if h < params.get("min_h", -100.0) or h > params.get("max_h", 100.0):
                        continue
                var n := _terrain_normal(x, z)
                if n.y < params.get("slope_min_n", 0.0):
                        continue
                var dl := Vector2(x, z).distance_to(LAKE_C)
                if dl < params.get("min_lake_d", 0.0) or dl > params.get("max_lake_d", 9999.0):
                        continue
                var dp := Vector2(x, z).distance_to(PLATEAU_C)
                if dp < params.get("min_plat_d", 0.0) or dp > params.get("max_plat_d", 9999.0):
                        continue
                # keep clear zones around cinematic camera positions
                var near_cam := false
                for cp in shot_cams:
                        var cpv: Vector3 = cp["pos"]
                        if Vector2(x, z).distance_to(Vector2(cpv.x, cpv.z)) < 5.5:
                                near_cam = true
                                break
                if near_cam:
                        continue
                var cell := Vector2i(int(x / 4.0), int(z / 4.0))
                if occ.has(cell):
                        continue
                occ[cell] = true
                var s := rng.randf_range(params.get("scale_jit", 0.82), params.get("scale_jit2", 1.22))
                var yaw := rng.randf_range(0.0, TAU)
                var sink: float = params.get("sink", 0.15)
                var b := Basis(Vector3.UP, yaw).scaled(Vector3(base_scale(target_h, s), base_scale(target_h, s), base_scale(target_h, s)))
                var xf := Transform3D(b, Vector3(x, h - sink, z))
                out.append(xf)
        # distribute over variants round-robin
        var per: Array = []
        per.resize(variants.size())
        for i in per.size():
                per[i] = []
        for i in out.size():
                per[i % variants.size()].append(out[i])
        for vi in variants.size():
                _scatter_variant("res://assets/models/nature/" + variants[vi], per[vi], target_h, use_x, mat_override)

func base_scale(_t: float, s: float) -> float:
        return s

func _scatter_nature() -> void:
        # dark pine forest: hills NW/N/W + outer ring slopes
        _scatter_group("pines", ["PineTree_1.glb", "PineTree_2.glb", "PineTree_3.glb", "PineTree_4.glb", "PineTree_5.glb"], 340, 11.0,
                {"min_h": 0.6, "max_h": 18.0, "slope_min_n": 0.70, "min_plat_d": 50.0, "min_lake_d": 58.0, "sink": 0.4})
        # birch groves: mixed into forest, lighter spots
        _scatter_group("birch", ["BirchTree_1.glb", "BirchTree_2.glb"], 70, 10.0,
                {"min_h": 0.6, "max_h": 14.0, "slope_min_n": 0.74, "min_plat_d": 40.0, "min_lake_d": 55.0, "sink": 0.45})
        # common trees near lake ring
        _scatter_group("common", ["CommonTree_1.glb", "CommonTree_2.glb"], 46, 9.0,
                {"min_h": 0.4, "max_h": 10.0, "slope_min_n": 0.76, "min_lake_d": 50.0, "max_lake_d": 110.0, "min_plat_d": 30.0, "sink": 0.4})
        # willows hugging the shore
        _scatter_group("willow", ["Willow_1.glb", "Willow_2.glb"], 14, 8.0,
                {"min_h": 0.15, "max_h": 4.5, "slope_min_n": 0.76, "min_lake_d": 47.0, "max_lake_d": 66.0, "sink": 0.35})
        # bushes
        _scatter_group("bush", ["Bush_1.glb", "Bush_2.glb", "BushBerries_1.glb"], 190, 1.6,
                {"min_h": -0.2, "max_h": 20.0, "slope_min_n": 0.60, "min_plat_d": 12.0, "sink": 0.22})
        # rocks & mossy rocks: above the waterline, near the shore ring
        _scatter_group("rock", ["Rock_1.glb", "Rock_2.glb", "Rock_3.glb", "Rock_4.glb", "Rock_Moss_1.glb", "Rock_Moss_2.glb"], 95, 2.8,
                {"min_h": 0.3, "max_h": 26.0, "slope_min_n": 0.0, "min_lake_d": 42.0, "sink": 0.45, "scale_jit": 0.5, "scale_jit2": 2.2})
        # stumps & logs on forest floor
        _scatter_group("stump", ["TreeStump.glb"], 14, 1.0, {"min_h": 0.5, "max_h": 16.0, "sink": 0.3})
        _scatter_group("log", ["WoodLog.glb"], 16, 3.0, {"min_h": 0.5, "max_h": 16.0, "sink": 0.3}, true)
        # grass tufts on meadows (denser: the refs are rich with ground detail)
        _scatter_group("grass", ["Grass.glb"], 650, 0.75,
                {"min_h": 0.2, "max_h": 14.0, "slope_min_n": 0.70, "min_lake_d": 48.0, "min_plat_d": 8.0, "sink": 0.05, "scale_jit": 0.7, "scale_jit2": 1.5})
        _scatter_group("flowers", ["Flowers.glb"], 90, 0.5,
                {"min_h": 0.3, "max_h": 10.0, "slope_min_n": 0.74, "min_lake_d": 50.0, "max_plat_d": 120.0, "min_plat_d": 6.0, "sink": 0.05})
        # lilypads on the shallow water edge
        _scatter_lilypads()

func _scatter_lilypads() -> void:
        var out: Array = []
        var tries := 0
        while out.size() < 9 and tries < 400:
                tries += 1
                var ang := rng.randf_range(-0.9, 0.4)   # NE shore sector (cluster)
                var rad := rng.randf_range(34.0, 50.0)
                var x := LAKE_C.x + cos(ang) * rad
                var z := LAKE_C.y + sin(ang) * rad
                if height_at(x, z) > WATER_Y - 0.5:
                        continue
                var yaw := rng.randf_range(0.0, TAU)
                var s := rng.randf_range(1.0, 1.9)
                var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
                out.append(Transform3D(b, Vector3(x, WATER_Y + 0.03, z)))
        _scatter_variant("res://assets/models/nature/Lilypad.glb", out, 0.5)

# ---------------------------------------------------------------- mountains
func _build_mountains() -> void:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.17, 0.19, 0.30)
        mat.roughness = 1.0
        var variants := ["Rock_2.glb", "Rock_4.glb", "Rock_5.glb", "Rock_3.glb"]
        for i in 15:
                var ang := TAU * float(i) / 15.0 + rng.randf_range(-0.12, 0.12)
                var rad := rng.randf_range(330.0, 430.0)
                var x := cos(ang) * rad
                var z := sin(ang) * rad
                var target := rng.randf_range(110.0, 230.0)
                var yaw := rng.randf_range(0.0, TAU)
                # main peak + a smaller shoulder rock: reads as a ridge, not a balloon
                var s := 1.0
                var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
                var list: Array = [Transform3D(b, Vector3(x, -target * 0.30, z))]
                var yaw2 := yaw + rng.randf_range(1.0, 2.5)
                var off := target * rng.randf_range(0.35, 0.55)
                var ox := x + cos(ang + 0.5) * off
                var oz := z + sin(ang + 0.5) * off
                list.append(Transform3D(Basis(Vector3.UP, yaw2).scaled(Vector3(s, s, s)), Vector3(ox, -target * 0.42, oz)))
                _scatter_variant("res://assets/models/nature/" + variants[i % variants.size()], list, target, false, mat)

# -------------------------------------------------- hero framing props
## Cozy refs are LOADED with foreground interest. For every cinematic shot
## place framing pines near the frame edges + a bush/rock up front.
func _build_hero_framing() -> void:
        var pines := ["PineTree_1.glb", "PineTree_2.glb", "PineTree_3.glb", "PineTree_4.glb"]
        for sd in shot_cams:
                var pos: Vector3 = sd["pos"]
                var look: Vector3 = sd["look"]
                var fwd := (look - pos).normalized()
                if absf(fwd.y) > 0.985:
                        continue  # straight-down debug cams: no framing
                var fwd_flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
                var side := fwd_flat.cross(Vector3.UP).normalized()
                var placed: Array = []
                for k in [-1.0, 1.0]:
                        var dist := rng.randf_range(10.0, 16.0)
                        var off := rng.randf_range(4.0, 6.5)
                        var px: Vector3 = pos + fwd_flat * dist + side * off * k
                        var h: float = height_at(px.x, px.z)
                        if h < 0.5:
                                px = pos + fwd_flat * (dist + 4.0) + side * off * k
                                h = height_at(px.x, px.z)
                        if h < 0.5:
                                continue
                        var yaw := rng.randf_range(0.0, TAU)
                        var sc := rng.randf_range(0.85, 1.25)
                        var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.03, 0.03)))
                        var b := (Basis(Vector3.UP, yaw) * tilt).scaled(Vector3(sc, sc, sc))
                        placed.append(Transform3D(b, Vector3(px.x, h - 0.3, px.z)))
                # bush + rock near the camera front
                var bx := pos + fwd_flat * rng.randf_range(5.0, 7.5) + side * rng.randf_range(-2.5, 2.5)
                var bh := height_at(bx.x, bx.z)
                if bh > 0.3:
                        placed.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(1.2, 1.2, 1.2)), Vector3(bx.x, bh - 0.15, bx.z)))
                if not placed.is_empty():
                        var pick := rng.randi_range(0, pines.size() - 1)
                        # framing pines as one variant multimesh (bush/rock separate quick hacks:
                        # reuse pines for trees, then add bush via its own scatter call)
                        var tree_list: Array = []
                        var bush_list: Array = []
                        for j in placed.size():
                                if j < 2:
                                        tree_list.append(placed[j])
                                else:
                                        bush_list.append(placed[j])
                        if not tree_list.is_empty():
                                _scatter_variant("res://assets/models/nature/" + pines[pick], tree_list, 12.0)
                        if not bush_list.is_empty():
                                _scatter_variant("res://assets/models/nature/Bush_1.glb", bush_list, 1.4)


# ---------------------------------------------------------------- campfire
## A lone warm campfire on the lake's west shore — the cozy anchor of the
## night world (ref: two gnomes by the fire). Flickering warm light.
var campfire_light: OmniLight3D

var _campfire_spot: Vector3 = Vector3(0.0, -999.0, 0.0)

func _find_campfire_spot() -> Vector3:
        # cached: _shot_list() and _build_campfire() must agree even though
        # the RNG state differs between the two calls
        if _campfire_spot.y > -900.0:
                return _campfire_spot
        # robust scan of the western shore arc: find dry ground near the water
        var best_spot: Vector3 = Vector3(LAKE_C.x - 52.0, 99.0, LAKE_C.y)
        var best_h := 99.0
        for ri in 12:
                var r := 40.0 + float(ri) * 2.5
                for ai in 9:
                        var ang := PI + (float(ai) - 4.0) * 0.22
                        var x := LAKE_C.x + cos(ang) * r
                        var z := LAKE_C.y + sin(ang) * r
                        var h := height_at(x, z)
                        if h >= 0.45 and h <= 2.2:
                                _campfire_spot = Vector3(x, h, z)
                                return _campfire_spot
                        # remember the lowest dry spot as fallback
                        if h > 0.45 and h < best_h:
                                best_h = h
                                best_spot = Vector3(x, h, z)
        # no gentle shore found: use the lowest dry ground (correct Y, never buried)
        _campfire_spot = best_spot
        return _campfire_spot

func _build_campfire() -> void:
        var c := _find_campfire_spot()
        # stone ring
        var ring: Array = []
        for i in 7:
                var a := TAU * float(i) / 7.0
                var px := c.x + cos(a) * 0.85
                var pz := c.z + sin(a) * 0.85
                ring.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(0.42, 0.42, 0.42)), Vector3(px, height_at(px, pz) - 0.05, pz)))
        _scatter_variant("res://assets/models/nature/Rock_1.glb", ring, 0.55)
        # crossed logs
        var logs: Array = []
        for i in 2:
                var a := rng.randf_range(0.0, TAU)
                var xf := Transform3D(Basis(Vector3.UP, a).scaled(Vector3(0.8, 0.8, 0.8)), c + Vector3(cos(a) * 0.2, -0.12, sin(a) * 0.2))
                logs.append(xf)
        _scatter_variant("res://assets/models/nature/WoodLog.glb", logs, 1.3, true)
        # embers: emissive sphere
        var ember_mat := StandardMaterial3D.new()
        ember_mat.emission_enabled = true
        ember_mat.emission = Color(1.0, 0.45, 0.12)
        ember_mat.emission_energy_multiplier = 2.2
        ember_mat.albedo_color = Color(0.25, 0.1, 0.05)
        var ember := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.22
        sm.height = 0.22
        sm.material = ember_mat
        ember.mesh = sm
        ember.position = c + Vector3(0, 0.05, 0)
        add_child(ember)
        # warm halo sprite above the ground
        var halo := MeshInstance3D.new()
        var qm := QuadMesh.new()
        qm.size = Vector2(7.0, 7.0)
        var hm := StandardMaterial3D.new()
        hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        hm.albedo_texture = load("res://assets/textures/soft_dot_warm.png")
        qm.material = hm
        halo.mesh = qm
        halo.position = c + Vector3(0, 0.35, 0)
        halo.rotation_degrees = Vector3(-90, 0, 0)
        add_child(halo)
        # fire particles
        var fmat := StandardMaterial3D.new()
        fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        fmat.albedo_texture = load("res://assets/textures/soft_dot_warm.png")
        fmat.vertex_color_use_as_albedo = true
        fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        var fp := CPUParticles3D.new()
        fp.amount = 24
        fp.lifetime = 1.4
        fp.explosiveness = 0.0
        fp.randomness = 1.0
        fp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
        fp.emission_sphere_radius = 0.18
        fp.position = c + Vector3(0, 0.25, 0)
        fp.direction = Vector3.UP
        fp.spread = 22.0
        fp.initial_velocity_min = 0.7
        fp.initial_velocity_max = 1.5
        fp.gravity = Vector3(0, 0.9, 0)
        fp.scale_amount_min = 0.12
        fp.scale_amount_max = 0.4
        fp.material_override = fmat
        add_child(fp)
        # warm flickering light
        campfire_light = OmniLight3D.new()
        campfire_light.light_color = Color(1.0, 0.62, 0.30)
        campfire_light.light_energy = 2.4
        campfire_light.omni_range = 22.0
        campfire_light.shadow_enabled = false
        campfire_light.position = c + Vector3(0, 1.0, 0)
        add_child(campfire_light)

func _process(_d: float) -> void:
        if campfire_light != null:
                campfire_light.light_energy = 2.1 + randf_range(-0.25, 0.35)

# ---------------------------------------------------------------- fireflies
func _build_fireflies() -> void:
        var spots := [
                {"c": Vector3(LAKE_C.x - 38, 1.6, LAKE_C.y + 18), "col": Color(1.0, 0.9, 0.55)},
                {"c": Vector3(PLATEAU_C.x + 20, 5.0, PLATEAU_C.y + 30), "col": Color(0.8, 1.0, 0.6)},
                {"c": Vector3(-20, 6.0, 150.0), "col": Color(1.0, 0.85, 0.5)},
        ]
        var dot_tex := load("res://assets/textures/soft_dot.png")
        for spot in spots:
                var mat := StandardMaterial3D.new()
                mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
                mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                mat.albedo_texture = dot_tex
                mat.vertex_color_use_as_albedo = true
                mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
                mat.no_depth_test = false
                var cp := CPUParticles3D.new()
                cp.amount = 40
                cp.lifetime = 7.0
                cp.explosiveness = 0.0
                cp.randomness = 1.0
                cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
                cp.emission_box_extents = Vector3(34.0, 2.6, 34.0)
                cp.position = spot["c"]
                cp.direction = Vector3.UP
                cp.spread = 180.0
                cp.initial_velocity_min = 0.15
                cp.initial_velocity_max = 0.5
                cp.gravity = Vector3(0, 0.015, 0)
                cp.scale_amount_min = 0.08
                cp.scale_amount_max = 0.30
                # gentle alpha pulse over lifetime (twinkle)
                var ramp := Gradient.new()
                ramp.add_point(0.0, Color(1, 1, 1, 0.0))
                ramp.add_point(0.2, Color(1, 1, 1, 0.7))
                ramp.add_point(0.75, Color(1, 1, 1, 0.55))
                ramp.add_point(1.0, Color(1, 1, 1, 0.0))
                cp.color_ramp = ramp
                cp.color = spot["col"]
                cp.material_override = mat
                add_child(cp)

# ---------------------------------------------------------------- shots
func _shot_list() -> Array:
        var moon_az := Vector2(MOON_DIR.x, MOON_DIR.z).normalized()
        var shots := []
        # 1. moon path across the lake, BOTH moons in frame (ref 07)
        var c1 := Vector3(LAKE_C.x - moon_az.x * 62.0, 0.0, LAKE_C.y - moon_az.y * 62.0)
        c1.y = maxf(height_at(c1.x, c1.z) + 1.7, WATER_Y + 1.2)
        var l1 := Vector3(c1.x + moon_az.x * 140.0, 16.0, c1.z + moon_az.y * 140.0)
        shots.append({"n": "01_lake_moonpath", "pos": c1, "look": l1, "fov": 74.0})
        # 2. two moons over the valley: aim along moon direction so both moons show
        var c2 := Vector3(-120.0, height_at(-120.0, -100.0) + 8.0, -100.0)
        var l2 := Vector3(c2.x + moon_az.x * 420.0, 42.0, c2.z + moon_az.y * 420.0)
        shots.append({"n": "02_two_moons_vista", "pos": c2, "look": l2, "fov": 68.0})
        # 3. pine forest with fog: from the open meadow looking at the lit forest edge
        var c3 := Vector3(-95.0, height_at(-95.0, 130.0) + 2.4, 130.0)
        var l3 := Vector3(30.0, height_at(30.0, 40.0) + 5.0, 40.0)
        shots.append({"n": "03_forest_fog", "pos": c3, "look": l3, "fov": 66.0})
        # 4. meadow under the stars, looking up toward the moons
        var c4 := Vector3(-20.0, height_at(-20.0, 78.0) + 0.8, 78.0)
        var l4 := Vector3(c4.x + moon_az.x * 180.0, 60.0, c4.z + moon_az.y * 180.0)
        shots.append({"n": "04_meadow_stars", "pos": c4, "look": l4, "fov": 74.0})
        # 5. lake panorama from the south, slightly NE toward moons
        var c5 := Vector3(30.0, height_at(30.0, 192.0) + 12.0, 192.0)
        shots.append({"n": "05_lake_panorama", "pos": c5, "look": Vector3(LAKE_C.x + moon_az.x * 130.0, 9.0, LAKE_C.y + moon_az.y * 130.0), "fov": 66.0})
        # 6. shore close-up with fireflies, toward the moon glow
        var c6 := Vector3(LAKE_C.x + 30.0, maxf(height_at(LAKE_C.x + 30.0, LAKE_C.y - 40.0) + 1.2, WATER_Y + 0.9), LAKE_C.y - 40.0)
        shots.append({"n": "06_shore_fireflies", "pos": c6, "look": Vector3(c6.x + moon_az.x * 120.0, 8.0, c6.z + moon_az.y * 120.0), "fov": 62.0})
        # 7. plateau — future village site, camera to the WEST looking EAST so moons crown the site
        var c7 := Vector3(PLATEAU_C.x - 78.0, height_at(PLATEAU_C.x - 78.0, PLATEAU_C.y + 42.0) + 3.0, PLATEAU_C.y + 42.0)
        shots.append({"n": "07_plateau_village_site", "pos": c7, "look": Vector3(c7.x + moon_az.x * 300.0, 26.0, c7.z + moon_az.y * 300.0), "fov": 64.0})
        # 8. close-up of a pine tree (model QA: pivot, crown, lighting)
        var c8 := Vector3(-40.0, height_at(-40.0, 120.0) + 1.6, 120.0)
        shots.append({"n": "08_tree_closeup", "pos": c8, "look": Vector3(-52.0, height_at(-52.0, 108.0) + 4.0, 108.0), "fov": 58.0})
        # 9. campfire: fire in the foreground, lake and moons behind (the cozy anchor shot)
        var cf := _find_campfire_spot()
        var c9 := cf + Vector3(-4.5, 1.4, -3.0)
        c9.y = maxf(height_at(c9.x, c9.z) + 1.4, WATER_Y + 0.9)
        shots.append({"n": "09_campfire", "pos": c9, "look": cf + Vector3(6.0, 4.5, 4.0), "fov": 70.0})
        # debug: full-world overhead map (QA: terrain holes / black patches)
        if OS.get_cmdline_user_args().has("--debug"):
                shots.append({"n": "d1_map_down", "pos": Vector3(0, 260, 0.1), "look": Vector3(0, 0, 0), "fov": 80.0})
                shots.append({"n": "d2_cam03_down", "pos": Vector3(-95.0, height_at(-95.0, 130.0) + 12.0, 130.0), "look": Vector3(-95.0, 0.0, 129.0), "fov": 60.0})
                shots.append({"n": "d3_cam03_horizon", "pos": Vector3(-95.0, height_at(-95.0, 130.0) + 2.4, 130.0), "look": Vector3(35.0, height_at(-95.0, 130.0) + 2.4, 38.0), "fov": 66.0})
        return shots

func _ready() -> void:
        rng.seed = 20261029
        # compute cinematic camera spots FIRST so the scatter keeps clear zones around them
        shot_cams.clear()
        for s in _shot_list():
                shot_cams.append(s)
        var stage := 5
        for a in OS.get_cmdline_user_args():
                if String(a).begins_with("--stage="):
                        stage = String(a).substr(8).to_int()
        _build_terrain()
        if OS.get_cmdline_user_args().has("--terrainglow"):
                for c in get_children():
                        if c.name == "Terrain":
                                var mi: MeshInstance3D = c
                                var mat: StandardMaterial3D = mi.mesh.surface_get_material(0)
                                mat.emission_enabled = true
                                mat.emission = Color(1.0, 0.2, 0.2)
                                mat.emission_energy_multiplier = 1.2
                                print("TERRAINGLOW: material found: ", mat, " cull: ", mat.cull_mode, " emission: ", mat.emission_enabled)
        _build_water()
        if stage >= 1:
                _build_environment()
        if stage >= 2:
                _build_mountains()
        if stage >= 3:
                _scatter_nature()
                _build_hero_framing()
        if stage >= 4:
                _build_fireflies()
                _build_campfire()
        if stage >= 5:
                _build_sky_dome()
        var args := OS.get_cmdline_user_args()
        var shots_dir := ""
        for a in args:
                if String(a).begins_with("--shots="):
                        shots_dir = String(a).substr(8)
        if shots_dir != "":
                _run_shots(shots_dir)

func _run_shots(out_dir: String) -> void:
        DirAccess.make_dir_recursive_absolute(out_dir)
        var cam := Camera3D.new()
        cam.fov = 60.0
        add_child(cam)
        cam.make_current()
        for s in _shot_list():
                cam.fov = s["fov"]
                cam.global_position = s["pos"]
                cam.look_at(s["look"], Vector3.UP)
                for i in 12:
                        await get_tree().process_frame
                var img := get_viewport().get_texture().get_image()
                img.save_png(out_dir + "/" + s["n"] + ".png")
                print("shot saved: ", s["n"])
        print("ALL_SHOTS_DONE")
        get_tree().quit()
