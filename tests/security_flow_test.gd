extends SceneTree

var _failed := false
var _main_scene: PackedScene

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		push_error("FAIL: " + message)

func _run() -> void:
	_main_scene = load("res://world/main.tscn") as PackedScene
	var main := await _spawn_main()
	var director := get_first_node_in_group("security_director") as SecurityDirector
	var player := get_first_node_in_group("player") as PlayerController
	var market := get_first_node_in_group("market_service") as MarketService
	var vita_facility := main.get_node("VITAFacility") as CompanyFacility
	var arc_facility := main.get_node("ARCFacility") as CompanyFacility
	var guards := get_nodes_in_group("security_agents")

	_check(director != null, "security director is present")
	_check(guards.size() == 4, "exactly four guards create the intended pressure")
	_check(director.get_company_agents("vita_medical").size() == 2, "VITA owns two local guards")
	_check(director.get_company_agents("arc_energy").size() == 2, "ARC owns two local guards")
	_check(guards.all(func(agent: Node) -> bool: return agent is CharacterBody3D and agent is SecurityAgent), "guards use moving humanoid agents instead of static targets")
	_check(guards.all(func(agent: SecurityAgent) -> bool: return not agent.is_alerted() and agent.get_state_name() == "PATROL"), "guards begin in patrol state")

	for guard_value in guards:
		(guard_value as SecurityAgent).set_physics_process(false)
	_check(market.open_short("arc_energy", 300) and market.open_short("vita_medical", 300), "security scenario keeps both independent shorts available")

	var vita_machine := vita_facility.get_equipment()[0]
	vita_machine.take_damage(1.0, vita_machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
	await process_frame
	_check(director.is_company_alerted("vita_medical"), "attacking VITA raises a local company alert")
	_check(not director.is_company_alerted("arc_energy"), "VITA alert does not wake ARC security")
	_check(director.get_alert_stage("vita_medical") == 1, "first attacked VITA machine creates alert level one")
	_check(director.get_company_agents("vita_medical").all(func(agent: SecurityAgent) -> bool: return agent.is_alerted()), "both VITA guards become immediately hostile")
	_check(director.get_company_agents("arc_energy").all(func(agent: SecurityAgent) -> bool: return not agent.is_alerted()), "ARC guards remain on patrol during a VITA-only alert")
	var security_alert_panel := main.get_node("HUD/SecurityAlertCenter/SecurityAlertPanel") as PanelContainer
	var security_alert_label := main.get_node("HUD/SecurityAlertCenter/SecurityAlertPanel/SecurityAlertLabel") as Label
	_check(security_alert_panel.visible and "VITA SECURITY ALERT" in security_alert_label.text, "HUD explains the local VITA security response")

	var arc_machine := arc_facility.get_equipment()[0]
	arc_machine.take_damage(1.0, arc_machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
	await process_frame
	_check(director.is_company_alerted("arc_energy") and director.get_alert_stage("arc_energy") == 1, "attacking ARC independently alerts ARC security")
	_check(director.get_company_agents("arc_energy").all(func(agent: SecurityAgent) -> bool: return agent.is_alerted()), "both ARC guards receive their local alarm")

	var guard := director.get_company_agents("vita_medical")[0]
	var guard_health := guard.health
	guard.take_damage(24.0, guard.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
	_check(guard.health < guard_health, "existing weapon damage contract hurts a security agent")
	guard.take_damage(guard.health, guard.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
	await process_frame
	_check(guard.is_dead() and not guard.is_in_group("targets"), "security agent death removes it from the combat target set")
	Engine.time_scale = 1.0

	var health_before_dash := player.health
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	_check(player.is_dashing(), "dash enters its active evasion window")
	_check(not player.take_damage(20.0, player.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD), "dash rejects an incoming security hit")
	_check(is_equal_approx(player.health, health_before_dash), "dash invulnerability preserves player health")
	await create_timer(player.dash_duration + 0.08, true, false, true).timeout
	_check(player.take_damage(20.0, player.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD), "player takes damage outside the dash window")
	_check(is_equal_approx(player.health, player.max_health - 20.0), "player health tracks incoming damage")
	_check(not player.take_damage(20.0, player.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD), "brief hurt invulnerability prevents instant damage stacking")
	await create_timer(player.hurt_invulnerability + 0.08, true, false, true).timeout

	var arc_price_before_death := market.get_current_price("arc_energy")
	var vita_price_before_death := market.get_current_price("vita_medical")
	player.take_damage(player.health, player.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
	await process_frame
	_check(not player.is_alive(), "lethal damage enters a clean player death state")
	_check((main.get_node("RunResults") as RunResults).visible, "death exposes the immediate run-result restart prompt")
	_check(not director.is_security_enabled(), "security simulation settles when the player is dead")
	_check(not market.has_open_position("arc_energy") and not market.has_open_position("vita_medical") and market.get_cash() == market.starting_cash, "death discards run positions and restores starting capital under the extraction loss rule")
	_check(is_equal_approx(market.get_current_price("arc_energy"), arc_price_before_death) and is_equal_approx(market.get_current_price("vita_medical"), vita_price_before_death), "death does not mutate market prices")

	await _remove_main(main)
	var reset_main := await _spawn_main()
	var reset_player := get_first_node_in_group("player") as PlayerController
	var reset_market := get_first_node_in_group("market_service") as MarketService
	var reset_director := get_first_node_in_group("security_director") as SecurityDirector
	_check(reset_player.is_alive() and is_equal_approx(reset_player.health, reset_player.max_health), "fresh reset restores full player health")
	_check(reset_director.get_alive_count() == 4 and not reset_director.is_company_alerted("vita_medical") and not reset_director.is_company_alerted("arc_energy"), "fresh reset restores four calm guards")
	_check(not reset_market.has_open_position("vita_medical") and not reset_market.has_open_position("arc_energy"), "fresh reset clears market positions as before")
	await _remove_main(reset_main)

	print("Security flow test complete.")
	quit(1 if _failed else 0)

func _spawn_main() -> Node3D:
	var main := _main_scene.instantiate() as Node3D
	root.add_child(main)
	await process_frame
	await process_frame
	await physics_frame
	return main

func _remove_main(main: Node3D) -> void:
	Engine.time_scale = 1.0
	_check(await SceneCleanup.free_scene(self, main), "scene and audio resources are released after scenario")
