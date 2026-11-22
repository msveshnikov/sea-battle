class_name Board
extends RefCounted
## One side's waters: the fleet (only known for your own side) and the record of shots received.
## Also used as the "tracker" of the enemy's waters: then `ships` stays empty and only `state`
## (what we have learned) is filled from shot results.

const N := 10

enum { UNKNOWN = 0, MISS = 1, HIT = 2, SUNK = 3, EMPTY = 4 }  # EMPTY = deduced empty (around sunk / diagonals of hits)

var ships: Array = []            # {kind, size, origin: Vector2i, horizontal: bool, cells: Array[Vector2i], hits: int}
var occ := PackedInt32Array()    # ship index per cell or -1
var state := PackedInt32Array()  # UNKNOWN/MISS/HIT/SUNK/EMPTY per cell
var radar: Array = []            # [{center: Vector2i, count: int}]
var sunk_kinds: Array = []       # kinds of ships sunk on this board (tracker side too)


func _init() -> void:
	occ.resize(N * N)
	occ.fill(-1)
	state.resize(N * N)
	state.fill(UNKNOWN)


static func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


static func idx(c: Vector2i) -> int:
	return c.y * N + c.x


static func cells_for(size: int, origin: Vector2i, horizontal: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in size:
		out.append(origin + (Vector2i(i, 0) if horizontal else Vector2i(0, i)))
	return out


func get_state(c: Vector2i) -> int:
	return state[idx(c)] if inside(c) else EMPTY


func ship_at(c: Vector2i) -> int:
	return occ[idx(c)] if inside(c) else -1


func can_place(size: int, origin: Vector2i, horizontal: bool, ignore := -1) -> bool:
	for c in cells_for(size, origin, horizontal):
		if not inside(c):
			return false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if inside(n):
					var s := occ[idx(n)]
					if s != -1 and s != ignore:
						return false
	return true


func place(kind: String, origin: Vector2i, horizontal: bool) -> int:
	var size: int = Game.SHIP_SIZE[kind]
	var cells := cells_for(size, origin, horizontal)
	var i := ships.size()
	ships.append({"kind": kind, "size": size, "origin": origin, "horizontal": horizontal, "cells": cells, "hits": 0})
	for c in cells:
		occ[idx(c)] = i
	return i


func remove(i: int) -> Dictionary:
	var s: Dictionary = ships[i]
	ships.remove_at(i)
	occ.fill(-1)
	for k in ships.size():
		for c in ships[k]["cells"]:
			occ[idx(c)] = k
	return s


func clear_fleet() -> void:
	ships.clear()
	occ.fill(-1)


## Random legal fleet (retries from scratch if it paints itself into a corner).
func randomize_fleet(fleet: Array = Game.FLEET) -> void:
	for attempt in 200:
		clear_fleet()
		var ok := true
		for kind in fleet:
			var size: int = Game.SHIP_SIZE[kind]
			var placed := false
			for t in 300:
				var hor := randf() < 0.5
				var o := Vector2i(randi_range(0, N - (size if hor else 1)), randi_range(0, N - (1 if hor else size)))
				if can_place(size, o, hor):
					place(kind, o, hor)
					placed = true
					break
			if not placed:
				ok = false
				break
		if ok:
			return


func fleet_complete() -> bool:
	return ships.size() == Game.FLEET.size()


func all_sunk() -> bool:
	for s in ships:
		if s["hits"] < s["size"]:
			return false
	return ships.size() > 0


func alive_ships() -> Array:
	return ships.filter(func(s): return s["hits"] < s["size"])


## Resolve an incoming shot on THIS board (we own the fleet). Returns a result the attacker can apply.
func receive_shot(c: Vector2i) -> Dictionary:
	var res := {"c": [c.x, c.y], "r": "miss"}
	if not inside(c):
		res["r"] = "repeat"
		return res
	var st := state[idx(c)]
	if st == HIT or st == SUNK or st == MISS:
		res["r"] = "repeat"
		return res
	var s := occ[idx(c)]
	if s == -1:
		state[idx(c)] = MISS
		return res
	state[idx(c)] = HIT
	ships[s]["hits"] += 1
	res["r"] = "hit"
	if ships[s]["hits"] >= ships[s]["size"]:
		res["r"] = "sunk"
		res["kind"] = ships[s]["kind"]
		var cells := []
		for sc in ships[s]["cells"]:
			state[idx(sc)] = SUNK
			cells.append([sc.x, sc.y])
		res["ship"] = cells
		res["horizontal"] = ships[s]["horizontal"]
		sunk_kinds.append(ships[s]["kind"])
		_mark_around(ships[s]["cells"])
	else:
		_mark_diagonals(c)
	return res


## Torpedo runs along row `row` from column 0 until it hits something.
func receive_torpedo(row: int) -> Array:
	var out := []
	for x in N:
		var c := Vector2i(x, row)
		var st := state[idx(c)]
		if occ[idx(c)] != -1 and st != HIT and st != SUNK:
			out.append(receive_shot(c))
			return out
		if st == UNKNOWN or st == EMPTY:
			if occ[idx(c)] == -1:
				state[idx(c)] = MISS
				out.append({"c": [x, row], "r": "miss", "torpedo_path": true})
	return out


func radar_count(center: Vector2i) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := center + Vector2i(dx, dy)
			if inside(c) and occ[idx(c)] != -1 and state[idx(c)] != HIT and state[idx(c)] != SUNK:
				n += 1
	return n


## Apply a result received for a shot WE fired (tracker of enemy waters).
func apply_result(res: Dictionary) -> void:
	var c := Vector2i(int(res["c"][0]), int(res["c"][1]))
	match str(res["r"]):
		"miss":
			state[idx(c)] = MISS
		"hit":
			state[idx(c)] = HIT
			_mark_diagonals(c)
		"sunk":
			var cells: Array[Vector2i] = []
			for sc in res["ship"]:
				var v := Vector2i(int(sc[0]), int(sc[1]))
				cells.append(v)
				state[idx(v)] = SUNK
			sunk_kinds.append(str(res.get("kind", "")))
			_mark_around(cells)


func apply_radar(center: Vector2i, count: int) -> void:
	radar.append({"center": center, "count": count})
	if count == 0:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := center + Vector2i(dx, dy)
				if inside(c) and state[idx(c)] == UNKNOWN:
					state[idx(c)] = EMPTY


func _mark_around(cells: Array[Vector2i]) -> void:
	for c in cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if inside(n) and state[idx(n)] == UNKNOWN:
					state[idx(n)] = EMPTY


func _mark_diagonals(c: Vector2i) -> void:
	for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var n: Vector2i = c + d
		if inside(n) and state[idx(n)] == UNKNOWN:
			state[idx(n)] = EMPTY


func is_open(c: Vector2i) -> bool:
	return inside(c) and (state[idx(c)] == UNKNOWN)


## Sizes of ships not yet sunk (for the AI), given the standard fleet.
func remaining_sizes() -> Array:
	var sizes := []
	var sunk := sunk_kinds.duplicate()
	for k in Game.FLEET:
		var i := sunk.find(k)
		if i >= 0:
			sunk.remove_at(i)
		else:
			sizes.append(Game.SHIP_SIZE[k])
	return sizes


func fleet_data() -> Array:
	var out := []
	for s in ships:
		out.append({"kind": s["kind"], "x": s["origin"].x, "y": s["origin"].y, "h": s["horizontal"]})
	return out
