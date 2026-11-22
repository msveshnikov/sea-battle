class_name Arena
extends Node3D
## Builds the archipelago from assets/levels/arena_layout.json (written by Blender build_env.py):
## sky, sun, water, scenery, corner buoys, lighthouse beacon and both grids. Also flies projectiles.

const LAYOUT := "res://assets/levels/arena_layout.json"

var layout: Dictionary
var cell := 4.0
var mood := "day"
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var water_mat: ShaderMaterial
var player_grid: GridView
var enemy_grid: GridView
var scenery: Node3D
var buoy_lights: Array[OmniLight3D] = []
var beacon: Node3D
var beacon_spot: SpotLight3D
var fx_root: Node3D
var _plane_scene: PackedScene
var _torpedo_scene: PackedScene
var _shell_scene: PackedScene


func build() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	cell = float(layout["cell"])
	Fx.low = Game.is_low_quality()
	_plane_scene = load("res://assets/ships/plane.gltf")
	_torpedo_scene = load("res://assets/ships/torpedo.gltf")
	_shell_scene = load("res://assets/ships/shell.gltf")
	_build_environment()
	_build_water()
	scenery = (load(layout["scenery"]) as PackedScene).instantiate()
	add_child(scenery)
	_fix_materials(scenery)
	for b in layout["buoys"]:
		var node: Node3D = (load("res://assets/env/buoy.gltf") as PackedScene).instantiate()
		add_child(node)
		node.position = Vector3(b[0], 0, b[1])
		node.set_meta("phase", randf() * TAU)
		var lamp := node.find_child("LIGHT_buoy", true, false) as Node3D
		var l := OmniLight3D.new()
		(lamp if lamp else node).add_child(l)
		l.light_color = Color(1.0, 0.75, 0.3)
		l.omni_range = 9.0
		l.light_energy = 0.0
		buoy_lights.append(l)
		_fix_materials(node)
	var bc: Dictionary = layout["beacon"]
	beacon = scenery.find_child("LIGHT_beacon", true, false) as Node3D
	if beacon:
		beacon_spot = SpotLight3D.new()
		beacon.add_child(beacon_spot)
		beacon_spot.spot_range = 160.0
		beacon_spot.spot_angle = 7.0
		beacon_spot.light_energy = 12.0
		beacon_spot.light_color = Color(1.0, 0.9, 0.65)
		beacon_spot.visible = false
	var g: Dictionary = layout["grids"]
	player_grid = GridView.new()
	add_child(player_grid)
	player_grid.setup(Vector2(g["player"]["x"], g["player"]["z"]), cell, false)
	enemy_grid = GridView.new()
	add_child(enemy_grid)
	enemy_grid.setup(Vector2(g["enemy"]["x"], g["enemy"]["z"]), cell, true)
	fx_root = Node3D.new()
	fx_root.name = "Fx"
	add_child(fx_root)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var cn := FastNoiseLite.new()
	cn.frequency = 0.012
	cn.fractal_octaves = 5
	var ct := NoiseTexture2D.new()
	ct.noise = cn
	ct.seamless = true
	ct.width = 512
	ct.height = 512
	sky_mat.set_shader_parameter("cloud_tex", ct)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.9)
	env.fog_density = 0.003
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = not Fx.low
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.8
	add_child(sun)


func _build_water() -> void:
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	for k in ["normal_a", "normal_b"]:
		var n := FastNoiseLite.new()
		n.frequency = 0.02 if k == "normal_a" else 0.035
		n.fractal_octaves = 4
		n.seed = 1 if k == "normal_a" else 7
		var t := NoiseTexture2D.new()
		t.noise = n
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 6.0
		t.width = 256
		t.height = 256
		water_mat.set_shader_parameter(k, t)
	var fn := FastNoiseLite.new()
	fn.frequency = 0.04
	fn.fractal_octaves = 3
	var ft := NoiseTexture2D.new()
	ft.noise = fn
	ft.seamless = true
	ft.width = 256
	ft.height = 256
	water_mat.set_shader_parameter("foam_noise", ft)
	var islands := PackedVector4Array()
	for i in layout["islands"]:
		islands.append(Vector4(i["x"], i["z"], i["r"], 0))
	water_mat.set_shader_parameter("islands", islands)
	water_mat.set_shader_parameter("island_count", min(islands.size(), 32))
	var pm := PlaneMesh.new()
	pm.size = Vector2(460, 460)
	var sub := 110 if Fx.low else 200
	pm.subdivide_width = sub
	pm.subdivide_depth = sub
	var w := MeshInstance3D.new()
	w.mesh = pm
	w.material_override = water_mat
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)
	var far_mat: ShaderMaterial = water_mat.duplicate()
	far_mat.set_shader_parameter("flat_far", 1.0)
	var fp := PlaneMesh.new()
	fp.size = Vector2(5000, 5000)
	var far := MeshInstance3D.new()
	far.mesh = fp
	far.position.y = -0.35
	far.material_override = far_mat
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)
	set_meta("far_mat", far_mat)


