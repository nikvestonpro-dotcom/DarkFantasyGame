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
var m_door: StandardMaterial3D


func _ready() -> void:
	rng.seed = 1313
	_make_materials()
	_build_tavern()
	_build_houses()
	_build_well()
	_build_campfire()
	_build_lanterns()
	_build_fences()
	_build_signpost()
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
	m_plaster = _cmap(Color(0.60, 0.57, 0.50))
	m_plaster_warm = _cmap(Color(0.54, 0.48, 0.40))
	m_beam = _pmat("dark_planks", Color(0.55, 0.50, 0.42), 0.55, 0.95, 1.1)
	m_wall = _pmat("wood_plank_wall", Color(0.82, 0.76, 0.68), 0.5, 0.95)
	m_wall_light = _pmat("wood_plank_wall", Color(1.05, 1.0, 0.9), 0.5, 0.95)
	m_roof_wood = _pmat("roof_planks", Color(0.85, 0.80, 0.72), 0.55, 0.95)
	m_roof_straw = _pmat("roof_planks", Color(1.05, 0.88, 0.55), 0.75, 1.0, 0.8)
	m_roof_tile = _pmat("clay_roof_tiles_02", Color(0.95, 0.85, 0.8), 0.6, 0.9)
	m_stone = _pmat("stone_wall", Color(0.85, 0.86, 0.9), 0.5, 0.95)
	m_ruin = _pmat("castle_wall_varriation", Color(0.8, 0.82, 0.88), 0.45, 0.95)
	m_window = _cmap(Color(0.08, 0.06, 0.04))
	m_window.emission_enabled = true
	m_window.emission = Color(1.0, 0.62, 0.25)
	m_window.emission_energy_multiplier = 3.4
	m_door = _pmat("dark_planks", Color(0.42, 0.30, 0.20), 0.7, 0.95)


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
	# Ставни
	if shutters:
		var side := Vector3(dir.z, 0.0, -dir.x)
		for s in [-1.0, 1.0]:
			var sf: float = s
			var open := rng.randf() < 0.5
			var sx: float = sf * (w * 0.5 + 0.16)
			var shutter := _box(parent, Vector3(0.09, h + 0.1, w * 0.42),
				pos + dir * 0.1 + side * sx, m_wall_light)
			shutter.rotation.y = rot_y + (sf * (0.95 if open else 0.0))
			shutter.position += side * (sf * 0.14 if open else 0.0)


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
	g.set_color(0, Color(0.75, 0.75, 0.78, 0.0))
	g.set_color(1, Color(0.75, 0.75, 0.78, 0.0))
	g.add_point(0.25, Color(0.75, 0.75, 0.78, 0.32))
	g.add_point(0.7, Color(0.7, 0.7, 0.74, 0.16))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.draw_pass_1 = quad
	parent.add_child(p)


func _building_at(pos: Vector2) -> Node3D:
	var b := Node3D.new()
	b.position = Vector3(pos.x, GY, pos.y)
	b.rotation.y = atan2(-pos.x, -pos.y)
	add_child(b)
	return b


# ---------- ТАВЕРНА ----------

func _build_tavern() -> void:
	var b := Node3D.new()
	b.position = Vector3(0, GY, -13.5)
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
	var defs = [
		[Vector2(12, 8), 6.5, 5.5, 3.0, "plaster", "straw", true],
		[Vector2(-12, 7), 7.0, 5.0, 2.8, "wood", "wood", true],
		[Vector2(3, 13), 6.0, 5.0, 2.9, "plaster", "tile", false],
		[Vector2(-18, 14), 6.8, 5.2, 2.7, "wood", "straw", true],
	]
	for d in defs:
		var wall_m: StandardMaterial3D = m_plaster if d[4] == "plaster" else m_wall
		var roof_m: StandardMaterial3D = m_roof_straw if d[5] == "straw" \
				else (m_roof_wood if d[5] == "wood" else m_roof_tile)
		_build_house(d[0], d[1], d[2], d[3], wall_m, roof_m, d[6], d[4] == "plaster")


