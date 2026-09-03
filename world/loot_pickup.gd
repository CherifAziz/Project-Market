class_name LootPickup
extends Node3D

@export var loot_id := ""
@export var definition: LootDefinition

var available := true
var _focus_ring: MeshInstance3D
var _visual: Node3D
var _pickup_tween: Tween

func _ready() -> void:
	add_to_group("loot_pickups")
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * 1.35
	add_child(_visual)
	if definition != null:
		_build_visual()

func collect_from_world(towards: Vector3) -> void:
	available = false
	set_focused(false)
	if _pickup_tween != null and _pickup_tween.is_valid():
		_pickup_tween.kill()
	_pickup_tween = create_tween().set_parallel(true)
	_pickup_tween.tween_property(_visual, "position", to_local(towards) * 0.55 + Vector3.UP * 0.7, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pickup_tween.tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.16)
	_pickup_tween.chain().tween_callback(hide)

func place_in_world(world_position: Vector3) -> void:
	if _pickup_tween != null and _pickup_tween.is_valid():
		_pickup_tween.kill()
	_visual.position = Vector3.ZERO
	_visual.scale = Vector3.ONE * 1.35
	global_position = world_position
	available = true
	visible = true

func set_focused(focused: bool) -> void:
	if is_instance_valid(_focus_ring):
		_focus_ring.visible = focused and available

func get_context_position() -> Vector3:
	return global_position + Vector3.UP * 1.25

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
			_box(Vector3(0, 0.29, 0), Vector3(0.86, 0.55, 0.57), accent)
			for x in [-0.31, -0.16, 0.0, 0.16, 0.31]:
				_box(Vector3(x, 0.59, 0), Vector3(0.065, 0.11, 0.5), metal)
			_box(Vector3(0, 0.3, 0.3), Vector3(0.63, 0.21, 0.035), accent)
			for side in [-1.0, 1.0]:
				_box(Vector3(side * 0.49, 0.39, 0), Vector3(0.13, 0.07, 0.24), metal)
		LootDefinition.VisualKind.LAB_INSTRUMENT:
			_box(Vector3(0, 0.08, 0), Vector3(0.68, 0.16, 0.6), accent)
			_box(Vector3(-0.22, 0.44, -0.13), Vector3(0.2, 0.7, 0.22), accent)
			_box(Vector3(0, 0.75, -0.02), Vector3(0.62, 0.18, 0.3), shell)
			_cylinder(Vector3(0.2, 0.59, 0.03), 0.11, 0.22, dark)
			_cylinder(Vector3(0.13, 0.19, 0.04), 0.2, 0.06, metal)
		LootDefinition.VisualKind.POWER_COMPONENT:
			_box(Vector3(0, 0.12, 0), Vector3(0.58, 0.22, 0.48), dark)
			for x in [-0.16, 0.0, 0.16]:
				_cylinder(Vector3(x, 0.45, 0), 0.09, 0.6, accent)
				for y in [0.25, 0.4, 0.55]:
					_cylinder(Vector3(x, y, 0), 0.13, 0.05, accent)
			_box(Vector3(0, 0.15, 0.25), Vector3(0.42, 0.09, 0.035), accent)
		LootDefinition.VisualKind.SAMPLE_CASE:
			_box(Vector3(0, 0.1, 0), Vector3(0.62, 0.2, 0.48), accent)
			for x in [-0.18, 0.18]:
				_cylinder(Vector3(x, 0.44, 0), 0.14, 0.58, shell)
				_cylinder(Vector3(x, 0.75, 0), 0.16, 0.12, accent)
				_cylinder(Vector3(x, 0.4, 0), 0.143, 0.15, accent)
		_:
			var width := 0.85
			_box(Vector3(0, 0.19, 0), Vector3(width, 0.32, 0.47), shell)
			_box(Vector3(0, 0.36, 0), Vector3(width + 0.025, 0.04, 0.49), shell)
			for side in [-1.0, 1.0]:
				_box(Vector3(side * width * 0.3, 0.25, 0.25), Vector3(0.07, 0.1, 0.035), dark)
			_box(Vector3(0, 0.19, 0.3), Vector3(0.19, 0.045, 0.09), dark)
			_box(Vector3(0, 0.39, 0), Vector3(0.38, 0.025, 0.12), accent)
			_box(Vector3(0, 0.39, 0), Vector3(0.12, 0.026, 0.38), accent)
	# A small asset tag and proximity ring, no floating labels or idle glow.
	_box(Vector3(0.15, 0.035, 0.48), Vector3(0.22, 0.015, 0.13), shell)
	_focus_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.73
	ring.outer_radius = 0.78
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
	_visual.add_child(instance)

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
	_visual.add_child(instance)

func _material(color: Color, metallic := 0.05) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.74
	material.metallic = metallic
	return material
