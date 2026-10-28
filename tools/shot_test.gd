extends SceneTree
## Быстрый тест рендера: запускает главную сцену, ждёт, снимает кадр.

func _init() -> void:
        call_deferred("_boot")


func _boot() -> void:
        var ps: PackedScene = load("res://scenes/main.tscn")
        var main := ps.instantiate()
        root.add_child(main)
        for i in 20:
                await process_frame
        var img: Image = root.get_viewport().get_texture().get_image()
        img.save_png("/home/z/my-project/diag/v5_test.png")
        print("shot saved, size ", img.get_size())
        quit(0)
