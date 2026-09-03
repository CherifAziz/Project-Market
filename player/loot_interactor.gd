class_name LootInteractor
extends Node

signal pickup_requested(pickup: LootPickup, replace_index: int)

@export var reach := 1.35

var focused_pickup: LootPickup
var _player: PlayerController
var _extraction: ExtractionPoint
var _inventory: RunInventory
var _cursor := Vector2.ZERO

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_extraction = get_tree().get_first_node_in_group("extraction_point") as ExtractionPoint
	_inventory = get_tree().get_first_node_in_group("run_inventory") as RunInventory
	_cursor = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor = event.position

func _physics_process(_delta: float) -> void:
	var next: LootPickup
	if _player.is_alive() and _player.is_gameplay_input_enabled() and not _player.is_dashing():
		# E has one owner: the extraction hold wins inside an unlocked exit.
		if not (_extraction.is_available() and _extraction.is_player_near()):
			var distance := reach
			for candidate in get_tree().get_nodes_in_group("loot_pickups"):
				var pickup := candidate as LootPickup
				var candidate_distance := _flat_distance(pickup)
				if candidate_distance <= distance and can_reach(pickup) and (not is_full() or is_aiming_at(pickup)):
					next = pickup
					distance = candidate_distance
	if is_instance_valid(focused_pickup) and focused_pickup != next:
		focused_pickup.set_focused(false)
	focused_pickup = next
	if focused_pickup != null:
		focused_pickup.set_focused(true)
		if not is_full() and Input.is_action_just_pressed("interact"):
			pickup_requested.emit(focused_pickup, -1)
		elif is_full():
			for index in range(3):
				if Input.is_action_just_pressed("cargo_%d" % (index + 1)):
					pickup_requested.emit(focused_pickup, index)
					break

func is_full() -> bool:
	return _inventory != null and _inventory.get_used_slots() == _inventory.capacity

func is_aiming_at(pickup: LootPickup) -> bool:
	# A generous screen-space target includes both the silhouette and its ground footprint.
	var camera := _player.get_viewport().get_camera_3d()
	if camera == null:
		return false
	var mouse := _cursor
	var base := camera.unproject_position(pickup.global_position)
	var top := camera.unproject_position(pickup.global_position + Vector3.UP)
	return Geometry2D.get_closest_point_to_segment(mouse, base, top).distance_to(mouse) < 42.0

func can_reach(pickup: LootPickup) -> bool:
	if pickup == null or not pickup.available or not _player.is_alive() or not _player.is_gameplay_input_enabled() or _player.is_dashing():
		return false
	if _flat_distance(pickup) > reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.65, pickup.global_position + Vector3.UP * 0.45, 3)
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _flat_distance(pickup: LootPickup) -> float:
	return Vector2(pickup.global_position.x - _player.global_position.x, pickup.global_position.z - _player.global_position.z).length()
