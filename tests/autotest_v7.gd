extends SceneTree
## Автотест v7.0 (headless): сборка мира, GLB-модели, карта, враги, факелы.
## Запуск: godot --headless --script res://tests/autotest_v7.gd

var frames := 0
var failed := false


func _initialize() -> void:
        var ps: PackedScene = load("res://scenes/main.tscn")
        root.add_child(ps.instantiate())


func _process(_delta: float) -> bool:
        frames += 1
        if frames == 150:
                _run_checks()
                quit(1 if failed else 0)
                return true
        return false


func _check(name: String, cond: bool) -> void:
        print(("  [OK] " if cond else "  [FAIL] ") + name)
        if not cond:
                failed = true


func _run_checks() -> void:
        print("=== АВТОТЕСТ ТЁМНЫЕ ЗЕМЛИ v7.0 ===")

        # 1. Мир построился (root — Window, ищем рекурсивно)
        var terrain := _find(root, "Terrain")
        _check("террейн построен", terrain != null)
        var floor_node := _find(root, "WorldFloor")
        _check("дно мира на месте", floor_node != null)

        # 2. Игрок и враги (группы — методы SceneTree, т.е. self)
        var player: Node = self.get_first_node_in_group("player")
        _check("игрок заспавнен", player != null)
        var enemies: Array = self.get_nodes_in_group("enemy")
        _check("врагов >= 12 (зомби + стражи + боссы)", enemies.size() >= 12)
        var facing_ok := true
        for e in enemies:
                if e.get("model_root") != null and absf(e.model_root.rotation.y) > 0.01:
                        facing_ok = false
        _check("фикс «спиной вперёд»: модели не развёрнуты на PI", facing_ok)

        # 3. GLB-деревья нового леса
        var gl_trees := 0
        var gl_instances := 0
        for n in _collect(root, "MultiMeshInstance3D"):
                if String(n.name).begins_with("GLTree_"):
                        gl_trees += 1
                        gl_instances += n.multimesh.visible_instance_count
        _check("GLB-деревья рассажены (>= 4 групп)", gl_trees >= 4)
        _check("GLB-деревьев >= 150 экземпляров", gl_instances >= 150)

        # 4. Городок: GLB-дома + кладбище + мостовая
        var cobble := _find(root, "CobbleStreet")
        _check("мощёная улица построена", cobble != null)
        # Таверна GLB: ищем крупный MeshInstance3D в зоне таверны (0, -13.5)
        var tavern_meshes := 0
        for n in _collect(root, "MeshInstance3D"):
                var g: Vector3 = n.global_position
                if absf(g.x) < 9.0 and absf(g.z + 13.5) < 8.0 and g.y > 5.0 and g.y < 12.0:
                        tavern_meshes += 1
        _check("таверна GLB стоит (меши в зоне)", tavern_meshes >= 3)

        # 5. Факелы и их мерцание
        var torches: Array = self.get_nodes_in_group("torch_light")
        _check("факелов/огней >= 10 (группа torch_light)", torches.size() >= 10)

        # 6. Карта на M
        var map_ui := _find(root, "", "map_ui.gd")
        _check("интерфейс карты создан", map_ui != null)
        if map_ui != null:
                map_ui.open()
                _check("карта открывается (пауза)", paused)
                _check("оверлей карты видим", map_ui._root.visible)
                map_ui.close()
                _check("карта закрывается (пауза снята)", not paused)

        # 7. Замок
        var castle: Node = self.get_first_node_in_group("castle")
        _check("замок построен (группа castle)", castle != null)

        # 8. NPC
        var npcs: Array = self.get_nodes_in_group("npc")
        _check("жителей >= 6", npcs.size() >= 6)

        # 9. Атмосфера (WorldEnvironment — тип узла, ищем по классу)
        var wes: Array = root.find_children("*", "WorldEnvironment", true, false)
        var we: Node = wes[0] if wes.size() > 0 else null
        _check("WorldEnvironment существует", we != null)
        if we != null:
                _check("SDFGI включён", we.environment.sdfgi_enabled)
                _check("объёмный туман включён", we.environment.volumetric_fog_enabled)

        print("=== ИТОГ: " + ("FAIL" if failed else "ВСЁ ПРОШЛО") + " ===")


func _find(from: Node, by_name: String, script_hint := "") -> Node:
        for n in from.find_children("*", "Node", true, false):
                if by_name != "" and n.name == by_name:
                        return n
                if script_hint != "" and n.get_script() != null \
                                and String(n.get_script().resource_path).contains(script_hint):
                        return n
        return null


func _collect(from: Node, classname: String) -> Array:
        var out: Array = []
        for n in from.find_children("*", classname, true, false):
                out.append(n)
        return out
