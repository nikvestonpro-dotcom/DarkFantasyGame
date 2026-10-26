extends Node3D
## tools/shot_tour.gd — НОЧНОЙ ФОТОРОБОТ v8.0 «Цветная ночь».
## Грузит основной мир (scenes/main.tscn), обезвреживает ИИ врагов
## (анимации живут, но никто не атакует и не уходит из зоны),
## облетает локации свободной камерой и пишет PNG в download/screenshots.
## Запуск: godot --path . res://tools/shot_tour.tscn (под Xvfb + lavapipe).

const OUT := "/home/z/my-project/download/screenshots"
const SETTLE := 24  # кадров на осадку volumetric fog после перелёта

# [имя, позиция камеры, цель, fov, показывать UI]
var plan := [
	["01_village_overview", Vector3(34, 19, -36), Vector3(-4, 5, 10), 66, true],
	["02_campfire_hero", Vector3(7, 4.6, 32), Vector3(0, 4.3, 21), 55, true],
	["03_tavern_warm", Vector3(16, 6, 26), Vector3(-10, 3.5, 6), 58, false],
	["04_road_rune_stone", Vector3(-14, 6, 30), Vector3(-30, 3, 44), 60, false],
	["05_road_field", Vector3(-34, 13, 44), Vector3(-85, 5, 92), 62, false],
	["06_hamlet", Vector3(-66, 9, 74), Vector3(-86, 3.5, 93), 58, false],
	["07_castle_ghost", Vector3(-100, 24, 108), Vector3(-152, 14, 158), 60, false],
	["08_lake_moon", Vector3(-92, 10, -6), Vector3(-158, 7, -34), 68, false],
	["09_fallen_forest", Vector3(-8, 8.5, 62), Vector3(-32, 2.5, 38), 62, false],
	["10_sky_moon_aurora", Vector3(0, 70, 0), Vector3(-41.8, 99.9, 30.5), 75, false],
]

var cam: Camera3D
var main: Node3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Софтверный рендер: MSAA 4x из project.godot слишком дорог на lavapipe
	get_viewport().msaa_3d = Viewport.MSAA_2X

	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)

	# Врагов обезвредить: логика (погоня/атаки) выключена, анимации живут
	var n_enemy := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		e.set_physics_process(false)
		e.set_process(false)
		n_enemy += 1
	print("[tour] врагов обезврежено: ", n_enemy)

	cam = Camera3D.new()
	cam.near = 0.15
	cam.far = 900.0
	add_child(cam)
	cam.make_current()

	_run_tour()


func _run_tour() -> void:
	# Первая осадка: мир, туман, glow, шейдер неба
	for i in SETTLE:
		await get_tree().process_frame
		if i % 8 == 0:
			print("[tour] прогрев кадр ", i, " fps=", Engine.get_frames_per_second())

	for s in plan:
		var pos: Vector3 = s[1]
		# не дать камере уйти под рельеф на наземных точках
		var ground := GameWorld.terrain_height(pos.x, pos.z) + 2.2
		if pos.y < ground:
			pos.y = ground
		cam.global_position = pos
		cam.fov = s[3]
		if main.ui != null:
			main.ui.visible = s[4]
		cam.look_at(s[2])
		print("[tour] >>> ", s[0], " pos=", pos)
		for i in SETTLE:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := OUT + "/" + str(s[0]) + ".png"
		img.save_png(path)
		print("[tour] saved ", path, " ", img.get_width(), "x", img.get_height())

	print("[tour] ГОТОВО: ", plan.size(), " снимков")
	get_tree().quit()
