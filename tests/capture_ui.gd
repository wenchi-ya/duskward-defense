extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func screenshot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var result = image.save_png("res://tests/output/" + name + ".png")
	print("CAPTURE ", name, " ", image.get_size(), " result=", result)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await screenshot("menu")
	app._start_game()
	await screenshot("tutorial")
	app._close_modal()
	app.battle.gold = 800
	app.battle.build(0, "archer")
	app.battle.build(2, "barracks")
	app.battle.build(4, "mage")
	app.battle.build(5, "cannon")
	app.battle.start_wave()
	for i in range(900):
		app.battle.step(1.0 / 60)
	app.selected = 1
	app.board.selected = 1
	app._refresh_actions()
	await screenshot("battle-v2")
	app._board_clicked(app.battle.pads[2])
	app._rally()
	var destination = app.battle.position_at(app.battle.towers[2].rally - 50)
	app.board.mouse_position = destination
	await screenshot("rally-v2")
	app._board_clicked(destination)
	for i in range(60):
		app.battle.step(1.0 / 60)
	app._cancel_selection()
	await screenshot("battle-clean-v2")
	app._pause()
	await screenshot("pause")
	app._level_select()
	await screenshot("levels")
	app._settings()
	await screenshot("settings")
	quit()
