class_name PlayerController
extends CharacterBody3D

signal dash_state_changed(ready_ratio: float)

@export_group("Movement")
@export var move_speed := 7.6
@export var acceleration := 42.0
@export var deceleration := 55.0

@export_group("Dash")
@export var dash_speed := 21.0
@export var dash_duration := 0.14
@export var dash_cooldown := 0.72

@onready var visual: Node3D = %Visual
@onready var weapon: AutomaticWeapon = %AutomaticWeapon
@onready var aim_cursor: MeshInstance3D = %AimCursor

var aim_direction := Vector3.FORWARD
var _aim_point := Vector3.ZERO
var _dash_direction := Vector3.FORWARD
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _visual_time := 0.0
var _dash_tween: Tween

func _ready() -> void:
	add_to_group("player")
	aim_cursor.top_level = true

func _physics_process(delta: float) -> void:
	_update_aim()
	_update_dash_timers(delta)

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0:
		_start_dash(move_direction)

	if _dash_time_left > 0.0:
		velocity.x = _dash_direction.x * dash_speed
		velocity.z = _dash_direction.z * dash_speed
	else:
		var target_velocity := move_direction * move_speed
		var rate := acceleration if move_direction != Vector3.ZERO else deceleration
		velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5

	move_and_slide()
	weapon.tick(delta, Input.is_action_pressed("shoot"))
	_update_visual(delta, move_direction)
	dash_state_changed.emit(get_dash_ready_ratio())

func _update_aim() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ground_plane := Plane(Vector3.UP, 0.035)
	var intersection: Variant = ground_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return
	_aim_point = intersection
	var flat_direction := _aim_point - global_position
	flat_direction.y = 0.0
	if flat_direction.length_squared() > 0.04:
		aim_direction = flat_direction.normalized()
		rotation.y = atan2(-aim_direction.x, -aim_direction.z)
	aim_cursor.global_position = _aim_point + Vector3.UP * 0.015

func _update_dash_timers(delta: float) -> void:
	_dash_time_left = maxf(_dash_time_left - delta, 0.0)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)

func _start_dash(move_direction: Vector3) -> void:
	_dash_direction = move_direction if move_direction != Vector3.ZERO else aim_direction
	_dash_direction.y = 0.0
	_dash_direction = _dash_direction.normalized()
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown

	if _dash_tween and _dash_tween.is_valid():
		_dash_tween.kill()
	visual.scale = Vector3(0.8, 0.82, 1.3)
	_dash_tween = create_tween()
	_dash_tween.tween_property(visual, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_dash(global_position, _dash_direction)
		effects.add_camera_shake(0.32)

func _update_visual(delta: float, move_direction: Vector3) -> void:
	_visual_time += delta * (10.0 if move_direction != Vector3.ZERO else 4.0)
	var speed_ratio := Vector2(velocity.x, velocity.z).length() / dash_speed
	visual.position.y = sin(_visual_time) * 0.035 * clampf(speed_ratio * 2.0, 0.0, 1.0)

func get_dash_ready_ratio() -> float:
	return 1.0 - clampf(_dash_cooldown_left / dash_cooldown, 0.0, 1.0)

