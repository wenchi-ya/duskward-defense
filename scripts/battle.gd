extends RefCounted
## Headless simulation; presentation and input are separate.

const LEVEL_PATH = "res://data/first_level.json"
const Campaign = preload("res://scripts/campaign.gd")
var config: Dictionary = {}
var route = PackedVector2Array()
var cumulative: Array[float] = [0.0]
var length: float = 0.0
var pads: Array[Vector2] = []
var towers: Array = []
var enemies: Array = []
var soldiers: Array = []
var effects: Array = []
var audio_events: Array[String] = []
var impacts: Array = []
var gold: int = 0
var lives: int = 0
var wave: int = 0
var state: String = "ready"
var paused: bool = false
var elapsed: float = 0.0
var kills: int = 0
var next_id: int = 1
var queue: Array = []
var spawn_clock: float = 0.0
var meteor_cd: float = 0.0
var reinforce_cd: float = 0.0
var notice: String = "选择道路旁的空地建塔，准备好后点击开始波次。"

func _audio(kind: String) -> void:
	# A bounded event queue also keeps headless simulations independent of playback.
	if audio_events.size() < 64:
		audio_events.append(kind)

func _init(level_index: int = 0) -> void:
	config = Campaign.level(level_index)
	for p in config.path:
		route.append(Vector2(p[0], p[1]))
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
		cumulative.append(length)
	for p in config.pads:
		pads.append(Vector2(p[0], p[1]))
		towers.append(null)
	gold = int(config.initial_gold)
	lives = int(config.initial_lives)

func position_at(distance: float) -> Vector2:
	var d = clampf(distance, 0.0, length)
	for i in range(1, cumulative.size()):
		if d <= cumulative[i]:
			return route[i - 1].lerp(route[i], (d - cumulative[i - 1]) / (cumulative[i] - cumulative[i - 1]))
	return route[-1]

func nearest_distance(point: Vector2) -> float:
	var best = INF
	var result = 0.0
	for i in range(1, route.size()):
		var closest = Geometry2D.get_closest_point_to_segment(point, route[i - 1], route[i])
		var distance = point.distance_squared_to(closest)
		if distance < best:
			best = distance
			result = cumulative[i - 1] + route[i - 1].distance_to(closest)
	return result

func build(index: int, kind: String) -> bool:
	if state in ["won", "lost"] or paused or index < 0 or index >= pads.size() or towers[index] != null or not config.towers.has(kind):
		return false
	var cost = int(config.towers[kind].cost)
	if gold < cost:
		notice = "金币不足。"
		return false
	gold -= cost
	towers[index] = {"kind": kind, "level": 1, "branch": -1, "timer": 0.0, "spent": cost, "rally": nearest_distance(pads[index]), "recoil": 0.0, "born": elapsed}
	effects.append({"type": "build", "p": pads[index], "life": 0.65, "duration": 0.65, "color": Color("e7cc8b"), "radius": 46.0})
	if kind == "barracks":
		for slot in range(3):
			_add_soldier(index, slot)
	notice = config.towers[kind].name + "建造完成。"
	_audio("build")
	return true

func upgrade_cost(index: int) -> int:
	return 65 + int(towers[index].level) * 45

func upgrade(index: int, branch: int = -1) -> bool:
	if paused or state in ["won", "lost"] or index < 0 or index >= towers.size() or towers[index] == null:
		return false
	var tower: Dictionary = towers[index]
	if int(tower.level) >= 4 or gold < upgrade_cost(index):
		return false
	if int(tower.level) == 3 and branch not in [0, 1]:
		return false
	var cost = upgrade_cost(index)
	gold -= cost
	tower.spent += cost
	tower.level += 1
	if int(tower.level) == 4:
		tower.branch = branch
	if tower.kind == "barracks":
		for soldier in soldiers:
			if int(soldier.tower) == index:
				var maximum = 85.0 + int(tower.level) * 18.0 + (130.0 if int(tower.branch) == 0 else 0.0)
				if soldier.hp > 0:
					soldier.hp += maximum - float(soldier.max_hp)
				soldier.max_hp = maximum
	notice = "升级完成。"
	_audio("upgrade")
	effects.append({"type": "build", "p": pads[index], "life": 0.7, "duration": 0.7, "color": Color("a8dfdc"), "radius": 55.0})
	return true

