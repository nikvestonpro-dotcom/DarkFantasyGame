extends SceneTree
## Diagnostic (headless, no rendering): rebuild the same deterministic world
## and dump stats: floating props, nearest prop to a camera.

func _init() -> void:
	var root := Node3D.new()
	root.name = "DiagRoot"
	get_root().add_child.call_deferred(root)
	root.set_script(null)
	call_deferred("_run", root)

func _run(root: Node3D) -> void:
	var src: GDScript = load("res://scripts/world_builder.gd")
	var wb: Node3D = src.new()
	root.add_child(wb)
	var rng = wb.get("rng")
	rng.seed = 20261029
	var shots_m: Array = wb.call("_shot_list")
	var cams: Array = []
	for s in shots_m:
		cams.append(s["pos"])
	wb.set("shot_cams", cams)
	wb.call("_build_terrain")
	wb.call("_build_water")
	wb.call("_scatter_nature")
	wb.call("_build_mountains")

	var floating := 0
	var total := 0
	var worst := []
	for c in wb.get_children():
		if c is MultiMeshInstance3D:
			var mmi: MultiMeshInstance3D = c
			var mm: MultiMesh = mmi.multimesh
			var mesh_aabb: AABB = mm.mesh.get_aabb()
			for i in mm.instance_count:
				var xf: Transform3D = mm.get_instance_transform(i)
				total += 1
				var wa: AABB = mesh_aabb * xf
				var gh: float = wb.call("height_at", xf.origin.x, xf.origin.z)
				var gap: float = wa.position.y - gh
				if gap > 0.6:
					floating += 1
					if worst.size() < 10:
						worst.append({"pos": xf.origin, "gap": gap, "ground": gh})
	print("TOTAL instances: ", total, " floating(>0.6m): ", floating)
	for w in worst:
		print("  FLOAT: ", w)

	var cam8: Vector3 = cams[7]
	var best: Vector3 = Vector3.ZERO
	var best_d := 1e9
	for c in wb.get_children():
		if c is MultiMeshInstance3D:
			var mmi2: MultiMeshInstance3D = c
			var mm2: MultiMesh = mmi2.multimesh
			for i in mm2.instance_count:
				var xf2: Transform3D = mm2.get_instance_transform(i)
				if xf2.origin.length() > 250.0:
					continue
				var d: float = xf2.origin.distance_to(cam8)
				if d < best_d:
					best_d = d
					best = xf2.origin
	print("NEAREST PROP TO CAM8: ", best, " dist: ", best_d)
	quit(0)
