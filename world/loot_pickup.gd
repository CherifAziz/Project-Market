class_name LootPickup
extends Node3D

@export var loot_id := ""
@export var definition: LootDefinition

var available := true
var _focus_ring: MeshInstance3D

func _ready() -> void:
	add_to_group("loot_pickups")
	if definition != null:
		_build_visual()

func collect_from_world() -> void:
	available = false
	visible = false
	set_focused(false)

func place_in_world(world_position: Vector3) -> void:
	global_position = world_position
	available = true
	visible = true

func set_focused(focused: bool) -> void:
	if is_instance_valid(_focus_ring):
		_focus_ring.visible = focused and available

func get_context_position() -> Vector3:
	return global_position + Vector3.UP * 0.75

func _build_visual() -> void:
	var shell := _material(Color("c7c1af"))
	var dark := _material(Color("36413f"))
	var accent := _material(definition.accent)
	var metal := _material(Color("8e9893"), 0.35)
	match definition.visual_kind:
		LootDefinition.VisualKind.COPPER_SPOOL:
			_cylinder(Vector3(0, 0.3, 0), 0.24, 0.5, accent, Vector3(90, 0, 0))
			for side in [-1.0, 1.0]:
				_cylinder(Vector3(0, 0.3, side * 0.28), 0.33, 0.075, shell, Vector3(90, 0, 0))
				_cylinder(Vector3(0, 0.3, side * 0.325), 0.06, 0.025, dark, Vector3(90, 0, 0))
		LootDefinition.VisualKind.ENERGY_MODULE:
			_box(Vector3(0, 0.29, 0), Vector3(0.86, 0.55, 0.57), dark)
			for x in [-0.31, -0.16, 0.0, 0.16, 0.31]:
				_box(Vector3(x, 0.59, 0), Vector3(0.065, 0.11, 0.5), metal)
			_box(Vector3(0, 0.3, 0.3), Vector3(0.63, 0.21, 0.035), accent)
			for side in [-1.0, 1.0]:
				_box(Vector3(side * 0.49, 0.39, 0), Vector3(0.13, 0.07, 0.24), metal)
		LootDefinition.VisualKind.LAB_INSTRUMENT:
			_box(Vector3(0, 0.25, 0), Vector3(0.58, 0.48, 0.48), shell)
			_box(Vector3(-0.1, 0.36, 0.25), Vector3(0.27, 0.16, 0.035), dark)
			_cylinder(Vector3(0.19, 0.54, -0.04), 0.075, 0.16, metal)
			_box(Vector3(0, 0.1, 0.25), Vector3(0.52, 0.08, 0.035), accent)
		LootDefinition.VisualKind.POWER_COMPONENT:
			_box(Vector3(0, 0.12, 0), Vector3(0.58, 0.22, 0.48), dark)
			for x in [-0.16, 0.0, 0.16]:
				_cylinder(Vector3(x, 0.36, 0), 0.066, 0.36, metal)
			_box(Vector3(0, 0.15, 0.25), Vector3(0.42, 0.09, 0.035), accent)
		_:
			var small := definition.visual_kind == LootDefinition.VisualKind.SAMPLE_CASE
			var width := 0.45 if small else 0.7
			_box(Vector3(0, 0.19, 0), Vector3(width, 0.32, 0.47), shell)
			_box(Vector3(0, 0.36, 0), Vector3(width + 0.025, 0.04, 0.49), accent)
			for side in [-1.0, 1.0]:
				_box(Vector3(side * width * 0.3, 0.25, 0.25), Vector3(0.07, 0.1, 0.035), dark)
			_box(Vector3(0, 0.19, 0.3), Vector3(0.19, 0.045, 0.09), dark)
			if not small:
				_box(Vector3(0, 0.39, 0), Vector3(0.28, 0.025, 0.075), shell)
				_box(Vector3(0, 0.39, 0), Vector3(0.075, 0.026, 0.28), shell)
	# A small asset tag and proximity ring, no floating labels or idle glow.
	_box(Vector3(0.15, 0.035, 0.48), Vector3(0.22, 0.015, 0.13), shell)
	_focus_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.53
	ring.outer_radius = 0.56
	ring.rings = 32
	ring.ring_segments = 5
	ring.material = accent
	_focus_ring.mesh = ring
	_focus_ring.position.y = 0.055
	_focus_ring.scale.y = 0.15
	_focus_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_focus_ring.visible = false
	add_child(_focus_ring)

func _box(at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)

func _cylinder(at: Vector3, radius: float, height: float, material: Material, rotation_value := Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation_value
	add_child(instance)

func _material(color: Color, metallic := 0.05) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.74
	material.metallic = metallic
	return material
