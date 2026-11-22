extends Node
## Autoload "Sfx": one-shot sounds (2D and positional), sea ambience and music.
## Music (CC0, OpenGameArt, see assets/CREDITS.md): a calm track for menus and placement,
## a playlist for battles; switching crossfades between two players.

const MENU_TRACKS := ["res://assets/music/song_of_the_sea.ogg"]
const BATTLE_TRACKS := ["res://assets/music/battle_theme_a.mp3", "res://assets/music/war_on_water_1.ogg",
	"res://assets/music/war_on_water_3.ogg"]

const NAMES := ["cannon", "explosion", "splash", "whistle", "click", "hover", "place", "sonar", "plane",
	"torpedo", "alarm", "victory", "defeat"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_kind := "menu"
var _battle_index := randi() % 3
var _fade: Tween
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
	_music_b = AudioStreamPlayer.new()
	add_child(_music_b)
	for p in [_music, _music_b]:
		p.finished.connect(_on_music_finished.bind(p))
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
	if not _music.playing and not _music_b.playing:
		_start_track(_music, _pick_track(), 0.0)
	if _sea.stream and not _sea.playing:
		_sea.play()


func apply_volume() -> void:
	if _fade == null or not _fade.is_running():
		for p in [_music, _music_b]:
			if p.playing:
				p.volume_db = _music_db()
	_sea.volume_db = linear_to_db(max(Game.sfx_volume, 0.0001) * 0.35)
	_music.stream_paused = Game.music_volume <= 0.01
	_music_b.stream_paused = Game.music_volume <= 0.01


func _music_db() -> float:
	return linear_to_db(maxf(Game.music_volume, 0.0001) * 0.7)


func _pick_track() -> String:
	if _music_kind == "battle":
		_battle_index = (_battle_index + 1) % BATTLE_TRACKS.size()
		return BATTLE_TRACKS[_battle_index]
	return MENU_TRACKS.pick_random()


## "menu" or "battle": crossfade to that kind of music (no-op if it is already playing).
func music(kind: String) -> void:
	if kind == _music_kind and (_music.playing or _music_b.playing):
		return
	_music_kind = kind
	if Game.flag("autotest") or Game.flag("mute") or (OS.has_feature("web") and not _unlocked):
		return
	var old := _music if _music.playing else _music_b
	var new := _music_b if old == _music else _music
	_start_track(new, _pick_track(), 1.5, old)


func _start_track(p: AudioStreamPlayer, path: String, fade: float, old: AudioStreamPlayer = null) -> void:
	var st: AudioStream = load(path)
	if st == null:
		return
	p.stream = st
	p.volume_db = -40.0 if fade > 0.0 else _music_db()
	p.play()
	if fade > 0.0:
		if _fade:
			_fade.kill()
		_fade = create_tween().set_parallel(true)
		_fade.tween_property(p, "volume_db", _music_db(), fade)
		if old and old.playing:
			_fade.tween_property(old, "volume_db", -40.0, fade)
			_fade.chain().tween_callback(old.stop)


## Battle tracks follow each other; the menu track simply repeats.
func _on_music_finished(p: AudioStreamPlayer) -> void:
	_start_track(p, _pick_track(), 0.0)


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
