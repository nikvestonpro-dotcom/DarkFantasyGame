extends SceneTree
## Тест v8.0: запускает main.tscn, инспектирует дерево мира и персонажей.

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	var main = ps.instantiate()
	root.add_child(main)
	# Даём миру построиться кадр
	await process_frame
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame

	print("=== V8.0 WORLD INSPECT ===")
	var player = root.find_children("*", "Node", true, false)
	# Игрок
	var pl = main.get_tree().get_first_node_in_group("player")
	if pl == null:
		push_error("TEST: player не найден!")
	else:
		var anim = pl.find_child("Anim", true, false)
		if anim == null:
			push_error("TEST: у игрока нет AnimationPlayer!")
		else:
			var names: Array = []
			for lib_name: String in anim.get_animation_library_list():
				names.append_array(PackedStringArray(anim.get_animation_library(lib_name).get_animation_list()))
			print("PLAYER anims: ", names)
			if names.size() < 5:
				push_error("TEST: анимаций у игрока меньше 5!")
			var cur: String = anim.current_animation
			print("PLAYER playing: '", cur, "' pos=", pl.global_position)
			if cur == "":
				push_error("TEST: у игрока ничего не играет!")
		# Меч
		var wpn = pl.find_children("WeaponAttachment", "BoneAttachment3D", true, false)
		print("PLAYER weapon attachments: ", wpn.size())
		if wpn.size() < 1:
			push_error("TEST: демонический меч не прикреплён!")

	# Враги
	var enemies = main.get_tree().get_nodes_in_group("enemy")
	print("ENEMIES: ", enemies.size())
	var kinds := {}
	var with_anim := 0
	for e in enemies:
		kinds[e.kind] = kinds.get(e.kind, 0) + 1
		if e.find_child("Anim", true, false) != null:
			with_anim += 1
	print("ENEMY kinds: ", kinds, " с анимациями: ", with_anim)
	if with_anim < 5:
		push_error("TEST: у врагов мало анимаций!")

	# NPC
	var npcs = main.get_tree().get_nodes_in_group("npc")
	var npc_anim := 0
	for n in npcs:
		if n.find_child("Anim", true, false) != null:
			npc_anim += 1
	print("NPC: ", npcs.size(), " с анимациями: ", npc_anim)

	# Деревня: счёт домов-холдеров
	var village = root.find_children("*", "Node3D", true, false)
	var house_count := 0
	var mm_count := 0
	for v in root.find_children("*", "MultiMeshInstance3D", true, false):
		mm_count += 1
	print("MULTIMESH instances (оптимизация): ", mm_count)
	if mm_count < 20:
		push_error("TEST: MultiMesh мало — оптимизация сломана?")

	# Хутор: ведьмин огонь
	var witch = 0
	for l in root.find_children("*", "OmniLight3D", true, false):
		if l.light_color.g > 0.7 and l.light_color.r < 0.5:
			witch += 1
	print("WITCH FIRES (хутор): ", witch)

	# Туман/небо
	var we = root.find_children("*", "WorldEnvironment", true, false)
	if we.size() > 0:
		var env = we[0].environment
		print("SKY: volumetric=", env.volumetric_fog_enabled,
			" density=", env.volumetric_fog_density,
			" albedo=", env.volumetric_fog_albedo,
			" exposure=", env.tonemap_exposure)

	print("=== INSPECT DONE ===")
	quit(0)
