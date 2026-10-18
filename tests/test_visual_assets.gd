extends SceneTree
const VisualAssets = preload("res://scripts/visual_assets.gd")
const Battle = preload("res://scripts/battle.gd")
var count: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	count += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	for kind in ["archer", "barracks", "mage", "cannon"]:
		var regions: Dictionary = {}
		for level in range(1, 5):
			var frame = VisualAssets.tower(kind, level, 0)
			regions[str(frame.rect)] = true
			check(frame.texture != null and frame.rect.size.x > 20 and frame.rect.size.y > 20, "%s level %d has image" % [kind, level])
		var branch = VisualAssets.tower(kind, 4, 1)
		regions[str(branch.rect)] = true
		check(regions.size() == 5, "five distinct architectural sprites: " + kind)
	for species in ["soldier", "goblin", "wolf", "brute", "bat", "shaman"]:
		var walk: Dictionary = {}
		var attacks: Dictionary = {}
		var image = VisualAssets.texture("res://art/units/" + species + ".png").get_image()
		var hashes: Dictionary = {}
		for frame_index in range(6):
			var frame = VisualAssets.unit(species, {"moving": true, "walk_distance": frame_index * (7 if species == "wolf" else (6 if species == "brute" else 5)), "swing": 0.0})
			walk[frame.index] = true
			var crop = image.get_region(Rect2i(frame.rect))
			hashes[crop.get_data().hex_encode().sha256_text()] = true
			var attack = VisualAssets.unit(species, {"moving": false, "swing": 0.48 - (frame_index + 0.25) * 0.08})
			attacks[attack.index] = true
		check(walk.size() == 6 and hashes.size() == 6, "six genuinely different walk/flap frames: " + species)
		check(attacks.size() == 6, "six-frame attack sequence available: " + species)
		var idle = VisualAssets.unit(species, {"moving": false, "walk_distance": 0.0, "swing": 0.0})
		check(idle.index == 11, "stationary unit uses rest pose: " + species)
	for kind in ["meteor", "reinforce"]:
		check(VisualAssets.icon(kind) != null, "painted ability image: " + kind)
	var game = Battle.new()
	game.start_wave()
	game.queue.clear()
	var enemy = game.spawn("goblin")
	game.step(0.1)
	check(enemy.walk_distance > 0 and VisualAssets.unit("goblin", enemy).index < 6, "moving enemy drives walk animation from distance")
	var distance = enemy.walk_distance
	var frame_before = VisualAssets.unit("goblin", enemy).index
	game.paused = true
	game.step(1)
	check(enemy.walk_distance == distance and VisualAssets.unit("goblin", enemy).index == frame_before, "pause freezes unit gait")
	for kind in game.config.enemies:
		var species = game.config.enemies[kind].get("sprite", kind)
		check(not VisualAssets.unit(species, {"moving": true, "walk_distance": 0.0, "swing": 0.0}).is_empty(), "enemy has full animation mapping: " + kind)
	print("RESULT: %d assertions, %d failures" % [count, failures])
	quit(1 if failures > 0 else 0)
