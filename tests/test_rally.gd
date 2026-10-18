extends SceneTree
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
	var battle = Battle.new()
	battle.gold = 1000
	battle.build(2, "barracks")
	battle.build(4, "barracks")
	var old_rally = float(battle.towers[2].rally)
	var second_rally = float(battle.towers[4].rally)
	var old_position = float(battle.soldiers[0].d)
	var destination = battle.position_at(old_rally - 45)
	check(battle.set_rally(2, destination), "accept nearby road rally")
	check(is_equal_approx(battle.towers[4].rally, second_rally), "other barracks keeps its own rally")
	check(is_equal_approx(battle.soldiers[0].d, old_position), "soldiers do not teleport when flag moves")
	battle.step(0.1)
	check(not is_equal_approx(battle.soldiers[0].d, old_position), "soldiers walk toward rally between waves")
	for i in range(60):
		battle.step(0.05)
	check(is_equal_approx(battle.soldiers[0].d, battle.soldiers[0].rally), "soldier reaches new formation position")
	var accepted = battle.towers[2].rally
	check(not battle.set_rally(2, Vector2(1200, 600)) and battle.towers[2].rally == accepted, "far road cannot move rally outside barracks range")
	check(not battle.set_rally(2, Vector2(440, 210)), "off-road rally rejected")
	check(not battle.set_rally(-1, destination) and not battle.set_rally(0, destination), "invalid and empty towers cannot rally")
	battle.paused = true
	var p = battle.soldiers[0].d
	check(not battle.set_rally(2, battle.position_at(old_rally)), "paused battle cannot change rally")
	battle.step(1)
	check(battle.soldiers[0].d == p, "paused soldier animation state stays fixed")
	battle.paused = false
	battle.soldiers[0].hp = 0
	for i in range(200):
		battle.step(0.05)
	check(battle.soldiers[0].hp > 0 and battle.soldiers[0].rally == accepted - 20, "replacement soldier respects moved rally")
	battle.start_wave()
	battle.queue.clear()
	var enemy = battle.spawn("brute")
	enemy.d = battle.soldiers[0].d
	var d = enemy.d
	battle.step(0.01)
	var blocked = enemy.d == d
	for i in range(4):
		battle.step(0.05)
	check(blocked and enemy.hp < enemy.max_hp, "moved soldiers still block and attack ground enemy")
	print("RESULT: %d assertions, %d failures" % [count, failures])
	quit(1 if failures > 0 else 0)
