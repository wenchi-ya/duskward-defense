extends Control

const Battle = preload("res://scripts/battle.gd")
const Board = preload("res://scripts/board.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const CommandButton = preload("res://scripts/command_button.gd")
const Campaign = preload("res://scripts/campaign.gd")
const AudioDirector = preload("res://scripts/audio_director.gd")
var save = SaveStore.new()
var battle
var board
var screen: String = "menu"
var selected: int = -1
var targeting: String = ""
var speed: int = 1
var hud: Label
var message: Label
var actions: Control
var rally_index: int = -1
var notice_age: float = 0.0
var last_notice: String = ""
var wave_button: Button
var meteor_button
var reinforce_button
var pause_button: Button
var speed_button: Button
var overlay: Control
var ended: bool = false
var level_index: int = 0
var font = SystemFont.new()
var audio

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "Arial"])
	var theme_data = Theme.new()
	theme_data.default_font = font
	theme_data.default_font_size = 19
	theme = theme_data
	save.load_data()
	audio = AudioDirector.new()
	add_child(audio)
	audio.configure(save.data)
	_menu()

func _clear() -> void:
	audio.clear_combat()
	for child in get_children():
		if child != audio:
			remove_child(child)
			child.queue_free()
	overlay = null

func _style(fill: Color, border: Color = Color("9d895d")) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _button(text: String, callback: Callable, width: float = 170) -> Button:
	var button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(width, 48)
	button.add_theme_stylebox_override("normal", _style(Color("344e49")))
	button.add_theme_stylebox_override("hover", _style(Color("4d7060"), Color("efdb9b")))
	button.add_theme_stylebox_override("pressed", _style(Color("263e37")))
	button.add_theme_stylebox_override("disabled", _style(Color("3d433d"), Color("676e5c")))
	button.add_theme_color_override("font_color", Color("f7ebc8"))
	button.add_theme_color_override("font_disabled_color", Color("8c9787"))
	button.pressed.connect(callback)
	button.pressed.connect(_sound)
	return button

func _label(text: String, font_size: int = 22) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f3e7c5"))
	return label

func _background(use_concept: bool = true) -> void:
	var bg = ColorRect.new()
	bg.color = Color("1c3029")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if use_concept and ResourceLoader.exists("res://art/concepts/village-style-v1.png"):
		var texture = TextureRect.new()
		texture.texture = load("res://art/concepts/village-style-v1.png")
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Show the complete illustration: cover mode crops its left/right edges on 16:10.
		texture.stretch_mode = TextureRect.STRETCH_SCALE
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture.modulate = Color(0.55, 0.58, 0.52)
		add_child(texture)

func _panel(rect: Rect2) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(Color(0.1, 0.17, 0.14, 0.96)))
	add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box

func _menu() -> void:
	screen = "menu"
	battle = null
	_clear()
	audio.set_music("hearth")
	_background()
	var box = _panel(Rect2(80, 100, 600, 660))
	box.add_child(_label("暮 境 守 卫", 56))
	box.add_child(_label("一片村庄，四种守护的方式", 25))
	box.add_child(_label("六关战役 · 战场内建造与集结", 17))
	box.add_child(_button("开始守卫", _level_select, 400))
	box.add_child(_button("设置", _settings, 400))
	box.add_child(_button("退出游戏", func(): get_tree().quit(), 400))
	var note = _label("村庄 · 森林 · 峡谷 · 沼泽 · 雪地 · 火山\n四类防御塔，九类敌军。英雄系统后续加入。\n" + save.warning, 18)
	box.add_child(note)

func _level_select() -> void:
	screen = "levels"
	_clear()
	audio.set_music("hearth")
	_background()
	var box = _panel(Rect2(55, 60, 1330, 790))
	box.add_child(_label("边境战役", 38))
	box.add_child(_label("选择战场 · 六关均可直接挑战，通关结果自动保存", 20))
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	var levels = Campaign.list_levels()
	for index in range(levels.size()):
		var data: Dictionary = levels[index]
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(420, 258)
		card.add_theme_stylebox_override("panel", _style(Color("293e32")))
		grid.add_child(card)
		var contents = VBoxContainer.new()
		contents.add_theme_constant_override("separation", 5)
		card.add_child(contents)
		var preview = TextureRect.new()
		preview.custom_minimum_size = Vector2(385, 142)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if ResourceLoader.exists(data.background):
			preview.texture = load(data.background)
		contents.add_child(preview)
		contents.add_child(_label(data.description, 16))
		var completed = "  ✓" if data.id in save.data.completed else ""
		var button = _button("%02d  %s%s" % [index + 1, data.name, completed], _start_game.bind(index), 380)
		button.name = "level_" + str(index)
		contents.add_child(button)
	box.add_child(_button("返回", _menu))

