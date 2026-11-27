class_name Hud
extends CanvasLayer
## Every screen, built in code: title, AI setup, online lobby, settings, placement bar,
## battle HUD, toasts, pause and game over. Calls back into main.gd.

var main: Node
var root: Control
var screen: Control
var banner: Label
var banner_box: PanelContainer
var toast_label: Label
var sub_toast: Label
var my_fleet: FleetPanel
var enemy_fleet: FleetPanel
var ability_bar: HBoxContainer
var ability_buttons := {}
var place_bar: Control
var place_list: VBoxContainer
var menu_button: Button
var status_label: Label
var room_edit: LineEdit
var name_edit: LineEdit
var vs_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_battle_layer()


# ------------------------------------------------------------------ helpers
func clear_screen() -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null


func _new_screen(dim := 0.0) -> Control:
	clear_screen()
	screen = Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_STOP if dim > 0.0 else Control.MOUSE_FILTER_IGNORE
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if dim > 0.0:
		var c := ColorRect.new()
		c.color = Color(0.0, 0.03, 0.06, dim)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.25)
	return screen


func _center_panel(parent: Control, width := 560) -> VBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


func _row(parent: Control, title: String, options: Array, current: String, cb: Callable) -> void:
	parent.add_child(UiKit.label(title, 20, UiKit.CYAN, true))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	for o in options:
		var key: String = o
		var b := UiKit.toggle(Game.t(key), key == current, func():
			cb.call(key)
		)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)


