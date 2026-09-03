class_name PlayerController
extends CharacterBody3D

signal dash_state_changed(ready_ratio: float)
signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float, current_health: float)
signal died

@export_group("Health")
@export var max_health := 100.0
@export_range(0.0, 1.0, 0.01) var hurt_invulnerability := 0.28

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

var health := 0.0
var aim_direction := Vector3.FORWARD
var _aim_point := Vector3.ZERO
var _dash_direction := Vector3.FORWARD
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _visual_time := 0.0
var _dash_tween: Tween
var _gameplay_input_enabled := true
var _hurt_invulnerability_left := 0.0
var _dead := false
var _damage_enabled := true
var _damage_tween: Tween
var _death_tween: Tween
var _flash_materials: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("player")
	health = max_health
	aim_cursor.top_level = true
	_prepare_flash_materials()
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if not _gameplay_input_enabled:
		_update_dash_timers(delta)
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		if not is_on_floor():
			velocity.y -= 18.0 * delta
		else:
			velocity.y = -0.5
		move_and_slide()
		weapon.tick(delta, false)
		if not _dead:
			_update_visual(delta, Vector3.ZERO)
		dash_state_changed.emit(get_dash_ready_ratio())
		return

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
	weapon.set_aim_point(_aim_point)
	aim_cursor.global_position = _aim_point + Vector3.UP * 0.015

func _update_dash_timers(delta: float) -> void:
	_dash_time_left = maxf(_dash_time_left - delta, 0.0)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_hurt_invulnerability_left = maxf(_hurt_invulnerability_left - delta, 0.0)

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

func set_gameplay_input_enabled(enabled: bool) -> void:
	_gameplay_input_enabled = enabled and not _dead
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0

func is_gameplay_input_enabled() -> bool:
	return _gameplay_input_enabled

func set_damage_enabled(enabled: bool) -> void:
	_damage_enabled = enabled

func take_damage(amount: float, hit_position := Vector3.ZERO, _hit_normal := Vector3.UP, shot_direction := Vector3.ZERO) -> bool:
	if _dead or not _damage_enabled or amount <= 0.0 or _hurt_invulnerability_left > 0.0 or is_dashing():
		return false
	health = maxf(health - amount, 0.0)
	_hurt_invulnerability_left = hurt_invulnerability
	_flash_damage()
	health_changed.emit(health, max_health)
	damaged.emit(amount, health)

	var effects := get_tree().get_first_node_in_group("effects")
	if effects != null:
		if effects.has_method("spawn_player_hit"):
			effects.spawn_player_hit(hit_position if hit_position != Vector3.ZERO else global_position + Vector3.UP * 0.6, shot_direction)
		else:
			effects.add_camera_shake(0.45)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_world"):
		audio.play_world(&"player_hit", global_position + Vector3.UP * 0.6, 0.025)

	if health <= 0.0:
		_die()
	return true

func is_dashing() -> bool:
	return _dash_time_left > 0.0

func is_alive() -> bool:
	return not _dead

func get_health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)

func _die() -> void:
	if _dead:
		return
	_dead = true
	_gameplay_input_enabled = false
	velocity = Vector3.ZERO
	aim_cursor.visible = false
	weapon.tick(0.0, false)
	died.emit()

	var effects := get_tree().get_first_node_in_group("effects")
	if effects != null:
		if effects.has_method("spawn_player_down"):
			effects.spawn_player_down(global_position)
		effects.hitstop(0.07, 0.08)
	var fall_direction := -1.0 if aim_direction.x >= 0.0 else 1.0
	_death_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_death_tween.tween_property(visual, "rotation:z", deg_to_rad(78.0) * fall_direction, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(visual, "position:y", -0.34, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(visual, "scale", Vector3(1.08, 0.82, 1.08), 0.4)

func _flash_damage() -> void:
	if _damage_tween != null and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	for entry in _flash_materials:
		var material: StandardMaterial3D = entry["material"]
		material.albedo_color = Color("f4b3a0")
		material.emission = Color("d96f5b")
		material.emission_energy_multiplier = 1.4
		_damage_tween.tween_property(material, "albedo_color", entry["albedo"], 0.2)
		_damage_tween.tween_property(material, "emission", entry["emission"], 0.22)
		_damage_tween.tween_property(material, "emission_energy_multiplier", entry["energy"], 0.22)

func _prepare_flash_materials() -> void:
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var active := mesh_instance.get_active_material(0)
		if active is StandardMaterial3D:
			var material := active.duplicate() as StandardMaterial3D
			material.emission_enabled = true
			mesh_instance.material_override = material
			_flash_materials.append({
				"material": material,
				"albedo": material.albedo_color,
				"emission": material.emission,
				"energy": material.emission_energy_multiplier,
			})
