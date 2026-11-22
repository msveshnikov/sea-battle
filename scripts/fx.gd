class_name Fx
extends RefCounted
## Particle effects built in code (CPUParticles3D: identical on Forward+/Mobile/Compatibility).

static var _soft: Texture2D
static var _mats := {}
static var low := false


static func soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


static func mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.albedo_texture = soft_tex()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	match kind:
		"fire":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		"smoke", "water":
			# lit, so smoke and spray darken at night instead of glowing
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			m.roughness = 1.0
			m.metallic_specular = 0.0
		"debris":
			m.albedo_texture = null
			m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_mats[kind] = m
	return m


static func _quad(size: float, kind: String) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat(kind)
	return q


static func _ramp(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	return c


static func _particles(parent: Node, pos: Vector3, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = one_shot
	p.local_coords = false
	p.emitting = false
	parent.add_child(p)
	p.global_position = pos
	if one_shot:
		p.finished.connect(p.queue_free)
	return p


static func explosion(parent: Node, pos: Vector3, scale := 1.0) -> void:
	var f := _particles(parent, pos, true)
	f.mesh = _quad(2.6 * scale, "fire")
	f.amount = 22 if low else 40
	f.lifetime = 0.9
	f.explosiveness = 0.95
	f.direction = Vector3.UP
	f.spread = 75
	f.initial_velocity_min = 4.0 * scale
	f.initial_velocity_max = 11.0 * scale
	f.gravity = Vector3(0, 2, 0)
	f.damping_min = 6
	f.damping_max = 9
	f.scale_amount_curve = _curve([[0, 0.6], [0.25, 1.4], [1, 0.3]])
	f.color_ramp = _ramp([Color(1, 1, 0.8, 1), Color(1, 0.6, 0.15, 1), Color(0.8, 0.2, 0.05, 0.8), Color(0.15, 0.1, 0.08, 0)], [0, 0.2, 0.55, 1])
	f.emitting = true
	var s := _particles(parent, pos + Vector3(0, 1, 0), true)
	s.mesh = _quad(3.5 * scale, "smoke")
	s.amount = 12 if low else 24
	s.lifetime = 3.2
	s.explosiveness = 0.7
	s.direction = Vector3.UP
	s.spread = 40
	s.initial_velocity_min = 2.0
	s.initial_velocity_max = 5.0
	s.gravity = Vector3(0.6, 1.4, 0)
	s.damping_min = 1.5
	s.damping_max = 2.5
	s.scale_amount_curve = _curve([[0, 0.5], [1, 2.2]])
	s.color_ramp = _ramp([Color(0.25, 0.22, 0.2, 0.0), Color(0.22, 0.2, 0.19, 0.75), Color(0.35, 0.34, 0.34, 0)], [0, 0.15, 1])
	s.emitting = true
	var d := _particles(parent, pos, true)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 0.12, 0.35) * scale
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.12, 0.12, 0.13)
	bm.material = dm
	d.mesh = bm
	d.amount = 8 if low else 16
	d.lifetime = 1.6
	d.explosiveness = 1.0
	d.direction = Vector3.UP
	d.spread = 50
	d.initial_velocity_min = 7
	d.initial_velocity_max = 14
	d.gravity = Vector3(0, -18, 0)
	d.angular_velocity_min = -400
	d.angular_velocity_max = 400
	d.particle_flag_rotate_y = true
	d.emitting = true
	flash(parent, pos + Vector3(0, 1.5, 0), Color(1, 0.6, 0.25), 14.0 * scale, 0.6)
	ring(parent, pos, Color(1, 0.85, 0.6, 0.8), 9.0 * scale, 0.7)


static func splash(parent: Node, pos: Vector3, scale := 1.0) -> void:
	var c := _particles(parent, pos, true)
	c.mesh = _quad(1.3 * scale, "water")
	c.amount = 26 if low else 48
	c.lifetime = 1.6
	c.explosiveness = 0.9
	c.direction = Vector3.UP
	c.spread = 12
	c.initial_velocity_min = 9 * scale
	c.initial_velocity_max = 17 * scale
	c.gravity = Vector3(0, -16, 0)
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 0.6 * scale
	c.scale_amount_curve = _curve([[0, 0.7], [0.5, 1.3], [1, 0.9]])
	c.color_ramp = _ramp([Color(1, 1, 1, 0.95), Color(0.85, 0.95, 1, 0.7), Color(0.8, 0.92, 1, 0)], [0, 0.6, 1])
	c.emitting = true
	var m := _particles(parent, pos, true)
	m.mesh = _quad(2.0 * scale, "water")
	m.amount = 12 if low else 22
	m.lifetime = 1.6
	m.explosiveness = 0.85
	m.direction = Vector3.UP
	m.spread = 60
	m.initial_velocity_min = 2
	m.initial_velocity_max = 6
	m.gravity = Vector3(0, -3, 0)
	m.scale_amount_curve = _curve([[0, 0.4], [1, 1.4]])
	m.color_ramp = _ramp([Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)], [0, 1])
	m.emitting = true
	ring(parent, pos, Color(1, 1, 1, 0.9), 6.0 * scale, 1.2)


