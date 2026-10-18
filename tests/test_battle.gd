extends SceneTree

const Battle = preload("res://scripts/battle.gd")
var failures: int = 0
var assertions: int = 0

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	var game = Battle.new()
	check(game.pads.size() == 8 and game.config.waves.size() == 8, "map loads eight pads and waves")
	var initial_gold = game.gold
	check(not game.build(-1, "archer") and game.gold == initial_gold, "invalid build cannot spend gold")
	check(game.build(0, "archer") and game.gold == initial_gold - 80, "build charges exact cost")
	check(not game.build(0, "mage") and game.gold == initial_gold - 80, "occupied pad rejects second build")
	game.gold = 0
	check(not game.build(1, "cannon") and game.towers[1] == null, "insufficient funds reject building")
	game.gold = 2000
	check(game.upgrade(0) and game.upgrade(0), "two standard upgrades")
	check(not game.upgrade(0), "branch choice required at level three")
	check(game.upgrade(0, 1) and game.towers[0].branch == 1 and not game.upgrade(0, 0), "branch selected and max level protected")
	var enemy = game.spawn("brute")
	game.hit(enemy, 100, "physical")
	check(is_equal_approx(enemy.hp, 185), "armor reduces physical damage")
	game.hit(enemy, 100, "magic")
	check(is_equal_approx(enemy.hp, 85), "magic bypasses physical armor")
	var before = game.gold
	game.hit(enemy, 999, "true")
	game.hit(enemy, 999, "true")
	check(game.gold == before + 22 and game.kills == 1, "dead enemy rewards only once")
	check(not game.cast("meteor", Vector2.ZERO), "skills unavailable between waves")
	game.start_wave()
	game.paused = true
	var clock = game.elapsed
	var queue_size = game.queue.size()
	game.step(5)
	check(game.elapsed == clock and game.queue.size() == queue_size and not game.build(2, "mage"), "pause freezes time spawning and building")
	game.paused = false
	check(not game.start_wave(), "cannot overlap waves")
	check(game.cast("meteor", Vector2.ZERO) and not game.cast("meteor", Vector2.ZERO), "skill cooldown enforced")
	check(not game.cast("reinforce", Vector2(500, 30)), "reinforcements require road placement")
	check(game.cast("reinforce", game.position_at(500)) and game.soldiers.size() == 3, "reinforcements create three soldiers")
	var soldiers_game = Battle.new()
	soldiers_game.build(0, "barracks")
	soldiers_game.start_wave()
	soldiers_game.queue.clear()
	var blocked = soldiers_game.spawn("brute")
	blocked.d = soldiers_game.soldiers[0].rally
	soldiers_game.step(0.01)
	check(is_equal_approx(blocked.d, soldiers_game.soldiers[0].rally), "soldier blocks nearby ground enemy")
	for i in range(4):
		soldiers_game.step(0.05)
	check(blocked.hp < blocked.max_hp, "soldier damages blocked enemy")
	soldiers_game.soldiers[0].hp = 0
	soldiers_game.step(9.1)
	check(soldiers_game.soldiers[0].hp > 0, "fallen barracks soldier respawns")
	var lose = Battle.new()
	for i in range(14000):
		if lose.state == "ready":
			lose.start_wave()
		lose.step(0.1)
		if lose.state == "lost":
			break
	check(lose.state == "lost" and lose.lives == 0, "undefended village eventually loses")
	var win = Battle.new()
	win.gold = 10000
	for i in range(8):
		win.build(i, ["archer", "mage", "barracks", "cannon"][i % 4])
		win.upgrade(i)
		win.upgrade(i)
		win.upgrade(i, i % 2)
	for i in range(30000):
		if win.state == "ready":
			win.start_wave()
		if not win.enemies.is_empty() and win.meteor_cd <= 0:
			win.cast("meteor", win.position_at(win.enemies[0].d))
		win.step(0.05)
		if win.state in ["won", "lost"]:
			break
	check(win.state == "won" and win.wave == 8 and win.queue.is_empty() and win.enemies.is_empty(), "full eight-wave simulation can reach victory")
	print("RESULT: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
