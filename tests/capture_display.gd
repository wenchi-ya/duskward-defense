extends SceneTree
var failures: int = 0
var count: int = 0

func check(ok: bool, label: String) -> void:
	count += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png("res://tests/output/" + name + ".png")
	print("CAPTURE ", name, " size=", image.get_size(), " canvas=", root.get_visible_rect(), " transform=", root.get_final_transform())

func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.save.data.sound = false
	app.save.data.music = false
	app.audio.configure(app.save.data)
	app.set_process(false)
	await capture("menu-v4")
	app._set_fullscreen(true)
	await create_timer(0.2).timeout
	await capture("menu-fullscreen-v4.1")
	app._settings()
	await capture("settings-v4")
	app._set_fullscreen(false)
	await create_timer(0.2).timeout
	app._start_game(0)
	app._close_modal()
	app.battle.build(0, "archer")
	app.battle.build(2, "barracks")
	app.battle.step(0.8)
	app._process(0)
	for dimensions in [Vector2i(1280,800), Vector2i(1366,768), Vector2i(1920,1080), Vector2i(2560,1080), Vector2i(960,600)]:
		DisplayServer.window_set_size(dimensions)
		await create_timer(0.2).timeout
		await process_frame
		await process_frame
		var actual = DisplayServer.window_get_size()
		check(actual == dimensions, "operating system applied requested window size: " + str(dimensions))
		var transform = root.get_final_transform()
		var bounds = transform * Rect2(Vector2.ZERO, Vector2(1440,900))
		check(bounds.position.is_equal_approx(Vector2.ZERO) and bounds.size.is_equal_approx(Vector2(actual)), "canvas covers physical window without bars: " + str(dimensions))
		app._cancel_selection()
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = transform * app.battle.pads[1]
		click.global_position = click.position
		root.push_input(click)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click)
		check(app.selected == 1, "physical mouse position selects correct tower pad: " + str(dimensions))
		await capture("display-%dx%d-v4" % [dimensions.x, dimensions.y])
	# Exercise the actual maximize and full-screen paths, then restore the hidden test window.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await capture("display-maximized-v4")
	var bounds = root.get_final_transform() * Rect2(Vector2.ZERO, Vector2(1440,900))
	check(bounds.size.is_equal_approx(Vector2(DisplayServer.window_get_size())), "maximized canvas fills client area")
	app._set_fullscreen(true)
	await capture("display-fullscreen-v4")
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "fullscreen enters correct display mode")
	bounds = root.get_final_transform() * Rect2(Vector2.ZERO, Vector2(1440,900))
	check(bounds.size.is_equal_approx(Vector2(DisplayServer.window_get_size())), "fullscreen canvas covers screen")
	app._set_fullscreen(false)
	await process_frame
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "fullscreen toggles back to windowed")
	app.audio.stop()
	app.queue_free()
	await process_frame
	print("RESULT: %d assertions, %d failures" % [count, failures])
	quit(1 if failures else 0)
