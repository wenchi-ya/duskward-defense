extends SceneTree
## Inspect alpha only. Source images are never modified or resampled.

func _initialize() -> void:
	var manifest = {"version": 1, "towers": {}, "units": {}, "icons": {}}
	for kind in ["archer", "barracks", "mage", "cannon"]:
		manifest.towers[kind] = inspect_sheet("res://art/towers/" + kind + ".png", 5, 1)
	for kind in ["soldier", "goblin", "wolf", "brute", "bat", "shaman"]:
		manifest.units[kind] = inspect_sheet("res://art/units/" + kind + ".png", 6, 2)
	for kind in ["meteor", "reinforce"]:
		var path = "res://art/icons/" + kind + ".png"
		var image = Image.load_from_file(path)
		assert(image != null and image.get_format() == Image.FORMAT_RGBA8, "Ability icon must have alpha")
		manifest.icons[kind] = path
	var file = FileAccess.open("res://data/art_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	print("ART IMPORT: 20 tower forms, 72 unit frames and 2 icons inspected")
	quit()

func inspect_sheet(path: String, columns: int, rows: int) -> Dictionary:
	var image = Image.load_from_file(path)
	assert(image != null and image.get_format() == Image.FORMAT_RGBA8, "Sheet missing or not transparent: " + path)
	var w = image.get_width()
	var h = image.get_height()
	var horizontal: Array[int] = []
	horizontal.resize(h)
	horizontal.fill(0)
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a > 0.15:
				horizontal[y] += 1
	var y_edges: Array[int] = [0]
	for row in range(1, rows):
		y_edges.append(find_gap(horizontal, int(h * row / float(rows)), int(h / float(rows) * 0.28)))
	y_edges.append(h)
	var frames: Array = []
	var walk_heights: Array = []
	for row in range(rows):
		var vertical: Array[int] = []
		vertical.resize(w)
		vertical.fill(0)
		for y in range(y_edges[row], y_edges[row + 1]):
			for x in range(w):
				if image.get_pixel(x, y).a > 0.15:
					vertical[x] += 1
		var x_edges: Array[int] = [0]
		for column in range(1, columns):
			x_edges.append(find_gap(vertical, int(w * column / float(columns)), int(w / float(columns) * 0.32)))
		x_edges.append(w)
		for column in range(columns):
			var left = x_edges[column]
			var right = x_edges[column + 1]
			var top = y_edges[row]
			var bottom = y_edges[row + 1]
			var min_x = right
			var min_y = bottom
			var max_x = left
			var max_y = top
			for y in range(top, bottom):
				for x in range(left, right):
					if image.get_pixel(x, y).a > 0.15:
						min_x = mini(min_x, x)
						min_y = mini(min_y, y)
						max_x = maxi(max_x, x)
						max_y = maxi(max_y, y)
			assert(max_x > min_x and max_y > min_y, "Empty frame: " + path)
			var width = max_x - min_x + 1
			var height = max_y - min_y + 1
			frames.append({"rect": [min_x, min_y, width, height], "offset": [min_x - (left + right) / 2.0, -height]})
			if row == 0:
				walk_heights.append(height)
	walk_heights.sort()
	var reference_height = walk_heights[walk_heights.size() / 2]
	print(path, " size=", image.get_size(), " frames=", frames.size(), " row_edges=", y_edges)
	return {"path": path, "width": w, "height": h, "columns": columns, "rows": rows, "reference_height": reference_height, "frames": frames}

func find_gap(counts: Array[int], center: int, radius: int) -> int:
	var result = center
	var best = counts[center]
	for index in range(maxi(1, center - radius), mini(counts.size() - 1, center + radius)):
		if counts[index] < best or (counts[index] == best and absi(index - center) < absi(result - center)):
			result = index
			best = counts[index]
	return result
