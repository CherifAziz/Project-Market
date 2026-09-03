class_name ExtractionPoint
extends Node3D

signal extraction_completed

@export var hold_duration := 2.2
@export var interaction_radius := 1.45

var _player: PlayerController
var _available := false
var _finished := false
var _completed := false
var _hold_time := 0.0
var _interruption_left := 0.0
var _indicator_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("extraction_point")
	_build_visual()
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player != null:
		_player.damaged.connect(_on_player_damaged)

func _physics_process(delta: float) -> void:
	_interruption_left = maxf(_interruption_left - delta, 0.0)
	if _finished:
		return
	if not is_instance_valid(_player) or not _player.is_alive():
		cancel_interaction()
		return
	var moving := Vector2(_player.velocity.x, _player.velocity.z).length() > 0.65
	if not _available or not is_player_near() or not _player.is_gameplay_input_enabled() or moving or _player.is_dashing() or _interruption_left > 0.0:
		cancel_interaction()
	elif Input.is_action_pressed("interact"):
		if _hold_time <= 0.0:
			_play_cue(&"extraction_start")
		_hold_time = minf(_hold_time + delta, hold_duration)
		if _hold_time >= hold_duration:
			_completed = true
			_finished = true
			extraction_completed.emit()
	else:
		cancel_interaction()
	_indicator_material.emission_energy_multiplier = 0.12 + get_progress() * 0.5 if _available else 0.0

func unlock() -> void:
	if _finished or _available:
		return
	_available = true
	_indicator_material.albedo_color = Color("7f9c87")
	_indicator_material.emission = Color("7f9c87")

func end_run() -> void:
	_finished = true
	if not _completed:
		cancel_interaction()

func cancel_interaction() -> void:
	_hold_time = 0.0

func is_available() -> bool:
	return _available and not _finished

func is_completed() -> bool:
	return _completed

func is_interrupted() -> bool:
	return _interruption_left > 0.0

func get_progress() -> float:
	return clampf(_hold_time / maxf(hold_duration, 0.01), 0.0, 1.0)

func get_player_distance() -> float:
	if not is_instance_valid(_player):
		return INF
	return Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()

func is_player_near() -> bool:
	return get_player_distance() <= interaction_radius

func _on_player_damaged(_amount: float, _health: float) -> void:
	if _finished or _hold_time <= 0.0:
		return
	cancel_interaction()
	_interruption_left = 0.7

func _play_cue(cue: StringName) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_world(cue, global_position + Vector3.UP, 0.0)

func _build_visual() -> void:
	var stone := _material(Color("bcb09b"))
	var charcoal := _material(Color("354247"))
	var marking := _material(Color("ddd2b9"))
	_indicator_material = _material(Color("777d74"))
	_indicator_material.emission_enabled = true
	_box("ServicePad", Vector3(0, 0.028, 0), Vector3(3.8, 0.04, 3.3), stone)
	for side in [-1.0, 1.0]:
		_box("BayEdge", Vector3(side * 1.68, 0.055, 0.3), Vector3(0.06, 0.025, 2.4), marking)
		_box("BayCorner", Vector3(side * 1.38, 0.057, 1.48), Vector3(0.65, 0.025, 0.06), marking)
	_box("ExitTerminal", Vector3(1.75, 0.68, -1.13), Vector3(0.55, 1.32, 0.46), charcoal)
	_box("TerminalFace", Vector3(1.75, 0.9, -0.885), Vector3(0.37, 0.4, 0.035), _indicator_material)
	_box("TerminalStripe", Vector3(1.75, 1.24, -0.88), Vector3(0.36, 0.04, 0.035), marking)
	_box("ServiceSign", Vector3(0, 1.75, -1.4), Vector3(2.8, 0.45, 0.12), charcoal)
	for side in [-1.0, 1.0]:
		_box("SignPost", Vector3(side * 1.25, 0.82, -1.4), Vector3(0.075, 1.64, 0.075), charcoal)
	var sign := Label3D.new()
	sign.text = "SERVICE EXIT"
	sign.position = Vector3(0, 1.76, -1.325)
	sign.font_size = 52
	sign.pixel_size = 0.0065
	sign.modulate = Color("ded6c4")
	sign.outline_size = 0
	add_child(sign)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = interaction_radius - 0.055
	mesh.outer_radius = interaction_radius
	mesh.rings = 40
	mesh.ring_segments = 6
	mesh.material = _indicator_material
	ring.mesh = mesh
	ring.position.y = 0.065
	ring.scale.y = 0.18
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func _box(node_name: String, position_value: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position_value
	add_child(instance)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
