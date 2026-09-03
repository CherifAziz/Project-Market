extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		push_error("FAIL: " + message)

func _run() -> void:
	var main_scene := load("res://world/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var player := get_first_node_in_group("player") as PlayerController
	var targets := get_nodes_in_group("targets")
	var vita_equipment := get_nodes_in_group("vita_equipment")
	var audio := get_first_node_in_group("audio_service")
	_check(player != null, "player scene is present")
	_check(targets.size() == 11, "all eleven targets spawn")
	_check(vita_equipment.size() == 3, "VITA adds exactly three separate critical machines")
	_check(audio != null and audio.has_method("play_world") and audio.has_method("play_ui"), "reusable audio service is present")
	if audio:
		var required_cues := [&"smg", &"metal_impact", &"machine_damaged", &"machine_destroyed", &"market_confirm", &"market_drop", &"profit_tick", &"profit_final"]
		_check(required_cues.all(func(cue: StringName) -> bool: return audio.has_cue(cue)), "all first-pass audio cues are generated")
	if not vita_equipment.is_empty():
		var first_equipment := vita_equipment[0] as DestructibleEquipment
		_check(first_equipment.find_children("*", "Label3D", true, false).is_empty(), "machines no longer carry permanent world-space labels")
	_check(main.has_node("HUD/EquipmentContext"), "HUD owns one contextual equipment identifier")
	if player == null or targets.is_empty():
		quit(1)
		return

	var start_position := player.global_position
	Input.action_press("move_forward")
	for _step in range(8):
		await physics_frame
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start_position) > 0.1, "movement input moves the player")

	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	_check(player.get_dash_ready_ratio() < 0.2, "dash starts and consumes its cooldown")

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var target := targets[0] as DamageableTarget
	player.global_position = target.global_position + Vector3(0, 0.7, 3.0)
	player.look_at(Vector3(target.global_position.x, player.global_position.y, target.global_position.z), Vector3.UP)
	await physics_frame

	var starting_health := target.health
	player.weapon.tick(1.0, true)
	await process_frame
	_check(target.health < starting_health, "automatic weapon ray damages a target")
	var health_after_first_shot := target.health
	player.weapon.tick(0.0, true)
	await process_frame
	_check(is_equal_approx(target.health, health_after_first_shot), "automatic fire respects its rate limiter")
	player.weapon._fire()
	player.weapon._fire()
	await process_frame
	_check(not target.is_in_group("targets"), "three shots kill and remove a target from the active set")

	await create_timer(0.1, true, false, true).timeout
	main.queue_free()
	await process_frame
	await process_frame
	print("Smoke test complete.")
	quit(1 if _failed else 0)
