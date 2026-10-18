extends SceneTree

const Battle = preload("res://scripts/battle.gd")

func _initialize() -> void:
	var game = Battle.new()
	var plan = [[0, "archer"], [2, "barracks"], [4, "mage"], [5, "archer"], [1, "cannon"], [6, "mage"], [3, "cannon"], [7, "archer"]]
	var next_build = 0
	for tick in range(40000):
		if next_build < plan.size():
			if game.build(plan[next_build][0], plan[next_build][1]):
				next_build += 1
		else:
			for index in [0, 4, 5, 1, 6, 3, 7, 2]:
				if int(game.towers[index].level) < 4:
					game.upgrade(index, 0)
					break
		if game.state == "ready":
			game.start_wave()
		if game.state == "battle":
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
	print("NORMAL ECONOMY PLAYTHROUGH: state=%s wave=%d lives=%d kills=%d gold=%d" % [game.state, game.wave, game.lives, game.kills, game.gold])
	quit(0 if game.state == "won" else 1)
