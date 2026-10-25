extends Node3D
## Главный сценарий: собирает мир из построителей, заспавнивает игрока,
## жителей и врагов, управляет мерцанием костра и возрождением.

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


const M_ROGUE := preload("res://assets/models/kay_Rogue.glb")
const M_MAGE := preload("res://assets/models/kay_Mage.glb")
const M_BARB := preload("res://assets/models/kay_Barbarian.glb")
const M_HOOD := preload("res://assets/models/kay_Rogue_Hooded.glb")

const HIDE_ROGUE := ["1H_Crossbow", "2H_Crossbow", "Throwable", "Knife_Offhand"]
const HIDE_MAGE := ["Spellbook", "Spellbook_open", "1H_Wand"]
const HIDE_BARB := ["1H_Axe_Offhand", "Barbarian_Round_Shield", "2H_Axe", "Mug"]


func _spawn_npcs() -> void:
	var roster = [
		["Марк-трактирщик", ["Вечер добрый, путник! Загляни в «Пьяный грифон» — сегодня глинтвейн и свежий хлеб.",
			"Слышала, в лесу развелись слизни. Тебе пригодится крепкий меч.",
			"Ночью над озером странный свет. Один туда не ходи."],
			M_ROGUE, HIDE_ROGUE, Color(1, 1, 1)],
		["Борис-кузнец", ["Мой меч тебя не подведёт. Бей первым — вот и вся наука.",
			"Куй железо, пока тепло, путник.",
			"Слизни боятся хорошего удара. И огня."],
			M_BARB, HIDE_BARB, Color(1, 1, 1)],
		["Старец Фёдор", ["В холме шепчут древние руины... Не буди то, что спит.",
			"Луна сегодня яркая. Дурной знак, ага.",
			"Мы тут сто лет живём. И драконов переживали."],
			M_MAGE, HIDE_MAGE, Color(1, 1, 1)],
		["Андрей", ["Ловлю светлячков для таверны! Красиво же...",
			"Ты новенький? Озеро вон там, за деревьями.",
			"Не буди слизней — они с утра злые."],
			M_HOOD, HIDE_ROGUE, Color(1, 1, 1)],
		["Гриша-сторож", ["Обхожу деревню каждый вечер. Пока тихо...",
			"Собираешься к руинам? Скажи Марку, куда пошёл.",
			"Меч держи крепче, путник. Ночь длинная."],
			M_ROGUE, HIDE_ROGUE, Color(1.06, 0.9, 0.8)],
		["Егерь Кузьмич", ["Борис опять весь день в кузне просидел...",
			"Ущипнул бы этого дракона за хвост!",
			"Заходи как-нибудь на чай, путник."],
			M_MAGE, HIDE_MAGE, Color(0.85, 0.95, 1.12)],
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
	var slime_spots := [
		Vector2(-45, -20), Vector2(-70, -100), Vector2(-55, 15), Vector2(-30, 40),
		Vector2(35, -35), Vector2(60, -60), Vector2(-20, -70), Vector2(95, -115),
		Vector2(115, -55), Vector2(-110, 25), Vector2(40, 45),
	]
	for i in slime_spots.size():
		var e = EnemyScript.new()
		e.setup("slime", 4242 + i * 13)
		var s: Vector2 = slime_spots[i]
		e.position = Vector3(s.x, GameWorld.terrain_height(s.x, s.y) + 0.6, s.y)
		add_child(e)
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
