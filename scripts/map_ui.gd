extends CanvasLayer
## v7.0 КАРТА «ТЁМНЫЕ ЗЕМЛИ» (клавиша M): полноэкранный оверлей в стиле
## выцветшего пергамента. Показывает деревню, замок, пещеру, руины, озеро,
## лес и горное кольцо; живой маркер игрока следует за позицией в мире.
## M / ESC — закрыть, игра на паузе, пока карта открыта.

const MAP_SIZE := 520.0  # мировой размер карты (совпадает с террейном)

var _root: Control
var _bg: ColorRect
var _panel: PanelContainer
var _map_area: Control
var _map_draw: Control
var _player_marker: Control
var _hint: Label
var _title: Label
var _open := false
var _t := 0.0


func _ready() -> void:
        layer = 20
        process_mode = Node.PROCESS_MODE_ALWAYS
        _build()
        _root.visible = false


func _build() -> void:
        _root = Control.new()
        _root.set_anchors_preset(Control.PRESET_FULL_RECT)
        _root.mouse_filter = Control.MOUSE_FILTER_STOP
        add_child(_root)

        # Затемнение мира под картой
        _bg = ColorRect.new()
        _bg.color = Color(0.02, 0.02, 0.04, 0.62)
        _bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        _root.add_child(_bg)

        # Панель-«пергамент»
        _panel = PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.32, 0.26, 0.17, 0.96)
        sb.border_color = Color(0.16, 0.12, 0.07)
        sb.set_border_width_all(4)
        sb.set_corner_radius_all(6)
        sb.content_margin_left = 26
        sb.content_margin_right = 26
        sb.content_margin_top = 18
        sb.content_margin_bottom = 18
        _panel.add_theme_stylebox_override("panel", sb)
        _panel.anchor_left = 0.5
        _panel.anchor_right = 0.5
        _panel.anchor_top = 0.5
        _panel.anchor_bottom = 0.5
        _panel.offset_left = -340
        _panel.offset_right = 340
        _panel.offset_top = -330
        _panel.offset_bottom = 300
        _root.add_child(_panel)

        _title = Label.new()
        _title.text = "ТЁМНЫЕ ЗЕМЛИ"
        _title.add_theme_font_size_override("font_size", 30)
        _title.add_theme_color_override("font_color", Color(0.83, 0.68, 0.38))
        _title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
        _title.add_theme_constant_override("shadow_offset_y", 2)
        _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _panel.add_child(_title)

        # Область рисования карты (квадрат ~620x520)
        _map_area = Control.new()
        _map_area.custom_minimum_size = Vector2(620, 500)
        _panel.add_child(_map_area)

        _map_draw = MapDraw.new()
        _map_area.add_child(_map_draw)

        # Маркер игрока поверх карты
        _player_marker = Control.new()
        _player_marker.custom_minimum_size = Vector2(18, 18)
        _player_marker.set_anchors_preset(Control.PRESET_CENTER)
        _map_area.add_child(_player_marker)
        _player_marker.draw.connect(_draw_player_marker)

        _hint = Label.new()
        _hint.text = "M / ESC — закрыть карту    ·    ты — здесь"
        _hint.add_theme_font_size_override("font_size", 15)
        _hint.add_theme_color_override("font_color", Color(0.62, 0.52, 0.36, 0.9))
        _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _panel.add_child(_hint)


func _draw_player_marker() -> void:
        # Стрелка-«ты»: латунный треугольник
        var s := _player_marker.size
        var c := s * 0.5
        _player_marker.draw_colored_polygon(
                PackedVector2Array([c + Vector2(0, -9), c + Vector2(7, 7),
                        c + Vector2(0, 3), c + Vector2(-7, 7)]),
                Color(0.95, 0.78, 0.25))


