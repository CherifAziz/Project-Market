class_name SecurityAgent
extends CharacterBody3D

signal died(agent: SecurityAgent)
signal player_spotted(company_id: String, world_position: Vector3)

enum State {
	PATROL,
	ENGAGE,
	TELEGRAPH,
	RECOVER,
	DEAD,
}

@export_group("Identity")
@export var company_id := "company"
@export var company_ticker := "COMP"
@export var accent_color := Color("66806e")
@export var agent_index := 0

@export_group("Survivability")
@export var max_health := 72.0

@export_group("Movement")
@export var patrol_speed := 1.65
@export var combat_speed := 3.65
@export var acceleration := 18.0
@export var turn_speed := 10.0
@export var patrol_axis := Vector3(1.2, 0.0, 0.0)

@export_group("Combat")
@export var detection_range := 9.5
@export var preferred_fire_range := 6.2
@export var fire_range := 10.5
@export var shot_damage := 18.0
@export var telegraph_duration := 0.48
@export var fire_cooldown := 1.35

@onready var visual: Node3D = %Visual
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var muzzle: Marker3D = %Muzzle
@onready var alert_icon: Label3D = %AlertIcon
@onready var health_bar: Node3D = %HealthBar
@onready var hp_fill: MeshInstance3D = %HPFill
@onready var left_leg: Node3D = %LeftLeg
@onready var right_leg: Node3D = %RightLeg
@onready var left_arm: Node3D = %LeftArm
@onready var right_arm: Node3D = %RightArm

var health := 0.0
var state: State = State.PATROL

var _player: PlayerController
var _home_position := Vector3.ZERO
var _patrol_points: Array[Vector3] = []
var _patrol_index := 0
var _patrol_wait := 0.0
var _perception_cooldown := 0.0
var _last_known_player_position := Vector3.ZERO
var _fire_cooldown_left := 0.0
var _telegraph_left := 0.0
var _recover_left := 0.0
var _locked_shot_point := Vector3.ZERO
var _alerted := false
var _dead := false
var _ai_enabled := true
var _walk_time := 0.0
var _strafe_side := 1.0
var _avoidance_direction := Vector3.ZERO
var _avoidance_left := 0.0
var _flash_tween: Tween
var _death_tween: Tween
var _flash_materials: Array[Dictionary] = []
var _left_arm_rest_x := 0.0
var _right_arm_rest_x := 0.0

func _ready() -> void:
	add_to_group("targets")
	add_to_group("security_agents")
	add_to_group("%s_security" % company_id)
	health = max_health
	_home_position = global_position
	var resolved_axis := patrol_axis
	resolved_axis.y = 0.0
	if resolved_axis.length_squared() < 0.01:
		resolved_axis = Vector3(1.2, 0.0, 0.0)
	_patrol_points = [_home_position - resolved_axis, _home_position + resolved_axis]
	_patrol_index = agent_index % 2
	_patrol_wait = 0.35 + float(agent_index) * 0.2
	_strafe_side = -1.0 if agent_index % 2 == 0 else 1.0
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_left_arm_rest_x = left_arm.rotation.x
	_right_arm_rest_x = right_arm.rotation.x
	_apply_company_look()
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController

	_fire_cooldown_left = maxf(_fire_cooldown_left - delta, 0.0)
	_perception_cooldown = maxf(_perception_cooldown - delta, 0.0)
	_avoidance_left = maxf(_avoidance_left - delta, 0.0)

	if not _ai_enabled:
		_stop_horizontal(delta)
		_apply_gravity(delta)
		move_and_slide()
		_animate(delta)
		return

	if is_instance_valid(_player) and _player.is_alive() and not _alerted and _perception_cooldown <= 0.0:
		_perception_cooldown = 0.14
		if _flat_distance_to(_player.global_position) <= detection_range and _has_line_of_sight():
			raise_alert(_player.global_position, 0)
			player_spotted.emit(company_id, _player.global_position)

	match state:
		State.PATROL:
			_update_patrol(delta)
		State.ENGAGE:
			_update_engage(delta)
		State.TELEGRAPH:
			_update_telegraph(delta)
		State.RECOVER:
			_update_recover(delta)

	_apply_gravity(delta)
	move_and_slide()
	_animate(delta)

