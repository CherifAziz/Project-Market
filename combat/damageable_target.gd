class_name DamageableTarget
extends StaticBody3D

signal died(target: DamageableTarget)

@export var max_health := 72.0
@export var accent_color := Color("c56449")

@onready var visual: Node3D = %Visual
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var hp_fill: MeshInstance3D = %HPFill
@onready var rings: Node3D = %Rings

var health := 0.0
var _dead := false
var _time := 0.0
var _flash_tween: Tween
var _flash_materials: Array[Dictionary] = []

func _ready() -> void:
	health = max_health
	add_to_group("targets")
	_prepare_unique_materials()
	_update_health_bar()

func _process(delta: float) -> void:
	_time += delta
	if not _dead:
		rings.rotation.y += delta * 1.45
		visual.position.y = sin(_time * 2.4 + global_position.x) * 0.035

func take_damage(amount: float, hit_position: Vector3, _hit_normal: Vector3, _shot_direction: Vector3) -> void:
	if _dead:
		return
	health = maxf(health - amount, 0.0)
	_flash()
	_update_health_bar()

	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_damage_number(hit_position, amount, health <= 0.0)

	if health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	remove_from_group("targets")
	collision_shape.set_deferred("disabled", true)
	died.emit(self)

	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_kill_burst(global_position, accent_color)
		effects.hitstop()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector3(1.45, 0.04, 1.45), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "position:y", -0.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "rotation:y", visual.rotation.y + PI * 0.75, 0.3)
	tween.finished.connect(queue_free)

func _flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for entry in _flash_materials:
		var material: StandardMaterial3D = entry.material
		material.albedo_color = Color.WHITE
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 2.4
		_flash_tween.tween_property(material, "albedo_color", entry.albedo, 0.12)
		_flash_tween.tween_property(material, "emission", entry.emission, 0.14)
		_flash_tween.tween_property(material, "emission_energy_multiplier", entry.energy, 0.15)

func _prepare_unique_materials() -> void:
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var active := mesh_instance.get_active_material(0)
		if active is StandardMaterial3D:
			var material := active.duplicate() as StandardMaterial3D
			mesh_instance.material_override = material
			_flash_materials.append({
				"material": material,
				"albedo": material.albedo_color,
				"emission": material.emission,
				"energy": material.emission_energy_multiplier,
			})

func _update_health_bar() -> void:
	var ratio := clampf(health / max_health, 0.0, 1.0)
	hp_fill.scale.x = ratio
	hp_fill.position.x = (ratio - 1.0) * 0.31
