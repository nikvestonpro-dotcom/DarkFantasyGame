extends SceneTree
## Изолированный тест неба v2: что светит небо — glow, объёмный туман,
## ambient? C — без тумана, D — без glow и без тумана.

func _init() -> void:
        call_deferred("_boot")


func _boot() -> void:
        var main: Node = load("res://scripts/atmosphere.gd").new()
        root.add_child(main)
        for i in 5:
                await process_frame

        var cam := Camera3D.new()
        cam.fov = 72.0
        cam.far = 4000.0
        root.add_child(cam)
        cam.make_current()
        await process_frame

        # Взгляд СТРОГО в зенит-северо-восток (вдали от луны и горизонта):
        # ожидаем почти чёрное небо
        cam.position = Vector3(0, 4.0, 0)
        cam.look_at(Vector3(20.0, 60.0, 20.0), Vector3.UP)
        await process_frame
        root.get_viewport().get_texture().get_image().save_png("/home/z/my-project/diag/skyC_fog.png")

        var we: WorldEnvironment = root.find_children("*", "WorldEnvironment", true, false)[0]
        we.environment.volumetric_fog_enabled = false
        await process_frame
        await process_frame
        root.get_viewport().get_texture().get_image().save_png("/home/z/my-project/diag/skyD_nofog.png")

        we.environment.glow_enabled = false
        await process_frame
        await process_frame
        root.get_viewport().get_texture().get_image().save_png("/home/z/my-project/diag/skyE_bare.png")
        print("CDE saved")
        quit(0)
