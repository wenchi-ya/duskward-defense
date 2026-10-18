extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Campaign = preload("res://scripts/campaign.gd")
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
	var ids: Dictionary = {}
	var backgrounds: Dictionary = {}
	var paths: Dictionary = {}
	var enemy_types: Dictionary = {}
	check(Campaign.list_levels().size() == 6, "six campaign levels")
	for index in range(6):
		var game = Battle.new(index)
		var data: Dictionary = game.config
		check(not ids.has(data.id) and not backgrounds.has(data.background) and not paths.has(str(data.path)), "unique id background and route: " + data.id)
		ids[data.id] = true
		backgrounds[data.background] = true
		paths[str(data.path)] = true
		check(ResourceLoader.exists(data.background), "map asset exists: " + data.id)
		var valid_pads = true
		for pad in game.pads:
			var distance = pad.distance_to(game.position_at(game.nearest_distance(pad)))
			valid_pads = valid_pads and distance >= 75 and distance <= 145 and pad.y >= 220
		check(valid_pads, "tower pads stay off-road within rally reach and below HUD: " + data.id)
		var valid_waves = true
		for wave in data.waves:
			for group in wave:
				valid_waves = valid_waves and data.enemies.has(group.kind) and int(group.count) > 0 and float(group.interval) > 0
				enemy_types[group.kind] = true
		check(valid_waves and data.waves.size() >= 8, "complete valid waves: " + data.id)
		var report = play(game)
		check(game.state == "won", "normal economy completes " + data.id + " " + report)
	check(enemy_types.size() == 9, "nine enemy types actually appear across campaign")
	var original = Battle.new()
	var flyer = original.spawn("bat")
	original.gold = 1000
	original.build(0, "barracks")
	original.start_wave()
	original.queue.clear()
	flyer.d = original.soldiers[0].d
	original.step(0.05)
	check(flyer.moving and original._blocker(flyer) == null, "flying enemies are not blocked by soldiers")
	var resistant = original.spawn("shaman")
	original.hit(resistant, 100, "magic")
	check(is_equal_approx(resistant.hp, resistant.max_hp - 35), "shaman magic resistance is effective")
	print("RESULT: %d assertions, %d failures" % [count, failures])
	quit(1 if failures > 0 else 0)

func play(game) -> String:
	var order: Array = []
	for index in range(game.pads.size()):
		order.append(index)
	order.sort_custom(func(a, b): return game.nearest_distance(game.pads[a]) < game.nearest_distance(game.pads[b]))
	var kinds = ["archer", "mage", "barracks", "archer", "cannon", "mage", "archer", "cannon", "mage", "archer"]
	var next = 0
	for tick in range(40000):
		if next < order.size():
			if game.build(order[next], kinds[next]):
				next += 1
		else:
			for pad in order:
				if int(game.towers[pad].level) < 4:
					game.upgrade(pad, 0)
					break
		if game.state == "ready":
			game.start_wave()
		var target = null
		for enemy in game.enemies:
			if target == null or enemy.d > target.d:
				target = enemy
		if target != null:
			var point = game.position_at(target.d)
			game.cast("meteor", point)
			game.cast("reinforce", point)
		game.step(0.05)
		if game.state in ["won", "lost"]:
			break
	return "state=%s wave=%d/%d lives=%d kills=%d gold=%d" % [game.state, game.wave, game.config.waves.size(), game.lives, game.kills, game.gold]
