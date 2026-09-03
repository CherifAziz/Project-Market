extends CanvasLayer

@onready var target_label: Label = %TargetLabel
@onready var sector_label: Label = %SectorLabel
@onready var dash_bar: ProgressBar = %DashBar
@onready var dash_label: Label = %DashLabel
@onready var equipment_context: PanelContainer = %EquipmentContext
@onready var equipment_name_label: Label = %EquipmentName
@onready var equipment_status_label: Label = %EquipmentStatus
@onready var equipment_health_bar: ProgressBar = %EquipmentHealthBar
@onready var equipment_integrity_label: Label = %EquipmentIntegrity

var _player: PlayerController
var _initial_target_count := 0
var _focused_equipment: DestructibleEquipment

const EQUIPMENT_PROXIMITY := 3.2

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_initial_target_count = get_tree().get_nodes_in_group("targets").size()

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player:
		var dash_ratio := _player.get_dash_ready_ratio()
		dash_bar.value = dash_ratio * 100.0
		dash_label.text = "DASH  READY" if dash_ratio >= 0.999 else "DASH  %02d" % int(dash_ratio * 100.0)

	var remaining := get_tree().get_nodes_in_group("targets").size()
	target_label.text = "%02d" % remaining
	if _initial_target_count > 0 and remaining == 0:
		sector_label.text = "SECTOR LIQUIDATED  //  R TO RESET"
		sector_label.modulate = Color("75fbff")
	else:
		sector_label.text = "HOSTILE ASSETS"

	_update_equipment_context(delta)

func _update_equipment_context(delta: float) -> void:
	var equipment := _find_context_equipment()
	if equipment == null:
		equipment_context.modulate.a = move_toward(equipment_context.modulate.a, 0.0, delta * 8.0)
		if equipment_context.modulate.a <= 0.01:
			equipment_context.visible = false
			_focused_equipment = null
		return

	_focused_equipment = equipment
	equipment_context.visible = true
	equipment_context.modulate.a = move_toward(equipment_context.modulate.a, 1.0, delta * 10.0)
	equipment_name_label.text = "VITA  //  " + equipment.display_name
	equipment_status_label.text = equipment.get_status_text()
	var context_color := equipment.get_context_color()
	equipment_status_label.add_theme_color_override("font_color", context_color)
	var fill_style := equipment_health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = context_color.darkened(0.08)
	equipment_health_bar.value = equipment.get_health_ratio() * 100.0
	equipment_integrity_label.text = "%d%%" % int(round(equipment.get_health_ratio() * 100.0))

	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(equipment.get_context_world_position()):
		return
	var screen_position := camera.unproject_position(equipment.get_context_world_position())
	var viewport_size := get_viewport().get_visible_rect().size
	var desired_position := screen_position + Vector2(-equipment_context.size.x * 0.5, -equipment_context.size.y - 15.0)
	desired_position.x = clampf(desired_position.x, 12.0, viewport_size.x - equipment_context.size.x - 12.0)
	desired_position.y = clampf(desired_position.y, 96.0, viewport_size.y - equipment_context.size.y - 90.0)
	if equipment_context.position == Vector2.ZERO:
		equipment_context.position = desired_position
	else:
		equipment_context.position = equipment_context.position.lerp(desired_position, 1.0 - exp(-14.0 * delta))

func _find_context_equipment() -> DestructibleEquipment:
	var aimed := _equipment_under_cursor()
	if aimed:
		return aimed
	if not is_instance_valid(_player):
		return null
	var nearest: DestructibleEquipment
	var nearest_distance := EQUIPMENT_PROXIMITY
	for node in get_tree().get_nodes_in_group("vita_equipment"):
		var equipment := node as DestructibleEquipment
		if equipment == null or not equipment.is_context_relevant():
			continue
		var distance := Vector2(
			equipment.global_position.x - _player.global_position.x,
			equipment.global_position.z - _player.global_position.z
		).length()
		if distance <= nearest_distance:
			nearest = equipment
			nearest_distance = distance
	return nearest

func _equipment_under_cursor() -> DestructibleEquipment:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse_position := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_position)
	var endpoint := origin + camera.project_ray_normal(mouse_position) * 80.0
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 2)
	if is_instance_valid(_player):
		query.exclude = [_player.get_rid()]
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.collider as DestructibleEquipment