func configure(id: String, ticker: String, color: Color, index: int, resolved_patrol_axis: Vector3) -> void:
	company_id = id
	company_ticker = ticker
	accent_color = color
	agent_index = index
	patrol_axis = resolved_patrol_axis

func raise_alert(world_position: Vector3, pressure_stage: int) -> void:
	if _dead:
		return
	_alerted = true
	_last_known_player_position = world_position
	alert_icon.visible = true
	alert_icon.text = "!"
	alert_icon.modulate = accent_color.lightened(0.38)
	_fire_cooldown_left = maxf(_fire_cooldown_left, maxf(0.18, 0.48 - float(pressure_stage) * 0.06))
	if state != State.TELEGRAPH:
		state = State.ENGAGE

func set_ai_enabled(enabled: bool) -> void:
	_ai_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		if state == State.TELEGRAPH:
			state = State.ENGAGE
			_fire_cooldown_left = maxf(_fire_cooldown_left, 0.25)

func is_alerted() -> bool:
	return _alerted

func is_dead() -> bool:
	return _dead

func get_health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)

func get_state_name() -> String:
	return State.keys()[state]

func take_damage(amount: float, hit_position: Vector3, _hit_normal: Vector3, shot_direction: Vector3) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	if not _alerted:
		var alert_position := _player.global_position if is_instance_valid(_player) else global_position - shot_direction
		raise_alert(alert_position, 0)
		player_spotted.emit(company_id, alert_position)
	health_bar.visible = true
	_update_health_bar()
	_flash()

	var effects := get_tree().get_first_node_in_group("effects")
	if effects != null:
		effects.spawn_damage_number(hit_position, amount, health <= 0.0)
	if health <= 0.0:
		_die()

func _update_patrol(delta: float) -> void:
	if _patrol_wait > 0.0:
		_patrol_wait = maxf(_patrol_wait - delta, 0.0)
		_stop_horizontal(delta)
		return
	var target := _patrol_points[_patrol_index]
	var direction := _flat_direction_to(target)
	if _flat_distance_to(target) < 0.35:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_patrol_wait = 0.72 + float((agent_index + _patrol_index) % 2) * 0.32
		_stop_horizontal(delta)
		return
	_move_in_direction(direction, patrol_speed, delta)

func _update_engage(delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_alive():
		_stop_horizontal(delta)
		return

	var player_position := _player.global_position
	var distance := _flat_distance_to(player_position)
	var has_sight := _has_line_of_sight()
	if has_sight:
		_last_known_player_position = player_position
		_face_direction(_flat_direction_to(player_position), delta)

	if has_sight and _fire_cooldown_left <= 0.0 and distance >= 2.25 and distance <= fire_range:
		_begin_telegraph()
		return

	var destination := _last_known_player_position
	if has_sight:
		var away := global_position - player_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.01 else Vector3.BACK
		var tangent := Vector3(-away.z, 0.0, away.x) * _strafe_side
		if distance < preferred_fire_range - 1.1:
			destination = global_position + away * 2.0 + tangent * 0.35
		elif distance > preferred_fire_range + 1.2:
			destination = player_position + away * preferred_fire_range + tangent * 1.1
		else:
			destination = global_position + tangent * 1.25

	var direction := _flat_direction_to(destination)
	if _flat_distance_to(destination) > 0.42:
		_move_in_direction(direction, combat_speed, delta)
	else:
		_stop_horizontal(delta)

func _begin_telegraph() -> void:
	state = State.TELEGRAPH
	_telegraph_left = telegraph_duration
	_locked_shot_point = _player.global_position + Vector3.UP * 0.62
	velocity.x = 0.0
	velocity.z = 0.0
	alert_icon.text = "!"
	alert_icon.modulate = Color("e6a16f")
	var effects := get_tree().get_first_node_in_group("effects")
	if effects != null and effects.has_method("spawn_enemy_telegraph"):
		effects.spawn_enemy_telegraph(muzzle.global_position, _locked_shot_point, Color("d8815e"), telegraph_duration)

func _update_telegraph(delta: float) -> void:
	_stop_horizontal(delta)
	_face_direction(_flat_direction_to(_locked_shot_point), delta * 1.5)
	if not is_instance_valid(_player) or not _player.is_alive():
		state = State.RECOVER
		_recover_left = 0.25
		return
	_telegraph_left = maxf(_telegraph_left - delta, 0.0)
	var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.025) * 0.28
	alert_icon.modulate = Color("e6a16f") * pulse
	if _telegraph_left <= 0.0:
		_fire_locked_shot()

