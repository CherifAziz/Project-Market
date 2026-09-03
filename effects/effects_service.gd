class_name EffectsService
extends Node3D

const RING_SHADER := preload("res://effects/aim_ring.gdshader")

var _hitstop_active := false

func _ready() -> void:
	add_to_group("effects")

func spawn_muzzle_flash(position: Vector3, direction: Vector3, color: Color) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = position
	root.look_at(position + direction, Vector3.UP)

	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _emissive_material(color, 5.0)
	flash.mesh = mesh
	flash.scale = Vector3(0.75, 0.75, 2.3)
	root.add_child(flash)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.4
	light.omni_range = 2.5
	light.shadow_enabled = false
	root.add_child(light)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ZERO, 0.065).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(light, "light_energy", 0.0, 0.06)
	tween.finished.connect(root.queue_free)

func spawn_tracer(from: Vector3, to: Vector3, color: Color, width: float, duration: float) -> void:
	var distance := from.distance_to(to)
	if distance < 0.05:
		return
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, distance)
	mesh.material = _emissive_material(color, 4.5, true)
	tracer.mesh = mesh
	add_child(tracer)
	tracer.global_position = from.lerp(to, 0.5)
	tracer.look_at(to, Vector3.UP)
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var tween := create_tween().set_parallel(true)
	tween.tween_property(tracer, "transparency", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(tracer, "scale", Vector3(0.35, 0.35, 1.0), duration)
	tween.finished.connect(tracer.queue_free)

func spawn_impact(position: Vector3, normal: Vector3, color: Color, strength := 1.0) -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.amount = int(10.0 * strength)
	particles.lifetime = 0.38
	particles.explosiveness = 1.0
	particles.randomness = 0.75
	particles.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.direction = normal
	process.spread = 62.0
	process.initial_velocity_min = 2.5 * strength
	process.initial_velocity_max = 5.5 * strength
	process.gravity = Vector3(0, -7.0, 0)
	process.scale_min = 0.025
	process.scale_max = 0.07 * strength
	process.color = color
	particles.process_material = process

	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.025
	spark_mesh.height = 0.13
	spark_mesh.radial_segments = 5
	spark_mesh.rings = 2
	spark_mesh.material = _emissive_material(color, 3.2)
	particles.draw_pass_1 = spark_mesh
	add_child(particles)
	particles.global_position = position + normal * 0.035
	particles.emitting = true
	_free_after(particles, 0.8)

	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.11 * strength
	flash_mesh.height = 0.22 * strength
	flash_mesh.radial_segments = 6
	flash_mesh.rings = 3
	flash_mesh.material = _emissive_material(color, 4.2, true)
	flash.mesh = flash_mesh
	add_child(flash)
	flash.global_position = position
	var flash_tween := create_tween().set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector3.ONE * 2.2, 0.12)
	flash_tween.tween_property(flash, "transparency", 1.0, 0.12)
	flash_tween.finished.connect(flash.queue_free)

