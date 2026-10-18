extends Button
const ArtAtlas = preload("res://scripts/art_atlas.gd")
const VisualAssets = preload("res://scripts/visual_assets.gd")
## Canvas-native command icon. Labels are short; full descriptions use tooltips.

var symbol: String = "flag"
var caption: String = ""
var price: int = -1
var cooldown: float = 0.0
var cooldown_max: float = 1.0
var atlas: Texture2D
var ink = Color("392b27")
var accent = Color("d5b775")
var display_font: Font
var picture: Texture2D
var tower_level: int = 1
var tower_branch: int = -1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2(76, 82)
	size = Vector2(76, 82)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	if ResourceLoader.exists("res://art/gameplay/units-towers-v1.png"):
		atlas = load("res://art/gameplay/units-towers-v1.png")
	if symbol in ["meteor", "reinforce"]:
		picture = VisualAssets.icon(symbol)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center = Vector2(38, 36)
	var hovered = is_hovered() and not disabled
	var push = Vector2(0, 2) if button_pressed else Vector2.ZERO
	center += push
	draw_circle(center + Vector2(0, 5), 36, Color(0.05, 0.04, 0.03, 0.35))
	draw_circle(center, 36, ink)
	draw_circle(center, 33, Color("e3c27e") if hovered else Color("ac8956"))
	draw_circle(center, 29, Color("395448") if hovered else Color("283c36"))
	draw_arc(center, 31, -2.8, -0.4, 32, Color("efdbad"), 2, true)
	var tint = Color(1, 1, 1, 0.4) if disabled else Color.WHITE
	if picture != null:
		draw_texture_rect(picture, Rect2(center - Vector2(28, 28), Vector2(56, 56)), false, tint)
	elif symbol in ["archer", "barracks", "mage", "cannon"]:
		var frame = VisualAssets.tower(symbol, tower_level, tower_branch)
		if not frame.is_empty():
			var source: Rect2 = frame.rect
			var dimensions = source.size * (52.0 / maxf(source.size.x, source.size.y))
			draw_texture_rect_region(frame.texture, Rect2(center - Vector2(dimensions.x / 2, dimensions.y / 2 + 3), dimensions), source, tint)
	else:
		_draw_symbol(center, tint)
	if cooldown > 0:
		draw_arc(center, 27, -PI / 2, -PI / 2 + TAU * clampf(cooldown / cooldown_max, 0, 1), 48, Color(0.1, 0.13, 0.15, 0.8), 13, true)
		_text(str(ceili(cooldown)), center + Vector2(0, 8), 22, Color("fff4d8"))
	var bottom = str(price) if price >= 0 else caption
	if not bottom.is_empty():
		var width = maxf(42, _font().get_string_size(bottom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 14)
		draw_style_box(_plaque(), Rect2(Vector2(38 - width / 2, 62), Vector2(width, 23)))
		_text(bottom, Vector2(38, 79), 15, Color("f6e4af") if not disabled else Color("aaa28c"))

func _font() -> Font:
	return display_font if display_font != null else ThemeDB.fallback_font

func _text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	var width = _font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font(), at - Vector2(width / 2, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _plaque() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("44372c")
	style.border_color = Color("b79b66")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _draw_symbol(p: Vector2, tint: Color) -> void:
	var gold = Color("f4d293") * tint
	var blue = Color("a9d2e2") * tint
	match symbol:
		"upgrade":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -22), p + Vector2(19, -3), p + Vector2(8, -3), p + Vector2(8, 20), p + Vector2(-8, 20), p + Vector2(-8, -3), p + Vector2(-19, -3)]), gold)
		"flag":
			draw_line(p + Vector2(-10, 20), p + Vector2(-10, -23), gold, 4, true)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -22), p + Vector2(21, -16), p + Vector2(-8, -4)]), blue)
		"wave":
			draw_circle(p + Vector2(0, -3), 18, gold)
			draw_circle(p + Vector2(-7, -6), 5, ink)
			draw_circle(p + Vector2(7, -6), 5, ink)
			draw_rect(Rect2(p + Vector2(-9, 9), Vector2(18, 11)), gold)
			for x in [-5, 0, 5]:
				draw_line(p + Vector2(x, 13), p + Vector2(x, 21), ink, 2)
		"meteor":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-17, 17), p + Vector2(-10, -4), p + Vector2(21, -25), p + Vector2(12, 0), p + Vector2(-1, 20)]), Color("ec7a3c") * tint)
			draw_circle(p + Vector2(-4, 7), 11, Color("ffcf71") * tint)
			draw_circle(p + Vector2(-4, 7), 5, Color("fff2bf") * tint)
		"reinforce":
			for x in [-14, 0, 14]:
				draw_circle(p + Vector2(x, -10 if x == 0 else -3), 7, blue)
				draw_line(p + Vector2(x, -2 if x == 0 else 5), p + Vector2(x, 17), blue, 10, true)
		"close":
			draw_line(p + Vector2(-9, -9), p + Vector2(9, 9), gold, 4, true)
			draw_line(p + Vector2(9, -9), p + Vector2(-9, 9), gold, 4, true)