## glTF leaves: alpha scissor; emissive windows/lamps follow the mood.
func _fix_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var sm: StandardMaterial3D = m
				if sm.resource_name == "palm_leaf":
					sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					sm.alpha_scissor_threshold = 0.5
					sm.cull_mode = BaseMaterial3D.CULL_DISABLED
				if sm.resource_name in ["windows", "lamp", "flare"]:
					sm.set_meta("emissive", true)


func _set_emission(root: Node, energy: float) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(i)
			if m is StandardMaterial3D and m.resource_name in ["windows", "lamp"]:
				(m as StandardMaterial3D).emission_energy_multiplier = energy


func apply_mood(name: String) -> void:
	mood = name
	var m: Dictionary = layout["moods"][name]
	var sd := Vector3(m["sun_dir"][0], m["sun_dir"][1], m["sun_dir"][2]).normalized()
	sun.look_at_from_position(Vector3.ZERO, sd, Vector3.UP if absf(sd.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = Color(m["sun_color"][0], m["sun_color"][1], m["sun_color"][2])
	sun.light_energy = m["sun_energy"]
	sky_mat.set_shader_parameter("sun_dir", -sd)
	sky_mat.set_shader_parameter("top_color", Color(m["sky_top"][0], m["sky_top"][1], m["sky_top"][2]))
	sky_mat.set_shader_parameter("horizon_color", Color(m["sky_horizon"][0], m["sky_horizon"][1], m["sky_horizon"][2]))
	sky_mat.set_shader_parameter("sun_color", sun.light_color)
	sky_mat.set_shader_parameter("stars", 1.0 if name == "night" else 0.0)
	sky_mat.set_shader_parameter("cloud_amount", 0.5 if name != "night" else 0.3)
	sky_mat.set_shader_parameter("cloud_color", Color(1, 0.8, 0.7) if name == "sunset" else (Color(0.25, 0.3, 0.45) if name == "night" else Color(1, 1, 1)))
	sky_mat.set_shader_parameter("sun_size", 0.9994 if name != "night" else 0.99965)
	env.ambient_light_energy = m["ambient"]
	env.fog_density = m["fog"]
	env.fog_light_color = Color(m["sky_horizon"][0], m["sky_horizon"][1], m["sky_horizon"][2])
	for mat in [water_mat, get_meta("far_mat")]:
		mat.set_shader_parameter("deep_color", Color(m["water_deep"][0], m["water_deep"][1], m["water_deep"][2]))
		mat.set_shader_parameter("shallow_color", Color(m["water_shallow"][0], m["water_shallow"][1], m["water_shallow"][2]))
		mat.set_shader_parameter("sparkle", 1.0 if name != "night" else 0.3)
	var lights: bool = m["lights"]
	ShipView.night_lights = name == "night"
	_set_emission(scenery, 1.6 if lights else 0.0)
	for l in buoy_lights:
		l.light_energy = 1.5 if lights else 0.0
	if beacon_spot:
		beacon_spot.visible = lights
	player_grid.set_intensity(1.0 if name == "day" else 1.35)
	enemy_grid.set_intensity(1.0 if name == "day" else 1.35)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if beacon_spot and beacon_spot.visible:
		beacon.rotation.y += delta * 0.9
		beacon_spot.rotation.x = deg_to_rad(-6)
	for i in buoy_lights.size():
		var l := buoy_lights[i]
		if l.light_energy > 0.0 or mood != "day":
			l.light_energy = 1.6 if fmod(t + i * 0.37, 2.0) < 0.35 else 0.15
	for b in get_children():
		if b.has_meta("phase"):
			var ph: float = b.get_meta("phase")
			b.position.y = sin(t * 1.2 + ph) * 0.18
			b.rotation.x = sin(t * 0.9 + ph) * 0.06
			b.rotation.z = cos(t * 1.1 + ph) * 0.06


# ------------------------------------------------------------------ projectiles
## Ballistic shell from `from` to `to`; awaits until impact.
func fly_shell(from: Vector3, to: Vector3, time := 1.3) -> void:
	var shell: Node3D = _shell_scene.instantiate()
	fx_root.add_child(shell)
	shell.global_position = from
	Fx.trail(shell, Color(0.95, 0.92, 0.88, 0.5), 0.8, 1.4)
	var glow := OmniLight3D.new()
	shell.add_child(glow)
	glow.light_color = Color(1, 0.6, 0.3)
	glow.light_energy = 1.2
	glow.omni_range = 4.0
	var height := clampf(from.distance_to(to) * 0.28, 6.0, 26.0)
	var steps := 0.0
	var start := Time.get_ticks_msec() / 1000.0
	var prev := from
	while true:
		await get_tree().process_frame
		var u := clampf((Time.get_ticks_msec() / 1000.0 - start) / time, 0.0, 1.0)
		var p := from.lerp(to, u) + Vector3(0, 4.0 * height * u * (1.0 - u), 0)
		shell.global_position = p
		if p.distance_to(prev) > 0.001:
			shell.look_at(p + (p - prev), Vector3.UP)
			shell.rotate_object_local(Vector3.UP, PI)
		prev = p
		if u >= 1.0:
			break
	_detach_trail(shell)
	shell.queue_free()


func _detach_trail(n: Node3D) -> void:
	for c in n.get_children():
		if c is CPUParticles3D:
			var gp: Vector3 = c.global_position
			n.remove_child(c)
			fx_root.add_child(c)
			c.global_position = gp
			c.emitting = false
			get_tree().create_timer(c.lifetime + 0.2).timeout.connect(c.queue_free)


## Torpedo along a straight line at the surface, leaving a white wake.
func run_torpedo(from: Vector3, to: Vector3, speed := 22.0) -> void:
	var t: Node3D = _torpedo_scene.instantiate()
	fx_root.add_child(t)
	t.global_position = from + Vector3(0, -0.15, 0)
	t.look_at(to + Vector3(0, -0.15, 0), Vector3.UP)
	t.rotate_object_local(Vector3.UP, PI)
	Fx.trail(t, Color(1, 1, 1, 0.75), 1.1, 2.6)
	var dist := from.distance_to(to)
	var tw := create_tween()
	tw.tween_property(t, "global_position", to + Vector3(0, -0.15, 0), dist / speed)
	await tw.finished
	_detach_trail(t)
	t.queue_free()


## Plane flies over `over` along +X/-X, returns after it passes; `drop` called above the target.
func fly_plane(over: Vector3, from_side := -1.0, drop: Callable = Callable()) -> void:
	var p: Node3D = _plane_scene.instantiate()
	fx_root.add_child(p)
	var start := over + Vector3(from_side * 110.0, 22.0, 18.0)
	var end := over + Vector3(-from_side * 110.0, 26.0, -10.0)
	p.global_position = start
	p.look_at(end, Vector3.UP)
	p.rotate_object_local(Vector3.UP, PI)
	var prop := p.find_child("PROP", true, false) as Node3D
	Sfx.play("plane", 0.9)
	var time := 3.4
	var t0 := Time.get_ticks_msec() / 1000.0
	var dropped := false
	while true:
		await get_tree().process_frame
		var u := clampf((Time.get_ticks_msec() / 1000.0 - t0) / time, 0.0, 1.0)
		p.global_position = start.lerp(end, u)
		p.rotation.z = sin(u * PI) * 0.25 * from_side
		if prop:
			prop.rotate_object_local(Vector3.FORWARD, 0.9)
		if not dropped and u >= 0.5:
			dropped = true
			if drop.is_valid():
				drop.call()
		if u >= 1.0:
			break
	p.queue_free()


## Bomb dropping from a height onto a point; awaits impact.
func drop_bomb(from: Vector3, to: Vector3, time := 0.9) -> void:
	var b: Node3D = _shell_scene.instantiate()
	fx_root.add_child(b)
	b.global_position = from
	b.scale = Vector3.ONE * 1.6
	var tw := create_tween()
	tw.tween_property(b, "global_position", to, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(b, "rotation:x", -PI / 2, time)
	await tw.finished
	b.queue_free()
