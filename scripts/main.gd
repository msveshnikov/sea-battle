extends Node3D
## Steel Tide: game flow. Title → (AI setup | online lobby) → fleet placement → battle → game over.
## Both opponents (AI or remote player) go through the same "action → outcome → animation" path:
##   action  {kind: shell|torpedo|airstrike|radar, cell: [x, y]}
##   outcome {kind, cell, results: [{c, r, ship?, kind?}], radar?: n, lost?: bool}
## The defender always resolves an action on its own board, so online nobody sees the other fleet.

enum State { TITLE, PLACEMENT, WAIT_OPPONENT, BATTLE, OVER }

var state := State.TITLE
var arena: Arena
var cam: CameraRig
var hud: Hud

var my_board: Board         # our fleet + shots received
var enemy_track: Board      # what we know about the enemy's waters
var enemy_board: Board      # AI games only: the AI's real fleet
var ai: Admiral
var ai_track: Board         # AI games only: what the AI knows about our waters

var my_views: Array[ShipView] = []
var enemy_views: Array[ShipView] = []
var hit_fires := {}         # enemy cell -> fire node (hits on still-hidden ships)

var online := false
var opponent_id := 0
var opponent_name := ""
var opponent_ready := false
var me_ready := false
var my_turn := false
var busy := false
var arcade := false
var charges := {"radar": 0, "torpedo": 0, "airstrike": 0}
var selected_ability := ""
var rematch_me := false
var rematch_them := false
var _pending_outcome: Variant = null
var _pending_action: Variant = null
var _quick_room := ""
var _private_code := ""
var _creator := false

# placement
var place_index := 0
var place_horizontal := true
var ghost: ShipView
var hover_cell := Vector2i(-1, -1)
var _press_pos := Vector2.ZERO
var _press_time := 0
var _touch_input := false
var _armed_cell := Vector2i(-1, -1)

# stats
var shots := 0
var hits := 0
var start_time := 0
var mood := "day"
var autotest: Node


func _ready() -> void:
	randomize()
	arena = Arena.new()
	add_child(arena)
	arena.build()
	cam = CameraRig.new()
	add_child(cam)
	hud = Hud.new()
	hud.main = self
	add_child(hud)
	mood = Game.pick_mood() if Game.flags.has("mood") else "sunset"
	arena.apply_mood(mood)
	cam.go_preset(arena.layout["cameras"]["title"], 0.0)
	_spawn_title_fleet()
	Net.message_received.connect(_on_net_message)
	Net.peer_left.connect(_on_peer_left)
	Net.peer_joined.connect(_on_peer_joined)
	Net.connection_changed.connect(_on_connection_changed)
	hud.show_title()
	if Game.flag("autotest"):
		autotest = load("res://scripts/autotest.gd").new()
		autotest.main = self
		add_child(autotest)


# ------------------------------------------------------------------ setup helpers
func _clear_views() -> void:
	for v in my_views + enemy_views:
		if is_instance_valid(v):
			v.queue_free()
	my_views.clear()
	enemy_views.clear()
	for f in hit_fires.values():
		if is_instance_valid(f):
			f.queue_free()
	hit_fires.clear()
	for c in arena.fx_root.get_children():
		c.queue_free()
	arena.player_grid.clear_markers()
	arena.enemy_grid.clear_markers()
	if ghost:
		ghost.queue_free()
		ghost = null


## A decorative fleet for the title screen and the background of menus.
func _spawn_title_fleet() -> void:
	_clear_views()
	var b := Board.new()
	b.randomize_fleet()
	for s in b.ships:
		_spawn_my_ship(s)
	arena.player_grid.visible = false
	arena.enemy_grid.visible = false


func _spawn_my_ship(s: Dictionary) -> ShipView:
	var v := ShipView.new()
	arena.add_child(v)
	v.setup(s["kind"], false)
	v.place(arena.player_grid, s["cells"], s["horizontal"])
	my_views.append(v)
	return v


func _spawn_enemy_ship(kind: String, cells: Array[Vector2i], horizontal: bool) -> ShipView:
	var v := ShipView.new()
	arena.add_child(v)
	v.setup(kind, true)
	v.place(arena.enemy_grid, cells, horizontal)
	enemy_views.append(v)
	return v


func _reset_match() -> void:
	_clear_views()
	my_board = Board.new()
	enemy_track = Board.new()
	enemy_board = null
	ai = null
	ai_track = null
	arcade = Game.mode == "arcade"
	charges = {"radar": 1, "torpedo": 1, "airstrike": 1} if arcade else {"radar": 0, "torpedo": 0, "airstrike": 0}
	selected_ability = ""
	shots = 0
	hits = 0
	busy = false
	me_ready = false
	opponent_ready = false
	rematch_me = false
	rematch_them = false
	_pending_outcome = null
	_pending_action = null
	place_index = 0
	place_horizontal = true
	arena.player_grid.visible = true
	arena.enemy_grid.visible = true
	arena.player_grid.refresh(my_board)
	arena.enemy_grid.refresh(enemy_track)
	arena.player_grid.clear_overlay()
	arena.enemy_grid.clear_overlay()


