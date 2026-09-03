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
	var main := load("res://world/main.tscn").instantiate() as Node3D
	root.add_child(main)
	current_scene = main
	await _frames(3)
	var player := main.get_node("Player") as PlayerController
	var inventory := main.get_node("RunInventory") as RunInventory
	var interactor := main.get_node("LootInteractor") as LootInteractor
	var market := main.get_node("MarketService") as MarketService
	var exit_point := main.get_node("ExtractionPoint") as ExtractionPoint
	var director := main.get_node("SecurityDirector") as SecurityDirector
	var results := main.get_node("RunResults") as RunResults
	for guard in get_nodes_in_group("security_agents"):
		guard.set_physics_process(false)
	var pickups := get_nodes_in_group("loot_pickups")
	_check(pickups.size() == 6 and pickups.all(func(item: LootPickup) -> bool: return item.available and item.global_position.distance_to(exit_point.global_position) > 8.0), "six authored assets are inside company grounds, away from extraction")
	var module := _pickup("arc_module")
	var copper := _pickup("copper_spool")
	var prototype := _pickup("vita_prototype")
	main._on_loot_pickup_requested(module)
	_check(module.available and inventory.get_items().is_empty(), "out-of-range pickup requests are rejected by world coordinator")
	market.reaction_time_scale = 0.02
	market.open_short("arc_energy")
	market.open_short("vita_medical")
	for machine in (main.get_node("ARCFacility") as CompanyFacility).get_equipment():
		machine.take_damage(machine.health, machine.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD)
		await market.sabotage_resolved
		await market.sabotage_resolved
	player.global_position = module.global_position + Vector3(0, 0.7, 0.85)
	player.velocity = Vector3.ZERO
	await _frames(4)
	var barrier := StaticBody3D.new()
	barrier.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 2.0, 0.15)
	collision.shape = shape
	barrier.add_child(collision)
	main.add_child(barrier)
	barrier.global_position = module.global_position + Vector3(0, 0.8, 0.42)
	await _frames(2)
	_check(not interactor.can_reach(module), "loot interaction does not reach through solid geometry")
	barrier.queue_free()
	await _frames(3)
	await _press_interact()
	_check(not module.available and inventory.contains(module.loot_id) and inventory.get_used_slots() == 1, "contextual E collects module into one slot")
	_check(market.get_cash() == 10000.0 and player.move_speed == 7.6, "cargo creates no cash or movement penalty")
	player.global_position = copper.global_position + Vector3(0, 0.7, 0.7)
	player.velocity = Vector3.ZERO
	await _frames(4)
	await _press_interact()
	_check(inventory.get_used_slots() == 2, "two objects occupy two slots")
	var component := _pickup("power_component")
	player.global_position = component.global_position + Vector3(0, 0.7, 0.8)
	player.velocity = Vector3.ZERO
	await _frames(4)
	await _press_interact()
	_check(inventory.get_used_slots() == 3 and inventory.get_value() == 12800, "three ARC objects fill all three slots")
	var hud := main.inventory_hud as InventoryHUD
	_check(hud._slots.size() == 3 and director.is_security_enabled(), "three compact slots keep the world live")
	player.global_position = prototype.global_position + Vector3(0, 0.7, 0.8)
	player.velocity = Vector3.ZERO
	_aim_at(player.global_position + Vector3(4, 0, 0))
	await _frames(4)
	await _press_interact()
	await _press_action("cargo_2")
	_check(prototype.available and inventory.get_value() == 12800, "full bag does not swap on E or an un-aimed number key")
	for _frame in range(6):
		_aim_at(prototype.global_position)
		await _frames(1)
	_check(interactor.focused_pickup == prototype and hud._context.text == "$4.8k  ↓" and hud._slots[0].key_number == 1 and hud._slots[2].key_number == 3, "aim exposes only price and three direct numbered slots")
	await _press_action("cargo_2", prototype.global_position)
	_check(not prototype.available and copper.available and inventory.get_value() == 15000, "2 directly replaces copper with prototype")
	_check(inventory.get_items()[0]["id"] == module.loot_id and inventory.get_items()[1]["id"] == prototype.loot_id and inventory.get_items()[2]["id"] == component.loot_id, "swap leaves other slot locations unchanged")
	_check(copper.global_position.is_equal_approx(prototype.global_position) and interactor.can_reach(copper), "old object returns to the same reachable location without duplication")
	_aim_at(copper.global_position)
	await _press_action("cargo_2", copper.global_position)
	_check(inventory.contains(copper.loot_id) and prototype.available, "same swapped object is recoverable with 2")
	_aim_at(prototype.global_position)
	await _press_action("cargo_2", prototype.global_position)
	_check(inventory.contains(prototype.loot_id) and copper.available, "repeated swaps preserve unique IDs and values")
	# Cargo has no locomotion coupling: actual input still reaches baseline move speed.
	player.global_position = Vector3(0, 0.1, 3)
	player.velocity = Vector3.ZERO
	Input.action_press("move_right")
	await _wait(0.3)
	_check(is_equal_approx(player.velocity.x, player.move_speed), "full cargo preserves actual movement speed")
	Input.action_release("move_right")
	player.global_position = exit_point.global_position + Vector3.UP * 0.7
	player.velocity = Vector3.ZERO
	exit_point.hold_duration = 0.2
	await _frames(4)
	Input.action_press("interact")
	await _wait(0.3)
	Input.action_release("interact")
	await _wait(2.9)
	_check(results.was_successful() and results.market_profit_label.text == "+$9,900" and results.loot_profit_label.text == "+$15,000" and results.profit_label.text == "+$24,900", "extraction presents trading, sold assets and combined profit separately")
	_check(market.get_cash() == 34900.0 and inventory.get_items().is_empty() and "ARC INDUSTRIAL MODULE" in results.sold_items_label.text, "service credits $34,900 once and result lists the actual sold items")
	results.restart_button.pressed.emit()
	await _frames(5)
	main = current_scene
	player = main.get_node("Player") as PlayerController
	inventory = main.get_node("RunInventory") as RunInventory
	market = main.get_node("MarketService") as MarketService
	director = main.get_node("SecurityDirector") as SecurityDirector
	_check(inventory.get_items().is_empty() and get_nodes_in_group("loot_pickups").all(func(item: LootPickup) -> bool: return item.available), "restart restores all six world items, empty bag")
	# One bounded ranged-combat contract; full pursuit is checked in the rendered run.
	for agent in get_nodes_in_group("security_agents"):
		agent.set_physics_process(false)
	var guard := director.get_company_agents("arc_energy")[0]
	guard.global_position = Vector3(0, 0.0, 0)
	guard.set_physics_process(true)
	guard.raise_alert(player.global_position, 1)
	main._set_market_open(true)
	var health_before := player.health
	await _wait(1.8)
	_check(main.market_panel.is_open() and director.is_security_enabled() and not player.is_gameplay_input_enabled(), "market is an exposed field overlay, not a security pause")
	_check(player.health < health_before, "a real guard shot can hurt the immobilized player while market is open")
	main._set_market_open(false)
	guard.set_physics_process(false)
	var sample := _pickup("sample_case")
	player.global_position = sample.global_position + Vector3(-0.8, 0.7, 0.4)
	player.velocity = Vector3.ZERO
	await _frames(4)
	main._on_loot_pickup_requested(sample)
	_check(not inventory.get_items().is_empty(), "loss scenario carries an actual physical asset")
	main._set_market_open(true)
	await _wait(0.4)
	player.take_damage(player.health)
	_check(inventory.get_items().is_empty() and market.get_cash() == 10000.0 and market.get_account_summary()["stolen_assets"] == 0.0, "death forfeits every carried asset without selling anything")
	_check(not main.market_panel.is_open() and (main.get_node("RunResults") as RunResults).visible, "death from the field overlay closes it and shows the run-loss result")
	current_scene = null
	_check(await SceneCleanup.free_scene(self, main), "loot flow releases scene and audio resources before quitting")
	print("Loot flow test complete.")
	quit(1 if _failed else 0)

func _pickup(asset: String) -> LootPickup:
	for node in get_nodes_in_group("loot_pickups"):
		if node.loot_id.ends_with(":" + asset):
			return node as LootPickup
	return null

func _press_interact() -> void:
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)

func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame

func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _press_action(action: String, aimed_at := Vector3.INF) -> void:
	if aimed_at.is_finite():
		_aim_at(aimed_at)
	Input.action_press(action)
	for _frame in range(2):
		if aimed_at.is_finite():
			_aim_at(aimed_at)
		await _frames(1)
	Input.action_release(action)
	await _frames(2)

func _aim_at(at: Vector3) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_camera_3d().unproject_position(at)
	root.push_input(motion, true)