## Отрисовка самой карты: граница мира, озеро, лес, локации, тропы.
class MapDraw:
        extends Control

        func _draw() -> void:
                var rect := Rect2(Vector2.ZERO, size)
                var c := size * 0.5
                var k: float = minf(size.x, size.y) / MAP_SIZE  # мир -> пиксели

                # Подписи-Label пересоздаются при каждом _draw (например, при
                # изменении размера окна) — сначала убираем старые
                for child in get_children():
                        child.queue_free()

                # Пергаментная подложка
                draw_rect(rect, Color(0.78, 0.68, 0.50, 0.32))
                draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)),
                        Color(0.70, 0.58, 0.38, 0.18), false, 2.0)

                # Горное кольцо (штриховка по краю мира)
                var ring_col := Color(0.42, 0.36, 0.26, 0.85)
                for i in 72:
                        var a := TAU * i / 72.0
                        var r0: float = MAP_SIZE * 0.42
                        var r1: float = MAP_SIZE * (0.465 + 0.02 * sin(i * 2.4))
                        draw_line(c + Vector2(cos(a), sin(a)) * r0 * k,
                                c + Vector2(cos(a), sin(a)) * r1 * k, ring_col, 3.0)

                # Озеро с лунной дорожкой
                var lake_c := c + Vector2(GameWorld.LAKE_CENTER.x,
                                GameWorld.LAKE_CENTER.y) * k
                draw_circle(lake_c, GameWorld.LAKE_RADIUS * k, Color(0.22, 0.26, 0.38, 0.9))
                draw_circle(lake_c, GameWorld.LAKE_RADIUS * k * 0.55,
                        Color(0.30, 0.36, 0.50, 0.9))
                _label(self, "ОЗЕРО", lake_c + Vector2(0, GameWorld.LAKE_RADIUS * k + 16),
                        15, Color(0.30, 0.34, 0.48))

                # Лесные массивы (пятна)
                var rng := RandomNumberGenerator.new()
                rng.seed = 4242
                for i in 46:
                        var a := rng.randf() * TAU
                        var r := rng.randf_range(30.0, 190.0)
                        var p := c + Vector2(cos(a), sin(a)) * r * k * 0.9
                        if p.distance_to(lake_c) < GameWorld.LAKE_RADIUS * k + 8:
                                continue
                        draw_circle(p, rng.randf_range(6.0, 16.0),
                                Color(0.16, 0.30, 0.16, 0.5))

                # Тропы (пунктир от деревни к локациям)
                for target in [GameWorld.LAKE_CENTER, GameWorld.HILL_CENTER,
                                GameWorld.CAVE_CENTER, GameWorld.CASTLE_CENTER]:
                        var tv: Vector2 = target
                        var a2 := c
                        var b2 := c + tv * k
                        var steps := int(a2.distance_to(b2) / 14.0)
                        for s in steps:
                                var t := float(s) / float(steps)
                                if s % 2 == 0:
                                        draw_circle(a2.lerp(b2, t), 2.2,
                                                        Color(0.45, 0.36, 0.22, 0.8))

                # Деревня (городок)
                var v := c
                draw_colored_polygon(PackedVector2Array([
                        v + Vector2(-11, -9), v + Vector2(11, -9), v + Vector2(11, 9),
                        v + Vector2(-11, 9)]), Color(0.78, 0.60, 0.30))
                draw_rect(Rect2(v - Vector2(11, 9), Vector2(22, 18)),
                        Color(0.35, 0.24, 0.10), false, 2.0)
                _label(self, "ГОРОДОК", v + Vector2(0, 30), 17, Color(0.83, 0.68, 0.38))

                # Замок
                var cast := c + Vector2(GameWorld.CASTLE_CENTER.x,
                                GameWorld.CASTLE_CENTER.y) * k
                draw_colored_polygon(PackedVector2Array([
                        cast + Vector2(-10, -10), cast + Vector2(10, -10),
                        cast + Vector2(10, 10), cast + Vector2(-10, 10)]),
                        Color(0.55, 0.55, 0.62))
                draw_colored_polygon(PackedVector2Array([
                        cast + Vector2(-4, -16), cast + Vector2(4, -16),
                        cast + Vector2(4, -6), cast + Vector2(-4, -6)]),
                        Color(0.55, 0.55, 0.62))
                _label(self, "ЗАМОК", cast + Vector2(0, 26), 16, Color(0.74, 0.74, 0.80))

                # Пещера
                var cav := c + Vector2(GameWorld.CAVE_CENTER.x,
                                GameWorld.CAVE_CENTER.y) * k
                draw_colored_polygon(PackedVector2Array([
                        cav + Vector2(-9, 6), cav + Vector2(0, -8), cav + Vector2(9, 6)]),
                        Color(0.20, 0.20, 0.24))
                _label(self, "ПЕЩЕРА", cav + Vector2(0, 24), 15, Color(0.62, 0.62, 0.68))

                # Руины на холме
                var rui := c + Vector2(GameWorld.HILL_CENTER.x,
                                GameWorld.HILL_CENTER.y) * k
                draw_circle(rui, 9, Color(0.48, 0.42, 0.32, 0.9))
                draw_line(rui + Vector2(-6, -6), rui + Vector2(6, 6),
                        Color(0.25, 0.20, 0.14), 3.0)
                draw_line(rui + Vector2(6, -6), rui + Vector2(-6, 6),
                        Color(0.25, 0.20, 0.14), 3.0)
                _label(self, "РУИНЫ", rui + Vector2(0, 24), 15, Color(0.66, 0.58, 0.44))

                # Кладбище у городка
                var gr := v + Vector2(16.5, 17.5) * k
                draw_line(gr + Vector2(0, -6), gr + Vector2(0, 6),
                        Color(0.30, 0.24, 0.16), 2.0)
                draw_line(gr + Vector2(-4, -2), gr + Vector2(4, -2),
                        Color(0.30, 0.24, 0.16), 2.0)
                _label(self, "кладбище", gr + Vector2(0, 18), 12,
                        Color(0.55, 0.48, 0.38))

                # v8.0: заброшенный хутор (полпути к замку)
                var ham := c + Vector2(GameWorld.HAMLET_CENTER.x,
                                GameWorld.HAMLET_CENTER.y) * k
                draw_colored_polygon(PackedVector2Array([
                        ham + Vector2(-7, -5), ham + Vector2(7, -5), ham + Vector2(7, 5),
                        ham + Vector2(-7, 5)]), Color(0.45, 0.40, 0.34, 0.9))
                draw_line(ham + Vector2(-5, -3), ham + Vector2(5, 3),
                        Color(0.20, 0.16, 0.12), 2.5)
                _label(self, "хутор", ham + Vector2(0, 20), 13, Color(0.62, 0.55, 0.45))

                # v8.0: открытое поле (штриховка травы)
                var fld := c + Vector2(GameWorld.FIELD_CENTER.x,
                                GameWorld.FIELD_CENTER.y) * k
                for i in 6:
                        draw_line(fld + Vector2(-30 + i * 12, -8),
                                        fld + Vector2(-24 + i * 12, 8),
                                        Color(0.30, 0.42, 0.24, 0.5), 2.0)
                _label(self, "поле", fld + Vector2(0, 24), 12, Color(0.45, 0.55, 0.38))

                # Компас
                var comp := Vector2(size.x - 34, 34)
                draw_circle(comp, 22, Color(0.35, 0.28, 0.16, 0.9))
                draw_line(comp, comp + Vector2(0, -16), Color(0.85, 0.68, 0.38), 3.0)
                _label(self, "С", comp + Vector2(0, -24), 14, Color(0.85, 0.68, 0.38))

        static func _label(parent: Control, txt: String, pos: Vector2,
                        size_px: int, col: Color) -> void:
                var l := Label.new()
                l.text = txt
                l.add_theme_font_size_override("font_size", size_px)
                l.add_theme_color_override("font_color", col)
                l.add_theme_color_override("font_shadow_color", Color(0.2, 0.15, 0.05, 0.9))
                l.add_theme_constant_override("shadow_offset_y", 1)
                l.position = pos - Vector2(txt.length() * size_px * 0.32, 8)
                parent.add_child(l)


