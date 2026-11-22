class_name GridView
extends Node3D
## The glowing 10x10 grid floating on one side's waters + 3D markers (miss buoys, hit flares).

const MARGIN := 0.05
const LETTERS_EN := "ABCDEFGHIJ"
const LETTERS_RU := "АБВГДЕЖЗИК"

var cell_size := 4.0
var center := Vector2.ZERO
var is_enemy := false
var mesh_inst: MeshInstance3D
var mat: ShaderMaterial
var cells_img: Image
var overlay_img: Image
var cells_tex: ImageTexture
var overlay_tex: ImageTexture
var markers := {}  # Vector2i -> Node3D
var labels: Array[Label3D] = []
var _miss_scene: PackedScene
var _hit_scene: PackedScene


func setup(c: Vector2, size: float, enemy: bool) -> void:
	center = c
	cell_size = size
	is_enemy = enemy
	position = Vector3(c.x, 0, c.y)
	_miss_scene = load("res://assets/env/marker_miss.gltf")
	_hit_scene = load("res://assets/env/marker_hit.gltf")
	cells_img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	overlay_img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	cells_tex = ImageTexture.create_from_image(cells_img)
	overlay_tex = ImageTexture.create_from_image(overlay_img)
	var pm := PlaneMesh.new()
	var full := cell_size * 10.0 / (1.0 - 2.0 * MARGIN)
	pm.size = Vector2(full, full)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/grid.gdshader")
	mat.set_shader_parameter("cells", cells_tex)
	mat.set_shader_parameter("overlay", overlay_tex)
	mat.set_shader_parameter("margin", MARGIN)
	if enemy:
		mat.set_shader_parameter("line_color", Color(1.0, 0.45, 0.3))
		mat.set_shader_parameter("hover_color", Color(1.0, 0.85, 0.4))
	pm.material = mat
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = pm
	mesh_inst.position.y = 0.32
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_inst)
	_make_labels()


func _make_labels() -> void:
	for l in labels:
		l.queue_free()
	labels.clear()
	var letters := LETTERS_RU if Game.lang == "ru" else LETTERS_EN
	var font: Font = load("res://assets/fonts/RussoOne-Regular.ttf")
	var col := Color(1.0, 0.6, 0.45) if is_enemy else Color(0.5, 1.0, 1.0)
	for i in 10:
		for k in 2:
			var l := Label3D.new()
			l.font = font
			l.font_size = 96
			l.pixel_size = 0.022
			l.modulate = col
			l.outline_size = 18
			l.outline_modulate = Color(0, 0.05, 0.1, 0.8)
			l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			l.rotation = Vector3(-PI / 2, 0, 0)
			l.no_depth_test = false
			if k == 0:
				l.text = letters[i]
				l.position = Vector3((i - 4.5) * cell_size, 0.4, 5.6 * cell_size)
			else:
				l.text = str(i + 1)
				l.position = Vector3(-5.65 * cell_size, 0.4, (i - 4.5) * cell_size)
			add_child(l)
			labels.append(l)


func relabel() -> void:
	_make_labels()


func cell_world(c: Vector2i) -> Vector3:
	return Vector3(center.x + (c.x - 4.5) * cell_size, 0.0, center.y + (c.y - 4.5) * cell_size)


func world_cell(p: Vector3) -> Vector2i:
	var x := floori((p.x - center.x) / cell_size + 5.0)
	var y := floori((p.z - center.y) / cell_size + 5.0)
	if x < 0 or y < 0 or x > 9 or y > 9:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func set_active(on: bool) -> void:
	mat.set_shader_parameter("active", 1.0 if on else 0.15)


func set_intensity(v: float) -> void:
	mat.set_shader_parameter("intensity", v)


func refresh(board: Board) -> void:
	for y in 10:
		for x in 10:
			var st := board.get_state(Vector2i(x, y))
			var col := Color(0, 0, 0, 0)
			match st:
				Board.MISS:
					col.r = 1
				Board.HIT:
					col.g = 1
				Board.SUNK:
					col.b = 1
				Board.EMPTY:
					col.a = 1
			cells_img.set_pixel(x, y, col)
	cells_tex.update(cells_img)


func clear_overlay() -> void:
	overlay_img.fill(Color(0, 0, 0, 0))
	overlay_tex.update(overlay_img)


func set_overlay(hover: Vector2i, preview: Array, valid: bool, radar: Array = []) -> void:
	overlay_img.fill(Color(0, 0, 0, 0))
	for c in radar:
		if Board.inside(c):
			var p := overlay_img.get_pixelv(c)
			p.b = 1
			overlay_img.set_pixelv(c, p)
	for c in preview:
		if Board.inside(c):
			var p := overlay_img.get_pixelv(c)
			if valid:
				p.r = 1
			else:
				p.g = 1
			overlay_img.set_pixelv(c, p)
	if Board.inside(hover):
		var p := overlay_img.get_pixelv(hover)
		p.a = 1
		overlay_img.set_pixelv(hover, p)
	overlay_tex.update(overlay_img)


func add_marker(c: Vector2i, hit: bool) -> Node3D:
	remove_marker(c)
	var node: Node3D = (_hit_scene if hit else _miss_scene).instantiate()
	add_child(node)
	node.global_position = cell_world(c) + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	node.rotation.y = randf() * TAU
	node.set_meta("phase", randf() * TAU)
	node.scale = Vector3.ONE * 0.01
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * (1.25 if hit else 1.1), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hit:
		var l := OmniLight3D.new()
		node.add_child(l)
		l.position = Vector3(0, 1.0, 0)
		l.light_color = Color(1, 0.3, 0.15)
		l.light_energy = 1.2
		l.omni_range = 5.0
	markers[c] = node
	return node


func remove_marker(c: Vector2i) -> void:
	if markers.has(c):
		var n: Node3D = markers[c]
		if is_instance_valid(n):
			n.queue_free()
		markers.erase(c)


func clear_markers() -> void:
	for c in markers.keys():
		remove_marker(c)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for c in markers:
		var n: Node3D = markers[c]
		if is_instance_valid(n):
			var ph: float = n.get_meta("phase", 0.0)
			n.position.y = sin(t * 1.4 + ph) * 0.12
			n.rotation.z = sin(t * 1.1 + ph) * 0.08