# ------------------------------------------------------------------ title
func show_title() -> void:
	set_battle_visible(false)
	var s := _new_screen()
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/title_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0.02, 0.05, 0.0))
	g.set_color(1, Color(0, 0.02, 0.05, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.25)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	s.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var logo := UiKit.label(Game.t("title"), 96, Color(1.0, 0.62, 0.2), true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_constant_override("outline_size", 22)
	logo.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.14))
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	logo.add_theme_constant_override("shadow_offset_y", 6)
	v.add_child(logo)
	var sub := UiKit.label(Game.t("subtitle").to_upper(), 34, UiKit.CYAN, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_constant_override("outline_size", 12)
	v.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	v.add_child(sp)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var bc := CenterContainer.new()
	bc.add_child(buttons)
	v.add_child(bc)
	var b1 := UiKit.button(Game.t("play_ai"), func(): show_ai_setup(), UiKit.ORANGE, 340)
	buttons.add_child(b1)
	buttons.add_child(UiKit.button(Game.t("online"), func(): show_online(), Color(0.1, 0.55, 0.7), 340))
	buttons.add_child(UiKit.button(Game.t("settings"), func(): show_settings(), Color(0.2, 0.3, 0.42), 340))
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		buttons.add_child(UiKit.button(Game.t("quit"), func(): get_tree().quit(), Color(0.2, 0.3, 0.42), 340))
	var st := UiKit.label(Game.t("stats_line") % [Game.stats["wins"], Game.stats["losses"]], 18, Color(0.85, 0.92, 1.0, 0.85))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var lang := UiKit.button("RU" if Game.lang == "en" else "EN", func():
		Game.lang = "ru" if Game.lang == "en" else "en"
		Game.save()
		main.on_language_changed()
		show_title(), Color(0.2, 0.3, 0.42), 80)
	s.add_child(lang)
	UiKit.place(lang, Control.PRESET_TOP_RIGHT, Vector2(20, 20))
	var ver := UiKit.label("v" + Game.version + "  •  © 2026 MaxSoft", 15, Color(1, 1, 1, 0.6))
	s.add_child(ver)
	UiKit.place(ver, Control.PRESET_BOTTOM_LEFT, Vector2(16, 12))
	logo.pivot_offset = Vector2(600, 50)
	logo.scale = Vector2(0.9, 0.9)
	logo.create_tween().tween_property(logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_ai_setup() -> void:
	var s := _new_screen(0.45)
	var v := _center_panel(s, 640)
	var h := UiKit.label(Game.t("play_ai"), 36, UiKit.ORANGE, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	_row(v, Game.t("opponent"), ["easy", "normal", "hard"], ["easy", "normal", "hard"][Game.difficulty], func(k):
		Game.difficulty = ["easy", "normal", "hard"].find(k)
		Game.save()
		show_ai_setup())
	_row(v, Game.t("mode"), ["classic", "arcade"], Game.mode, func(k):
		Game.mode = k
		Game.save()
		show_ai_setup())
	_row(v, Game.t("time"), ["day", "sunset", "night", "random"], Game.mood_choice, func(k):
		Game.mood_choice = k
		Game.save()
		show_ai_setup())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hb)
	hb.add_child(UiKit.button(Game.t("back"), func(): show_title(), Color(0.2, 0.3, 0.42), 180))
	hb.add_child(UiKit.button(Game.t("start"), func(): main.start_ai_game(), UiKit.ORANGE, 300))


func show_settings() -> void:
	var s := _new_screen(0.45)
	var v := _center_panel(s, 640)
	var h := UiKit.label(Game.t("settings"), 36, UiKit.ORANGE, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	v.add_child(UiKit.label(Game.t("language"), 20, UiKit.CYAN, true))
	var lh := HBoxContainer.new()
	v.add_child(lh)
	for l in [["en", "English"], ["ru", "Русский"]]:
		var code: String = l[0]
		var b := UiKit.toggle(l[1], Game.lang == code, func():
			Game.lang = code
			Game.save()
			main.on_language_changed()
			show_settings())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.add_child(b)
	for row in [["sound", "sfx_volume"], ["music", "music_volume"]]:
		v.add_child(UiKit.label(Game.t(row[0]), 20, UiKit.CYAN, true))
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 1
		sl.step = 0.05
		sl.value = Game.get(row[1])
		sl.custom_minimum_size = Vector2(0, 34)
		var prop: String = row[1]
		sl.value_changed.connect(func(val):
			Game.set(prop, val)
			Sfx.apply_volume()
			Game.save())
		v.add_child(sl)
	_row(v, Game.t("quality"), ["auto", "low", "high"], Game.quality, func(k):
		Game.quality = k
		Game.save()
		main.on_quality_changed()
		show_settings())
	var b := UiKit.button(Game.t("back"), func():
		if main.state == main.State.TITLE:
			show_title()
		else:
			show_pause(), Color(0.2, 0.3, 0.42), 220)
	var c := CenterContainer.new()
	c.add_child(b)
	v.add_child(c)


# ------------------------------------------------------------------ online
func show_online() -> void:
	var s := _new_screen(0.45)
	var v := _center_panel(s, 640)
	var h := UiKit.label(Game.t("online"), 36, UiKit.ORANGE, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	v.add_child(UiKit.label(Game.t("your_name"), 20, UiKit.CYAN, true))
	name_edit = LineEdit.new()
	name_edit.max_length = 16
	name_edit.text = Game.player_name if Game.player_name != "" else ("Captain %d" % randi_range(100, 999))
	v.add_child(name_edit)
	_row(v, Game.t("mode"), ["classic", "arcade"], Game.mode, func(k):
		Game.mode = k
		Game.player_name = name_edit.text
		Game.save()
		show_online())
	v.add_child(UiKit.button(Game.t("quick_match"), func(): _online_go("quick"), UiKit.ORANGE, 400))
	v.add_child(UiKit.button(Game.t("create_room"), func(): _online_go("create"), Color(0.1, 0.55, 0.7), 400))
	var jh := HBoxContainer.new()
	jh.add_theme_constant_override("separation", 10)
	v.add_child(jh)
	room_edit = LineEdit.new()
	room_edit.placeholder_text = Game.t("room_code")
	room_edit.max_length = 4
	room_edit.custom_minimum_size = Vector2(170, 0)
	jh.add_child(room_edit)
	var jb := UiKit.button(Game.t("join_room"), func(): _online_go("join"), Color(0.1, 0.55, 0.7), 220)
	jb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jh.add_child(jb)
	status_label = UiKit.label("", 20, Color(1, 0.85, 0.5))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status_label)
	var c := CenterContainer.new()
	c.add_child(UiKit.button(Game.t("back"), func():
		main.online_cancel()
		show_title(), Color(0.2, 0.3, 0.42), 220))
	v.add_child(c)


func _online_go(kind: String) -> void:
	Game.player_name = name_edit.text.strip_edges()
	if Game.player_name == "":
		Game.player_name = "Captain %d" % randi_range(100, 999)
	Game.save()
	match kind:
		"quick":
			main.online_quick()
		"create":
			main.online_create()
		"join":
			main.online_join(room_edit.text.strip_edges().to_upper())


func set_status(text: String) -> void:
	if status_label and is_instance_valid(status_label):
		status_label.text = text


# ------------------------------------------------------------------ battle layer
func _build_battle_layer() -> void:
	banner_box = PanelContainer.new()
	banner_box.add_theme_stylebox_override("panel", UiKit.panel_box(0.78))
	banner = UiKit.label("", 26, UiKit.TEXT, true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner)
	root.add_child(banner_box)
	UiKit.place(banner_box, Control.PRESET_CENTER_TOP, Vector2(0, 14))
	vs_label = UiKit.label("", 17, Color(0.85, 0.92, 1.0, 0.85))
	root.add_child(vs_label)
	UiKit.place(vs_label, Control.PRESET_CENTER_TOP, Vector2(0, 86))
	toast_label = UiKit.label("", 72, Color(1, 1, 1), true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_constant_override("outline_size", 18)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast_label.offset_top -= 215
	toast_label.offset_bottom -= 215
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub_toast = UiKit.label("", 30, Color(1, 0.9, 0.7), true)
	sub_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_toast.add_theme_constant_override("outline_size", 10)
	sub_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sub_toast)
	sub_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sub_toast.offset_top -= 150
	sub_toast.offset_bottom -= 150
	sub_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	my_fleet = FleetPanel.new()
	my_fleet.accent = UiKit.CYAN
	root.add_child(my_fleet)
	UiKit.place(my_fleet, Control.PRESET_TOP_LEFT, Vector2(14, 14))
	enemy_fleet = FleetPanel.new()
	enemy_fleet.enemy = true
	enemy_fleet.accent = Color(1, 0.55, 0.4)
	root.add_child(enemy_fleet)
	UiKit.place(enemy_fleet, Control.PRESET_TOP_RIGHT, Vector2(14, 84))
	ability_bar = HBoxContainer.new()
	ability_bar.add_theme_constant_override("separation", 12)
	root.add_child(ability_bar)
	for a in ["radar", "torpedo", "airstrike"]:
		var key: String = a
		var b := UiKit.button(Game.t(a), func(): main.select_ability(key), Color(0.12, 0.45, 0.6), 170)
		b.toggle_mode = false
		ability_bar.add_child(b)
		ability_buttons[a] = b
	UiKit.place(ability_bar, Control.PRESET_CENTER_BOTTOM, Vector2(0, 16))
	menu_button = UiKit.button("II", func(): main.on_pause(), Color(0.2, 0.3, 0.42), 64)
	menu_button.custom_minimum_size = Vector2(64, 58)
	root.add_child(menu_button)
	UiKit.place(menu_button, Control.PRESET_TOP_RIGHT, Vector2(14, 14))
	place_bar = VBoxContainer.new()
	place_bar.add_theme_constant_override("separation", 10)
	root.add_child(place_bar)
	var pb := HBoxContainer.new()
	pb.add_theme_constant_override("separation", 10)
	place_bar.add_child(pb)
	pb.add_child(UiKit.button(Game.t("rotate"), func(): main.on_rotate(), Color(0.12, 0.45, 0.6), 160))
	pb.add_child(UiKit.button(Game.t("random_place"), func(): main.on_auto_place(), Color(0.12, 0.45, 0.6), 160))
	pb.add_child(UiKit.button(Game.t("clear"), func(): main.on_clear_place(), Color(0.2, 0.3, 0.42), 160))
	var ready := UiKit.button(Game.t("ready"), func(): main.on_ready(), UiKit.ORANGE, 220)
	ready.name = "ReadyButton"
	pb.add_child(ready)
	UiKit.place(place_bar, Control.PRESET_CENTER_BOTTOM, Vector2(0, 16))
	set_battle_visible(false)


func relabel_battle_layer() -> void:
	for c in root.get_children():
		if c in [banner_box, vs_label, toast_label, sub_toast, my_fleet, enemy_fleet, ability_bar, menu_button, place_bar]:
			c.queue_free()
	ability_buttons.clear()
	_build_battle_layer()


func set_battle_visible(on: bool) -> void:
	for c in [banner_box, vs_label, my_fleet, enemy_fleet, ability_bar, menu_button, place_bar]:
		c.visible = on


func show_placement() -> void:
	clear_screen()
	set_battle_visible(true)
	enemy_fleet.visible = false
	ability_bar.visible = false
	place_bar.visible = true
	set_banner(Game.t("place_fleet"))
	vs_label.text = Game.t("place_hint")


func show_battle(arcade: bool) -> void:
	clear_screen()
	set_battle_visible(true)
	place_bar.visible = false
	ability_bar.visible = arcade


func set_banner(text: String, color := UiKit.TEXT) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner_box.pivot_offset = banner_box.size / 2
	banner_box.scale = Vector2(1.08, 1.08)
	banner_box.create_tween().tween_property(banner_box, "scale", Vector2.ONE, 0.25)


func set_vs(text: String) -> void:
	vs_label.text = text


func set_abilities(charges: Dictionary, selected: String, enabled: bool) -> void:
	for a in ability_buttons:
		var b: Button = ability_buttons[a]
		var n: int = charges.get(a, 0)
		b.text = Game.t(a) + ("  ×%d" % n if n > 0 else "  —")
		b.disabled = n <= 0 or not enabled
		b.modulate = Color(1.3, 1.1, 0.7) if a == selected else Color.WHITE


func set_ready_enabled(on: bool) -> void:
	var b := place_bar.find_child("ReadyButton", true, false) as Button
	if b:
		b.disabled = not on


func toast(text: String, color := Color.WHITE, sub := "", time := 1.3) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.pivot_offset = Vector2(toast_label.size.x / 2, toast_label.size.y / 2)
	sub_toast.text = sub
	var tw := toast_label.create_tween()
	toast_label.modulate.a = 1.0
	sub_toast.modulate.a = 1.0
	toast_label.scale = Vector2(1.6, 1.6)
	tw.tween_property(toast_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(time)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(sub_toast, "modulate:a", 0.0, 0.4)


func show_pause() -> void:
	var s := _new_screen(0.55)
	var v := _center_panel(s, 460)
	var h := UiKit.label(Game.t("title"), 34, UiKit.ORANGE, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	v.add_child(UiKit.button(Game.t("resume"), func(): main.on_resume(), UiKit.ORANGE, 400))
	v.add_child(UiKit.button(Game.t("settings"), func(): show_settings(), Color(0.2, 0.3, 0.42), 400))
	v.add_child(UiKit.button(Game.t("surrender"), func(): main.on_surrender(), Color(0.6, 0.15, 0.12), 400))
	v.add_child(UiKit.button(Game.t("menu"), func(): main.to_title(), Color(0.2, 0.3, 0.42), 400))


func show_game_over(won: bool, stats: Dictionary, online: bool, reason := "") -> void:
	var s := _new_screen(0.35)
	var v := _center_panel(s, 560)
	var h := UiKit.label(Game.t("victory") if won else Game.t("defeat"), 72, Color(1, 0.75, 0.25) if won else UiKit.RED, true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var sub := UiKit.label(reason if reason != "" else (Game.t("victory_sub") if won else Game.t("defeat_sub")), 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	v.add_child(gc)
	for row in [[Game.t("shots"), str(stats["shots"])], [Game.t("accuracy"), "%d%%" % stats["accuracy"]], [Game.t("time_s"), stats["time"]]]:
		grid.add_child(UiKit.label(row[0], 22, UiKit.CYAN))
		grid.add_child(UiKit.label(row[1], 22))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	hb.add_child(UiKit.button(Game.t("menu"), func(): main.to_title(), Color(0.2, 0.3, 0.42), 220))
	hb.add_child(UiKit.button(Game.t("rematch") if online else Game.t("play_again"), func(): main.on_play_again(), UiKit.ORANGE, 240))
	h.pivot_offset = Vector2(260, 40)
	h.scale = Vector2(0.4, 0.4)
	h.create_tween().tween_property(h, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Waiting overlay used online (opponent deploying / rematch).
func show_wait(text: String) -> void:
	var s := _new_screen(0.0)
	var l := UiKit.label(text, 26, Color(1, 0.9, 0.6), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(l)
	UiKit.place(l, Control.PRESET_CENTER_BOTTOM, Vector2(0, 100))
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