func set_rally(index: int, point: Vector2) -> bool:
	if paused or state in ["won", "lost"] or index < 0 or index >= towers.size() or towers[index] == null or towers[index].kind != "barracks":
		return false
	var d = nearest_distance(point)
	var destination = position_at(d)
	var reach = float(config.towers.barracks.range)
	if point.distance_to(destination) > 55 or destination.distance_to(pads[index]) > reach:
		notice = "请在兵营旗帜范围内的道路上选择集结点。"
		return false
	towers[index].rally = d
	for soldier in soldiers:
		if int(soldier.tower) == index:
			soldier.rally = clampf(d + (int(soldier.slot) - 1) * 20, 0, length)
			soldier.target = -1
	effects.append({"type": "rally", "p": destination, "life": 0.8, "duration": 0.8, "color": Color("b8e6dc"), "radius": 36.0})
	notice = "集结点已设置，士兵正在前往。"
	_audio("reinforce")
	return true

func start_wave() -> bool:
	if paused or state != "ready" or wave >= config.waves.size():
		return false
	wave += 1
	for group in config.waves[wave - 1]:
		for i in range(int(group.count)):
			queue.append({"kind": group.kind, "interval": float(group.interval)})
	spawn_clock = 0.0
	state = "battle"
	notice = "敌人来袭！可以继续建造和升级。"
	_audio("wave")
	return true

func spawn(kind: String) -> Dictionary:
	var data: Dictionary = config.enemies[kind]
	var enemy = {"id": next_id, "kind": kind, "hp": float(data.hp), "max_hp": float(data.hp), "d": 0.0, "walk_distance": 0.0, "slow": 0.0, "attack": 0.0, "burn": 0.0, "dead": false, "hurt": 0.0, "swing": 0.0, "moving": true}
	next_id += 1
	enemies.append(enemy)
	return enemy

func hit(enemy: Dictionary, amount: float, damage_type: String) -> void:
	if enemy.dead:
		return
	var data: Dictionary = config.enemies[enemy.kind]
	var resistance = float(data.resist) if damage_type == "magic" else float(data.armor)
	if damage_type == "true":
		resistance = 0.0
	enemy.hp -= maxf(1.0, amount * (1.0 - resistance))
	if amount >= 3:
		enemy.hurt = 0.16
		effects.append({"type": "impact", "p": position_at(enemy.d) + Vector2(0, -18), "life": 0.22, "duration": 0.22, "color": Color("efcf8a") if damage_type == "physical" else Color("d4a5f2"), "radius": 16.0})
	if enemy.hp <= 0:
		enemy.dead = true
		gold += int(data.reward)
		kills += 1
		_audio("death")
		effects.append({"type": "death", "p": position_at(enemy.d), "kind": enemy.kind, "life": 0.5, "duration": 0.5, "color": Color("f5d991"), "radius": 20.0})

func _add_soldier(tower_index: int, slot: int, rally: float = -1.0, temporary: bool = false) -> void:
	var distance = float(towers[tower_index].rally) if rally < 0 else rally
	var level = int(towers[tower_index].level) if tower_index >= 0 else 1
	var d = clampf(distance + (slot - 1) * 20.0, 0, length)
	soldiers.append({"tower": tower_index, "slot": slot, "rally": d, "d": d, "walk_distance": 0.0, "hp": 85.0 + level * 18.0, "max_hp": 85.0 + level * 18.0, "attack": 0.0, "respawn": 0.0, "target": -1, "temporary": temporary, "ttl": 18.0, "moving": false, "swing": 0.0, "hurt": 0.0, "born": elapsed, "facing": 1.0})

func cast(skill: String, point: Vector2) -> bool:
	if paused or state != "battle":
		return false
	if skill == "meteor" and meteor_cd <= 0:
		meteor_cd = 28.0
		impacts.append({"delay": 0.36, "kind": "meteor", "p": point})
		effects.append({"type": "meteor", "p": point, "life": 0.9, "duration": 0.9, "color": Color("f28c45"), "radius": 120.0})
		notice = "陨火轰击！"
		return true
	if skill == "reinforce" and reinforce_cd <= 0:
		var d = nearest_distance(point)
		if position_at(d).distance_to(point) > 85:
			notice = "请在道路上部署援军。"
			return false
		reinforce_cd = 20.0
		for slot in range(3):
			_add_soldier(-1, slot, d, true)
		effects.append({"type": "rally", "p": position_at(d), "life": 0.8, "duration": 0.8, "color": Color("b1d7e7"), "radius": 45.0})
		notice = "援军已抵达，可作战 18 秒。"
		_audio("reinforce")
		return true
	return false

