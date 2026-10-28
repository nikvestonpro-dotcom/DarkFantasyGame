extends SceneTree
## Минимальный тест рендера: куб на цветном фоне.

func _init() -> void:
        call_deferred("_boot")


func _boot() -> void:
        print("boot begin")
        var env := Environment.new()
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.1, 0.2, 0.4)
        var we := WorldEnvironment.new()
        we.environment = env
        root.add_child(we)
        var cam := Camera3D.new()
        cam.position = Vector3(0, 0, 3)
        root.add_child(cam)
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(1, 1, 1)
        mi.mesh = bm
        root.add_child(mi)
        var d := DirectionalLight3D.new()
        d.rotation_degrees = Vector3(-45, 30, 0)
        root.add_child(d)
        for i in 5:
                await process_frame
                print("frame ", i)
        var img: Image = root.get_viewport().get_texture().get_image()
        img.save_png("/home/z/my-project/diag/min_test.png")
        print("saved, ", img.get_size())
        quit(0)
