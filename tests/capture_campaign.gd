extends SceneTree
const VisualAssets = preload("res://scripts/visual_assets.gd")

class Gallery extends Control:
	var assets
	var display_font: Font
	var units: bool = false
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1440, 900), Color("d3c6a0"))
		draw_string(display_font, Vector2(45, 55), "连续动作帧 · 行走与振翅" if units else "建筑成长 · 一级、二级、三级与两种四级分支", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("344436"))
		var kinds = ["soldier", "goblin", "wolf", "brute", "bat", "shaman"] if units else ["archer", "barracks", "mage", "cannon"]
		for row in range(kinds.size()):
			for column in range(6 if units else 5):
				var kind = kinds[row]
				var frame: Dictionary
				if units:
					frame = assets.unit(kind, {"moving": true, "walk_distance": column * (7 if kind == "wolf" else (6 if kind == "brute" else 5)), "swing": 0.0})
				else:
					frame = assets.tower(kind, mini(column + 1, 4), 1 if column == 4 else 0)
				var p = Vector2(145 + column * (225 if units else 275), (205 if units else 235) + row * (132 if units else 190))
				var rect: Rect2 = frame.rect
				var factor = (78.0 if units else 145.0) / float(frame.reference_height)
				if not units:
					factor = minf([94.0, 112.0, 132.0, 150.0, 150.0][column] / rect.size.x, [105.0, 130.0, 155.0, 175.0, 175.0][column] / rect.size.y)
				var dimensions = rect.size * factor
				draw_texture_rect_region(frame.texture, Rect2(p - Vector2(dimensions.x / 2, dimensions.y), dimensions), rect)
				var label = str(column + 1) if units else ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ A", "Ⅳ B"][column]
				draw_string(display_font, p + Vector2(-20, 23), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("45513c"))

func _initialize() -> void:
	call_deferred("capture")

func screenshot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("res://tests/output/" + name + ".png")
	print("CAPTURE ", name, " result=", result)

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.save.data.sound = false
	app._level_select()
	await screenshot("campaign-selection-v3")
	for index in range(6):
		app._start_game(index)
		app._close_modal()
		app.battle.gold = 10000
		for pad in range(app.battle.pads.size()):
			app.battle.build(pad, ["archer", "barracks", "mage", "cannon"][pad % 4])
			var level = 1 + (pad / 2) % 4
			for upgrade in range(level - 1):
				app.battle.upgrade(pad, pad % 2)
		app.battle.start_wave()
		for tick in range(180):
			app.battle.step(1.0 / 60)
		var types = app.battle.config.enemies.keys()
		for enemy_index in range(types.size()):
			var enemy = app.battle.spawn(types[enemy_index])
			enemy.d = 180 + enemy_index * 130
			enemy.walk_distance = enemy_index * 7
		app.battle.paused = false
		app._process(0.0)
		app.set_process(false)
		await screenshot("campaign-level-%d-v3" % (index + 1))
	app.hide()
	var gallery = Gallery.new()
	gallery.size = Vector2(1440, 900)
	gallery.assets = VisualAssets
	gallery.display_font = app.font
	root.add_child(gallery)
	await screenshot("tower-progression-v3")
	gallery.units = true
	gallery.queue_redraw()
	await screenshot("unit-walk-frames-v3")
	gallery.queue_free()
	app.audio.stop()
	app.queue_free()
	await process_frame
	quit()
