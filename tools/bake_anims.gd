extends SceneTree
## Офлайн-печка анимаций охотника:
##  - срезы «Todo» -> res://assets/anims/hunter_slices.tres
##  - ретаргет KayKit (Idle, Walking_A) -> res://assets/anims/hunter_retarg.tres
## Запуск: godot --headless --path . --script res://tools/bake_anims.gd

const HunterAnim := preload("res://scripts/hunter_anim.gd")

func _init() -> void:
	call_deferred("_boot")

func _boot() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/anims")

	# --- 1) срезы Todo ---
	var hunter = load(HunterAnim.HUNTER_PATH).instantiate()
	root.add_child(hunter)
	await process_frame
	var slices := HunterAnim.slice_library(hunter)
	var err := ResourceSaver.save(slices, "res://assets/anims/hunter_slices.tres")
	print("slices: ", slices.get_animation_list(), " err=", err)
	hunter.queue_free()
	await process_frame

	# --- 2) ретаргет ---
	var donor = load(HunterAnim.DONOR_PATH).instantiate()
	root.add_child(donor)
	hunter = load(HunterAnim.HUNTER_PATH).instantiate()
	root.add_child(hunter)
	await process_frame
	var lib := AnimationLibrary.new()
	for clip in ["Walking_A", "Idle"]:
		var a: Animation = HunterAnim.retarget_clip(donor, hunter, clip)
		var name := "walk" if clip == "Walking_A" else "idle_calm"
		lib.add_animation(name, a)
		print("retarget ", clip, ": len=", a.length,
				" tracks=", a.get_track_count())
	err = ResourceSaver.save(lib, "res://assets/anims/hunter_retarg.tres")
	print("retarg err=", err)
	print("BAKE DONE")
	quit(0)
