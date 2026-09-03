class_name FollowCamera
extends Node3D

@export var follow_speed := 8.5
@export var aim_lookahead := 1.35

@onready var camera: Camera3D = $Camera3D

var _target: PlayerController
var _trauma := 0.0
var _base_camera_position := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _tracked_occluders: Array[GeometryInstance3D] = []

func _ready() -> void:
	add_to_group("camera_rig")
	_rng.randomize()
	_base_camera_position = camera.position
	_target = get_tree().get_first_node_in_group("player") as PlayerController
	if _target:
		global_position = _target.global_position

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as PlayerController
	if _target:
		var desired := _target.global_position + _target.aim_direction * aim_lookahead
		desired.y = 0.0
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))

	_trauma = maxf(_trauma - delta * 2.9, 0.0)
	var amount := _trauma * _trauma
	camera.position = _base_camera_position + Vector3(
		_rng.randf_range(-0.14, 0.14) * amount,
		_rng.randf_range(-0.1, 0.1) * amount,
		0.0
	)
	camera.rotation.z = _rng.randf_range(-0.012, 0.012) * amount
	_update_camera_occlusion(delta)

func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _update_camera_occlusion(delta: float) -> void:
	var active_meshes: Array[GeometryInstance3D] = []
	if is_instance_valid(_target):
		var ray_target := _target.global_position + Vector3.UP * 0.55
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, ray_target, 1)
		query.exclude = [_target.get_rid()]
		var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			var collider := result.collider as Node
			if collider != null and collider.is_in_group("camera_occluder"):
				for child in collider.find_children("*", "GeometryInstance3D", true, false):
					var geometry := child as GeometryInstance3D
					if geometry != null:
						active_meshes.append(geometry)
						if not _tracked_occluders.has(geometry):
							_tracked_occluders.append(geometry)

	for geometry in _tracked_occluders.duplicate():
		if not is_instance_valid(geometry):
			_tracked_occluders.erase(geometry)
			continue
		var target_transparency := 0.72 if active_meshes.has(geometry) else 0.0
		geometry.transparency = move_toward(geometry.transparency, target_transparency, delta * 4.8)
		if target_transparency <= 0.0 and geometry.transparency <= 0.001:
			geometry.transparency = 0.0
			_tracked_occluders.erase(geometry)

func _exit_tree() -> void:
	for geometry in _tracked_occluders:
		if is_instance_valid(geometry):
			geometry.transparency = 0.0
