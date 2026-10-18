extends Node
## A persistent, bounded audio service. Combat publishes events, never plays audio itself.
const EFFECTS = ["ui", "build", "upgrade", "arrow", "magic", "cannon", "melee", "death", "meteor", "reinforce", "wave", "victory", "defeat", "leak"]
const TRACKS = ["hearth", "border_watch", "last_bastion"]
const POOL_SIZE = 12
const GAP = {"arrow": 0.09, "magic": 0.12, "cannon": 0.18, "melee": 0.12, "death": 0.12, "leak": 0.25}
const LEVEL = {"arrow": 0.5, "magic": 0.55, "cannon": 0.65, "melee": 0.5, "death": 0.45}
var settings: Dictionary = {}
var music: AudioStreamPlayer
var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var tracks: Dictionary = {}
var last_played: Dictionary = {}
var current_track: String = ""
var fade: Tween
var music_gain: float = 0.0

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	for kind in EFFECTS:
		streams[kind] = AudioStreamWAV.load_from_file("res://audio/sfx/%s.wav" % kind)
	for name in TRACKS:
		var stream = AudioStreamWAV.load_from_file("res://audio/music/%s.wav" % name)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 4 # Stereo, signed 16-bit PCM.
		tracks[name] = stream
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		add_child(player)
		players.append(player)

func configure(values: Dictionary) -> void:
	settings = values
	_update_music_volume()
	if not settings.get("sound", true) or float(settings.get("volume", 0.5)) <= 0:
		for player in players:
			player.stop()
	else:
		for player in players:
			player.volume_db = linear_to_db(maxf(0.0001, float(settings.get("volume", 0.5)) * float(player.get_meta("gain", 1.0))))
	if settings.get("music", true) and float(settings.get("music_volume", 0.4)) > 0 and not current_track.is_empty():
		if not music.playing:
			music.play()
	else:
		music.stop()

func set_music(track: String) -> void:
	if current_track == track:
		return
	if is_instance_valid(fade):
		fade.kill()
	current_track = track
	music.stop()
	music.stream = tracks[track]
	music_gain = 0.0
	_update_music_volume()
	configure(settings)
	fade = create_tween()
	fade.tween_method(_set_music_gain, 0.0, 1.0, 0.7)

func _set_music_gain(value: float) -> void:
	music_gain = value
	_update_music_volume()

func _update_music_volume() -> void:
	if music != null:
		music.volume_db = linear_to_db(maxf(0.0001, float(settings.get("music_volume", 0.4)) * music_gain * 0.65))

func play_event(kind: String) -> bool:
	if not settings.get("sound", true) or float(settings.get("volume", 0.5)) <= 0 or not streams.has(kind):
		return false
	var now = Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(kind, -100.0)) < float(GAP.get(kind, 0.04)):
		return false
	var available: AudioStreamPlayer = null
	for player in players:
		if not player.playing:
			available = player
			break
	# Critical cues can replace a combat sound, but a projectile never cuts a victory cue.
	if available == null and kind in ["meteor", "wave", "victory", "defeat", "leak", "build", "upgrade", "reinforce", "ui"]:
		for player in players:
			if player.get_meta("kind", "") in ["arrow", "magic", "cannon", "melee", "death"]:
				available = player
				break
	if available == null:
		return false
	last_played[kind] = now
	available.stop()
	available.stream = streams[kind]
	available.set_meta("kind", kind)
	available.set_meta("gain", float(LEVEL.get(kind, 0.8)))
	available.volume_db = linear_to_db(float(settings.get("volume", 0.5)) * float(available.get_meta("gain")))
	available.play()
	return true

func clear_combat() -> void:
	for player in players:
		player.stop()
	last_played.clear()

# Compatibility with older diagnostic scripts that called the old single player.
func stop() -> void:
	if is_instance_valid(fade):
		fade.kill()
	clear_combat()
	music.stop()
	music.stream = null
	for player in players:
		player.stream = null

func _exit_tree() -> void:
	stop()

var stream: AudioStream:
	get:
		return music.stream if music != null else null
	set(value):
		if music != null:
			music.stream = value
