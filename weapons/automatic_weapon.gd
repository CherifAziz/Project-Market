class_name AutomaticWeapon
extends Node3D

signal fired

@export var data: WeaponData
@export_flags_3d_physics var hit_mask: int = 3

@onready var muzzle: Marker3D = %Muzzle
@onready var weapon_visual: Node3D = %WeaponVisual

var _cooldown := 0.0
var _recoil_tween: Tween

func tick(delta: float, wants_to_fire: bool) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if wants_to_fire and _cooldown <= 0.0:
		_fire()
		_cooldown += data.shot_interval() if data else 0.1

func _fire() -> void:
	if data == null or not is_inside_tree():
		return

	var direction := -global_transform.basis.z.normalized()
	var spread := deg_to_rad(data.spread_degrees)
	direction = direction.rotated(Vector3.UP, randf_range(-spread, spread)).normalized()
	var origin := muzzle.global_position
	var endpoint := origin + direction * data.range
	var hit_position := endpoint
	var hit_normal := Vector3.UP

	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, hit_mask)
	var body := get_parent() as CollisionObject3D
	if body:
		query.exclude = [body.get_rid()]
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		hit_position = result.position
		hit_normal = result.normal
		var collider: Object = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(data.damage, hit_position, hit_normal, direction)

	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_muzzle_flash(origin, direction, data.muzzle_color)
		effects.spawn_tracer(origin, hit_position, data.tracer_color, data.tracer_width, data.tracer_duration)
		if not result.is_empty():
			effects.spawn_impact(hit_position, hit_normal, data.tracer_color)
		effects.add_camera_shake(data.camera_shake)

	_play_recoil()
	fired.emit()

func _play_recoil() -> void:
	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()
	weapon_visual.position = Vector3(0.0, 0.0, 0.11)
	weapon_visual.rotation.x = deg_to_rad(-5.0)
	_recoil_tween = create_tween().set_parallel(true)
	_recoil_tween.tween_property(weapon_visual, "position", Vector3.ZERO, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(weapon_visual, "rotation:x", 0.0, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