func _build_house(pos: Vector2, w: float, dep: float, wall_h: float,
		wall_m: Material, roof_m: Material, chimney: bool, timber: bool) -> void:
	var b := _building_at(pos)
	var up_h: float = wall_h * 0.85       # высота второго этажа
	var up_y: float = 0.7 + wall_h        # низ второго этажа (над цоколем)
	var top_y: float = up_y + up_h        # верх стен (линия низа крыши)
	var eave := 0.95                      # свес крыши по скатам
	var over := 0.8                       # свес крыши по фронтонам
	var roof_h: float = maxf(1.9, w * 0.4)
	var leaf_m := _cmap(Color(0.18, 0.34, 0.15))
	var iron_m := _cmap(Color(0.14, 0.13, 0.12), 0.45)
	var log_m := _pmat("dark_planks", Color(0.55, 0.46, 0.36), 0.35)

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

	# --- Окна: нижний этаж с цветниками, верхний — со ставнями ---
	_window(b, Vector3(-w * 0.26, 0.7 + wall_h * 0.55, dep * 0.5 + 0.03))
	_window(b, Vector3(w * 0.38, 0.7 + wall_h * 0.55, dep * 0.5 + 0.03))
	_window(b, Vector3(-w * 0.5 - 0.44, up_y + up_h * 0.5, 0), 90.0, 0.62, 0.8)
	_window(b, Vector3(w * 0.5 + 0.44, up_y + up_h * 0.5, 0), 90.0, 0.62, 0.8)
	_window(b, Vector3(-w * 0.3, up_y + up_h * 0.55, dep * 0.5 + 0.44), 0.0, 0.66, 0.9, false)
	_window(b, Vector3(w * 0.3, up_y + up_h * 0.55, dep * 0.5 + 0.44), 0.0, 0.66, 0.9, false)
	_window(b, Vector3(-w * 0.24, up_y + up_h * 0.55, -dep * 0.5 - 0.44), 180.0, 0.66, 0.9, false)
	# Цветники под двумя нижними окнами
	for wx in [-w * 0.26, w * 0.38]:
		_box(b, Vector3(1.0, 0.24, 0.28), Vector3(wx, 0.7 + wall_h * 0.55 - 0.72,
				dep * 0.5 + 0.14), m_beam)
		_box(b, Vector3(0.92, 0.12, 0.22), Vector3(wx, 0.7 + wall_h * 0.55 - 0.55,
				dep * 0.5 + 0.14), leaf_m)

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
	var holder := _place_model(MDL + "ken_well.fbx", Vector3(4.5, GY, 3.5),
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
		b.position = Vector3(4.5, GY, 3.5)
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
	b.position = Vector3(0, GY, 0)
	add_child(b)
	# Костровище — фотограмметрическая модель Poly Haven
	var pit := _place_model(MDL + "stone_fire_pit.glb", Vector3(0, GY, 0),
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
		fm.emission_energy_multiplier = 3.0
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
	sq.material = sm2
	sparks.draw_pass_1 = sq
	b.add_child(sparks)


# ---------- ФОНАРИ ----------

func _build_lanterns() -> void:
	var spots := [
		Vector3(5.5, GY, -5.5), Vector3(-5.5, GY, -5.5), Vector3(6.5, GY, 4.0),
		Vector3(-6.5, GY, 4.0), Vector3(0, GY, 10.5), Vector3(-3.0, GY, -9.0),
	]
	for s in spots:
		var b := Node3D.new()
		b.position = s
		add_child(b)
		_box(b, Vector3(0.14, 3.1, 0.14), Vector3(0, 1.55, 0), m_beam)
		# Кронштейн и подвесной фонарь
		_box(b, Vector3(0.5, 0.08, 0.08), Vector3(0.2, 3.0, 0), m_beam)
		_box(b, Vector3(0.42, 0.5, 0.42), Vector3(0.4, 2.72, 0), m_window)
		_box(b, Vector3(0.55, 0.08, 0.55), Vector3(0.4, 3.02, 0), m_beam)
		_box(b, Vector3(0.03, 0.18, 0.03), Vector3(0.4, 3.08, 0), m_beam)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.68, 0.35)
		light.light_energy = 2.2
		light.omni_range = 10.0
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
	for i in n:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 1.1, 0.16)
		post.mesh = bm
		post.material_override = m_beam
		post.position = a + dir * (seg * float(i) / float(n - 1)) + Vector3(0, 0.55, 0)
		add_child(post)
	for yy in [0.45, 0.85]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.06, 0.1, seg)
		rail.mesh = rm
		rail.material_override = m_wall_light
		rail.position = (a + b_end) * 0.5 + Vector3(0, yy, 0)
		rail.rotation.y = yaw
		add_child(rail)


