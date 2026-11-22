class_name FleetPanel
extends Control
## Ship silhouettes as rows of segments: alive / hit / sunk. Own fleet shows hits per ship,
## the enemy fleet only which classes went down.

var title := ""
var enemy := false
var rows: Array = []  # [{kind, size, hits, sunk}]
var accent := UiKit.CYAN


func _init() -> void:
	custom_minimum_size = Vector2(250, 250)


func set_rows(r: Array) -> void:
	rows = r
	custom_minimum_size = Vector2(250, 44 + rows.size() * 20.5)
	queue_redraw()


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.07, 0.12, 0.72)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var f := UiKit.head_font if UiKit.head_font else get_theme_default_font()
	draw_string(f, Vector2(14, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)
	var y := 42.0
	for r in rows:
		var x := 14.0
		var seg := 22.0
		for i in r["size"]:
			var col := Color(0.45, 0.55, 0.62)
			if r["sunk"]:
				col = Color(0.5, 0.12, 0.08)
			elif i < r["hits"]:
				col = UiKit.RED
			elif not enemy:
				col = Color(0.55, 0.75, 0.82)
			var rect := Rect2(x, y, seg - 3, 12)
			draw_rect(rect, col)
			if i == 0 and r["size"] > 1:
				draw_colored_polygon(PackedVector2Array([Vector2(x - 6, y + 6), Vector2(x, y), Vector2(x, y + 12)]), col)
			x += seg
		if r["sunk"]:
			draw_line(Vector2(10, y + 6), Vector2(x + 2, y + 6), Color(1, 0.4, 0.3), 2.0)
		draw_string(get_theme_default_font(), Vector2(x + 8, y + 12), Game.ship_name(r["kind"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.88, 0.95, 0.85 if not r["sunk"] else 0.4))
		y += 20
