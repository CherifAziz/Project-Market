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
@onready var player_health_bar: ProgressBar = %PlayerHealthBar
@onready var player_health_label: Label = %PlayerHealthLabel
@onready var damage_flash: ColorRect = %DamageFlash
@onready var security_alert_panel: PanelContainer = %SecurityAlertPanel
@onready var security_alert_label: Label = %SecurityAlertLabel
@onready var crosshair: Control = $Crosshair
@onready var extraction_label: Label = %ExtractionLabel
@onready var extraction_detail: Label = %ExtractionDetail
@onready var extraction_progress: ProgressBar = %ExtractionProgress
@onready var extraction_arrow: Label = %ExtractionArrow

var _player: PlayerController
var _security_director: SecurityDirector
var _extraction: ExtractionPoint
var _initial_target_count := 0
var _focused_equipment: DestructibleEquipment
var _damage_flash_tween: Tween
var _security_alert_tween: Tween

const EQUIPMENT_PROXIMITY := 3.2

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_initial_target_count = get_tree().get_nodes_in_group("targets").size()
	call_deferred("_bind_runtime_signals")

func _bind_runtime_signals() -> void:
	_extraction = get_tree().get_first_node_in_group("extraction_point") as ExtractionPoint
	if is_instance_valid(_player):
		if not _player.health_changed.is_connected(_on_player_health_changed):
			_player.health_changed.connect(_on_player_health_changed)
		if not _player.damaged.is_connected(_on_player_damaged):
			_player.damaged.connect(_on_player_damaged)
		if not _player.died.is_connected(_on_player_died):
			_player.died.connect(_on_player_died)
		_on_player_health_changed(_player.health, _player.max_health)
	_security_director = get_tree().get_first_node_in_group("security_director") as SecurityDirector
	if is_instance_valid(_security_director):
		if not _security_director.security_alert.is_connected(_on_security_alert):
			_security_director.security_alert.connect(_on_security_alert)
		if not _security_director.security_count_changed.is_connected(_on_security_count_changed):
			_security_director.security_count_changed.connect(_on_security_count_changed)
		_initial_target_count = maxi(_initial_target_count, _security_director.get_initial_count())

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		_bind_runtime_signals()
	if _player:
		var dash_ratio := _player.get_dash_ready_ratio()
		dash_bar.value = dash_ratio * 100.0
		dash_label.text = "DASH  READY" if dash_ratio >= 0.999 else "DASH  %02d" % int(dash_ratio * 100.0)

	var remaining := get_tree().get_nodes_in_group("targets").size()
	if _initial_target_count == 0 and remaining > 0:
		_initial_target_count = remaining
	target_label.text = "%02d" % remaining
	if _initial_target_count > 0 and remaining == 0:
		sector_label.text = "SECURITY NEUTRALIZED  //  EXTRACT"
		sector_label.modulate = Color("9fc49f")
	else:
		sector_label.text = "SECURITY PRESENCE"

	_update_equipment_context(delta)
	_update_extraction_hint()

func _update_extraction_hint() -> void:
	if not is_instance_valid(_extraction) or not is_instance_valid(_player):
		return
	var available := _extraction.is_available()
	var nearby := _extraction.is_player_near()
	extraction_progress.visible = available and nearby
	extraction_progress.value = _extraction.get_progress() * 100.0
	extraction_arrow.visible = available and not nearby
	if not available:
		extraction_label.text = "SABOTAGE  →  SURVIVE  →  EXTRACT"
		extraction_detail.text = "ATTACK A COMPANY MACHINE TO UNLOCK THE EXIT"
	elif not nearby:
		extraction_label.text = "SERVICE EXIT  //  %d m" % int(ceil(_extraction.get_player_distance()))
		extraction_detail.text = "REACH THE EXIT TO SECURE ALL RUN GAINS"
	elif _extraction.is_interrupted():
		extraction_label.text = "HIT  //  EXTRACTION INTERRUPTED"
		extraction_detail.text = "GET CLEAR — THEN HOLD E AGAIN"
	else:
		extraction_label.text = "EXTRACTING  %02d%%" % int(extraction_progress.value) if _extraction.get_progress() > 0.0 else "HOLD E  //  EXTRACT  %.1f s" % _extraction.hold_duration
		extraction_detail.text = "STAY STILL — DASH OR DAMAGE INTERRUPTS"
	var camera := get_viewport().get_camera_3d()
	if camera != null and extraction_arrow.visible:
		var direction := camera.unproject_position(_extraction.global_position) - camera.unproject_position(_player.global_position)
		extraction_arrow.pivot_offset = extraction_arrow.size * 0.5
		extraction_arrow.rotation = direction.angle() + PI * 0.5

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
	equipment_name_label.text = "%s  //  %s" % [equipment.owner_ticker, equipment.display_name]
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
	for node in get_tree().get_nodes_in_group("company_equipment"):
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

func _on_player_health_changed(current_health: float, max_health: float) -> void:
	var ratio := clampf(current_health / maxf(max_health, 0.001), 0.0, 1.0)
	player_health_bar.value = ratio * 100.0
	player_health_label.text = "HEALTH  %03d" % int(round(current_health))
	var fill_style := player_health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style != null:
		fill_style.bg_color = Color("b96654") if ratio < 0.34 else Color("789b7f")

func _on_player_damaged(_amount: float, _current_health: float) -> void:
	if _damage_flash_tween != null and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()
	damage_flash.visible = true
	damage_flash.color.a = 0.24
	_damage_flash_tween = create_tween().set_ignore_time_scale(true)
	_damage_flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_player_died() -> void:
	crosshair.visible = false
	equipment_context.visible = false
	dash_label.text = "DASH  UNAVAILABLE"

func _on_security_alert(_company_id: String, message: String, accent_color: Color, pressure_stage: int) -> void:
	if _security_alert_tween != null and _security_alert_tween.is_valid():
		_security_alert_tween.kill()
	security_alert_label.text = "%s  //  LEVEL %02d" % [message, maxi(pressure_stage, 1)]
	security_alert_label.add_theme_color_override("font_color", accent_color.lightened(0.36))
	var style := security_alert_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color(accent_color, 0.9)
	security_alert_panel.add_theme_stylebox_override("panel", style)
	security_alert_panel.visible = true
	security_alert_panel.modulate.a = 0.0
	security_alert_panel.position.y = -7.0
	_security_alert_tween = create_tween().set_ignore_time_scale(true)
	_security_alert_tween.set_parallel(true)
	_security_alert_tween.tween_property(security_alert_panel, "modulate:a", 1.0, 0.13)
	_security_alert_tween.tween_property(security_alert_panel, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_security_alert_tween.set_parallel(false)
	_security_alert_tween.tween_interval(1.25)
	_security_alert_tween.tween_property(security_alert_panel, "modulate:a", 0.0, 0.32)
	_security_alert_tween.finished.connect(func() -> void: security_alert_panel.visible = false)

func _on_security_count_changed(_alive_count: int, initial_count: int) -> void:
	_initial_target_count = maxi(_initial_target_count, initial_count)
