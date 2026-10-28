extends SceneTree
## Проверка компиляции всех скриптов проекта (без запуска сцены).

func _init() -> void:
        var scripts := [
                "res://scripts/atmosphere.gd",
                "res://scripts/game_world.gd",
                "res://scripts/village_builder.gd",
                "res://scripts/tree_builder.gd",
                "res://scripts/terrain_builder.gd",
                "res://scripts/castle_builder.gd",
                "res://scripts/main.gd",
                "res://scripts/ui.gd",
                "res://scripts/player.gd",
        ]
        var ok := true
        for p in scripts:
                var s: GDScript = load(p)
                if s == null:
                        printerr("FAIL: ", p)
                        ok = false
                else:
                        # reload для принудительной компиляции
                        var err := s.reload()
                        if err != OK:
                                printerr("COMPILE FAIL: ", p, " err=", err)
                                ok = false
                        else:
                                print("OK: ", p)
        if ok:
                print("ALL SCRIPTS OK")
        else:
                print("ERRORS FOUND")
        quit(0 if ok else 1)