func _build_fences() -> void:
	_fence(Vector3(8, GY, 11), Vector3(14, GY, 9))
	_fence(Vector3(-8, GY, 10), Vector3(-15, GY, 8))
	_fence(Vector3(-10, GY, -3), Vector3(-10, GY, 4))


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
	# Стога сена
	var hay := _pmat("roof_planks", Color(1.1, 0.95, 0.55), 0.9, 1.0, 0.7)
	for hp in [Vector3(16.5, GY, 11.5), Vector3(-17.5, GY, -9.5), Vector3(9.5, GY, -12.5)]:
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
	# Бочки
	var barrel_m := _pmat("dark_planks", Color(0.6, 0.5, 0.4), 0.5)
	var hoop_m := _cmap(Color(0.16, 0.15, 0.14), 0.5)
	for bp in [Vector3(-4.2, 0, 6.8), Vector3(-4.6, 0, 7.6), Vector3(10.8, 0, -9.0),
			Vector3(-10.5, 0, 8.8)]:
		var y := GameWorld.terrain_height(bp.x, bp.z)
		var bar := _cyl(self, 0.36, 0.33, 0.95, Vector3(bp.x, y + 0.48, bp.z), barrel_m, 14)
		for hy in [0.15, 0.8]:
			_cyl(bar, 0.375, 0.375, 0.06, Vector3(0, hy - 0.48, 0), hoop_m, 14)
	# Ящики
	for cp in [Vector3(-3.4, 0, 6.2), Vector3(11.3, 0, -8.2), Vector3(-11.0, 0, 8.0),
			Vector3(5.8, 0, 12.5), Vector3(-6.9, 0, -9.6)]:
		var y := GameWorld.terrain_height(cp.x, cp.z)
		var crate := _box(self, Vector3(0.72, 0.72, 0.72), Vector3(cp.x, y + 0.36, cp.z),
			m_wall, Vector3(0, rng.randf() * TAU, 0))
		crate.name = "Crate"
	# Поленница у таверны
	var log_m := _pmat("dark_planks", Color(0.55, 0.46, 0.36), 0.35)
	for i in 7:
		var ang := i * 0.45
		var r := 0.14
		var lx := 5.6 + cos(ang) * r * 2.2
		var lz := -10.5 + sin(ang) * r * 2.2
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


# ---------- ИМПОРТНЫЕ CC0-МОДЕЛИ ----------

func _build_imported() -> void:
	# Два дома-фахверка (Quaternius) на месте бывших процедурных
	var house_restyle := {
		"light_ochre": m_plaster, "dark_blue": m_roof_tile,
		"brown": m_beam, "dark_brown": m_beam,
		"dark_grey": m_stone, "dark_purple": m_beam,
	}
	for hp in [Vector2(-14, -6), Vector2(13, -5)]:
		var yaw := atan2(-hp.x, -hp.y) + PI
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
			_build_house(hp, 6.0, 6.0, 3.0, m_plaster, m_roof_straw, true, true)

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
	for bdef in [[Vector3(3.4, GY, -7.4), 2.6], [Vector3(-3.0, GY, 6.9), 1.0]]:
		var bench := _place_model(MDL + "painted_wooden_bench.glb",
			Vector3(bdef[0].x, GameWorld.terrain_height(bdef[0].x, bdef[0].z), bdef[0].z),
			bdef[1], 0.95, 0.04, {})
		if bench == null:
			_box(self, Vector3(1.6, 0.1, 0.5), bdef[0] + Vector3(0, 0.5, 0), m_beam,
				Vector3(0, bdef[1], 0))

	# Живые кусты у домов (Poly Haven)
	for s in [Vector3(-8.5, 0, 5.5), Vector3(10.5, 0, 10.0), Vector3(17.0, 0, 4.0),
			Vector3(-16.5, 0, -10.5), Vector3(6.5, 0, -12.0)]:
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

