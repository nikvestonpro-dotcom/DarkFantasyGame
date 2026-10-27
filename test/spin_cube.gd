extends MeshInstance3D
## Test scene: slowly rotates the cube to verify the low-res PS1 render (480x270 -> 1280x720).

func _process(delta: float) -> void:
	rotate_y(delta * 0.7)
	rotate_x(delta * 0.25)
