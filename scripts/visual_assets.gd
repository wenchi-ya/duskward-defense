extends RefCounted
## Runtime atlas selection. Walk phase follows traveled distance, not wall time.
static var manifest: Dictionary = {}
static var textures: Dictionary = {}

static func _load_manifest() -> void:
	if manifest.is_empty() and FileAccess.file_exists("res://data/art_manifest.json"):
		manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_manifest.json"))

static func texture(path: String) -> Texture2D:
	if not textures.has(path) and ResourceLoader.exists(path):
		textures[path] = load(path)
	return textures.get(path)

static func icon(kind: String) -> Texture2D:
	_load_manifest()
	return texture(manifest.get("icons", {}).get(kind, ""))

static func tower(kind: String, level: int, branch: int = -1) -> Dictionary:
	_load_manifest()
	if not manifest.get("towers", {}).has(kind):
		return {}
	var sheet: Dictionary = manifest.towers[kind]
	var index = clampi(level - 1, 0, 3)
	if level == 4 and branch == 1:
		index = 4
	return _frame(sheet, index)

static func unit(kind: String, data: Dictionary) -> Dictionary:
	_load_manifest()
	if not manifest.get("units", {}).has(kind):
		return {}
	var sheet: Dictionary = manifest.units[kind]
	var frame_index = 11
	if float(data.get("swing", 0.0)) > 0:
		frame_index = 6 + clampi(int((1.0 - float(data.swing) / 0.48) * 6), 0, 5)
	elif bool(data.get("moving", false)):
		var stride = 7.0 if kind == "wolf" else (6.0 if kind == "brute" else 5.0)
		frame_index = int(float(data.get("walk_distance", 0.0)) / stride) % 6
	return _frame(sheet, frame_index)

static func _frame(sheet: Dictionary, index: int) -> Dictionary:
	var frame: Dictionary = sheet.frames[index]
	var rect: Array = frame.rect
	return {"texture": texture(sheet.path), "rect": Rect2(rect[0], rect[1], rect[2], rect[3]), "offset": Vector2(frame.offset[0], frame.offset[1]), "reference_height": float(sheet.reference_height), "index": index, "path": sheet.path}
