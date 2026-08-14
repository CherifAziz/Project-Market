extends Control

var _kick := 0.0
var _weapon: AutomaticWeapon

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_connect_weapon")

func _process(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 7.5)
	queue_redraw()

func _draw() -> void:
	var center := get_viewport().get_mouse_position()
	var cyan := Color(0.55, 0.98, 1.0, 0.92)
	var shadow := Color(0.0, 0.02, 0.05, 0.8)
	var gap := 8.0 + _kick * 7.0
	var line_length := 6.0
	draw_circle(center, 2.1 + _kick * 0.9, cyan)
	draw_arc(center, 9.0 + _kick * 4.0, -0.75, 0.75, 16, cyan, 1.35, true)
	draw_arc(center, 9.0 + _kick * 4.0, PI - 0.75, PI + 0.75, 16, cyan, 1.35, true)
	for direction_value in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var direction := direction_value as Vector2
		var perpendicular := Vector2(-direction.y, direction.x)
		var start: Vector2 = center + direction * gap
		var finish: Vector2 = center + direction * (gap + line_length)
		draw_line(start + perpendicular, finish + perpendicular, shadow, 3.5, true)
		draw_line(start, finish, cyan, 1.4, true)

func _connect_weapon() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player and player.weapon:
		_weapon = player.weapon
		if not _weapon.fired.is_connected(_on_weapon_fired):
			_weapon.fired.connect(_on_weapon_fired)

func _on_weapon_fired() -> void:
	_kick = minf(_kick + 0.68, 1.0)
