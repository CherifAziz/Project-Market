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
	var main := (load("res://world/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(3)
	var market := main.get_node("MarketService") as MarketService
	var player := main.get_node("Player") as PlayerController
	var director := main.get_node("SecurityDirector") as SecurityDirector
	var exit_point := main.get_node("ExtractionPoint") as ExtractionPoint
	var panel := main.get_node("MarketPanel") as MarketPanel
	var results := main.get_node("RunResults") as RunResults
	market.reaction_time_scale = 0.02
	exit_point.hold_duration = 0.4
	for guard in get_nodes_in_group("security_agents"):
		guard.set_physics_process(false)
	_check(main.run_state == main.RunState.ACTIVE and not exit_point.is_available() and not results.visible, "fresh run starts active with a locked physical exit and hidden results")
	player.global_position = exit_point.global_position + Vector3.UP * 0.7
	Input.action_press("interact")
	await _wait(0.5)
	_check(not exit_point.is_completed() and exit_point.get_progress() == 0.0, "holding interaction before sabotage cannot extract")
	Input.action_release("interact")
	main._set_market_open(true)
	_check(panel.open_short_for("arc_energy") and panel.open_short_for("vita_medical"), "market UI opens both positions in a run")
	_check(panel.cash_label.text == "$10,000" and panel.realized_label.text == "$0", "market UI distinguishes initial cash and realized P&L")
	main._set_market_open(false)
	var machines := (main.get_node("ARCFacility") as CompanyFacility).get_equipment()
	machines[0].take_damage(24.0, machines[0].global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
	_check(exit_point.is_available(), "first physical equipment hit unlocks extraction")
	player.global_position = Vector3(0, 0.7, 4)
	Input.action_press("interact")
	await _wait(0.15)
	_check(exit_point.get_progress() == 0.0, "interaction outside the physical zone cannot progress")
	player.global_position = exit_point.global_position + Vector3.UP * 0.7
	await _wait(0.15)
	_check(exit_point.get_progress() > 0.0 and director.is_security_enabled(), "hold progresses in-zone without pausing security")
	Input.action_release("interact")
	await _frames(2)
	_check(exit_point.get_progress() == 0.0, "releasing E cancels rather than banks extraction progress")
	Input.action_press("interact")
	await _wait(0.12)
	Input.action_press("move_right")
	await _wait(0.1)
	Input.action_release("move_right")
	Input.action_release("interact")
	_check(exit_point.get_progress() == 0.0, "moving interrupts extraction")
	player.global_position = exit_point.global_position + Vector3.UP * 0.7
	await _wait(0.15)
	Input.action_press("interact")
	await _wait(0.12)
	Input.action_press("dash")
	await _frames(2)
	_check(player.is_dashing() and exit_point.get_progress() == 0.0, "dash evasion interrupts extraction rather than completing it invulnerably")
	Input.action_release("dash")
	Input.action_release("interact")
	await _wait(0.35)
	player.global_position = exit_point.global_position + Vector3.UP * 0.7
	player.velocity = Vector3.ZERO
	await _frames(2)
	Input.action_press("interact")
	await _wait(0.12)
	var health_before_hit := player.health
	player.take_damage(18.0, player.global_position, Vector3.UP, Vector3.FORWARD)
	_check(player.health < health_before_hit and exit_point.get_progress() == 0.0 and exit_point.is_interrupted(), "player remains vulnerable and damage interrupts the hold")
	Input.action_release("interact")
	await _wait(0.75)
	Input.action_press("interact")
	await _wait(0.12)
	main._set_market_open(true)
	await _wait(0.5)
	_check(exit_point.get_progress() == 0.0 and not exit_point.is_completed() and director.is_security_enabled(), "live market overlay cancels extraction without pausing security")
	Input.action_release("interact")
	main._set_market_open(false)
	for machine in machines:
		machine.take_damage(machine.health, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		await market.sabotage_resolved
		await market.sabotage_resolved
	_check(market.get_total_unrealized_pnl() == 9900.0, "complete ARC sabotage still yields the validated $9,900 latent profit")
	_check(panel.close_short_for("arc_energy"), "manual close is available from the market UI")
	_check(panel.cash_label.text == "$18,700" and panel.realized_label.text == "+$8,700", "manual close updates cash and realized UI independently of latent VITA")
	player.global_position = exit_point.global_position + Vector3.UP * 0.7
	player.velocity = Vector3.ZERO
	Input.action_press("interact")
	await _wait(0.55)
	Input.action_release("interact")
	_check(exit_point.is_completed() and main.run_state == main.RunState.EXTRACTED, "full hold ends the run through the physical extraction event")
	_check(market.get_cash() == 19900.0 and market.get_total_realized_pnl() == 9900.0 and market.get_total_unrealized_pnl() == 0.0, "extraction settles prior closed ARC plus open VITA exactly once")
	_check(results.visible and results.was_successful() and results.get_summary()["companies"].size() == 2, "success screen receives a two-company settled statement")
	_check(not director.is_security_enabled() and not player.is_gameplay_input_enabled(), "combat freezes only after extraction succeeds")
	_check(not player.take_damage(200.0), "late same-frame shots cannot overturn a completed run")
	await _wait(2.9)
	_check(results.profit_label.text == "+$9,900" and results.cash_label.text == "$19,900", "animated statement lands on exact realized profit and new cash")
	main._unhandled_input(_restart_event())
	await _frames(5)
	main = current_scene
	market = main.get_node("MarketService") as MarketService
	player = main.get_node("Player") as PlayerController
	exit_point = main.get_node("ExtractionPoint") as ExtractionPoint
	results = main.get_node("RunResults") as RunResults
	_check(market.get_cash() == 10000.0 and market.get_total_realized_pnl() == 0.0 and not market.has_open_position("arc_energy"), "actual R restart creates a fresh account without permanent carryover")
	_check(player.is_alive() and player.health == 100.0 and not exit_point.is_available() and not results.visible, "actual restart restores player, extraction and result UI")
	_check(get_nodes_in_group("security_agents").size() == 4 and get_nodes_in_group("company_equipment").all(func(machine: DestructibleEquipment) -> bool: return not machine.is_destroyed()), "restart restores all guards and equipment")
	for guard in get_nodes_in_group("security_agents"):
		guard.set_physics_process(false)
	market.reaction_time_scale = 0.02
	market.open_short("arc_energy", 300)
	market.open_short("vita_medical", 300)
	var machine := (main.get_node("ARCFacility") as CompanyFacility).get_equipment()[0]
	machine.take_damage(machine.health, machine.global_position, Vector3.UP, Vector3.FORWARD)
	await market.sabotage_resolved
	await market.sabotage_resolved
	market.close_short("arc_energy")
	player.take_damage(player.health)
	await _frames(2)
	_check(main.run_state == main.RunState.FAILED and results.visible and not results.was_successful(), "death before extraction produces a failed run")
	_check(market.get_cash() == 10000.0 and market.get_total_realized_pnl() == 0.0 and not market.has_open_position("vita_medical"), "death forfeits manual profits and cancels remaining shorts")
	_check("closed gains" in results.rule_label.text and not exit_point.is_completed(), "failure UI explicitly explains forfeiture of even closed gains")
	results.restart_button.pressed.emit()
	await _frames(5)
	main = current_scene
	_check((main.get_node("MarketService") as MarketService).get_cash() == 10000.0 and (main.get_node("Player") as PlayerController).is_alive(), "result-screen new-run button performs the same full reset")
	for guard in get_nodes_in_group("security_agents"):
		guard.set_physics_process(false)
	market = main.get_node("MarketService") as MarketService
	player = main.get_node("Player") as PlayerController
	exit_point = main.get_node("ExtractionPoint") as ExtractionPoint
	machine = (main.get_node("VITAFacility") as CompanyFacility).get_equipment()[0]
	machine.take_damage(1.0, machine.global_position, Vector3.UP, Vector3.FORWARD)
	player.global_position = exit_point.global_position + Vector3.UP * 0.7
	exit_point.hold_duration = 0.1
	Input.action_press("interact")
	await _wait(0.2)
	Input.action_release("interact")
	_check(exit_point.is_completed() and market.get_cash() == 10000.0 and market.get_total_realized_pnl() == 0.0, "VITA attack also unlocks extraction and a run with no positions settles without phantom profit")
	current_scene = null
	_check(await SceneCleanup.free_scene(self, main), "final scene and audio resources are released before quitting")
	print("Run flow test complete.")
	quit(1 if _failed else 0)

func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame

func _restart_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"restart"
	event.pressed = true
	return event
