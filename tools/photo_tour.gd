extends SceneTree
## Фото-тур v9.0: строим мир один раз, снимаем кадры с разных точек.
## Возобновляемый: существующие файлы пропускаются (-chunked запуск).
## Запуск: run_xvfb.sh :97 godot --path . --resolution 1280x720 \
##         --script res://tools/photo_tour.gd

const OUT := "/home/z/my-project/diag/tour"

func _init() -> void:
        call_deferred("_boot")


func _boot() -> void:
        DirAccess.make_dir_recursive_absolute(OUT)
        var ps: PackedScene = load("res://scenes/main.tscn")
        var main := ps.instantiate()
        root.add_child(main)

        # Своя камера поверх игрока
        var cam := Camera3D.new()
        cam.fov = 72.0
        cam.far = 4000.0
        cam.near = 0.1
        root.add_child(cam)
        cam.make_current()

        # Прогрев: строим мир, частицы preprocess
        for i in 12:
                await process_frame
        print("world warmed up")

        # [имя, позиция, цель, fov]
        var shots := [
                ["01_spawn_street", Vector3(0, 4.2, 24), Vector3(0, 5.5, -20), 72.0],
                ["02_moon_closeup", Vector3(0, 4.0, 24), Vector3(-55.7, 51.6, -44.8), 26.0],
                ["03_square", Vector3(1.5, 4.0, 12), Vector3(-3.5, 3.0, -1.0), 72.0],
                ["04_tavern", Vector3(0, 4.0, 2), Vector3(0, 4.5, -14.5), 72.0],
                ["05_village_top", Vector3(10, 95, 55), Vector3(0, 3, -4), 62.0],
                ["06_forest", Vector3(-30, 5.0, -14), Vector3(-95, 9.0, -32), 72.0],
                ["07_west_row", Vector3(-6, 4.0, -2), Vector3(-14, 4.5, -6), 72.0],
        ]

        for s in shots:
                var path := "%s/%s.png" % [OUT, s[0]]
                if FileAccess.file_exists(path):
                        print("skip existing ", path)
                        continue
                cam.fov = s[3]
                cam.position = s[1]
                cam.look_at(s[2], Vector3.UP)
                for k in 2:
                        await process_frame
                var img: Image = root.get_viewport().get_texture().get_image()
                img.save_png(path)
                print("saved ", path)
        print("TOUR DONE")
        quit(0)