func _concept() -> void:
	screen = "concept"
	_clear()
	_background(false)
	var texture = TextureRect.new()
	texture.texture = load("res://art/concepts/village-style-v1.png")
	texture.position = Vector2(0, 35)
	texture.size = Vector2(1440, 810)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(texture)
	var label = _label("已确认的美术基准 · 此图为概念画面，不是实际运行截图", 19)
	label.position = Vector2(25, 8)
	add_child(label)
	var back = _button("返回主菜单", _menu)
	back.position = Vector2(1230, 843)
	add_child(back)

func _settings() -> void:
	screen = "settings"
	_clear()
	_background()
	var box = _panel(Rect2(410, 110, 620, 680))
	box.add_child(_label("设置", 38))
	var music_check = CheckButton.new()
	music_check.name = "MusicEnabled"
	music_check.text = "背景音乐"
	music_check.button_pressed = save.data.music
	music_check.toggled.connect(func(value): save.data.music = value; audio.configure(save.data); save.save_data())
	box.add_child(music_check)
	box.add_child(_label("音乐音量", 19))
	_audio_slider(box, "music_volume", "MusicVolume")
	var check = CheckButton.new()
	check.name = "SoundEnabled"
	check.text = "战斗与操作音效"
	check.button_pressed = save.data.sound
	check.toggled.connect(func(value): save.data.sound = value; audio.configure(save.data); save.save_data(); _sound())
	box.add_child(check)
	box.add_child(_label("音效音量", 19))
	_audio_slider(box, "volume", "SoundVolume")
	var fullscreen = CheckButton.new()
	fullscreen.name = "Fullscreen"
	fullscreen.text = "全屏显示"
	fullscreen.button_pressed = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	fullscreen.toggled.connect(_set_fullscreen)
	box.add_child(fullscreen)
	box.add_child(_label("F11 切换全屏 / 窗口\n画面随屏幕及窗口尺寸自动铺满。", 18))
	box.add_child(_button("返回", _menu))

func _audio_slider(box: VBoxContainer, key: String, node_name: String) -> void:
	var slider = HSlider.new()
	slider.name = node_name
	slider.custom_minimum_size = Vector2(0, 30)
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = save.data[key]
	slider.value_changed.connect(func(value):
		save.data[key] = value
		audio.configure(save.data)
		save.save_data())
	box.add_child(slider)

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	var check = find_child("Fullscreen", true, false)
	if check != null:
		check.set_pressed_no_signal(enabled)

func _start_game(index: int = -1) -> void:
	if index >= 0:
		level_index = index
	screen = "battle"
	_clear()
	audio.set_music("border_watch" if level_index < 3 else "last_bastion")
	battle = Battle.new(level_index)
	selected = -1
	targeting = ""
	rally_index = -1
	speed = 1
	ended = false
	board = Board.new()
	board.battle = battle
	board.font = font
	board.size = Vector2(1440, 900)
	board.clicked.connect(_board_clicked)
	board.cancelled.connect(_cancel_selection)
	add_child(board)
	var top = PanelContainer.new()
	top.position = Vector2(15, 10)
	top.size = Vector2(1410, 58)
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_theme_stylebox_override("panel", _style(Color(0.13, 0.22, 0.18, 0.96)))
	add_child(top)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	hud = _label("", 22)
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hud)
	speed_button = _button("速度 ×1", func(): speed = 2 if speed == 1 else 1; speed_button.text = "速度 ×" + str(speed), 130)
	row.add_child(speed_button)
	pause_button = _button("暂停 [Esc]", _pause, 150)
	row.add_child(pause_button)
	# All battle commands live directly over the battlefield; no bottom toolbar.
	meteor_button = _command("meteor", "陨火", func(): _target("meteor"))
	meteor_button.position = Vector2(32, 792)
	meteor_button.tooltip_text = "陨火 [1]：点击战场释放范围轰击"
	add_child(meteor_button)
	reinforce_button = _command("reinforce", "援军", func(): _target("reinforce"))
	reinforce_button.position = Vector2(122, 792)
	reinforce_button.tooltip_text = "援军 [2]：在道路上部署临时士兵"
	add_child(reinforce_button)
	wave_button = _command("wave", "来袭", func():
		if battle.start_wave():
			_cancel_selection())
	wave_button.position = Vector2(40, clampf(battle.route[1].y - 110, 90, 650))
	wave_button.tooltip_text = "开始下一波 [空格]"
	add_child(wave_button)
	message = _label("", 18)
	message.position = Vector2(350, 84)
	message.size = Vector2(740, 34)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_color_override("font_shadow_color", Color("26362c"))
	message.add_theme_constant_override("shadow_outline_size", 5)
	add_child(message)
	actions = Control.new()
	actions.name = "WorldActions"
	actions.size = Vector2(270, 270)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actions)
	last_notice = ""
	notice_age = 0
	_refresh_actions()
	_tutorial()