func _set_mood(m: String) -> void:
	mood = m
	arena.apply_mood(m)


func to_title() -> void:
	get_tree().paused = false
	if online:
		Net.send({"t": "bye"})
		Net.leave()
	online = false
	state = State.TITLE
	_set_mood(["sunset", "day", "night"].pick_random())
	_spawn_title_fleet()
	cam.go_preset(arena.layout["cameras"]["title"], 1.5)
	cam.orbit_enabled = false
	hud.show_title()


func on_language_changed() -> void:
	arena.player_grid.relabel()
	arena.enemy_grid.relabel()
	hud.relabel_battle_layer()


func on_quality_changed() -> void:
	Fx.low = Game.is_low_quality()
	arena.sun.shadow_enabled = not Fx.low


# ------------------------------------------------------------------ AI game
func start_ai_game() -> void:
	online = false
	_reset_match()
	_set_mood(Game.pick_mood())
	enemy_board = Board.new()
	enemy_board.randomize_fleet()
	ai = Admiral.new(Game.difficulty, arcade)
	ai_track = Board.new()
	opponent_name = Game.t("ai_name") + " (" + Game.t(["easy", "normal", "hard"][Game.difficulty]) + ")"
	_begin_placement()


func _begin_placement() -> void:
	state = State.PLACEMENT
	cam.orbit_enabled = true
	cam.go_preset(arena.layout["cameras"]["placement"], 1.6)
	arena.player_grid.set_active(true)
	arena.enemy_grid.set_active(false)
	hud.show_placement()
	_update_fleet_panels()
	_update_ghost()
	hud.set_ready_enabled(false)


func _current_kind() -> String:
	return Game.FLEET[my_board.ships.size()] if my_board.ships.size() < Game.FLEET.size() else ""


func on_rotate() -> void:
	place_horizontal = not place_horizontal
	_update_ghost()


func on_auto_place() -> void:
	if state != State.PLACEMENT:
		return
	for v in my_views:
		v.queue_free()
	my_views.clear()
	my_board.randomize_fleet()
	for s in my_board.ships:
		_spawn_my_ship(s)
	Sfx.play("place")
	_update_ghost()
	_after_place_change()


func on_clear_place() -> void:
	if state != State.PLACEMENT:
		return
	for v in my_views:
		v.queue_free()
	my_views.clear()
	my_board.clear_fleet()
	_update_ghost()
	_after_place_change()


func _after_place_change() -> void:
	hud.set_ready_enabled(my_board.fleet_complete())
	_update_fleet_panels()
	arena.player_grid.set_overlay(hover_cell, [], true)


