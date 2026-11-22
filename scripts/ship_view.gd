class_name ShipView
extends Node3D
## A ship model on the water: bobbing, aiming turrets, muzzle flashes, fires on hits, sinking.

const SCENES := {
	"battleship": "res://assets/ships/battleship.gltf",
	"cruiser": "res://assets/ships/cruiser.gltf",
	"destroyer": "res://assets/ships/destroyer.gltf",
	"patrol": "res://assets/ships/patrol.gltf",
}
const ENEMY_TINT := {
	"steel": Color(0.27, 0.3, 0.36), "hull": Color(0.72, 0.78, 0.92), "orange": Color(0.75, 0.08, 0.07),
	"deck": Color(0.8, 0.72, 0.66), "steel_dark": Color(0.1, 0.1, 0.12),
}

static var night_lights := false
static var _enemy_mats := {}
static var _foam_noise: Texture2D

var kind := "patrol"
var enemy := false
var cells: Array[Vector2i] = []
var horizontal := true
var sunk := false
var model: Node3D
var turrets: Array[Node3D] = []
var guns: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var searchlights: Array[SpotLight3D] = []
var fires: Array[Node3D] = []
var foam: MeshInstance3D
var _phase := randf() * TAU
var _aim_yaw := {}
var _aim_pitch := 0.0
var _rest_yaw := {}
var _base_y := 0.0
var _ghost := false
var _sweep := randf() * TAU


func setup(ship_kind: String, is_enemy: bool) -> void:
	kind = ship_kind
	enemy = is_enemy
	var packed: PackedScene = load(SCENES[kind])
	model = packed.instantiate()
	model.scale = Vector3.ONE * 1.18
	add_child(model)
	for t in model.find_children("TURRET_*", "", true, false):
		turrets.append(t)
		_rest_yaw[t] = t.rotation.y
		_aim_yaw[t] = t.rotation.y
	for g in model.find_children("GUN_*", "", true, false):
		guns.append(g)
	for m in model.find_children("MUZZLE_*", "", true, false):
		muzzles.append(m)
	_setup_materials(model)
	_add_foam()
	if not Fx.low:
		for f in model.find_children("FUNNEL_*", "", true, false):
			_funnel_smoke(f)
	for s in model.find_children("SEARCHLIGHT_*", "", true, false):
		if kind == "battleship" or kind == "cruiser":
			var l := SpotLight3D.new()
			s.add_child(l)
			l.spot_range = 70.0
			l.spot_angle = 9.0
			l.light_energy = 6.0
			l.light_color = Color(1.0, 0.95, 0.8)
			l.visible = night_lights
			searchlights.append(l)


func _setup_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(i)
			if not m is StandardMaterial3D:
				continue
			var sm: StandardMaterial3D = m
			if sm.resource_name in ["windows", "lamp"]:
				sm.emission_energy_multiplier = 1.4 if night_lights else 0.0
			if enemy and ENEMY_TINT.has(sm.resource_name):
				mi.set_surface_override_material(i, _enemy_mat(sm))


static func _enemy_mat(sm: StandardMaterial3D) -> StandardMaterial3D:
	if not _enemy_mats.has(sm.resource_name):
		var d: StandardMaterial3D = sm.duplicate()
		d.albedo_color = ENEMY_TINT[sm.resource_name]
		_enemy_mats[sm.resource_name] = d
	return _enemy_mats[sm.resource_name]


func _add_foam() -> void:
	if _foam_noise == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.03
		n.fractal_octaves = 3
		var nt := NoiseTexture2D.new()
		nt.noise = n
		nt.seamless = true
		nt.width = 128
		nt.height = 128
		_foam_noise = nt
	foam = MeshInstance3D.new()
	var q := QuadMesh.new()
	var length: float = Game.SHIP_SIZE[kind] * 4.0 + 1.5
	var width: float = {"battleship": 5.2, "cruiser": 4.4, "destroyer": 3.6, "patrol": 3.0}[kind]
	q.size = Vector2(width, length)
	q.orientation = PlaneMesh.FACE_Y
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/foam.gdshader")
	sm.set_shader_parameter("noise_tex", _foam_noise)
	q.material = sm
	foam.mesh = q
	foam.position = Vector3(0, 0.12, 0)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)


func _funnel_smoke(f: Node3D) -> void:
	var s := CPUParticles3D.new()
	f.add_child(s)
	s.mesh = Fx._quad(0.9, "smoke")
	s.amount = 10
	s.lifetime = 4.0
	s.local_coords = false
	s.direction = Vector3.UP
	s.spread = 8
	s.initial_velocity_min = 0.8
	s.initial_velocity_max = 1.4
	s.gravity = Vector3(0.5, 0.15, 0.2)
	s.scale_amount_curve = Fx._curve([[0, 0.5], [1, 2.4]])
	s.color_ramp = Fx._ramp([Color(0.3, 0.3, 0.32, 0.0), Color(0.35, 0.35, 0.37, 0.35), Color(0.6, 0.6, 0.62, 0)], [0, 0.15, 1])
	s.emitting = true


