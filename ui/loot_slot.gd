class_name LootSlot
extends Control

var item: Dictionary = {}
var key_number := 0
var flash := 0.0
var _pulse: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(76, 82)

func set_item(value: Dictionary) -> void:
	item = value
	queue_redraw()

func pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	flash = 1.0
	_pulse = create_tween()
	_pulse.tween_method(func(value: float) -> void: flash = value; queue_redraw(), 1.0, 0.0, 0.28)

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151d19").lerp(Color("66775b"), flash * 0.45)
	style.bg_color.a = 0.9
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.border_color = Color("9aa58d") if key_number > 0 else Color("526054")
	draw_style_box(style, Rect2(Vector2.ZERO, Vector2(76, 82)))
	if item.is_empty():
		draw_line(Vector2(29, 40), Vector2(47, 40), Color("526054"), 2)
	else:
		draw_icon(self, Vector2(38, 30), item)
		var text := MoneyFormat.short_cash(float(item["value"]))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2((76 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x) * 0.5, 70), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("eee5cc"))
	if key_number > 0:
		var key_style := StyleBoxFlat.new()
		key_style.bg_color = Color("e2ddc6")
		key_style.set_corner_radius_all(3)
		draw_style_box(key_style, Rect2(3, -9, 23, 24))
		draw_string(ThemeDB.fallback_font, Vector2(10, 9), str(key_number), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("20281f"))

# Same six shape/color identities as the world props, without descriptive labels.
static func draw_icon(canvas: CanvasItem, at: Vector2, data: Dictionary) -> void:
	var accent: Color = data.get("accent", Color("9cae91"))
	var pale := Color("e5e1cf")
	var dark := Color("26362f")
	canvas.draw_set_transform(at)
	match int(data.get("visual_kind", 0)):
		LootDefinition.VisualKind.MEDICAL_CASE:
			canvas.draw_rect(Rect2(-25, -14, 50, 30), pale)
			canvas.draw_rect(Rect2(-9, -19, 18, 5), dark)
			canvas.draw_rect(Rect2(-4, -11, 8, 24), accent)
			canvas.draw_rect(Rect2(-13, -3, 26, 8), accent)
		LootDefinition.VisualKind.LAB_INSTRUMENT:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-23, 18), Vector2(-23, 9), Vector2(-15, 9), Vector2(-15, -18), Vector2(19, -18), Vector2(19, -6), Vector2(7, -6), Vector2(7, -10), Vector2(-5, -10), Vector2(-5, 9), Vector2(21, 9), Vector2(21, 18)]), accent)
			canvas.draw_rect(Rect2(-7, -19, 29, 9), pale)
			canvas.draw_circle(Vector2(10, 5), 5, pale)
		LootDefinition.VisualKind.SAMPLE_CASE:
			canvas.draw_rect(Rect2(-24, 9, 48, 10), accent)
			for x in [-12, 12]:
				canvas.draw_rect(Rect2(x - 7, -16, 14, 28), pale)
				canvas.draw_rect(Rect2(x - 8, -20, 16, 7), accent)
				canvas.draw_rect(Rect2(x - 7, -2, 14, 7), accent)
		LootDefinition.VisualKind.ENERGY_MODULE:
			canvas.draw_rect(Rect2(-27, -15, 54, 34), accent)
			for x in [-18, -9, 0, 9, 18]:
				canvas.draw_rect(Rect2(x - 2, -19, 4, 23), dark)
			canvas.draw_rect(Rect2(-9, 10, 18, 4), pale)
		LootDefinition.VisualKind.COPPER_SPOOL:
			canvas.draw_rect(Rect2(-17, -14, 34, 28), accent)
			for x in [-10, -3, 4, 11]:
				canvas.draw_line(Vector2(x, -13), Vector2(x, 13), accent.lightened(0.25), 2)
			for x in [-20, 20]:
				canvas.draw_set_transform(at + Vector2(x, 0), 0, Vector2(0.43, 1))
				canvas.draw_circle(Vector2.ZERO, 19, pale)
				canvas.draw_circle(Vector2.ZERO, 6, dark)
		LootDefinition.VisualKind.POWER_COMPONENT:
			canvas.draw_rect(Rect2(-26, 12, 52, 8), dark)
			for x in [-17, 0, 17]:
				canvas.draw_rect(Rect2(x - 4, -22, 8, 35), accent)
				for y in [-14, -4, 6]:
					canvas.draw_rect(Rect2(x - 7, y, 14, 4), accent.lightened(0.25))
	canvas.draw_set_transform(Vector2.ZERO)