# ---------- ВВОД И АНИМАЦИЯ ----------

func _unhandled_input(event: InputEvent) -> void:
        if event is InputEventKey and event.pressed and not event.echo:
                if event.keycode == KEY_M or event.physical_keycode == KEY_M:
                        toggle()
                        get_viewport().set_input_as_handled()
                elif event.keycode == KEY_ESCAPE and _open:
                        close()
                        get_viewport().set_input_as_handled()


func toggle() -> void:
        if _open:
                close()
        else:
                open()


func open() -> void:
        if _open:
                return
        _open = true
        _root.visible = true
        get_tree().paused = true
        var tw := create_tween().set_parallel(true)
        tw.tween_property(_bg, "color:a", 0.62, 0.25).from(0.0)
        tw.tween_property(_panel, "modulate:a", 1.0, 0.28).from(0.0)
        tw.tween_property(_panel, "scale", Vector2.ONE, 0.28).from(Vector2(0.92, 0.92))


func close() -> void:
        if not _open:
                return
        _open = false
        var tw := create_tween().set_parallel(true)
        tw.tween_property(_bg, "color:a", 0.0, 0.2)
        tw.tween_property(_panel, "modulate:a", 0.0, 0.2)
        tw.tween_property(_panel, "scale", Vector2(0.95, 0.95), 0.2)
        tw.chain().tween_callback(_hide_root)
        get_tree().paused = false


func _hide_root() -> void:
        _root.visible = false
        _panel.scale = Vector2.ONE


func _process(dt: float) -> void:
        _t += dt
        if not _open:
                return
        # Пульс маркера игрока
        _player_marker.queue_redraw()
        # Позиция игрока -> позиция маркера на карте
        var player := get_tree().get_first_node_in_group("player") as Node3D
        if player == null or _map_area.size == Vector2.ZERO:
                return
        var k: float = minf(_map_area.size.x, _map_area.size.y) / MAP_SIZE
        var local := Vector2(player.global_position.x, player.global_position.z)
        # «Север» (минус Z мира) сверху карты: screen_y = +world_z
        var px := _map_area.size * 0.5 + local * k
        _player_marker.position = px - _player_marker.size * 0.5
