extends SceneTree
const Director = preload("res://scripts/audio_director.gd")
const Battle = preload("res://scripts/battle.gd")
const SaveStore = preload("res://scripts/save_store.gd")
var count: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	count += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var director = Director.new()
	root.add_child(director)
	var settings = {"sound": true, "volume": 0.5, "music": true, "music_volume": 0.4}
	director.configure(settings)
	for kind in Director.EFFECTS:
		check(director.streams[kind] != null and director.streams[kind].get_length() > 0.05, "effect loads: " + kind)
	for track in Director.TRACKS:
		check(director.tracks[track].get_length() > 30 and director.tracks[track].loop_mode == AudioStreamWAV.LOOP_FORWARD, "long looping music: " + track)
	director.set_music("hearth")
	await process_frame
	check(director.music.playing and director.current_track == "hearth", "menu starts background music")
	check(director.play_event("arrow") and not director.play_event("arrow"), "dense identical attacks are throttled")
	settings.sound = false
	director.configure(settings)
	check(not director.play_event("build") and director.players.all(func(player): return not player.playing) and director.music.playing, "effects mute immediately without muting music")
	settings.music = false
	director.configure(settings)
	check(not director.music.playing, "music can be muted independently")
	settings.music = true
	settings.music_volume = 0
	director.configure(settings)
	check(not director.music.playing, "zero music volume stops playback")
	settings.music_volume = 0.6
	settings.sound = true
	director.configure(settings)
	director.set_music("last_bastion")
	check(director.music.playing and director.music.stream == director.tracks.last_bastion, "battle theme changes without adding another player")
	for i in range(100):
		director.last_played.clear()
		director.play_event("arrow")
	check(director.players.size() == 12 and director.get_child_count() == 13, "sound pool remains bounded during dense combat")
	check(director.play_event("victory"), "victory cue can replace a crowded combat effect")
	director.clear_combat()
	check(director.players.all(func(player): return not player.playing), "leaving battle clears lingering effects")
	var game = Battle.new()
	game.build(0, "archer")
	game.start_wave()
	check("build" in game.audio_events and "wave" in game.audio_events, "simulation publishes successful actions")
	game.audio_events.clear()
	game.build(0, "archer")
	check(game.audio_events.is_empty(), "failed construction makes no success sound")
	game.queue.clear()
	var enemy = game.spawn("brute")
	enemy.d = game.nearest_distance(game.pads[0])
	game.step(0.01)
	check("arrow" in game.audio_events, "projectile sound is emitted at release")
	game.audio_events.clear()
	game.cast("meteor", game.position_at(enemy.d))
	check(not "meteor" in game.audio_events, "meteor explosion waits for impact")
	game.paused = true
	game.step(1)
	check(game.audio_events.is_empty(), "paused combat emits no attacks or explosions")
	game.paused = false
	game.step(0.37)
	check("meteor" in game.audio_events, "meteor sound aligns with its damage frame")
	for i in range(1000):
		game._audio("arrow")
	check(game.audio_events.size() == 64, "simulation event queue is bounded without an audio consumer")
	var legacy_path = "res://tests/output/audio-legacy.json"
	var file = FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string('{"schema_version":1,"completed":["village_01"],"sound":false,"volume":0.7}')
	file.close()
	var store = SaveStore.new(legacy_path)
	store.load_data()
	check(store.data.completed == ["village_01"] and not store.data.sound and is_equal_approx(store.data.volume, 0.7) and store.data.music, "old saves retain progress and effects settings with music defaults")
	check(not store._valid({"schema_version":1,"music":"yes"}) and not store._valid({"schema_version":1,"music_volume":[]}), "invalid new audio settings rejected")
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.save = SaveStore.new("res://tests/output/audio-settings.json")
	app.audio.configure(app.save.data)
	check(find_button(app, "查看画风") == null, "concept preview entry removed from main menu")
	app._settings()
	app.find_child("MusicEnabled", true, false).button_pressed = false
	app.find_child("MusicVolume", true, false).value = 0.25
	app.find_child("SoundVolume", true, false).value = 0.65
	var reloaded = SaveStore.new(app.save.path)
	reloaded.load_data()
	check(not reloaded.data.music and is_equal_approx(reloaded.data.music_volume, 0.25) and is_equal_approx(reloaded.data.volume, 0.65), "music and effect controls save independently")
	var old_damage = {"archer":17.0, "barracks":8.0, "mage":41.0, "cannon":35.0}
	for kind in old_damage:
		check(is_equal_approx(game.config.towers[kind].damage, old_damage[kind]*0.94), "six percent direct damage reduction: " + kind)
	var melee = Battle.new()
	melee.gold = 1000
	melee.build(0, "barracks")
	var foe = melee.spawn("brute")
	foe.d = melee.soldiers[0].d
	melee._update_soldiers(0.01)
	check(is_equal_approx(melee.impacts[0].damage, 8*0.94), "level-one soldier actually uses reduced damage")
	melee.upgrade(0)
	melee.upgrade(0)
	melee.upgrade(0, 1)
	melee.impacts.clear()
	melee.soldiers[0].attack = 0
	melee._update_soldiers(0.01)
	check(is_equal_approx(melee.impacts[0].damage, (8+3*7)*1.8*0.94), "final soldier branch retains exactly six percent reduction")
	app.audio.stop()
	director.stop()
	# Allow the Dummy audio mixing thread to retire stopped WAV playbacks.
	await create_timer(0.2).timeout
	app.queue_free()
	director.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d assertions, %d failures" % [count, failures])
	quit(1 if failures else 0)

func find_button(node: Node, text: String):
	if node is Button and node.text.begins_with(text):
		return node
	for child in node.get_children():
		var result = find_button(child, text)
		if result != null:
			return result
	return null