func _tutorial() -> void:
	battle.paused = true
	var box = _modal("守住" + battle.config.name)
	box.add_child(_label("① 点击塔位图标建造，点击已有塔升级或选择分支。\n② 点击兵营旗帜，在附近道路设置士兵集结点。\n③ 左下角火球与援军图标：点击后选择施放位置。\n④ 骷髅旗或空格开始下一波，守完 %d 波即胜利。\n\n%s\n\n右键取消选择 · Esc 暂停" % [battle.config.waves.size(), battle.config.description], 21))
	box.add_child(_button("明白了，准备布防", _close_modal, 450))

func _modal(title: String) -> VBoxContainer:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0.04, 0.08, 0.06, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel = PanelContainer.new()
	panel.position = Vector2(360, 170)
	panel.size = Vector2(720, 540)
	panel.add_theme_stylebox_override("panel", _style(Color("253e32")))
	overlay.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(_label(title, 36))
	return box

func _close_modal() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null
	if battle != null:
		battle.paused = false

func _pause() -> void:
	if screen != "battle" or ended:
		return
	if is_instance_valid(overlay):
		_close_modal()
		return
	battle.paused = true
	audio.clear_combat()
	var box = _modal("暂时休整")
	box.add_child(_label("关卡内进度不会保存，通关结果会自动保存。", 20))
	box.add_child(_button("继续战斗", _close_modal, 450))
	box.add_child(_button("重新开始本关", _start_game, 450))
	box.add_child(_button("返回选关", _level_select, 450))

func _board_clicked(point: Vector2) -> void:
	if battle == null or battle.paused or ended:
		return
	if not targeting.is_empty():
		var accepted = battle.set_rally(rally_index, point) if targeting == "rally" else battle.cast(targeting, point)
		if accepted:
			targeting = ""
			board.targeting = ""
			_refresh_actions()
		return
	selected = -1
	for i in range(battle.pads.size()):
		var pad: Vector2 = battle.pads[i]
		var tower_hit = battle.towers[i] != null and Rect2(pad + Vector2(-46, -105), Vector2(92, 130)).has_point(point)
		if point.distance_to(pad) < 45 or tower_hit:
			selected = i
			break
	board.selected = selected
	_refresh_actions()

func _target(skill: String) -> void:
	if battle.paused or battle.state != "battle":
		return
	if (skill == "meteor" and battle.meteor_cd > 0) or (skill == "reinforce" and battle.reinforce_cd > 0):
		return
	targeting = skill
	board.targeting = skill
	actions.hide()
	battle.notice = "点击战场释放陨火，右键取消。" if skill == "meteor" else "点击道路部署三名援军，右键取消。"

func _cancel_selection() -> void:
	targeting = ""
	board.targeting = ""
	selected = -1
	board.selected = -1
	rally_index = -1
	board.rally_index = -1
	_refresh_actions()

func _command(symbol: String, caption: String, callback: Callable):
	var button = CommandButton.new()
	button.symbol = symbol
	button.caption = caption
	button.display_font = font
	button.pressed.connect(callback)
	return button

func _rally() -> void:
	if selected < 0 or battle.paused or ended:
		return
	rally_index = selected
	board.rally_index = selected
	targeting = "rally"
	board.targeting = "rally"
	actions.hide()
	battle.notice = "在兵营范围内点击道路，士兵将前往新集结点。"

func _radial_command(symbol: String, caption: String, offset: Vector2, callback: Callable, id: String, price: int = -1):
	var button = _command(symbol, caption, callback)
	button.name = id
	button.price = price
	button.position = Vector2(135, 135) + offset - Vector2(38, 36)
	button.set_meta("cost", price)
	actions.add_child(button)
	return button