func step(delta: float) -> void:
	if paused or state in ["won", "lost"]:
		return
	elapsed += delta
	meteor_cd = maxf(0.0, meteor_cd - delta)
	reinforce_cd = maxf(0.0, reinforce_cd - delta)
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect): return effect.life > 0)
	for tower in towers:
		if tower != null:
			tower.recoil = maxf(0, float(tower.recoil) - delta)
	_update_impacts(delta)
	_update_soldiers(delta)
	if state != "battle":
		return
	spawn_clock -= delta
	if not queue.is_empty() and spawn_clock <= 0:
		var item: Dictionary = queue.pop_front()
		spawn(item.kind)
		spawn_clock += float(item.interval)
	for enemy in enemies:
		if enemy.dead:
			continue
		var data: Dictionary = config.enemies[enemy.kind]
		enemy.hurt = maxf(0, float(enemy.hurt) - delta)
		enemy.swing = maxf(0, float(enemy.swing) - delta)
		enemy.slow = maxf(0.0, float(enemy.slow) - delta)
		if float(enemy.burn) > 0:
			enemy.burn -= delta
			hit(enemy, 9.0 * delta, "magic")
			if enemy.dead:
				continue
		var blocker = _blocker(enemy)
		enemy.moving = blocker == null
		if blocker != null:
			enemy.attack -= delta
			if enemy.attack <= 0:
				impacts.append({"delay": 0.18, "kind": "enemy_melee", "owner": enemy, "target": blocker, "damage": float(data.damage)})
				enemy.swing = 0.48
				enemy.attack = 0.95
		else:
			var distance = float(data.speed) * delta * (0.55 if float(enemy.slow) > 0 else 1.0)
			enemy.d += distance
			enemy.walk_distance += distance
		if enemy.d >= length:
			enemy.dead = true
			lives -= 1
			_audio("leak")
			if lives <= 0:
				state = "lost"
				notice = "防线失守。试试用兵营拦截、法师对付重甲。"
				return
	_update_towers(delta)
	enemies = enemies.filter(func(enemy): return not enemy.dead)
	if queue.is_empty() and enemies.is_empty() and impacts.is_empty():
		if wave >= config.waves.size():
			state = "won"
			notice = "守住了%s！本关完成。" % config.name
		else:
			state = "ready"
			gold += 35
			notice = "本波结束，获得 35 金币补给。准备好后开始下一波。"

func _update_impacts(delta: float) -> void:
	for impact in impacts:
		impact.delay -= delta
		if impact.delay > 0:
			continue
		if impact.kind == "meteor":
			_audio("meteor")
			for enemy in enemies:
				if not enemy.dead and position_at(enemy.d).distance_to(impact.p) < 120:
					hit(enemy, 150, "true")
		elif impact.kind == "enemy_melee":
			if not impact.owner.dead and impact.target.hp > 0:
				impact.target.hp -= impact.damage
				impact.target.hurt = 0.18
				_audio("melee")
		elif impact.kind == "melee":
			if impact.owner.hp > 0 and not impact.target.dead:
				hit(impact.target, impact.damage, "physical")
				_audio("melee")
		elif impact.kind == "cannon":
			var p = position_at(impact.target.d)
			for enemy in enemies:
				if not enemy.dead and not config.enemies[enemy.kind].air and position_at(enemy.d).distance_to(p) < (95.0 if int(impact.branch) == 0 else 65.0):
					hit(enemy, impact.damage, impact.damage_type)
					if int(impact.branch) == 1:
						enemy.burn = 3.0
			effects.append({"type": "impact", "p": p, "life": 0.35, "duration": 0.35, "color": Color("f3c17c"), "radius": 60.0})
		elif not impact.target.dead:
			hit(impact.target, impact.damage, impact.damage_type)
			if impact.kind == "mage" and int(impact.branch) == 1:
				impact.target.slow = 2.0
	impacts = impacts.filter(func(impact): return impact.delay > 0)

