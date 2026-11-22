extends Node
## --autotest: plays a whole match against the AI with a bot admiral on our side and writes
## screenshots + a log to renders/game/. Flags: --mood=day|sunset|night, --arcade, --quick (fewer shots)
## --shots-only (title, placement and two turns, then quit).

var main: Node
var bot: Admiral
var log_lines: PackedStringArray = []
var out_dir := ""
var turns := 0
var t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	out_dir = ProjectSettings.globalize_path("res://renders/game")
	DirAccess.make_dir_recursive_absolute(out_dir)
	t0 = Time.get_ticks_msec()
	_log("start renderer=%s adapter=%s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	_run()


func _log(s: String) -> void:
	var line := "AUTOTEST %6.1fs %s" % [(Time.get_ticks_msec() - t0) / 1000.0, s]
	print(line)
	log_lines.append(line)


func shot(name: String) -> void:
	if Game.flag("nohud") and main and main.hud:
		main.hud.visible = false  # clean captures for store/site images
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var tag := str(Game.flags.get("mood", "x")) + ("_net%d" % Net.my_id if Game.flag("online") else "")
	img.save_png(out_dir.path_join("%s_%s.png" % [tag, name]))
	_log("shot " + name)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	await _wait(2.0)
	await shot("01_title")
	main.hud.show_ai_setup()
	await _wait(0.6)
	await shot("02_setup")
	Game.difficulty = 2
	Game.mode = "arcade" if Game.flag("arcade") or not Game.flag("classic") else "classic"
	if Game.flag("online"):
		Game.player_name = "Bot%d" % (randi() % 1000)
		main.hud.show_online()
		main.online_quick()
		_log("online: searching")
		while main.state != main.State.PLACEMENT:
			await _wait(0.5)
			if Time.get_ticks_msec() - t0 > 60000:
				_log("online: no opponent found")
				_finish()
				return
		_log("online: matched with %s (id %d, me %d)" % [main.opponent_name, main.opponent_id, Net.my_id])
	else:
		main.start_ai_game()
	if Game.flags.has("mood"):
		main._set_mood(str(Game.flags["mood"]))
	await _wait(2.0)
	# place two ships by hand to exercise the click path, then auto
	main.hover_cell = Vector2i(2, 2)
	main._update_ghost()
	await _wait(0.4)
	await shot("03_placement_ghost")
	main._try_place(Vector2i(2, 2))
	main._try_place(Vector2i(7, 6))
	await _wait(0.6)
	main.on_auto_place()
	await _wait(1.2)
	await shot("04_placement_done")
	_log("fleet placed: %d ships" % main.my_board.ships.size())
	bot = Admiral.new(2, main.arcade)
	main.on_ready()


func my_turn() -> void:
	turns += 1
	if Game.flag("shots-only") and turns > 3:
		_finish()
		return
	await _wait(1.5)
	if main.state != main.State.BATTLE or not main.my_turn:
		return
	var d := bot.decide(main.enemy_track)
	if d["kind"] != "shell":
		main.select_ability(d["kind"])
		main.hover_cell = Vector2i(-1, -1)
		main._hover(main.cam.unproject_position(main.arena.enemy_grid.cell_world(d["cell"])))
		await _wait(0.3)
		await shot("ability_%s" % d["kind"])
	else:
		main.hover_cell = Vector2i(-1, -1)
		main._hover(main.cam.unproject_position(main.arena.enemy_grid.cell_world(d["cell"])))
	_log("turn %d: %s at %s" % [turns, d["kind"], d["cell"]])
	if turns <= 2:
		await shot("05_attack_aim_%d" % turns)
	main.fire_at(d["cell"])
	if turns == 1:
		await _wait(0.9)
		await shot("06_shell_flight")
	if turns == 3:
		await _wait(2.2)
		await shot("07_impact")
	if turns % 6 == 0 and turns < 30:
		await _wait(2.5)
		await shot("08_battle_%d" % turns)


func game_over(won: bool) -> void:
	_log("game over: %s after %d turns, shots %d hits %d" % ["WON" if won else "LOST", turns, main.shots, main.hits])
	await _wait(3.5)
	await shot("09_game_over")
	_finish()


func _finish() -> void:
	_log("done")
	var f := FileAccess.open(out_dir.path_join("autotest.log"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
	get_tree().quit()


func _process(_delta: float) -> void:
	# enemy-turn screenshots (defence camera) a couple of times
	if main and main.state == main.State.BATTLE and not main.my_turn and not has_meta("def_shot"):
		set_meta("def_shot", true)
		get_tree().create_timer(3.2).timeout.connect(func(): shot("10_defense"))