func _fire_locked_shot() -> void:
	var origin := muzzle.global_position
	var direction := (_locked_shot_point - origin).normalized()
	var endpoint := origin + direction * fire_range
	var hit_position := endpoint
	var hit_normal := Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 7)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_player := false
	if not result.is_empty():
		hit_position = result.position
		hit_normal = result.normal
		if result.collider == _player:
			hit_player = _player.take_damage(shot_damage, hit_position, hit_normal, direction)

	var effects := get_tree().get_first_node_in_group("effects")
	if effects != null:
		effects.spawn_muzzle_flash(origin, direction, Color("f0b071"))
		effects.spawn_tracer(origin, hit_position, Color("dc7958"), 0.032, 0.1)
		if not result.is_empty() and not hit_player:
			effects.spawn_impact(hit_position, hit_normal, Color("d98a64"), 0.72)
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_world"):
		audio.play_world(&"security_shot", origin, 0.045)

	_fire_cooldown_left = fire_cooldown + float(agent_index) * 0.08
	_recover_left = 0.32
	state = State.RECOVER
	alert_icon.modulate = accent_color.lightened(0.38)

func _update_recover(delta: float) -> void:
	_stop_horizontal(delta)
	_recover_left = maxf(_recover_left - delta, 0.0)
	if _recover_left <= 0.0:
		state = State.ENGAGE

func _has_line_of_sight() -> bool:
	if not is_instance_valid(_player):
		return false
	var origin := global_position + Vector3.UP * 1.32
	var target := _player.global_position + Vector3.UP * 0.58
	var query := PhysicsRayQueryParameters3D.create(origin, target, 7)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == _player

func _move_in_direction(direction: Vector3, speed: float, delta: float) -> void:
	if direction.length_squared() < 0.01:
		_stop_horizontal(delta)
		return
	if state == State.ENGAGE:
		direction = _steer_around_obstacle(direction)
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	_face_direction(direction, delta)

func _steer_around_obstacle(direction: Vector3) -> Vector3:
	# Short committed sidesteps are enough for this map's low facility barriers.
	if _avoidance_left > 0.0 and _movement_probe(_avoidance_direction).is_empty():
		return _avoidance_direction
	var obstacle := _movement_probe(direction)
	if obstacle.is_empty():
		return direction
	var normal: Vector3 = obstacle["normal"]
	var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
	if tangent.length_squared() < 0.01:
		tangent = Vector3(-direction.z, 0.0, direction.x)
	var pursuit := _flat_direction_to(_player.global_position) if is_instance_valid(_player) else direction
	if tangent.dot(pursuit) < 0.0:
		tangent = -tangent
	if not _movement_probe(tangent).is_empty():
		tangent = -tangent
	if not _movement_probe(tangent).is_empty():
		tangent = -direction
	_avoidance_direction = tangent
	_avoidance_left = 0.65
	return tangent

func _movement_probe(direction: Vector3) -> Dictionary:
	var origin := global_position + Vector3.UP * 0.45
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 0.85, 3)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * 1.35 * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * 1.35 * delta)

