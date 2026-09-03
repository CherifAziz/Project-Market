class_name LootInteractor
extends Node

signal pickup_requested(pickup: LootPickup)

@export var reach := 1.35

var focused_pickup: LootPickup
var _player: PlayerController
var _extraction: ExtractionPoint

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_extraction = get_tree().get_first_node_in_group("extraction_point") as ExtractionPoint

func _physics_process(_delta: float) -> void:
	var next: LootPickup
	if _player.is_alive() and _player.is_gameplay_input_enabled() and not _player.is_dashing():
		# E has one owner: the extraction hold wins inside an unlocked exit.
		if not (_extraction.is_available() and _extraction.is_player_near()):
			var distance := reach
			for candidate in get_tree().get_nodes_in_group("loot_pickups"):
				var pickup := candidate as LootPickup
				var candidate_distance := _flat_distance(pickup)
				if candidate_distance <= distance and can_reach(pickup):
					next = pickup
					distance = candidate_distance
	if is_instance_valid(focused_pickup) and focused_pickup != next:
		focused_pickup.set_focused(false)
	focused_pickup = next
	if focused_pickup != null:
		focused_pickup.set_focused(true)
		if Input.is_action_just_pressed("interact"):
			pickup_requested.emit(focused_pickup)

func can_reach(pickup: LootPickup) -> bool:
	if pickup == null or not pickup.available or not _player.is_alive() or not _player.is_gameplay_input_enabled() or _player.is_dashing():
		return false
	if _flat_distance(pickup) > reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.65, pickup.global_position + Vector3.UP * 0.45, 3)
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func get_drop_position() -> Vector3:
	var forward := _player.aim_direction
	var side := forward.cross(Vector3.UP)
	var space := _player.get_world_3d().direct_space_state
	for direction in [forward, side, -side, -forward, Vector3.ZERO]:
		var at: Vector3 = _player.global_position + direction * 0.9
		if direction != Vector3.ZERO:
			var path_query := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.5, at + Vector3.UP * 0.5, 3)
			path_query.exclude = [_player.get_rid()]
			if not space.intersect_ray(path_query).is_empty():
				continue
		var floor_query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, at + Vector3.DOWN * 1.5, 1)
		var floor_hit := space.intersect_ray(floor_query)
		if floor_hit.is_empty() or floor_hit["normal"].y < 0.8 or floor_hit["position"].y > _player.global_position.y + 0.2:
			continue
		var floor_position: Vector3 = floor_hit["position"]
		var shape := SphereShape3D.new()
		shape.radius = 0.34
		var clearance := PhysicsShapeQueryParameters3D.new()
		clearance.shape = shape
		clearance.transform.origin = floor_position + Vector3.UP * 0.5
		clearance.collision_mask = 3
		if space.intersect_shape(clearance, 1).is_empty():
			return floor_position + Vector3.UP * 0.025
	return Vector3.INF

func _flat_distance(pickup: LootPickup) -> float:
	return Vector2(pickup.global_position.x - _player.global_position.x, pickup.global_position.z - _player.global_position.z).length()
