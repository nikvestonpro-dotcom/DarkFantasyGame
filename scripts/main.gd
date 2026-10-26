extends Node3D
## Главный сценарий v8.0: собирает мир из построителей, спавнит игрока
## (паладин с демоническим мечом), жителей (Арисса + рыцари-стражи),
## павших рыцарей по долине; управляет мерцанием костра и факелов,
## возрождением и картой.

const TerrainBuilderScript := preload("res://scripts/terrain_builder.gd")
const TreeBuilderScript := preload("res://scripts/tree_builder.gd")
const VillageBuilderScript := preload("res://scripts/village_builder.gd")
const CaveBuilderScript := preload("res://scripts/cave_builder.gd")
const CastleBuilderScript := preload("res://scripts/castle_builder.gd")
const AtmosphereScript := preload("res://scripts/atmosphere.gd")
const PlayerScript := preload("res://scripts/player.gd")
const NpcScript := preload("res://scripts/npc.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const UiScript := preload("res://scripts/ui.gd")
const MapUiScript := preload("res://scripts/map_ui.gd")

## v8.0: Mixamo-модели (CC0) вместо KayKit
const M_ARISSA := preload("res://assets/models/characters/arissa.fbx")
const M_KNIGHT := preload("res://assets/models/characters/knight.fbx")

var player
var ui
var npcs: Array = []
var _respawn_t := -1.0
var _t := 0.0


func _ready() -> void:
        add_child(TerrainBuilderScript.new())
        add_child(TreeBuilderScript.new())
        add_child(VillageBuilderScript.new())
        add_child(CaveBuilderScript.new())
        add_child(CastleBuilderScript.new())
        add_child(AtmosphereScript.new())

        player = PlayerScript.new()
        player.position = GameWorld.PLAYER_SPAWN
        add_child(player)
        player.died.connect(_on_player_died)

        _spawn_npcs()
        _spawn_enemies()

        ui = UiScript.new()
        add_child(ui)

        # v7.0: карта на клавишу M
        var map_ui = MapUiScript.new()
        add_child(map_ui)


func _spawn_npcs() -> void:
        ## v8.0: Арисса — трактирщица и две её помощницы; рыцарь-стража и мужские
        ## жители — модель knight.fbx с разными тонировками одежды.
        var roster = [
                ["Арисса-трактирщица", ["Добро пожаловать в «Пьяного грифона», путник! Глинтвейн, эль, жаркое.",
                        "Стража говорит: в лесу павшие рыцари поднялись. С тех пор я на ночь двери запираю.",
                        "Слышишь вой? Не лиса это... Пей до дна и не ходи к озеру после полуночи."],
                        M_ARISSA, [], Color(1, 1, 1)],
                ["Марта-повариха", ["Тесто ставлю, а сама слушаю, как лес скрипит. Не к добру.",
                        "Хлеб ещё тёплый, возьми с дороги. Соль — от нечисти.",
                        "Арисса у стойки, я у печи. Так и живём."],
                        M_ARISSA, [], Color(0.8, 0.85, 1.0)],
                ["Сэр Готфрид-страж", ["Держи меч крепче, паладин. Павшие не знают жалости.",
                        "Я охраняю этот городок с тех пор, как замок пал. Мой долг — здесь.",
                        "На стенах старой цитадели — призрак. Я видел его собственными глазами."],
                        M_KNIGHT, [], Color(1.0, 0.95, 0.85)],
                ["Борис-кузнец", ["Дай мне руду — и я перекую твой клинок. Демона, что в нём живёт, не обижу.",
                        "Куй железо, пока луна стоит. Утром она будет другой стороной.",
                        "Павшим рыцарям огонь страшен. И хорошего удара по шлему они не любят."],
                        M_KNIGHT, [], Color(1.1, 0.85, 0.7)],
                ["Старец Фёдор", ["В холме шепчут древние руины... Не буди то, что спит.",
                        "Луна сегодня огромная и цвет крови не обещает. Смотри под ноги.",
                        "Мы тут сто лет живём. И драконов переживали, и хуже."],
                        M_KNIGHT, [], Color(0.85, 0.95, 1.1)],
                ["Андрей-светлячков", ["Ловлю светлячков для таверны! Красиво же...",
                        "Ты новенький? Озеро вон там, за деревьями. Только не ходи туда в тумане.",
                        "Не гуляй у пещеры — оттуда павшие выходят, с красными глазами."],
                        M_KNIGHT, [], Color(0.9, 1.0, 0.9)],
        ]
        var spots := [
                Vector2(6, 4), Vector2(-7, 2), Vector2(-2, -6),
                Vector2(9, -2), Vector2(-4, 9), Vector2(3, 12),
        ]
        for i in roster.size():
                var npc = NpcScript.new()
                var r = roster[i]
                npc.setup(r[0], r[1], 1000 + i * 77, r[2], r[3], r[4])
                var s: Vector2 = spots[i]
                npc.position = Vector3(s.x, GameWorld.terrain_height(s.x, s.y), s.y)
                add_child(npc)
                npcs.append(npc)


func _spawn_enemies() -> void:
        ## v8.0: по долине бродят павшие рыцари («fallen»), на дальних точках —
        ## ржавые тяжеловесы («rust»). Мини-босс «crimson» — в крипте замка
        ## (спавн в castle_builder.gd).
        var fallen_spots := [
                Vector2(-45, -20), Vector2(-70, -100), Vector2(-55, 15), Vector2(-30, 40),
                Vector2(35, -35), Vector2(60, -60), Vector2(-20, -70), Vector2(95, -115),
                Vector2(115, -55), Vector2(-110, 25), Vector2(40, 45),
        ]
        for i in fallen_spots.size():
                var e = EnemyScript.new()
                e.setup("fallen", 4242 + i * 13)
                var s: Vector2 = fallen_spots[i]
                e.position = Vector3(s.x, GameWorld.terrain_height(s.x, s.y) + 0.6, s.y)
                add_child(e)
        # Ржавые — ближе к пещере и руинам (охраняют подходы)
        var rust_spots := [Vector2(95, 90), Vector2(130, 120), Vector2(-125, 130)]
        for i in rust_spots.size():
                var e2 = EnemyScript.new()
                e2.setup("rust", 8800 + i * 31)
                var s2: Vector2 = rust_spots[i]
                e2.position = Vector3(s2.x, GameWorld.terrain_height(s2.x, s2.y) + 0.6, s2.y)
                add_child(e2)
        var dummy = EnemyScript.new()
        dummy.setup("dummy", 1)
        dummy.position = Vector3(7.5, GameWorld.VILLAGE_HEIGHT, 6.5)
        add_child(dummy)


func _on_player_died() -> void:
        ui.show_death(true)
        _respawn_t = 2.6


func _process(dt: float) -> void:
        _t += dt
        # Мерцание костра
        for l in get_tree().get_nodes_in_group("campfire_light"):
                l.light_energy = 3.3 + 0.5 * sin(_t * 13.7) + 0.25 * sin(_t * 29.3)
        # Тление факелов (у каждого свой ритм, чтобы не «моргали синхронно»)
        for l2 in get_tree().get_nodes_in_group("torch_light"):
                if not l2.has_meta("base_energy"):
                        l2.set_meta("base_energy", l2.light_energy)
                var ph := float(l2.get_instance_id() % 97) * 0.631
                l2.light_energy = l2.get_meta("base_energy") * \
                        (1.0 + 0.16 * sin(_t * 9.7 + ph) + 0.09 * sin(_t * 23.3 + ph * 2.7))
        var fi := 0
        for f in get_tree().get_nodes_in_group("campfire_flame"):
                fi += 1
                f.scale.y = 1.0 + 0.18 * sin(_t * 9.0 + fi * 2.1)
                f.rotation.y += dt * 1.5
        # Возрождение
        if _respawn_t > 0.0:
                _respawn_t -= dt
                if _respawn_t <= 0.0:
                        player.respawn()
                        ui.show_death(false)
        if ui != null and player != null:
                ui.update(player, npcs)
