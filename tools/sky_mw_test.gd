extends SceneTree
## Тест Млечного Пути: камера смотрит на север (30° вверх) — там полоса.

func _init() -> void:
        call_deferred("_boot")


func _boot() -> void:
        var main: Node = load("res://scripts/atmosphere.gd").new()
        root.add_child(main)
        for i in 5:
                await process_frame
        var cam := Camera3D.new()
        cam.fov = 60.0
        cam.far = 4000.0
        root.add_child(cam)
        cam.make_current()
        await process_frame
        cam.position = Vector3(0, 4.0, 0)
        cam.look_at(Vector3(0.0, 30.0, -50.0), Vector3.UP)
        await process_frame
        await process_frame
        root.get_viewport().get_texture().get_image().save_png("/home/z/my-project/diag/skyMW.png")
        print("MW saved")
        quit(0)