static func muzzle(parent: Node, pos: Vector3, dir: Vector3) -> void:
	var f := _particles(parent, pos, true)
	f.mesh = _quad(1.4, "fire")
	f.amount = 14
	f.lifetime = 0.35
	f.explosiveness = 1.0
	f.direction = dir
	f.spread = 18
	f.initial_velocity_min = 8
	f.initial_velocity_max = 18
	f.damping_min = 20
	f.damping_max = 30
	f.color_ramp = _ramp([Color(1, 1, 0.8, 1), Color(1, 0.5, 0.1, 0.8), Color(0.3, 0.2, 0.1, 0)], [0, 0.4, 1])
	f.emitting = true
	var s := _particles(parent, pos, true)
	s.mesh = _quad(2.2, "smoke")
	s.amount = 10
	s.lifetime = 2.0
	s.explosiveness = 0.9
	s.direction = dir
	s.spread = 25
	s.initial_velocity_min = 3
	s.initial_velocity_max = 7
	s.damping_min = 3
	s.damping_max = 4
	s.gravity = Vector3(0, 0.6, 0)
	s.scale_amount_curve = _curve([[0, 0.4], [1, 2.0]])
	s.color_ramp = _ramp([Color(0.85, 0.82, 0.78, 0.7), Color(0.8, 0.8, 0.8, 0)], [0, 1])
	s.emitting = true
	flash(parent, pos, Color(1, 0.7, 0.3), 8.0, 0.25)


## Long-lived fire + smoke column on a burning hull or a hit cell. Returns the node to free later.
static func fire(parent: Node, pos: Vector3, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var f := CPUParticles3D.new()
	root.add_child(f)
	f.mesh = _quad(1.3 * scale, "fire")
	f.amount = 12 if low else 22
	f.lifetime = 0.8
	f.direction = Vector3.UP
	f.spread = 15
	f.initial_velocity_min = 1.5
	f.initial_velocity_max = 3.0
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 0.35 * scale
	f.scale_amount_curve = _curve([[0, 0.5], [0.3, 1.0], [1, 0.2]])
	f.color_ramp = _ramp([Color(1, 0.9, 0.5, 0.9), Color(1, 0.45, 0.1, 0.8), Color(0.4, 0.1, 0.05, 0)], [0, 0.45, 1])
	f.local_coords = false
	f.emitting = true
	var s := CPUParticles3D.new()
	root.add_child(s)
	s.position = Vector3(0, 0.8, 0)
	s.mesh = _quad(2.4 * scale, "smoke")
	s.amount = 14 if low else 28
	s.lifetime = 5.0
	s.direction = Vector3.UP
	s.spread = 10
	s.initial_velocity_min = 2.0
	s.initial_velocity_max = 3.2
	s.gravity = Vector3(0.9, 0.4, 0.2)
	s.scale_amount_curve = _curve([[0, 0.4], [1, 2.6]])
	s.color_ramp = _ramp([Color(0.1, 0.09, 0.09, 0.0), Color(0.12, 0.11, 0.11, 0.7), Color(0.3, 0.3, 0.32, 0)], [0, 0.1, 1])
	s.local_coords = false
	s.emitting = true
	var l := OmniLight3D.new()
	root.add_child(l)
	l.position = Vector3(0, 1.0, 0)
	l.light_color = Color(1, 0.55, 0.2)
	l.light_energy = 1.6 * scale
	l.omni_range = 7.0 * scale
	l.shadow_enabled = false
	l.set_meta("flicker", true)
	l.set_script(load("res://scripts/flicker.gd"))
	return root


## Thin smoke trail that follows a node (shell, torpedo wake, plane). Detaches on target free.
static func trail(target: Node3D, color := Color(0.9, 0.9, 0.9, 0.55), size := 0.9, lifetime := 1.6) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	target.add_child(s)
	s.mesh = _quad(size, "smoke")
	s.amount = 40 if low else 70
	s.lifetime = lifetime
	s.local_coords = false
	s.direction = Vector3.UP
	s.spread = 180
	s.initial_velocity_min = 0.1
	s.initial_velocity_max = 0.4
	s.scale_amount_curve = _curve([[0, 0.5], [1, 2.0]])
	s.color_ramp = _ramp([color, Color(color.r, color.g, color.b, 0)], [0, 1])
	s.emitting = true
	return s


static func flash(parent: Node, pos: Vector3, color: Color, energy: float, time: float) -> void:
	var l := OmniLight3D.new()
	parent.add_child(l)
	l.global_position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 22.0
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## Expanding flat ring on the water (shock wave / splash ring).
static func ring(parent: Node, pos: Vector3, color: Color, radius: float, time: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	tm.material = m
	mi.mesh = tm
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.15, 0)
	mi.scale = Vector3(0.5, 0.05, 0.5)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.05, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Expanding radar sweep circle (amber), used by the Radar ability.
static func sonar(parent: Node, pos: Vector3, radius: float) -> void:
	for k in 3:
		var tw := parent.create_tween()
		tw.tween_interval(k * 0.35)
		tw.tween_callback(func(): ring(parent, pos, Color(1, 0.75, 0.2, 0.9), radius, 1.1))
