extends SceneTree
## Тест: куда рендерится луна панорамы при известных направлениях камеры.
## Запуск: godot --headless --script res://tests/test_sky_mapping.gd

const HDR_PATH := "res://assets/hdr/rogland_moonlit_night_4k.hdr"

var DIRS := [
	Vector3(-0.696, 0.498, 0.508),   # заявленный MOON_DIR
	Vector3(0.586, 0.471, 0.659),    # atan2(x,z) вариант
	Vector3(-0.586, 0.471, 0.659),   # atan2(-x,z) вариант
	Vector3(0.659, 0.471, 0.586),    # atan2(z,x) вариант
]


func _init() -> void:
	var env_res := Environment.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load(HDR_PATH)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env_res.background_mode = Environment.BG_SKY
	env_res.sky = sky
	env_res.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_res.tonemap_exposure = 0.008

	var vp := SubViewport.new()
	vp.size = Vector2i(400, 400)
	vp.own_world = true
	vp.world = World3D.new()
	# окружение для сабвьюпорта
	var we2 := WorldEnvironment.new()
	we2.environment = env_res
	vp.add_child(we2)
	root.add_child(vp)

	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)

	for i in DIRS.size():
		var d: Vector3 = DIRS[i].normalized()
		cam.position = Vector3.ZERO
		cam.look_at(d, Vector3.UP)
		await process_frame
		await process_frame
		var img := vp.get_texture().get_image()
		img.save_png("/home/z/my-project/diag/skymap_%d.png" % i)
		print("saved skymap_%d dir=(%.3f, %.3f, %.3f)" % [i, d.x, d.y, d.z])
	quit(0)
