extends RefCounted
## First-level defaults remain compatible; each map overrides only its own data.

static func list_levels() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))

static func level(index: int = 0) -> Dictionary:
	var levels = list_levels()
	assert(index >= 0 and index < levels.size(), "Invalid campaign level")
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/first_level.json"))
	var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/extra_enemies.json"))
	result.enemies.merge(extra)
	for key in levels[index]:
		result[key] = levels[index][key]
	result.index = index
	return result
