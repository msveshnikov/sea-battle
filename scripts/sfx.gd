extends Node
## Autoload "Sfx": one-shot sounds (2D and positional), sea ambience and music.

const NAMES := ["cannon", "explosion", "splash", "whistle", "click", "hover", "place", "sonar", "plane",
	"torpedo", "alarm", "victory", "defeat"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _sea: AudioStreamPlayer
var _unlocked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var s: AudioStream = load("res://assets/audio/%s.wav" % n)
		if s:
			_streams[n] = s
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	var m: AudioStreamWAV = load("res://assets/audio/music.wav")
	if m:
		_music.stream = m
	_sea = AudioStreamPlayer.new()
	add_child(_sea)
	var sea: AudioStreamWAV = load("res://assets/audio/sea_loop.wav")
	if sea:
		_sea.stream = sea
	apply_volume()
	if not OS.has_feature("web"):
		start_loops()


## Web browsers only allow audio after the first user gesture.
func _input(event: InputEvent) -> void:
	if not _unlocked and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey):
		_unlocked = true
		start_loops()


func start_loops() -> void:
	if Game.flag("autotest") or Game.flag("mute"):
		return
	if _music.stream and not _music.playing:
		_music.play()
	if _sea.stream and not _sea.playing:
		_sea.play()


func apply_volume() -> void:
	_music.volume_db = linear_to_db(max(Game.music_volume, 0.0001) * 0.55)
	_sea.volume_db = linear_to_db(max(Game.sfx_volume, 0.0001) * 0.35)
	_music.stream_paused = Game.music_volume <= 0.01


func play(name: String, volume := 1.0, pitch := 1.0) -> void:
	if not _streams.has(name) or Game.sfx_volume <= 0.01:
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = linear_to_db(volume * Game.sfx_volume)
			p.pitch_scale = pitch * randf_range(0.96, 1.04)
			p.play()
			return


## Positional sound attached to the 3D world (falls back to 2D when no parent given).
func play_at(name: String, parent: Node, pos: Vector3, volume := 1.0, pitch := 1.0) -> void:
	if not _streams.has(name) or Game.sfx_volume <= 0.01 or parent == null:
		play(name, volume, pitch)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[name]
	p.unit_size = 40.0
	p.max_db = 3.0
	p.volume_db = linear_to_db(volume * Game.sfx_volume) + 4.0
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