## Put the ship on its cells. `grid` converts cells to world positions.
func place(grid: GridView, ship_cells: Array[Vector2i], is_horizontal: bool) -> void:
	cells = ship_cells
	horizontal = is_horizontal
	var c := Vector3.ZERO
	for cell in cells:
		c += grid.cell_world(cell)
	c /= cells.size()
	global_position = Vector3(c.x, 0, c.z)
	_base_y = 0.0
	if horizontal:
		rotation.y = PI / 2 if not enemy else -PI / 2
	else:
		rotation.y = PI if not enemy else 0.0


func set_ghost(on: bool, valid := true) -> void:
	_ghost = on
	foam.visible = not on
	var m: StandardMaterial3D = null
	if on:
		m = StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.3, 1.0, 0.5, 0.45) if valid else Color(1.0, 0.25, 0.2, 0.45)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = m


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if not sunk:
		position.y = _base_y + sin(t * 0.9 + _phase) * 0.07
		model.rotation.z = sin(t * 0.7 + _phase) * 0.012
		model.rotation.x = sin(t * 0.55 + _phase * 1.3) * 0.008
	for tur in turrets:
		tur.rotation.y = lerp_angle(tur.rotation.y, _aim_yaw[tur], 1.0 - exp(-delta * 3.0))
	for g in guns:
		g.rotation.x = lerpf(g.rotation.x, -_aim_pitch, 1.0 - exp(-delta * 3.0))
	if night_lights and searchlights.size() > 0:
		_sweep += delta * 0.25
		for i in searchlights.size():
			var l := searchlights[i]
			l.visible = not sunk
			l.rotation = Vector3(deg_to_rad(-9), PI + (0.7 if i % 2 == 0 else -0.7) + sin(_sweep + i * 2.1) * 0.6, 0)


## Swing every turret that can bear toward `target` (world). Returns the time until they are on target.
func aim_at(target: Vector3) -> float:
	var biggest := 0.0
	for tur in turrets:
		var p: Node3D = tur.get_parent()
		var local := p.global_transform.affine_inverse() * target
		var rel := local - tur.position
		var yaw := atan2(rel.x, rel.z)
		if absf(angle_difference(_rest_yaw[tur], yaw)) < deg_to_rad(150):
			_aim_yaw[tur] = yaw
			biggest = maxf(biggest, absf(angle_difference(tur.rotation.y, yaw)))
	var dist := global_position.distance_to(target)
	_aim_pitch = deg_to_rad(clampf(dist * 0.32, 6, 32))
	return clampf(biggest / 2.2, 0.25, 1.0)


func rest_turrets() -> void:
	for tur in turrets:
		_aim_yaw[tur] = _rest_yaw[tur]
	_aim_pitch = 0.0


## Muzzle that points most toward the target (after aiming).
func best_muzzle(target: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := -2.0
	for m in muzzles:
		var dir := (target - m.global_position).normalized()
		var fwd := m.global_transform.basis.z.normalized()
		var d := fwd.dot(dir)
		if d > best_d:
			best_d = d
			best = m
	return best


func muzzle_flash_all(world: Node) -> void:
	for m in muzzles:
		var tur := m.get_parent().get_parent() as Node3D
		if tur and absf(angle_difference(tur.rotation.y, _aim_yaw.get(tur, tur.rotation.y))) < 0.4:
			Fx.muzzle(world, m.global_position, m.global_transform.basis.z.normalized())


func add_fire(world_pos: Vector3, scale := 1.0) -> void:
	var f := Fx.fire(self, world_pos + Vector3(0, 1.2, 0), scale)
	fires.append(f)


func sink(world: Node) -> void:
	if sunk:
		return
	sunk = true
	for l in searchlights:
		l.visible = false
	var tw := create_tween().set_parallel(true)
	var roll := (1 if randf() < 0.5 else -1) * deg_to_rad(randf_range(18, 35))
	var pitch := deg_to_rad(randf_range(-14, 14))
	tw.tween_property(model, "rotation:z", roll, 3.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(model, "rotation:x", pitch, 4.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", -7.5, 6.5).set_delay(1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(foam, "scale", Vector3(1.6, 1, 1.4), 2.0)
	tw.chain().tween_callback(func():
		for f in fires:
			if is_instance_valid(f):
				f.queue_free()
		fires.clear()
		model.visible = false
		foam.visible = false
	)
	# bubbles and an oil slick left behind
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(func():
		if is_inside_tree():
			Fx.splash(world, global_position + Vector3(0, 0.2, 0), 0.6)
	)
