extends SceneTree

func _initialize() -> void:
	var image = Image.load_from_file("res://art/gameplay/units-towers-v1.png")
	var best = image.get_width()
	var best_row = 0
	for y in range(int(image.get_height() * 0.45), int(image.get_height() * 0.65)):
		var count = 0
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.1:
				count += 1
		if count < best:
			best = count
			best_row = y
	print("ATLAS dimensions=", image.get_size(), " format=", image.get_format(), " row_split=", best_row, " opacity_count=", best)
	for column in range(4):
		for row in range(2):
			var left = int(column * image.get_width() / 4.0)
			var right = int((column + 1) * image.get_width() / 4.0)
			var top = 0 if row == 0 else best_row
			var bottom = best_row if row == 0 else image.get_height()
			var bounds = Rect2i(right, bottom, 0, 0)
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
			print("REGION ", column, ",", row, ": ", Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	quit()