func _refresh_actions() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	if selected < 0:
		actions.hide()
		return
	var index = selected
	var p: Vector2 = battle.pads[index]
	actions.position = Vector2(clampf(p.x, 140, 1300), clampf(p.y - 15, 205, 735)) - Vector2(135, 135)
	actions.show()
	if battle.towers[index] == null:
		var offsets = [Vector2(-88, 0), Vector2(0, -90), Vector2(88, 0), Vector2(0, 90)]
		var slot = 0
		for kind in ["archer", "barracks", "mage", "cannon"]:
			var data: Dictionary = battle.config.towers[kind]
			var button = _radial_command(kind, "", offsets[slot], func():
				battle.build(index, kind)
				_refresh_actions(), "build_" + kind, int(data.cost))
			button.tooltip_text = "%s · %d 金\n%s" % [data.name, int(data.cost), data.description]
			slot += 1
	else:
		var tower: Dictionary = battle.towers[index]
		var data: Dictionary = battle.config.towers[tower.kind]
		if int(tower.level) < 3:
			var upgrade_button = _radial_command("upgrade", "", Vector2(0, -100), func():
				battle.upgrade(index)
				_refresh_actions(), "upgrade", battle.upgrade_cost(index))
			upgrade_button.tooltip_text = "升级%s · %d 金" % [data.name, battle.upgrade_cost(index)]
			upgrade_button.symbol = tower.kind
			upgrade_button.tower_level = int(tower.level) + 1
		elif int(tower.level) == 3:
			for branch in [0, 1]:
				var branch_button = _radial_command(tower.kind, str(branch + 1), Vector2(-88 if branch == 0 else 88, -55), func():
					battle.upgrade(index, branch)
					_refresh_actions(), "branch_" + str(branch), battle.upgrade_cost(index))
				branch_button.tooltip_text = "%s · %d 金" % [data.branches[branch], battle.upgrade_cost(index)]
				branch_button.tower_level = 4
				branch_button.tower_branch = branch
		if tower.kind == "barracks":
			var flag = _radial_command("flag", "集结", Vector2(0, 88), _rally, "rally")
			flag.tooltip_text = "移动此兵营士兵的集结点"

func _process(delta: float) -> void:
	if screen != "battle" or battle == null:
		return
	# Bounded substeps keep low frame rates from skipping combat interactions.
	var remaining = minf(delta, 0.1) * speed
	while remaining > 0:
		var step_size = minf(remaining, 1.0 / 60.0)
		battle.step(step_size)
		remaining -= step_size
	for event in battle.audio_events:
		audio.play_event(event)
	battle.audio_events.clear()
	hud.text = "%s     生命 %d     金币 %d     波次 %d / %d" % [battle.config.name, battle.lives, battle.gold, battle.wave, battle.config.waves.size()]
	message.text = battle.notice
	if last_notice != battle.notice:
		last_notice = battle.notice
		notice_age = 0
	notice_age += delta if not battle.paused else 0.0
	message.modulate.a = 1.0 if not targeting.is_empty() else clampf(4.0 - notice_age, 0.0, 1.0)
	for command in actions.get_children():
		if command is Button:
			command.disabled = battle.paused or ended or int(command.get_meta("cost", -1)) > battle.gold
	wave_button.disabled = battle.state != "ready" or battle.paused
	wave_button.visible = battle.state == "ready"
	meteor_button.disabled = battle.meteor_cd > 0 or battle.state != "battle" or battle.paused
	reinforce_button.disabled = battle.reinforce_cd > 0 or battle.state != "battle" or battle.paused
	meteor_button.cooldown = battle.meteor_cd
	meteor_button.cooldown_max = 28.0
	reinforce_button.cooldown = battle.reinforce_cd
	reinforce_button.cooldown_max = 20.0
	if battle.state in ["won", "lost"] and not ended:
		ended = true
		_result()

func _result() -> void:
	var won = battle.state == "won"
	audio.clear_combat()
	audio.play_event("victory" if won else "defeat")
	if won and battle.config.id not in save.data.completed:
		save.data.completed.append(battle.config.id)
		save.save_data()
	var box = _modal(battle.config.name + "守住了！" if won else "防线失守")
	box.add_child(_label("完成波次：%d / %d\n击败敌人：%d\n剩余生命：%d\n\n%s" % [battle.wave, battle.config.waves.size(), battle.kills, battle.lives, "通关进度已保存。" if won and save.warning.is_empty() else (save.warning if won else "调整塔的组合：弓箭对空、法师破甲、兵营拦截。")], 23))
	if won and level_index < Campaign.list_levels().size() - 1:
		box.add_child(_button("下一关", _start_game.bind(level_index + 1), 450))
	box.add_child(_button("重新挑战", _start_game, 450))
	box.add_child(_button("返回选关", _level_select, 450))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var fullscreen = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
			_set_fullscreen(not fullscreen)
		if screen == "battle":
			if event.keycode == KEY_ESCAPE:
				if not targeting.is_empty():
					_cancel_selection()
				else:
					_pause()
			elif not battle.paused and not ended:
				if event.keycode == KEY_SPACE:
					battle.start_wave()
				elif event.keycode == KEY_1 and battle.meteor_cd <= 0:
					_target("meteor")
				elif event.keycode == KEY_2 and battle.reinforce_cd <= 0:
					_target("reinforce")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and screen == "battle":
		_cancel_selection()

func _sound() -> void:
	audio.configure(save.data)
	audio.play_event("ui")
