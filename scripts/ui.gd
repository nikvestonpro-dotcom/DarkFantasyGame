extends CanvasLayer
## Интерфейс: здоровье, подсказки управления, диалоги жителей, счётчик слизней
## и экран смерти (появляется только при смерти).

var hp_fill: ColorRect
var hp_label: Label
var dialog_panel: PanelContainer
var dialog_name: Label
var dialog_text: Label
var kills_label: Label
var death_overlay: ColorRect
var death_label: Label
var death_hint: Label


func _ready() -> void:
	layer = 10
	_build_hud()


func _label(txt: String, size: int, col := Color(0.92, 0.9, 0.85)) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _build_hud() -> void:
	# Полоса здоровья
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.55)
	hp_bg.position = Vector2(16, 16)
	hp_bg.size = Vector2(224, 30)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.75, 0.15, 0.12)
	hp_fill.position = Vector2(4, 4)
	hp_fill.size = Vector2(216, 22)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(hp_fill)
	hp_label = _label("HP 10/10", 14, Color(1, 0.9, 0.85))
	hp_label.position = Vector2(80, 4)
	hp_bg.add_child(hp_label)

	# Подсказка управления сверху
	var hint := _label(
		"WASD — движение   ·   SHIFT — бег   ·   ПРОБЕЛ — прыжок   ·   ЛКМ — удар   ·   F — полёт (пробел/C — вверх/вниз)   ·   ESC — курсор",
		15, Color(0.9, 0.88, 0.8, 0.85))
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_top = 12
	hint.offset_bottom = 40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	# Счётчик слизней
	kills_label = _label("Слизни: 0", 18, Color(0.8, 1.0, 0.75))
	kills_label.anchor_left = 1.0
	kills_label.anchor_right = 1.0
	kills_label.offset_left = -240
	kills_label.offset_right = -16
	kills_label.offset_top = 14
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(kills_label)

	# Маркер версии сборки — видно, что запущена именно новая версия.
	# v4.0: если в углу НЕ v4.0 — запущена старая распаковка.
	var ver := _label("Тёмные земли · v5.0", 15, Color(0.95, 0.85, 0.45, 0.95))
	ver.anchor_left = 0.0
	ver.anchor_right = 0.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 16
	ver.offset_top = -30
	ver.offset_bottom = -10
	add_child(ver)

	# Панель диалога
	dialog_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.09, 0.82)
	sb.border_color = Color(0.55, 0.42, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	dialog_panel.add_theme_stylebox_override("panel", sb)
	dialog_panel.anchor_left = 0.5
	dialog_panel.anchor_right = 0.5
	dialog_panel.anchor_top = 1.0
	dialog_panel.anchor_bottom = 1.0
	dialog_panel.offset_left = -330
	dialog_panel.offset_right = 330
	dialog_panel.offset_top = -128
	dialog_panel.offset_bottom = -22
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.add_child(vb)
	dialog_name = _label("Имя", 17, Color(1.0, 0.78, 0.4))
	vb.add_child(dialog_name)
	dialog_text = _label("...", 16)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(620, 0)
	vb.add_child(dialog_text)
	dialog_panel.visible = false
	add_child(dialog_panel)

	# Экран смерти
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0, 0, 0, 0)
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_overlay)
	death_label = _label("Ты пал в бою...", 42, Color(0.9, 0.25, 0.18))
	death_label.anchor_left = 0.5
	death_label.anchor_right = 0.5
	death_label.anchor_top = 0.45
	death_label.anchor_bottom = 0.45
	death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# ВАЖНО: ColorRect с alpha=0 не скрывает дочерние элементы,
	# поэтому надпись скрываем явно — иначе «Ты пал в бою» висит на
	# экране постоянно, даже когда игрок жив.
	death_label.visible = false
	death_overlay.add_child(death_label)
	death_hint = _label("Ты вернёшься к костру через мгновение...", 20, Color(0.85, 0.75, 0.6))
	death_hint.anchor_left = 0.5
	death_hint.anchor_right = 0.5
	death_hint.anchor_top = 0.52
	death_hint.anchor_bottom = 0.52
	death_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	death_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_hint.visible = false
	death_overlay.add_child(death_hint)


func update(player, npcs: Array) -> void:
	if player == null:
		return
	hp_fill.size.x = 216.0 * clampf(player.hp / player.MAX_HP, 0.0, 1.0)
	hp_label.text = "HP %d/%d" % [int(player.hp), int(player.MAX_HP)]
	kills_label.text = "Слизни: %d" % player.kills
	var best = null
	var best_d := 3.6
	for n in npcs:
		if not is_instance_valid(n):
			continue
		var d: float = player.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best != null:
		dialog_panel.visible = true
		dialog_name.text = best.npc_name
		dialog_text.text = best.get_dialogue()
	else:
		dialog_panel.visible = false


func show_death(v: bool) -> void:
	var tw := create_tween()
	if v:
		death_label.modulate.a = 0.0
		death_hint.modulate.a = 0.0
		death_label.visible = true
		death_hint.visible = true
		tw.tween_property(death_overlay, "color:a", 0.75, 0.6)
		tw.parallel().tween_property(death_label, "modulate:a", 1.0, 0.6)
		tw.parallel().tween_property(death_hint, "modulate:a", 1.0, 0.8)
	else:
		tw.tween_property(death_overlay, "color:a", 0.0, 0.5)
		tw.parallel().tween_property(death_label, "modulate:a", 0.0, 0.4)
		tw.parallel().tween_property(death_hint, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_hide_death_labels)


func _hide_death_labels() -> void:
	if death_label != null:
		death_label.visible = false
	if death_hint != null:
		death_hint.visible = false