func _try_place(cell: Vector2i) -> void:
	var s := my_board.ship_at(cell)
	if s != -1:
		# pick the ship up again
		var data := my_board.remove(s)
		var v := my_views[s]
		my_views.remove_at(s)
		v.queue_free()
		place_horizontal = data["horizontal"]
		Sfx.play("click")
		_reorder_fleet_order()
		_update_ghost()
		_after_place_change()
		return
	var kind := _current_kind()
	if kind == "":
		return
	var size: int = Game.SHIP_SIZE[kind]
	var origin := _placement_origin(cell, size)
	if not my_board.can_place(size, origin, place_horizontal):
		hud.toast(Game.t("cant_place"), UiKit.RED, "", 0.6)
		return
	my_board.place(kind, origin, place_horizontal)
	var v := _spawn_my_ship(my_board.ships[-1])
	v.position.y = 3.0
	var tw := v.create_tween()
	tw.tween_property(v, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Fx.splash(arena.fx_root, v.global_position, 0.4)
	Sfx.play("place")
	_update_ghost()
	_after_place_change()


## Ships are always placed largest first; after picking one up keep the board's list in FLEET order.
func _reorder_fleet_order() -> void:
	var order := {"battleship": 0, "cruiser": 1, "destroyer": 2, "patrol": 3}
	var pairs := []
	for i in my_board.ships.size():
		pairs.append([my_board.ships[i], my_views[i]])
	pairs.sort_custom(func(a, b): return order[a[0]["kind"]] < order[b[0]["kind"]])
	my_board.clear_fleet()
	my_views.clear()
	for p in pairs:
		my_board.place(p[0]["kind"], p[0]["origin"], p[0]["horizontal"])
		my_views.append(p[1])


func _placement_origin(cell: Vector2i, size: int) -> Vector2i:
	var o := cell
	if place_horizontal:
		o.x = clampi(cell.x - (size - 1) / 2, 0, 10 - size)
	else:
		o.y = clampi(cell.y - (size - 1) / 2, 0, 10 - size)
	return o


func _update_ghost() -> void:
	var kind := _current_kind()
	if state != State.PLACEMENT or kind == "" or not Board.inside(hover_cell):
		if ghost:
			ghost.visible = false
		arena.player_grid.set_overlay(hover_cell if state == State.PLACEMENT else Vector2i(-1, -1), [], true)
		return
	if ghost == null or ghost.kind != kind:
		if ghost:
			ghost.queue_free()
		ghost = ShipView.new()
		arena.add_child(ghost)
		ghost.setup(kind, false)
	var size: int = Game.SHIP_SIZE[kind]
	var origin := _placement_origin(hover_cell, size)
	var cells := Board.cells_for(size, origin, place_horizontal)
	var valid := my_board.can_place(size, origin, place_horizontal)
	ghost.visible = true
	ghost.place(arena.player_grid, cells, place_horizontal)
	ghost.set_ghost(true, valid)
	arena.player_grid.set_overlay(hover_cell, cells, valid)


func on_ready() -> void:
	if state != State.PLACEMENT:
		return
	if not my_board.fleet_complete():
		hud.toast(Game.t("place_all"), UiKit.RED, "", 0.8)
		return
	if ghost:
		ghost.queue_free()
		ghost = null
	arena.player_grid.clear_overlay()
	me_ready = true
	if online:
		Net.send({"t": "ready"})
		if not opponent_ready:
			state = State.WAIT_OPPONENT
			hud.set_battle_visible(false)
			hud.show_wait(Game.t("waiting_ready") % opponent_name)
			cam.go_preset(arena.layout["cameras"]["overview"], 2.0)
			return
		_start_battle(_online_first_turn())
	else:
		_start_battle(true)


func _online_first_turn() -> bool:
	return Net.my_id < opponent_id


func _start_battle(i_start: bool) -> void:
	state = State.BATTLE
	start_time = Time.get_ticks_msec()
	hud.show_battle(arcade)
	hud.set_vs("%s  %s  %s" % [Game.player_name if Game.player_name != "" else Game.t("you"), Game.t("vs"), opponent_name])
	_update_fleet_panels()
	arena.player_grid.refresh(my_board)
	arena.enemy_grid.refresh(enemy_track)
	Sfx.play("alarm", 0.5)
	if i_start:
		_begin_my_turn()
	else:
		_begin_enemy_turn()


# ------------------------------------------------------------------ turns
func _begin_my_turn() -> void:
	_armed_cell = Vector2i(-1, -1)
	my_turn = true
	busy = false
	selected_ability = ""
	cam.go_preset(arena.layout["cameras"]["attack"], 1.3)
	arena.enemy_grid.set_active(true)
	arena.player_grid.set_active(false)
	hud.set_banner(Game.t("your_turn"), Color(1, 0.85, 0.5))
	hud.set_abilities(charges, selected_ability, true)
	if autotest:
		autotest.call_deferred("my_turn")


func _begin_enemy_turn() -> void:
	my_turn = false
	busy = true
	arena.enemy_grid.clear_overlay()
	arena.enemy_grid.set_active(false)
	arena.player_grid.set_active(true)
	hud.set_banner(Game.t("enemy_turn") if not online else Game.t("waiting_enemy"), UiKit.RED)
	hud.set_abilities(charges, "", false)
	cam.go_preset(arena.layout["cameras"]["defense"], 1.4)
	if not online:
		await get_tree().create_timer(1.3).timeout
		if state != State.BATTLE:
			return
		var d := ai.decide(ai_track)
		var action := {"kind": d["kind"], "cell": [d["cell"].x, d["cell"].y]}
		var outcome := resolve_action(my_board, action)
		_apply_tracker(ai_track, outcome)
		await _animate(false, outcome)
		_after_enemy_outcome(outcome)
	elif _pending_action != null:
		var a: Dictionary = _pending_action
		_pending_action = null
		_handle_remote_shot(a)


func select_ability(a: String) -> void:
	if not my_turn or busy or charges.get(a, 0) <= 0:
		return
	selected_ability = "" if selected_ability == a else a
	hud.set_abilities(charges, selected_ability, true)
	if selected_ability != "":
		hud.set_banner(Game.t(a + "_hint"), Color(1, 0.8, 0.3))
	else:
		hud.set_banner(Game.t("your_turn"), Color(1, 0.85, 0.5))


func _ability_cells(kind: String, c: Vector2i) -> Array:
	var out := []
	match kind:
		"radar":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					out.append(c + Vector2i(dx, dy))
		"airstrike":
			for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				out.append(c + d)
		"torpedo":
			for x in 10:
				out.append(Vector2i(x, c.y))
		_:
			out.append(c)
	return out.filter(func(v): return Board.inside(v))


func fire_at(cell: Vector2i) -> void:
	if state != State.BATTLE or not my_turn or busy:
		return
	var kind := selected_ability if selected_ability != "" else "shell"
	if kind == "shell" and not enemy_track.is_open(cell):
		return
	if kind != "shell":
		charges[kind] -= 1
	selected_ability = ""
	busy = true
	arena.enemy_grid.clear_overlay()
	hud.set_abilities(charges, "", false)
	var action := {"kind": kind, "cell": [cell.x, cell.y]}
	var outcome: Dictionary
	if online:
		Net.send({"t": "shot", "a": action})
		hud.set_banner(Game.t("waiting_enemy"), UiKit.CYAN)
		_pending_outcome = null
		var waited := 0.0
		while _pending_outcome == null and state == State.BATTLE:
			await get_tree().process_frame
			waited += get_process_delta_time()
		if state != State.BATTLE:
			return
		outcome = _pending_outcome
		_pending_outcome = null
	else:
		outcome = resolve_action(enemy_board, action)
	_apply_tracker(enemy_track, outcome)
	if outcome["kind"] != "radar":
		for r in outcome["results"]:
			if not r.get("torpedo_path", false):
				shots += 1
			if r["r"] != "miss" and r["r"] != "repeat":
				hits += 1
	await _animate(true, outcome)
	if state != State.BATTLE:
		return
	var won: bool = outcome.get("lost", false) or (enemy_board != null and enemy_board.all_sunk())
	if won:
		_game_over(true)
		return
	if _any_hit(outcome):
		hud.toast(Game.t("extra_shot"), Color(1, 0.9, 0.5), "", 0.7)
		_begin_my_turn()
	else:
		_begin_enemy_turn()


func _after_enemy_outcome(outcome: Dictionary) -> void:
	if state != State.BATTLE:
		return
	if my_board.all_sunk():
		_game_over(false)
		return
	if _any_hit(outcome):
		_begin_enemy_turn()
	else:
		_begin_my_turn()


func _any_hit(outcome: Dictionary) -> bool:
	for r in outcome["results"]:
		if r["r"] == "hit" or r["r"] == "sunk":
			return true
	return false


## Defender side: resolve an action on our own board.
func resolve_action(board: Board, action: Dictionary) -> Dictionary:
	var c := Vector2i(int(action["cell"][0]), int(action["cell"][1]))
	var out := {"kind": action["kind"], "cell": [c.x, c.y], "results": []}
	match str(action["kind"]):
		"shell":
			out["results"].append(board.receive_shot(c))
		"airstrike":
			for cell in _ability_cells("airstrike", c):
				var r := board.receive_shot(cell)
				if r["r"] != "repeat":
					out["results"].append(r)
		"torpedo":
			out["results"] = board.receive_torpedo(c.y)
		"radar":
			out["radar"] = board.radar_count(c)
	out["lost"] = board.all_sunk()
	return out


func _apply_tracker(tracker: Board, outcome: Dictionary) -> void:
	var c := Vector2i(int(outcome["cell"][0]), int(outcome["cell"][1]))
	if outcome["kind"] == "radar":
		tracker.apply_radar(c, int(outcome["radar"]))
	for r in outcome["results"]:
		if r["r"] != "repeat":
			tracker.apply_result(r)


# ------------------------------------------------------------------ animation
func _animate(mine: bool, outcome: Dictionary) -> void:
	var grid := arena.enemy_grid if mine else arena.player_grid
	var c := Vector2i(int(outcome["cell"][0]), int(outcome["cell"][1]))
	var target := grid.cell_world(c)
	match str(outcome["kind"]):
		"shell":
			var res: Dictionary = outcome["results"][0]
			await _fire_shell(mine, target)
			_impact(mine, res)
			await get_tree().create_timer(0.6 if res["r"] == "miss" else 1.1).timeout
		"airstrike":
			hud.toast(Game.t("airstrike"), Color(1, 0.8, 0.3), "", 0.8)
			var results: Array = outcome["results"]
			var done := [false]
			arena.fly_plane(target, -1.0 if mine else 1.0, func():
				_drop_bombs(mine, results, done))
			while not done[0]:
				await get_tree().process_frame
			await get_tree().create_timer(1.2).timeout
		"torpedo":
			hud.toast(Game.t("torpedo"), Color(1, 0.8, 0.3), "", 0.8)
			var results: Array = outcome["results"]
			var start := grid.cell_world(Vector2i(0, c.y)) - Vector3(grid.cell_size * 2.5, 0, 0)
			var last: Dictionary = results[-1] if not results.is_empty() else {}
			var end_cell := Vector2i(int(last["c"][0]), int(last["c"][1])) if not last.is_empty() and last["r"] != "miss" else Vector2i(9, c.y)
			var end := grid.cell_world(end_cell)
			if last.is_empty() or last["r"] == "miss":
				end += Vector3(grid.cell_size * 2.5, 0, 0)
			Sfx.play("torpedo")
			await arena.run_torpedo(start, end)
			for r in results:
				if r["r"] == "miss":
					grid.add_marker(Vector2i(int(r["c"][0]), int(r["c"][1])), false)
			if not last.is_empty() and last["r"] != "miss":
				_impact(mine, last)
			_refresh_grids()
			await get_tree().create_timer(1.3).timeout
		"radar":
			Sfx.play("sonar")
			Fx.sonar(arena.fx_root, target, grid.cell_size * 2.2)
			grid.set_overlay(Vector2i(-1, -1), [], true, _ability_cells("radar", c))
			_radar_label(grid, target, int(outcome["radar"]))
			hud.toast(Game.t("contacts") % int(outcome["radar"]), Color(1, 0.8, 0.3), "", 1.2)
			_refresh_grids()
			await get_tree().create_timer(2.2).timeout
			grid.clear_overlay()
	_update_fleet_panels()


func _radar_label(grid: GridView, pos: Vector3, n: int) -> void:
	var l := Label3D.new()
	l.text = str(n)
	l.font = load("res://assets/fonts/RussoOne-Regular.ttf")
	l.font_size = 200
	l.pixel_size = 0.02
	l.modulate = Color(1, 0.75, 0.2)
	l.outline_size = 30
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	grid.add_child(l)
	l.global_position = pos + Vector3(0, 4, 0)
	var key := grid.world_cell(pos) + Vector2i(100, 100)  # keep apart from cell markers
	grid.markers[key] = l


func _drop_bombs(mine: bool, results: Array, done: Array) -> void:
	var grid := arena.enemy_grid if mine else arena.player_grid
	for i in results.size():
		var r: Dictionary = results[i]
		var p := grid.cell_world(Vector2i(int(r["c"][0]), int(r["c"][1])))
		await arena.drop_bomb(p + Vector3(randf_range(-3, 3), 22, randf_range(-3, 3)), p, 0.6 + i * 0.12)
		_impact(mine, r)
	done[0] = true


func _fire_shell(mine: bool, target: Vector3) -> void:
	var from: Vector3
	if mine:
		var shooters := my_views.filter(func(v): return not v.sunk and v.muzzles.size() > 0)
		shooters.sort_custom(func(a, b): return Game.SHIP_SIZE[a.kind] > Game.SHIP_SIZE[b.kind])
		var ship: ShipView = shooters[randi() % mini(2, shooters.size())] if not shooters.is_empty() else null
		if ship:
			var t := ship.aim_at(target)
			await get_tree().create_timer(t).timeout
			var m := ship.best_muzzle(target)
			from = m.global_position if m else ship.global_position + Vector3(0, 3, 0)
			ship.muzzle_flash_all(arena.fx_root)
			cam.shake(0.5)
		else:
			from = arena.player_grid.cell_world(Vector2i(5, 9)) + Vector3(0, 4, 10)
	else:
		# enemy guns fire from beyond their grid so the flash does not give their ships away
		var g := arena.enemy_grid
		from = Vector3(g.center.x + randf_range(-18, 18), 3.0, g.center.y - 26.0)
		Fx.muzzle(arena.fx_root, from, (target - from).normalized())
	Sfx.play_at("cannon", arena, from, 1.0)
	var flight := clampf(from.distance_to(target) / 45.0, 1.0, 1.8)
	get_tree().create_timer(flight * 0.45).timeout.connect(func(): Sfx.play("whistle", 0.5))
	await arena.fly_shell(from, target, flight)


func _impact(mine: bool, r: Dictionary) -> void:
	var grid := arena.enemy_grid if mine else arena.player_grid
	var c := Vector2i(int(r["c"][0]), int(r["c"][1]))
	var p := grid.cell_world(c)
	match str(r["r"]):
		"miss":
			Fx.splash(arena.fx_root, p)
			Sfx.play_at("splash", arena, p)
			grid.add_marker(c, false)
			if mine:
				hud.toast(Game.t("miss"), Color(0.7, 0.9, 1.0), "", 0.5)
		"hit":
			Fx.explosion(arena.fx_root, p)
			Sfx.play_at("explosion", arena, p)
			cam.shake(0.9 if not mine else 0.6)
			if mine:
				grid.add_marker(c, true)
				hit_fires[c] = Fx.fire(arena.fx_root, p + Vector3(0, 0.3, 0), 0.8)
				hud.toast(Game.t("hit"), Color(1, 0.55, 0.2))
			else:
				var v := _my_view_at(c)
				if v:
					v.add_fire(p)
				hud.toast(Game.t("enemy_hit"), UiKit.RED, "", 0.8)
		"sunk":
			Fx.explosion(arena.fx_root, p, 1.6)
			Sfx.play_at("explosion", arena, p, 1.2, 0.8)
			cam.shake(1.4)
			var cells: Array[Vector2i] = []
			for sc in r["ship"]:
				cells.append(Vector2i(int(sc[0]), int(sc[1])))
			var kind := str(r.get("kind", "patrol"))
			if mine:
				for sc in cells:
					grid.remove_marker(sc)
					if hit_fires.has(sc):
						hit_fires[sc].queue_free()
						hit_fires.erase(sc)
				var horiz := cells.size() > 1 and cells[0].y == cells[1].y
				var v := _spawn_enemy_ship(kind, cells, horiz)
				for sc in cells:
					v.add_fire(grid.cell_world(sc), 0.9)
				v.sink(arena.fx_root)
				hud.toast(Game.t("sunk"), Color(1, 0.75, 0.2), Game.ship_name(kind))
			else:
				var v := _my_view_at(c)
				if v:
					v.add_fire(p, 1.2)
					v.sink(arena.fx_root)
				hud.toast(Game.t("enemy_sunk"), UiKit.RED, Game.ship_name(kind))
				Sfx.play("alarm", 0.4)
			for sc in cells:
				Fx.explosion(arena.fx_root, grid.cell_world(sc), 0.8)
	_refresh_grids()


func _my_view_at(c: Vector2i) -> ShipView:
	for v in my_views:
		if c in v.cells:
			return v
	return null


func _refresh_grids() -> void:
	arena.player_grid.refresh(my_board)
	arena.enemy_grid.refresh(enemy_track)
	_update_fleet_panels()


func _update_fleet_panels() -> void:
	var rows := []
	if my_board:
		for s in my_board.ships:
			rows.append({"kind": s["kind"], "size": s["size"], "hits": s["hits"], "sunk": s["hits"] >= s["size"]})
		if state == State.PLACEMENT:
			for i in range(my_board.ships.size(), Game.FLEET.size()):
				var k: String = Game.FLEET[i]
				rows.append({"kind": k, "size": Game.SHIP_SIZE[k], "hits": 0, "sunk": false, "pending": true})
	hud.my_fleet.title = Game.t("your_fleet")
	hud.my_fleet.set_rows(rows)
	var erows := []
	var sunk: Array = enemy_track.sunk_kinds.duplicate() if enemy_track else []
	for k in Game.FLEET:
		var i := sunk.find(k)
		var is_sunk := i >= 0
		if is_sunk:
			sunk.remove_at(i)
		erows.append({"kind": k, "size": Game.SHIP_SIZE[k], "hits": 0, "sunk": is_sunk})
	hud.enemy_fleet.title = Game.t("enemy_fleet")
	hud.enemy_fleet.set_rows(erows)


func _game_over(won: bool, reason := "") -> void:
	state = State.OVER
	busy = true
	my_turn = false
	cam.go_preset(arena.layout["cameras"]["overview"], 2.5)
	arena.enemy_grid.set_active(false)
	arena.player_grid.set_active(false)
	if won:
		Game.stats["wins"] += 1
		if online:
			Game.stats["online_wins"] += 1
			Net.send({"t": "fleet", "ships": my_board.fleet_data()})
		Sfx.play("victory")
	else:
		Game.stats["losses"] += 1
		Sfx.play("defeat")
		if enemy_board:
			_reveal_enemy_fleet(enemy_board.fleet_data())
	Game.stats["shots"] += shots
	Game.stats["hits"] += hits
	Game.save()
	hud.set_battle_visible(false)
	var secs := (Time.get_ticks_msec() - start_time) / 1000
	var st := {"shots": shots, "accuracy": int(round(100.0 * hits / maxf(shots, 1))), "time": "%d:%02d" % [secs / 60, secs % 60]}
	await get_tree().create_timer(1.6).timeout
	if state == State.OVER:
		hud.show_game_over(won, st, online, reason)
	if autotest:
		autotest.call_deferred("game_over", won)


## Show the enemy ships that survived (after a defeat).
func _reveal_enemy_fleet(ships: Array) -> void:
	for s in ships:
		var size: int = Game.SHIP_SIZE[s["kind"]]
		var cells := Board.cells_for(size, Vector2i(int(s["x"]), int(s["y"])), bool(s["h"]))
		var already := false
		for v in enemy_views:
			if v.cells == cells:
				already = true
		if already or enemy_track.get_state(cells[0]) == Board.SUNK:
			continue
		var v := _spawn_enemy_ship(s["kind"], cells, bool(s["h"]))
		v.position.y = -4.0
		v.create_tween().tween_property(v, "position:y", 0.0, 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func on_play_again() -> void:
	if online:
		rematch_me = true
		Net.send({"t": "rematch"})
		if rematch_them:
			_online_new_round()
		else:
			hud.show_wait(Game.t("rematch_wait"))
	else:
		start_ai_game()


func on_pause() -> void:
	if state == State.TITLE:
		return
	if not online:
		get_tree().paused = true
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.show_pause()


func on_resume() -> void:
	get_tree().paused = false
	hud.clear_screen()
	if state == State.WAIT_OPPONENT:
		hud.show_wait(Game.t("waiting_ready") % opponent_name)


func on_surrender() -> void:
	get_tree().paused = false
	hud.clear_screen()
	if state == State.BATTLE or state == State.PLACEMENT or state == State.WAIT_OPPONENT:
		if online:
			Net.send({"t": "surrender"})
		_game_over(false)
	else:
		to_title()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if state == State.PLACEMENT:
					on_rotate()
			KEY_ESCAPE:
				if state in [State.BATTLE, State.PLACEMENT]:
					on_pause()
	if state != State.PLACEMENT and state != State.BATTLE:
		return
	if event is InputEventMouseMotion:
		_hover(event.position)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_press_time = Time.get_ticks_msec()
			elif mb.position.distance_to(_press_pos) < 18 and Time.get_ticks_msec() - _press_time < 700:
				_touch_input = mb.device == InputEvent.DEVICE_ID_EMULATION or Game.flag("touch")
				_hover(mb.position)
				_click()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and state == State.PLACEMENT:
			on_rotate()


func _hover(screen: Vector2) -> void:
	var p: Variant = cam.water_point(screen)
	var grid := arena.player_grid if state == State.PLACEMENT else arena.enemy_grid
	var c := grid.world_cell(p) if p != null else Vector2i(-1, -1)
	if c == hover_cell:
		return
	hover_cell = c
	if state == State.PLACEMENT:
		_update_ghost()
	elif my_turn and not busy:
		var kind := selected_ability
		var cells := _ability_cells(kind, c) if kind != "" and Board.inside(c) else []
		if kind == "radar":
			grid.set_overlay(c, [], true, cells)
		else:
			grid.set_overlay(c, cells, true)
		if Board.inside(c):
			Sfx.play("hover", 0.15)


func _click() -> void:
	if not Board.inside(hover_cell):
		return
	if state == State.PLACEMENT:
		_try_place(hover_cell)
	elif state == State.BATTLE:
		# phones: first tap aims, a second tap on the same cell fires
		if _touch_input and _armed_cell != hover_cell:
			_armed_cell = hover_cell
			Sfx.play("click", 0.4)
			hud.set_banner(Game.t("tap_again"), Color(1, 0.85, 0.5))
			return
		_armed_cell = Vector2i(-1, -1)
		fire_at(hover_cell)


# ------------------------------------------------------------------ online
func online_cancel() -> void:
	Net.leave()
	online = false


func online_quick() -> void:
	if has_meta("room_mood"):
		remove_meta("room_mood")
	_quick_room = "quick-" + Game.mode + str(Game.flags.get("qroom", ""))
	_private_code = ""
	_creator = false
	online = true
	opponent_id = 0
	hud.set_status(Game.t("connecting"))
	Net.join(_quick_room)


func online_create() -> void:
	if has_meta("room_mood"):
		remove_meta("room_mood")
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	_private_code = ""
	for i in 4:
		_private_code += letters[randi() % letters.length()]
	_quick_room = ""
	_creator = true
	online = true
	opponent_id = 0
	hud.set_status(Game.t("connecting"))
	Net.join("room-" + _private_code)


func online_join(code: String) -> void:
	if has_meta("room_mood"):
		remove_meta("room_mood")
	if code.length() < 4:
		hud.set_status(Game.t("room_code") + "?")
		return
	_private_code = code
	_quick_room = ""
	_creator = false
	online = true
	opponent_id = 0
	hud.set_status(Game.t("connecting"))
	Net.join("room-" + code)


func _on_connection_changed(is_online: bool) -> void:
	if not online:
		return
	if is_online:
		if _quick_room != "":
			hud.set_status(Game.t("searching"))
			_try_pair()
		else:
			if _creator:
				hud.set_status(Game.t("room_wait") % _private_code)
			if Net.peers.size() > 1:
				hud.set_status(Game.t("room_full"))
				Net.leave()
				return
			_send_hello()
	else:
		if state == State.TITLE:
			hud.set_status(Game.t("offline"))
		elif state in [State.BATTLE, State.PLACEMENT, State.WAIT_OPPONENT] and opponent_id != 0:
			_game_over(false, Game.t("offline"))


func _on_peer_joined(_id: int) -> void:
	if not online:
		return
	if _quick_room != "":
		_try_pair()
	elif opponent_id == 0:
		_send_hello()


## Quick match lobby: the two lowest ids pair up; the lowest invents a private room and both move there.
func _try_pair() -> void:
	var all: Array[int] = [Net.my_id]
	all.append_array(Net.peers)
	all.sort()
	if all.size() >= 2 and all[0] == Net.my_id and not has_meta("pairing"):
		set_meta("pairing", true)
		var code := "q%d%d" % [all[0], randi() % 100000]
		var m := Game.pick_mood()
		set_meta("room_mood", m)
		Net.send({"t": "pair", "a": all[0], "b": all[1], "room": code, "mood": m})
		# let the message leave before the socket is closed
		get_tree().create_timer(0.5).timeout.connect(func():
			remove_meta("pairing")
			_move_to_room(code, true))


func _move_to_room(code: String, creator: bool) -> void:
	_quick_room = ""
	_private_code = code
	_creator = creator
	Net.join("room-" + code)


func _send_hello() -> void:
	var hello := {"t": "hello", "name": Game.player_name, "creator": _creator}
	if _creator:
		hello["mode"] = Game.mode
		if not has_meta("room_mood"):
			set_meta("room_mood", Game.pick_mood())
		hello["mood"] = get_meta("room_mood")
	Net.send(hello)


func _on_peer_left(id: int) -> void:
	if not online or id != opponent_id:
		return
	if state in [State.BATTLE, State.PLACEMENT, State.WAIT_OPPONENT]:
		_game_over(true, Game.t("opponent_left"))
	elif state == State.OVER:
		hud.show_wait(Game.t("opponent_left"))
		opponent_id = 0


func _on_net_message(from: int, d: Dictionary) -> void:
	if not online:
		return
	match str(d.get("t", "")):
		"pair":
			if int(d.get("b", 0)) == Net.my_id:
				set_meta("room_mood", str(d.get("mood", "day")))
				_move_to_room(str(d["room"]), false)
		"hello":
			if opponent_id != 0 and from != opponent_id:
				return
			var first := opponent_id == 0
			opponent_id = from
			opponent_name = str(d.get("name", "?")).left(16)
			if d.get("creator", false):
				Game.mode = str(d.get("mode", Game.mode))
				set_meta("room_mood", str(d.get("mood", "day")))
			if first:
				_send_hello()
				if state == State.TITLE:
					_online_new_round()
		"ready":
			if from != opponent_id:
				return
			opponent_ready = true
			if me_ready and state == State.WAIT_OPPONENT:
				_start_battle(_online_first_turn())
		"shot":
			if from != opponent_id:
				return
			if state == State.BATTLE and not my_turn and not busy_with_remote:
				_handle_remote_shot(d["a"])
			else:
				_pending_action = d["a"]
		"res":
			if from == opponent_id:
				_pending_outcome = d["o"]
		"fleet":
			if from == opponent_id:
				_reveal_enemy_fleet(d["ships"])
		"surrender":
			if from == opponent_id and state in [State.BATTLE, State.PLACEMENT, State.WAIT_OPPONENT]:
				_game_over(true, Game.t("opponent_left"))
		"bye":
			if from == opponent_id:
				_on_peer_left(from)
		"rematch":
			if from == opponent_id:
				rematch_them = true
				if rematch_me:
					_online_new_round()


var busy_with_remote := false


func _handle_remote_shot(action: Dictionary) -> void:
	busy_with_remote = true
	var outcome := resolve_action(my_board, action)
	Net.send({"t": "res", "o": outcome})
	await _animate(false, outcome)
	busy_with_remote = false
	_after_enemy_outcome(outcome)


func _online_new_round() -> void:
	_reset_match()
	_set_mood(str(get_meta("room_mood", "day")))
	arcade = Game.mode == "arcade"
	charges = {"radar": 1, "torpedo": 1, "airstrike": 1} if arcade else {"radar": 0, "torpedo": 0, "airstrike": 0}
	hud.toast(Game.t("opponent_found") % opponent_name, UiKit.CYAN, "", 1.2)
	_begin_placement()
