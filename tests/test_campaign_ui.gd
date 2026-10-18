extends SceneTree
const SaveStore = preload("res://scripts/save_store.gd")
var failures: int = 0
var count: int = 0

func check(condition: bool, message: String) -> void:
	count += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func find_button(node: Node, text: String):
	if node is Button and node.text.begins_with(text):
		return node
	for child in node.get_children():
		var found = find_button(child, text)
		if found != null:
			return found
	return null

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.save = SaveStore.new("res://tests/output/campaign-ui-progress.json")
	app.save.data.sound = false
	app.save.data.completed = ["village_01"]
	app._level_select()
	check(find_button(app, "06") != null and not find_button(app, "06").disabled, "sixth level is directly playable")
	for index in range(6):
		app._start_game(index)
		app._close_modal()
		app._process(0.0)
		check(app.battle.config.index == index and app.hud.text.contains(app.battle.config.name), "HUD and simulation select correct level " + str(index + 1))
		check(app.meteor_button.picture != null and app.reinforce_button.picture != null, "both skill buttons use painted images on level " + str(index + 1))
		app.battle.state = "won"
		app._process(0.0)
		check(app.battle.config.id in app.save.data.completed, "completion records correct map " + str(index + 1))
		if index < 5:
			var next = find_button(app.overlay, "下一关")
			check(next != null, "victory offers next map " + str(index + 1))
			next.pressed.emit()
			check(app.level_index == index + 1 and app.battle.wave == 0, "next-map button starts fresh correct level")
		else:
			check(find_button(app.overlay, "下一关") == null, "final victory does not offer nonexistent seventh map")
	var reload = SaveStore.new("res://tests/output/campaign-ui-progress.json")
	reload.load_data()
	check(reload.data.completed.size() == 6 and "village_01" in reload.data.completed and "volcano_06" in reload.data.completed, "all six completions reload with old progress preserved")
	check(int(reload.data.schema_version) == 1, "campaign preserves existing save schema")
	app.audio.stop()
	await create_timer(0.2).timeout
	app.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d assertions, %d failures" % [count, failures])
	quit(1 if failures > 0 else 0)
