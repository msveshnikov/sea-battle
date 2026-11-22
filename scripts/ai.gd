class_name Admiral
extends RefCounted
## Computer opponent. Works only from what it has learned (a Board used as a tracker), never peeks.
## Easy: random with a little follow-up. Normal: hunt (checkerboard) / target. Hard: probability heat map.

var difficulty := 1
var abilities := {"radar": 0, "torpedo": 0, "airstrike": 0}
var turn := 0


func _init(level := 1, arcade := false) -> void:
	difficulty = level
	if arcade:
		abilities = {"radar": 1, "torpedo": 1, "airstrike": 1}


## Returns {"kind": "shell"|"radar"|"torpedo"|"airstrike", "cell": Vector2i}
func decide(tracker: Board) -> Dictionary:
	turn += 1
	var heat := heat_map(tracker)
	var hunting := _unresolved_hits(tracker).is_empty()
	if hunting and difficulty >= 1:
		if abilities["airstrike"] > 0 and turn >= 4 and randf() < 0.35:
			var best := _best_area(tracker, heat, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])
			if best.x >= 0:
				abilities["airstrike"] -= 1
				return {"kind": "airstrike", "cell": best}
		if abilities["radar"] > 0 and turn >= 2 and randf() < 0.3:
			var area: Array[Vector2i] = []
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					area.append(Vector2i(dx, dy))
			var best := _best_area(tracker, heat, area)
			if best.x >= 0:
				abilities["radar"] -= 1
				return {"kind": "radar", "cell": best}
		if abilities["torpedo"] > 0 and turn >= 6 and randf() < 0.3:
			var best_row := 0
			var best_v := -1.0
			for y in Board.N:
				var v := 0.0
				for x in Board.N:
					if tracker.is_open(Vector2i(x, y)):
						v += heat[y * Board.N + x] * pow(0.85, x)
				if v > best_v:
					best_v = v
					best_row = y
			abilities["torpedo"] -= 1
			return {"kind": "torpedo", "cell": Vector2i(0, best_row)}
	return {"kind": "shell", "cell": choose_shot(tracker, heat)}


func choose_shot(tracker: Board, heat := PackedFloat32Array()) -> Vector2i:
	var open: Array[Vector2i] = []
	for y in Board.N:
		for x in Board.N:
			if tracker.is_open(Vector2i(x, y)):
				open.append(Vector2i(x, y))
	if open.is_empty():
		return Vector2i(0, 0)
	var hits := _unresolved_hits(tracker)
	match difficulty:
		0:
			if not hits.is_empty() and randf() < 0.55:
				var n := _neighbours(tracker, hits.pick_random())
				if not n.is_empty():
					return n.pick_random()
			return open.pick_random()
		1:
			if not hits.is_empty():
				return _target(tracker, hits)
			var parity := open.filter(func(c): return (c.x + c.y) % 2 == 0)
			return (parity if not parity.is_empty() else open).pick_random()
		_:
			if heat.is_empty():
				heat = heat_map(tracker)
			var best: Array[Vector2i] = []
			var best_v := -1.0
			for c in open:
				var v := heat[c.y * Board.N + c.x]
				if v > best_v + 0.0001:
					best_v = v
					best = [c]
				elif absf(v - best_v) <= 0.0001:
					best.append(c)
			return best.pick_random()


func _unresolved_hits(tracker: Board) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in Board.N:
		for x in Board.N:
			if tracker.get_state(Vector2i(x, y)) == Board.HIT:
				out.append(Vector2i(x, y))
	return out


func _neighbours(tracker: Board, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if tracker.is_open(c + d):
			out.append(c + d)
	return out


## Extend a line of hits; with a single hit try the four neighbours.
func _target(tracker: Board, hits: Array[Vector2i]) -> Vector2i:
	if hits.size() >= 2:
		var horizontal := hits[0].y == hits[1].y
		var line := hits.filter(func(h): return h.y == hits[0].y if horizontal else h.x == hits[0].x)
		line.sort_custom(func(a, b): return (a.x < b.x) if horizontal else (a.y < b.y))
		var ends: Array[Vector2i] = []
		var d := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
		if tracker.is_open(line[0] - d):
			ends.append(line[0] - d)
		if tracker.is_open(line[-1] + d):
			ends.append(line[-1] + d)
		if not ends.is_empty():
			return ends.pick_random()
	for h in hits:
		var n := _neighbours(tracker, h)
		if not n.is_empty():
			return n.pick_random()
	return choose_shot_fallback(tracker)


func choose_shot_fallback(tracker: Board) -> Vector2i:
	for y in Board.N:
		for x in Board.N:
			if tracker.is_open(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i.ZERO


## Count of legal placements of each remaining ship through every open cell; placements through
## unresolved hits weigh far more. Radar counts bias their 3×3 areas.
func heat_map(tracker: Board) -> PackedFloat32Array:
	var heat := PackedFloat32Array()
	heat.resize(Board.N * Board.N)
	var hits := _unresolved_hits(tracker)
	for size in tracker.remaining_sizes():
		for hor in [true, false]:
			for y in Board.N:
				for x in Board.N:
					var cells := Board.cells_for(size, Vector2i(x, y), hor)
					var ok := true
					var covered := 0
					for c in cells:
						if not Board.inside(c):
							ok = false
							break
						var st := tracker.get_state(c)
						if st == Board.MISS or st == Board.SUNK or st == Board.EMPTY:
							ok = false
							break
						if st == Board.HIT:
							covered += 1
					if not ok:
						continue
					if not hits.is_empty() and covered == 0:
						continue
					var w := 1.0 + covered * 30.0
					for c in cells:
						heat[c.y * Board.N + c.x] += w
	for r in tracker.radar:
		var center: Vector2i = r["center"]
		if r["count"] <= 0:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := center + Vector2i(dx, dy)
				if Board.inside(c):
					heat[c.y * Board.N + c.x] *= 1.0 + 0.4 * r["count"]
	return heat


func _best_area(tracker: Board, heat: PackedFloat32Array, shape: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_v := 0.0
	for y in range(1, Board.N - 1):
		for x in range(1, Board.N - 1):
			var v := 0.0
			var open := 0
			for d in shape:
				var c: Vector2i = Vector2i(x, y) + d
				if tracker.is_open(c):
					v += heat[c.y * Board.N + c.x]
					open += 1
			if open >= shape.size() - 1 and v > best_v:
				best_v = v
				best = Vector2i(x, y)
	return best
