extends RefCounted

var path: String
var backup: String
var writable: bool = true
var data: Dictionary = {"schema_version": 1, "completed": [], "sound": true, "volume": 0.5, "music": true, "music_volume": 0.4}
var warning: String = ""

func _init(file_path: String = "user://progress.json") -> void:
	path = file_path
	backup = file_path + ".backup"

func load_data() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed = _read_json(path)
	if parsed is Dictionary and int(parsed.get("schema_version", 0)) > 1:
		warning = "存档来自更新版本，已保留原文件；当前版本不覆盖它。"
		writable = false
		return
	if not _valid(parsed):
		if FileAccess.file_exists(backup):
			parsed = _read_json(backup)
		if not _valid(parsed):
			warning = "旧存档无法读取，已使用默认进度；原文件保留。"
			writable = false
			return
		warning = "已从备份恢复进度。"
	for key in data:
		if parsed.has(key):
			data[key] = parsed[key]
	data.volume = clampf(float(data.volume), 0.0, 1.0)
	data.music_volume = clampf(float(data.music_volume), 0.0, 1.0)

func _valid(value) -> bool:
	if not (value is Dictionary and value.get("schema_version", 0) in [1, 1.0] and value.get("completed", []) is Array and value.get("sound", true) is bool and (value.get("volume", 0.5) is float or value.get("volume", 0.5) is int)):
		return false
	if not value.get("music", true) is bool or not (value.get("music_volume", 0.4) is float or value.get("music_volume", 0.4) is int):
		return false
	for item in value.get("completed", []):
		if not item is String:
			return false
	return true

func _read_json(file_path: String):
	var json = JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return null
	return json.data

func save_data() -> bool:
	if not writable:
		return false
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		warning = "存档写入失败。"
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	if FileAccess.file_exists(path):
		var old = _read_json(path)
		var destination = backup if _valid(old) else path + ".damaged"
		var copied = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(destination))
		if copied != OK:
			warning = "无法备份旧存档，已取消覆盖。"
			return false
	var result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if result != OK:
		warning = "存档替换失败，临时文件已保留。"
	if result == OK:
		warning = ""
	return result == OK
