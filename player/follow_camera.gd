class_name FollowCamera
extends Node3D

@export var follow_speed := 8.5
@export var aim_lookahead := 1.35

@onready var camera: Camera3D = $Camera3D

var _target: PlayerController
var _trauma := 0.0
var _base_camera_position := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

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

func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

