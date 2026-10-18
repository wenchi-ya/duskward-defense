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
	var meteor = Battle.new()
	meteor.start_wave()
	meteor.queue.clear()
	var enemy = meteor.spawn("brute")
	enemy.d = 400
	meteor.cast("meteor", meteor.position_at(400))
	check(enemy.hp == enemy.max_hp and meteor.impacts.size() == 1, "meteor does not damage before falling")
	meteor.step(0.2)
	check(enemy.hp == enemy.max_hp, "meteor windup preserves target health")
	meteor.paused = true
	var delay = meteor.impacts[0].delay
	var life = meteor.effects[0].life
	meteor.step(1)
	check(meteor.impacts[0].delay == delay and meteor.effects[0].life == life, "pause freezes projectile and particle clocks")
	meteor.paused = false
	meteor.step(0.17)
	check(enemy.hp == enemy.max_hp - 150, "meteor damage occurs on impact")
	var game = Battle.new()
	game.build(0, "archer")
	game.start_wave()
	game.queue.clear()
	var target = game.spawn("brute")
	target.d = game.nearest_distance(game.pads[0])
	game.step(0.01)
	check(target.hp == target.max_hp and not game.impacts.is_empty(), "arrow release creates travelling projectile")
	check(game.towers[0].recoil > 0, "tower has attack recoil state")
	for i in range(8):
		game.step(0.05)
	check(target.hp < target.max_hp and target.hurt > 0, "arrow arrival deals damage and triggers hit flash")
	game.hit(target, 999, "true")
	check(target.dead and game.effects.any(func(effect): return effect.type == "death"), "death creates a separate fading animation")
	var melee = Battle.new()
	melee.build(0, "barracks")
	melee.start_wave()
	melee.queue.clear()
	var foe = melee.spawn("brute")
	foe.d = melee.soldiers[0].d
	melee.step(0.01)
	check(foe.hp == foe.max_hp and melee.soldiers[0].hp == melee.soldiers[0].max_hp, "melee windup does not damage before strike frame")
	for i in range(4):
		melee.step(0.05)
	check(foe.hp < foe.max_hp and melee.soldiers[0].hp < melee.soldiers[0].max_hp, "friendly and enemy melee damage aligns with strike frame")
	var saved_hp = foe.hp
	melee.impacts.append({"delay": 0.01, "kind": "melee", "owner": {"hp": 0.0}, "target": foe, "damage": 999.0})
	melee.step(0.02)
	check(foe.hp == saved_hp, "fallen attacker cannot land a pending melee strike")
	print("RESULT: %d assertions, %d failures" % [count, failures])
	quit(1 if failures > 0 else 0)
