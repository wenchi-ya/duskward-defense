extends SceneTree

var failures: int = 0
var assertions: int = 0

func check(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func find_button(node: Node, text: String):
	if node is Button and node.text.begins_with(text):
		return node
	for child in node.get_children():
		var result = find_button(child, text)
		if result != null:
			return result
	return null

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	# UI checks do not test audio playback or persist this session override.
	app.save.data.sound = false
	check(app.screen == "menu", "main menu loads")
	find_button(app, "开始守卫").pressed.emit()
	check(app.screen == "levels" and not find_button(app, "06").disabled, "all six completed maps are selectable")
	find_button(app, "01").pressed.emit()
	check(app.screen == "battle" and app.battle.paused, "new game opens paused tutorial")
	find_button(app, "明白了").pressed.emit()
	check(not app.battle.paused, "tutorial confirmation resumes game")
	app.board.clicked.emit(app.battle.pads[0])
	check(app.selected == 0, "board click selects build pad")
	check(app.board.size == Vector2(1440, 900) and app.meteor_button.position.y > 720, "battlefield fills canvas with floating skills and no bottom toolbar")
	app.actions.get_node("build_archer").pressed.emit()
	check(app.battle.towers[0].kind == "archer" and app.battle.gold == 280, "build button creates tower and deducts cost")
	app.board.clicked.emit(app.battle.pads[2])
	app.actions.get_node("build_barracks").pressed.emit()
	check(app.battle.towers[2].kind == "barracks" and app.actions.has_node("rally"), "barracks has a canvas rally flag")
	app.actions.get_node("rally").pressed.emit()
	check(app.targeting == "rally" and not app.actions.visible, "rally command enters road targeting mode")
	var d = app.battle.towers[2].rally
	app.board.clicked.emit(Vector2(1300, 700))
	check(app.targeting == "rally" and app.battle.towers[2].rally == d, "invalid rally click keeps targeting and preserves destination")
	app.board.clicked.emit(app.battle.position_at(d - 30))
	check(app.targeting.is_empty() and is_equal_approx(app.battle.towers[2].rally, d - 30), "road click moves selected barracks rally point")
	app.board.clicked.emit(app.battle.pads[6])
	check(app.actions.position.y >= 70 and app.actions.position.x >= 0, "radial menu at upper pad stays inside canvas")
	app.wave_button.pressed.emit()
	check(app.battle.state == "battle", "wave button starts battle")
	app.meteor_button.pressed.emit()
	check(app.targeting == "meteor", "skill button enters targeting mode")
	app.board.cancelled.emit()
	check(app.targeting.is_empty() and app.selected == -1, "right-click cancellation clears skill and selection")
	app.pause_button.pressed.emit()
	check(app.battle.paused and app.overlay != null, "pause button opens modal and freezes simulation")
	find_button(app.overlay, "继续战斗").pressed.emit()
	check(not app.battle.paused, "resume button restores simulation")
	app._start_game()
	check(app.battle.gold == 360 and app.battle.wave == 0 and app.battle.towers[0] == null, "retry resets previous battle state")
	app._level_select()
	await process_frame
	check(app.screen == "levels", "return to level select stops battle loop")
	app.audio.stop()
	app.audio.stream = null
	await create_timer(0.2).timeout
	app.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
