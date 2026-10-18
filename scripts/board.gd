extends Control
## Painted terrain and atlas sprites, animated from simulation state.
const ArtAtlas = preload("res://scripts/art_atlas.gd")
const VisualAssets = preload("res://scripts/visual_assets.gd")
const UNIT_HEIGHTS = {"soldier": 37.0, "goblin": 32.0, "wolf": 28.0, "brute": 45.0, "bat": 31.0, "shaman": 37.0}
signal clicked(point: Vector2)
signal cancelled
var battle
var selected: int = -1
var targeting: String = ""
var rally_index: int = -1
var mouse_position = Vector2.ZERO
var font: Font = ThemeDB.fallback_font
var terrain: Texture2D
var atlas: Texture2D
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if ResourceLoader.exists(battle.config.background):
		terrain = load(battle.config.background)
	if ResourceLoader.exists("res://art/gameplay/units-towers-v1.png"):
		atlas = load("res://art/gameplay/units-towers-v1.png")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_position = event.position
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancelled.emit()

func _process(_delta: float) -> void:
	queue_redraw()

func _oval(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(center, 0, radius)
	draw_circle(Vector2.ZERO, 1, color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if battle == null:
		return
	if terrain != null:
		draw_texture_rect(terrain, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("96a46a"))
	_road()
	for i in range(battle.pads.size()):
		var p: Vector2 = battle.pads[i]
		_pad(p, battle.towers[i] == null)
		if i == selected:
			draw_arc(p, 44, 0, TAU, 50, Color("f7e6a7"), 2, true)
			if battle.towers[i] != null:
				var t: Dictionary = battle.towers[i]
				var radius = float(battle.config.towers[t.kind].range) + (int(t.level) - 1) * 10
				if t.kind == "barracks":
					radius = float(battle.config.towers.barracks.range)
				if int(t.branch) == 0 and t.kind != "barracks":
					radius += 35
				draw_circle(p, radius, Color(0.9, 1, 0.8, 0.065))
				draw_arc(p, radius, 0, TAU, 80, Color(0.94, 1, 0.84, 0.45), 1.5, true)
				if t.kind == "barracks":
					_flag(battle.position_at(t.rally), Color("82b5ce"))
	var entities: Array = []
	for i in range(battle.towers.size()):
		if battle.towers[i] != null:
			entities.append({"type": "tower", "p": battle.pads[i], "data": battle.towers[i]})
	for soldier in battle.soldiers:
		if soldier.hp > 0:
			entities.append({"type": "soldier", "p": battle.position_at(soldier.d) + Vector2(0, (int(soldier.slot) - 1) * 9), "data": soldier})
	for enemy in battle.enemies:
		if not enemy.dead:
			entities.append({"type": "enemy", "p": battle.position_at(enemy.d), "data": enemy})
	entities.sort_custom(func(a, b): return a.p.y < b.p.y)
	for entity in entities:
		var data: Dictionary = entity.data
		var p: Vector2 = entity.p
		if entity.type == "tower":
			_tower(p, data)
		else:
			var kind = "soldier" if entity.type == "soldier" else data.kind
			var ahead = battle.position_at(float(data.d) + 2) - battle.position_at(maxf(0, float(data.d) - 2))
			_unit(p, kind, data, -1.0 if ahead.x < -0.1 else 1.0)
			if data.hp < data.max_hp:
				var definition: Dictionary = {} if kind == "soldier" else battle.config.enemies[kind]
				var species: String = definition.get("sprite", kind)
				var elevation = 28.0 if definition.get("air", false) else 0.0
				var height = float(UNIT_HEIGHTS.get(species, 36.0)) * float(definition.get("scale", 1.0))
				_health(p + Vector2(0, -height - elevation - 6), float(data.hp) / float(data.max_hp), 27)
	for effect in battle.effects:
		_effect(effect)
	_target_preview()

func _road() -> void:
	var palette: Array = battle.config.road
	for layer in [[88.0, Color(palette[0])], [81.0, Color(palette[1])], [72.0, Color(palette[2])], [62.0, Color(palette[3])]]:
		draw_polyline(battle.route, layer[1], layer[0], true)
		for p in battle.route:
			draw_circle(p, layer[0] / 2, layer[1])
	rng.seed = 57213
	for i in range(650):
		var d = rng.randf_range(0, battle.length)
		var p = battle.position_at(d)
		var tangent = (battle.position_at(d + 2) - battle.position_at(maxf(0, d - 2))).normalized()
		p += Vector2(-tangent.y, tangent.x) * rng.randf_range(-31, 31)
		var tint = Color(0.65, 0.5, 0.3, 0.2) if i % 3 == 0 else Color(1, 0.9, 0.65, 0.2)
		draw_line(p, p + tangent * rng.randf_range(2, 9), tint, rng.randf_range(1, 3), true)
	for i in range(70):
		var d = rng.randf_range(0, battle.length)
		var p = battle.position_at(d)
		var tangent = (battle.position_at(d + 2) - battle.position_at(maxf(0, d - 2))).normalized()
		p += Vector2(-tangent.y, tangent.x) * (rng.randf_range(35, 46) * (-1 if i % 2 else 1))
		_oval(p, Vector2(3, 1.8), Color("9c9c6b"))
	if battle.config.biome == "village":
		for i in range(9):
			draw_rect(Rect2(1178 + i * 13, 264, 11.5, 75), Color("a57c4e"))
			draw_line(Vector2(1180 + i * 13, 268), Vector2(1180 + i * 13, 333), Color("c79e67"), 2)
		for y in [264, 339]:
			draw_line(Vector2(1176, y), Vector2(1297, y), Color("55402c"), 6, true)
			draw_line(Vector2(1176, y - 2), Vector2(1297, y - 2), Color("ad8756"), 2, true)

func _pad(p: Vector2, empty: bool) -> void:
	_oval(p + Vector2(2, 7), Vector2(42, 20), Color(0.15, 0.19, 0.1, 0.35))
	_oval(p, Vector2(40, 20), Color("675f49"))
	_oval(p - Vector2(0, 3), Vector2(38, 18), Color("aaa182"))
	_oval(p - Vector2(0, 3), Vector2(30, 13), Color("877953"))
	for i in range(9):
		var angle = i * TAU / 9
		var normal = Vector2(cos(angle) * 38, sin(angle) * 17)
		draw_line(p + normal * 0.79, p + normal, Color("6a624d"), 2, true)
	if empty:
		var pulse = 0.7 + sin(battle.elapsed * 2.5 + p.x) * 0.15
		draw_line(p + Vector2(-7, -3), p + Vector2(7, -3), Color(1, 0.91, 0.68, pulse), 2, true)
		draw_line(p + Vector2(0, -10), p + Vector2(0, 4), Color(1, 0.91, 0.68, pulse), 2, true)

func _sprite(kind: String, at: Vector2, width: float, angle: float = 0.0, scale_value: Vector2 = Vector2.ONE, tint: Color = Color.WHITE) -> void:
	if atlas == null:
		return
	var source: Rect2 = ArtAtlas.REGIONS[kind]
	var dimensions = source.size * (width / source.size.x)
	draw_set_transform(at, angle, scale_value)
	draw_texture_rect_region(atlas, Rect2(Vector2(-dimensions.x / 2, -dimensions.y + 8), dimensions), source, tint)
	draw_set_transform(Vector2.ZERO)

func _tower(p: Vector2, tower: Dictionary) -> void:
	var age = battle.elapsed - float(tower.born)
	var grow = clampf(age / 0.26, 0, 1)
	var pop = 1 + sin(grow * PI) * 0.12
	var recoil = sin(clampf(float(tower.recoil) / 0.25, 0, 1) * PI)
	var scale_value = Vector2(pop + recoil * 0.035, maxf(0.05, grow) * pop - recoil * 0.04)
	var frame = VisualAssets.tower(tower.kind, int(tower.level), int(tower.branch))
	if not frame.is_empty():
		var source: Rect2 = frame.rect
		var width = [78.0, 91.0, 106.0, 119.0][int(tower.level) - 1]
		var dimensions = source.size * (width / source.size.x)
		var max_height = [83.0, 104.0, 128.0, 150.0][int(tower.level) - 1]
		dimensions *= minf(1.0, max_height / dimensions.y)
		draw_set_transform(p, -0.035 * recoil if tower.kind == "cannon" else 0.0, scale_value)
		draw_texture_rect_region(frame.texture, Rect2(Vector2(-dimensions.x / 2, -dimensions.y + 8), dimensions), source)
		draw_set_transform(Vector2.ZERO)
	else:
		_sprite(tower.kind, p, 108, 0.0, scale_value)
	if tower.kind == "mage":
		var glow = 0.4 + sin(battle.elapsed * 2.8) * 0.15
		draw_circle(p + Vector2(0, -99), 13, Color(0.75, 0.5, 1, glow * 0.12))
	for i in range(int(tower.level)):
		draw_circle(p + Vector2(-12 + i * 8, 13), 2.7, Color("fff0b5"))
	if int(tower.branch) >= 0:
		_flag(p + Vector2(39, 0), Color("d16f4c") if int(tower.branch) == 0 else Color("79b3cb"), 0.7)

func _unit(p: Vector2, kind: String, data: Dictionary, facing: float) -> void:
	var definition: Dictionary = {} if kind == "soldier" else battle.config.enemies[kind]
	var species: String = definition.get("sprite", kind)
	var frame = VisualAssets.unit(species, data)
	if frame.is_empty():
		return
	var airborne = bool(definition.get("air", false))
	var height = float(UNIT_HEIGHTS.get(species, 36.0)) * float(definition.get("scale", 1.0))
	var factor = height / float(frame.reference_height)
	var tint = Color(definition.get("tint", "ffffff"))
	if float(data.hurt) > 0:
		tint = Color(1.35, 1.15, 1.0)
	_oval(p + Vector2(0, 3), Vector2(13 if not airborne else 18, 4), Color(0.1, 0.13, 0.08, 0.25 if not airborne else 0.16))
	if kind == "soldier":
		facing *= float(data.get("facing", 1.0))
	var offset: Vector2 = frame.offset * factor
	var source: Rect2 = frame.rect
	var elevation = 28.0 if airborne else 0.0
	draw_set_transform(p + Vector2(0, -elevation), 0, Vector2(facing, 1))
	draw_texture_rect_region(frame.texture, Rect2(offset, source.size * factor), source, tint)
	draw_set_transform(Vector2.ZERO)

func _health(p: Vector2, ratio: float, width: float) -> void:
	draw_rect(Rect2(p - Vector2(width / 2 + 1, 1), Vector2(width + 2, 5)), Color("383c2c"))
	draw_rect(Rect2(p - Vector2(width / 2, 0), Vector2(width * clampf(ratio, 0, 1), 3)), Color("8bc878"))

func _flag(p: Vector2, color: Color, scale_value: float = 1.0) -> void:
	draw_line(p, p + Vector2(0, -39) * scale_value, Color("675339"), 3, true)
	var flutter = sin(battle.elapsed * 5 + p.x) * 3
	var points = PackedVector2Array([p + Vector2(1, -38) * scale_value, p + Vector2(23, -34 + flutter) * scale_value, p + Vector2(19, -22 + flutter) * scale_value, p + Vector2(1, -25) * scale_value])
	draw_colored_polygon(points, color)
	draw_polyline(points, Color("e6d9a8"), 1, true)
	_oval(p, Vector2(14, 6) * scale_value, Color(color, 0.2))

func _effect(effect: Dictionary) -> void:
	var duration = float(effect.get("duration", 0.4))
	var t = clampf(1.0 - float(effect.life) / duration, 0, 1)
	var p: Vector2 = effect.p
	var color: Color = effect.color
	if effect.type == "shot":
		var origin: Vector2 = effect.from
		if effect.has("target"):
			p = battle.position_at(effect.target.d)
		var at = origin.lerp(p, t)
		if effect.kind != "mage":
			at.y -= sin(t * PI) * (65 if effect.kind == "cannon" else 18)
		var direction = (p - origin).normalized()
		if effect.kind == "cannon":
			draw_circle(at + Vector2(-6, 3), 7, Color(0.6, 0.5, 0.35, 0.15))
			draw_circle(at, 5, Color("332f2a"))
			draw_circle(at - Vector2(1, 1), 2, Color("b0996a"))
		elif effect.kind == "mage":
			draw_line(at - direction * 28, at, Color(0.72, 0.48, 1, 0.35), 9, true)
			draw_line(at - direction * 18, at, Color("e5c7ff"), 3, true)
			draw_circle(at, 4, Color("fbecff"))
		else:
			draw_line(at - direction * 16, at, Color("6b482d"), 2, true)
			draw_line(at - direction * 5 + direction.orthogonal() * 3, at, Color("f7e5bc"), 2, true)
	elif effect.type == "death":
		var definition: Dictionary = battle.config.enemies[effect.kind]
		var species: String = definition.get("sprite", effect.kind)
		var frame = VisualAssets.unit(species, {"moving": false, "swing": 0.0})
		if not frame.is_empty():
			var source: Rect2 = frame.rect
			var factor = float(UNIT_HEIGHTS.get(species, 36.0)) * float(definition.get("scale", 1.0)) / float(frame.reference_height)
			draw_set_transform(p + Vector2(0, t * 5), t * 1.1, Vector2(1, 1 - t * 0.3))
			draw_texture_rect_region(frame.texture, Rect2(frame.offset * factor, source.size * factor), source, Color(1, 1, 1, 1 - t))
			draw_set_transform(Vector2.ZERO)
		_particles(p, t, color, 25)
	elif effect.type == "meteor":
		if t < 0.4:
			var at = p + Vector2(-190, -320) * (1 - t / 0.4)
			draw_line(at + Vector2(-45, -75), at, Color(1, 0.4, 0.1, 0.55), 15, true)
			draw_circle(at, 17, Color("f0903e"))
			draw_circle(at, 9, Color("fff1a4"))
		else:
			var progress = (t - 0.4) / 0.6
			draw_circle(p, 110 * progress, Color(1, 0.45, 0.12, (1 - progress) * 0.25))
			draw_arc(p, 120 * progress, 0, TAU, 50, Color(1, 0.77, 0.4, 1 - progress), 5 * (1 - progress) + 1, true)
			_particles(p, progress, Color("f9ba61"), 90)
	elif effect.type in ["build", "rally"]:
		_oval(p, Vector2(effect.radius * (0.6 + t), effect.radius * (0.35 + t * 0.4)), Color(color, (1 - t) * 0.2))
		_particles(p, t, color, effect.radius)
	else:
		_particles(p, t, color, effect.radius)

func _particles(p: Vector2, t: float, color: Color, radius: float) -> void:
	for i in range(9):
		var angle = i * TAU / 9 + 0.3
		var offset = Vector2(cos(angle), sin(angle) * 0.65) * radius * t
		offset.y -= sin(t * PI) * 12
		draw_circle(p + offset, maxf(0.5, 3 * (1 - t)), Color(color, 1 - t))

func _target_preview() -> void:
	if targeting.is_empty():
		return
	if targeting == "rally" and rally_index >= 0:
		var tower_position: Vector2 = battle.pads[rally_index]
		var reach = float(battle.config.towers.barracks.range)
		draw_circle(tower_position, reach, Color(0.5, 0.85, 0.9, 0.06))
		draw_arc(tower_position, reach, 0, TAU, 80, Color(0.7, 0.93, 1, 0.75), 2, true)
		var p = battle.position_at(battle.nearest_distance(mouse_position))
		var valid = p.distance_to(mouse_position) <= 55 and p.distance_to(tower_position) <= reach
		var color = Color("b9e5ce") if valid else Color("e68b72")
		draw_dashed_line(tower_position, p, Color(color, 0.65), 2, 7, true)
		_flag(p, color)
	else:
		var radius = 120.0 if targeting == "meteor" else 50.0
		draw_circle(mouse_position, radius, Color(1, 0.8, 0.4, 0.12))
		draw_arc(mouse_position, radius, 0, TAU, 60, Color("ffe3a1"), 2, true)
