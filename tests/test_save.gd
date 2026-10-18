extends SceneTree

const SaveStore = preload("res://scripts/save_store.gd")
const TEST_PATH = "res://tests/output/test-progress.json"
var failures: int = 0
var assertions: int = 0

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
	else:
		print("PASS: " + label)

func write_file(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var store = SaveStore.new(TEST_PATH)
	store.data.completed = ["village_01"]
	check(store.save_data(), "write progress")
	store.data.volume = 0.7
	check(store.save_data(), "replace existing progress and create backup")
	var loaded = SaveStore.new(TEST_PATH)
	loaded.load_data()
	check(loaded.data.completed == ["village_01"] and is_equal_approx(loaded.data.volume, 0.7), "progress and settings survive reload")
	write_file(TEST_PATH, "{broken")
	loaded = SaveStore.new(TEST_PATH)
	loaded.load_data()
	check(loaded.data.completed == ["village_01"] and not loaded.warning.is_empty(), "recover malformed primary from backup")
	check(loaded.save_data() and FileAccess.file_exists(TEST_PATH + ".damaged"), "preserve damaged original before replacement")
	write_file(TEST_PATH, '{"schema_version":99,"completed":["future"]}')
	loaded = SaveStore.new(TEST_PATH)
	loaded.load_data()
	check(not loaded.save_data() and "future" in FileAccess.get_file_as_string(TEST_PATH), "future schema cannot be overwritten")
	check(not store._valid({"schema_version":1,"completed":[42]}), "reject malformed progress identifiers")
	print("RESULT: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