func spawn_damage_number(position: Vector3, amount: float, critical := false) -> void:
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.font_size = 54 if critical else 44
	label.pixel_size = 0.006
	label.modulate = Color("ffd27a") if critical else Color("f5efe3")
	label.outline_modulate = Color(0.08, 0.1, 0.1, 0.92)
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.global_position = position + Vector3(randf_range(-0.12, 0.12), 0.55, 0.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3(0.0, 0.85, 0.0), 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.62).set_delay(0.22)
	tween.tween_property(label, "scale", Vector3.ONE * 1.18, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(label.queue_free)

func spawn_kill_burst(position: Vector3, color := Color("cf6848")) -> void:
	spawn_impact(position + Vector3.UP * 0.65, Vector3.UP, color, 2.2)
	_spawn_ring(position + Vector3.UP * 0.045, color, 0.55, 2.4, 0.28)
	add_camera_shake(0.48)

func spawn_equipment_destruction(position: Vector3, color: Color, severity := 1) -> void:
	var resolved_severity := clampi(severity, 1, 3)
	spawn_impact(position + Vector3.UP * 0.9, Vector3.UP, color, 1.25 + float(resolved_severity) * 0.16)
	_spawn_ring(position + Vector3.UP * 0.05, color, 0.42, 1.55 + float(resolved_severity) * 0.12, 0.3)
	_spawn_debris(position + Vector3.UP * 0.72, color, resolved_severity)
	_spawn_smoke(position + Vector3.UP * 0.78, resolved_severity)
	add_camera_shake(0.22 + float(resolved_severity) * 0.035)

func spawn_dash(position: Vector3, direction: Vector3) -> void:
	var color := Color("c7b58d")
	_spawn_ring(position + Vector3.UP * 0.045, color, 0.45, 1.65, 0.22)

	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055, 0.035, 1.65)
		mesh.material = _emissive_material(color, 3.4, true)
		streak.mesh = mesh
		add_child(streak)
		var lateral: Vector3 = direction.cross(Vector3.UP).normalized() * 0.3 * side
		streak.global_position = position - direction * 0.7 + lateral + Vector3.UP * 0.18
		streak.look_at(streak.global_position + direction, Vector3.UP)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(streak, "transparency", 1.0, 0.2)
		tween.tween_property(streak, "scale:z", 0.25, 0.2)
		tween.finished.connect(streak.queue_free)

func add_camera_shake(amount: float) -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("add_shake"):
		rig.add_shake(amount)

func hitstop(real_duration := 0.055, time_scale := 0.06) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(real_duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false

func _spawn_ring(position: Vector3, color: Color, start_scale: float, end_scale: float, duration: float) -> void:
	var ring := MeshInstance3D.new()
	var material := ShaderMaterial.new()
	material.shader = RING_SHADER
	material.set_shader_parameter("ring_color", color)
	material.set_shader_parameter("alpha", 0.9)
	material.set_shader_parameter("pulse_speed", 0.0)
	material.set_shader_parameter("intensity", 1.15)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.35, 1.35)
	mesh.material = material
	ring.mesh = mesh
	ring.rotation.x = -PI * 0.5
	ring.scale = Vector3.ONE * start_scale
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = position
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * end_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(ring.queue_free)

func _spawn_debris(position: Vector3, color: Color, severity: int) -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.amount = 7 + severity * 2
	particles.lifetime = 0.85
	particles.explosiveness = 1.0
	particles.randomness = 0.8
	particles.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 5, 6))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.45, 0.28, 0.4)
	process.direction = Vector3.UP
	process.spread = 72.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 3.8 + float(severity) * 0.35
	process.gravity = Vector3(0, -8.5, 0)
	process.scale_min = 0.65
	process.scale_max = 1.25
	process.color = color.darkened(0.2)
	particles.process_material = process

	var debris_mesh := BoxMesh.new()
	debris_mesh.size = Vector3(0.11, 0.055, 0.08)
	debris_mesh.material = _matte_material(color.darkened(0.28), 0.35, 0.62)
	particles.draw_pass_1 = debris_mesh
	add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_free_after(particles, 1.25)

func _spawn_smoke(position: Vector3, severity: int) -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.amount = 5 + severity * 2
	particles.lifetime = 1.65
	particles.explosiveness = 0.72
	particles.randomness = 0.9
	particles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.4, 0.2, 0.36)
	process.direction = Vector3.UP
	process.spread = 32.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.85
	process.gravity = Vector3(0, 0.45, 0)
	process.scale_min = 0.65
	process.scale_max = 1.35
	process.color = Color(0.24, 0.25, 0.24, 0.62)
	particles.process_material = process

	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.2
	smoke_mesh.height = 0.4
	smoke_mesh.radial_segments = 7
	smoke_mesh.rings = 4
	var smoke_material := _matte_material(Color(0.3, 0.31, 0.29, 0.52), 0.0, 1.0)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mesh.material = smoke_material
	particles.draw_pass_1 = smoke_mesh
	add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_free_after(particles, 2.2)

func _emissive_material(color: Color, energy: float, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.42
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _matte_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _free_after(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()