func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_rotation := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, 1.0 - exp(-turn_speed * delta))

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5

func _animate(delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	_walk_time += delta * (3.4 + planar_speed * 2.1)
	var stride := sin(_walk_time) * clampf(planar_speed / combat_speed, 0.0, 1.0)
	left_leg.rotation.x = stride * 0.48
	right_leg.rotation.x = -stride * 0.48
	left_arm.rotation.x = _left_arm_rest_x - stride * 0.18
	right_arm.rotation.x = _right_arm_rest_x + stride * 0.1
	if state != State.DEAD:
		visual.position.y = absf(sin(_walk_time)) * 0.025 * clampf(planar_speed, 0.0, 1.0)

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for entry in _flash_materials:
		var material: StandardMaterial3D = entry["material"]
		material.albedo_color = Color.WHITE
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 1.8
		_flash_tween.tween_property(material, "albedo_color", entry["albedo"], 0.13)
		_flash_tween.tween_property(material, "emission", entry["emission"], 0.15)
		_flash_tween.tween_property(material, "emission_energy_multiplier", entry["energy"], 0.16)

func _apply_company_look() -> void:
	var uniform_color := accent_color.darkened(0.48).lerp(Color("29363a"), 0.52)
	var skin_colors := [Color("8f6852"), Color("6f4b3b"), Color("b18162"), Color("7d5744")]
	var skin_color: Color = skin_colors[agent_index % skin_colors.size()]
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var active := mesh_instance.get_active_material(0)
		if not active is StandardMaterial3D:
			continue
		var material := active.duplicate() as StandardMaterial3D
		if mesh_instance.name.begins_with("Uniform"):
			material.albedo_color = uniform_color
		elif mesh_instance.name.begins_with("Accent"):
			material.albedo_color = accent_color.darkened(0.04)
		elif mesh_instance.name.begins_with("Skin"):
			material.albedo_color = skin_color
		elif mesh_instance.name.begins_with("Dark"):
			material.albedo_color = Color("252d30")
		else:
			continue
		material.emission_enabled = true
		material.emission = Color.BLACK
		material.emission_energy_multiplier = 0.0
		mesh_instance.material_override = material
		_flash_materials.append({
			"material": material,
			"albedo": material.albedo_color,
			"emission": material.emission,
			"energy": material.emission_energy_multiplier,
		})
	var hp_material := hp_fill.get_active_material(0).duplicate() as StandardMaterial3D
	hp_material.albedo_color = accent_color.lightened(0.16)
	hp_fill.material_override = hp_material
	alert_icon.modulate = accent_color.lightened(0.38)

func _update_health_bar() -> void:
	var ratio := get_health_ratio()
	hp_fill.scale.x = ratio
	hp_fill.position.x = (ratio - 1.0) * 0.28

func _die() -> void:
	if _dead:
		return
	_dead = true
	state = State.DEAD
	remove_from_group("targets")
	remove_from_group("security_agents")
	collision_shape.set_deferred("disabled", true)
	alert_icon.visible = false
	health_bar.visible = false
	velocity = Vector3.ZERO
	died.emit(self)

	var effects := get_tree().get_first_node_in_group("effects")
	if effects != null:
		effects.spawn_kill_burst(global_position, accent_color)
		effects.hitstop(0.045, 0.1)
	var fall_side := -1.0 if agent_index % 2 == 0 else 1.0
	_death_tween = create_tween().set_parallel(true)
	_death_tween.tween_property(visual, "rotation:z", fall_side * deg_to_rad(76.0), 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(visual, "position:y", -0.42, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(visual, "scale", Vector3(1.08, 0.82, 1.08), 0.34)
	_death_tween.finished.connect(queue_free)
	set_physics_process(false)

func _flat_direction_to(world_position: Vector3) -> Vector3:
	var direction := world_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO

func _flat_distance_to(world_position: Vector3) -> float:
	return Vector2(world_position.x - global_position.x, world_position.z - global_position.z).length()
