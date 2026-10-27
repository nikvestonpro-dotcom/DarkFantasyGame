extends MeshInstance3D
## Небесный купол: всегда центрирован на камере активного viewport,
## чтобы игрок мог улетать куда угодно — небо не "кончится".


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_position = cam.global_position