func _blocker(enemy: Dictionary):
	if config.enemies[enemy.kind].air:
		return null
	for soldier in soldiers:
		if float(soldier.hp) > 0 and int(soldier.target) == int(enemy.id) and absf(float(soldier.d) - float(enemy.d)) <= 27:
			return soldier
	return null

func _update_soldiers(delta: float) -> void:
	var claimed: Dictionary = {}
	for soldier in soldiers:
		soldier.swing = maxf(0, float(soldier.swing) - delta)
		soldier.hurt = maxf(0, float(soldier.hurt) - delta)
		if soldier.temporary:
			soldier.ttl -= delta
			if soldier.ttl <= 0:
				soldier.hp = 0.0
				continue
		if soldier.hp <= 0:
			soldier.target = -1
			if soldier.temporary:
				continue
			soldier.respawn += delta
			if soldier.respawn >= 9.0:
				soldier.hp = soldier.max_hp
				soldier.respawn = 0.0
				soldier.d = soldier.rally
				soldier.born = elapsed
			continue
		soldier.target = -1
		var chosen = null
		var best = 85.0
		for enemy in enemies:
			if enemy.dead or config.enemies[enemy.kind].air or claimed.has(enemy.id):
				continue
			var distance = absf(float(enemy.d) - float(soldier.rally))
			if distance < best:
				best = distance
				chosen = enemy
		if chosen != null:
			soldier.target = chosen.id
			claimed[chosen.id] = true
		var destination = float(soldier.rally) if chosen == null else float(chosen.d) - 17.0
		soldier.moving = absf(float(soldier.d) - destination) > 2
		var previous_distance = float(soldier.d)
		soldier.d = move_toward(float(soldier.d), destination, delta * 115.0)
		soldier.walk_distance += absf(float(soldier.d) - previous_distance)
		if absf(float(soldier.d) - previous_distance) > 0.01:
			soldier.facing = signf(float(soldier.d) - previous_distance)
		if chosen != null and absf(float(chosen.d) - float(soldier.d)) > 1:
			soldier.facing = signf(float(chosen.d) - float(soldier.d))
		if chosen != null and absf(float(soldier.d) - float(chosen.d)) <= 30:
			soldier.attack -= delta
			if soldier.attack <= 0:
				var level = int(towers[soldier.tower].level) if int(soldier.tower) >= 0 else 1
				var damage = float(config.towers.barracks.damage) + (level - 1) * 6.58
				if int(soldier.tower) >= 0 and int(towers[soldier.tower].branch) == 1:
					damage *= 1.8
				impacts.append({"delay": 0.18, "kind": "melee", "owner": soldier, "target": chosen, "damage": damage})
				soldier.attack = 0.9
				soldier.swing = 0.48
	soldiers = soldiers.filter(func(s): return not s.temporary or (s.ttl > 0 and s.hp > 0))

func _update_towers(delta: float) -> void:
	for index in range(towers.size()):
		if towers[index] == null:
			continue
		var tower: Dictionary = towers[index]
		if tower.kind == "barracks":
			continue
		var data: Dictionary = config.towers[tower.kind]
		tower.timer -= delta
		if tower.timer > 0:
			continue
		var target = null
		var reach = float(data.range) + (int(tower.level) - 1) * 10.0
		if int(tower.branch) == 0:
			reach += 35.0
		for enemy in enemies:
			if enemy.dead or (config.enemies[enemy.kind].air and not data.air):
				continue
			if pads[index].distance_to(position_at(enemy.d)) <= reach:
				if target == null or enemy.d > target.d:
					target = enemy
		if target == null:
			continue
		var damage = float(data.damage) * (1.0 + (int(tower.level) - 1) * 0.65)
		if int(tower.branch) == 0:
			damage *= 1.45
		var position = position_at(target.d)
		_audio("arrow" if tower.kind == "archer" else tower.kind)
		impacts.append({"delay": 0.38, "kind": tower.kind, "target": target, "damage": damage, "damage_type": data.damage_type, "branch": tower.branch})
		var tint = Color("b4a1fa") if tower.kind == "mage" else Color("ffda8c")
		tower.recoil = 0.25
		effects.append({"type": "shot", "kind": tower.kind, "target": target, "from": pads[index] + Vector2(0, -65), "p": position, "life": 0.38, "duration": 0.38, "color": tint, "radius": 4.0})
		tower.timer = float(data.interval) * (0.65 if tower.kind == "archer" and int(tower.branch) == 1 else 1.0)
