class_name CameraRig
extends Camera3D
## Cinematic camera: glides between presets (pos + target), lets the player orbit/zoom around the
## current target (drag with right mouse / two fingers or one finger in free mode, wheel/pinch),
## and shakes on big explosions.

var target := Vector3.ZERO
var base_offset := Vector3(0, 40, 40)
var user_yaw := 0.0
var user_pitch := 0.0
var user_zoom := 1.0
var _cur_target := Vector3.ZERO
var _cur_offset := Vector3(0, 40, 40)
var _shake := 0.0
var _tween: Tween
var _drag_from := Vector2.ZERO
var _dragging := false
var _touches := {}
var _pinch_d := 0.0
var smooth := 2.5
var orbit_enabled := true
var drag_moved := false


func _ready() -> void:
	fov = 50.0
	near = 0.3
	far = 1500.0


func go(pos: Vector3, tgt: Vector3, time := 1.4, reset_user := true) -> void:
	target = tgt
	base_offset = pos - tgt
	if reset_user:
		user_yaw = 0.0
		user_pitch = 0.0
		user_zoom = 1.0
	if time <= 0.0:
		_cur_target = target
		_cur_offset = base_offset
		_apply()
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_cur_target", target, time)
	_tween.tween_property(self, "_cur_offset", base_offset, time)


func go_preset(p: Dictionary, time := 1.4) -> void:
	go(Vector3(p["pos"][0], p["pos"][1], p["pos"][2]), Vector3(p["target"][0], p["target"][1], p["target"][2]), time)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 1.6)
	_apply()


func _apply() -> void:
	var off := _cur_offset
	var dist := off.length() * user_zoom
	var dir := off.normalized()
	var yaw_q := Basis(Vector3.UP, user_yaw)
	dir = yaw_q * dir
	var right := dir.cross(Vector3.UP).normalized()
	if right.length() > 0.01:
		dir = Basis(right, user_pitch) * dir
	dir.y = clampf(dir.y, 0.12, 0.98)
	dir = dir.normalized()
	var p := _cur_target + dir * dist
	if _shake > 0.0:
		p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.6
	global_position = p
	if p.distance_to(_cur_target) > 0.01:
		look_at(_cur_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if not orbit_enabled:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			user_zoom = clampf(user_zoom * 0.9, 0.45, 1.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			user_zoom = clampf(user_zoom * 1.1, 0.45, 1.6)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		_orbit(mm.relative)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_d = 0.0
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_d > 0.0:
				user_zoom = clampf(user_zoom * _pinch_d / maxf(d, 1.0), 0.45, 1.6)
			_pinch_d = d
			_orbit(sd.relative * 0.5)


func _orbit(rel: Vector2) -> void:
	user_yaw = clampf(user_yaw - rel.x * 0.005, -1.3, 1.3)
	user_pitch = clampf(user_pitch - rel.y * 0.004, -0.5, 0.45)


## Ray from the screen point onto the water plane (y = 0).
func water_point(screen: Vector2) -> Variant:
	var o := project_ray_origin(screen)
	var d := project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return null
	var t := -o.y / d.y
	if t < 0:
		return null
	return o + d * t
