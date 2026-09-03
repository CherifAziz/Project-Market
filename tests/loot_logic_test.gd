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
	var prototype := load("res://data/loot/vita_prototype.tres") as LootDefinition
	var analyzer := load("res://data/loot/lab_analyzer.tres") as LootDefinition
	var component := load("res://data/loot/power_component.tres") as LootDefinition
	var module := load("res://data/loot/arc_module.tres") as LootDefinition
	for asset in ["vita_prototype", "lab_analyzer", "sample_case", "arc_module", "copper_spool", "power_component"]:
		var definition := load("res://data/loot/%s.tres" % asset) as LootDefinition
		_check(definition != null and definition.is_valid() and not definition.category.is_empty(), "authored loot has valid name/value/weight/slots/category: " + asset)
	var inventory := RunInventory.new()
	root.add_child(inventory)
	_check(inventory.capacity == 3 and inventory.get_items().is_empty(), "inventory begins empty with exactly three slots")
	_check(inventory.collect("prototype", prototype)["accepted"], "small medical prototype occupies one slot")
	_check(not inventory.collect("prototype", prototype)["accepted"], "same physical item cannot be collected twice")
	inventory.collect("analyzer", analyzer)
	inventory.collect("component", component)
	_check(inventory.get_used_slots() == 3 and inventory.get_value() == 11400.0 and inventory.get_weight() == 9.0, "three small items create the alternate light $11,400 loadout")
	_check(not inventory.collect("module", module)["accepted"] and not inventory.collect("module", module, 1)["accepted"], "a two-slot module cannot overwrite a full bag or exchange for insufficient room")
	_check(inventory.get_items().size() == 3 and inventory.contains("analyzer"), "failed exchange leaves existing cargo untouched")
	inventory.select_item(1)
	var dropped := inventory.drop_selected()
	_check(dropped["id"] == "analyzer" and inventory.get_used_slots() == 2, "dropping the selected item frees its capacity")
	var exchanged := inventory.collect("module", module, 1)
	_check(exchanged["accepted"] and exchanged["dropped"]["id"] == "component", "atomic replacement returns the old item for physical placement")
	_check(inventory.get_used_slots() == 3 and inventory.get_weight() == 16.0 and inventory.get_value() == 12000.0, "prototype plus bulky ARC module is $12,000 / 16 kg / three slots")
	var snapshot := inventory.get_items()
	snapshot[0]["value"] = 1.0
	_check(inventory.get_value() == 12000.0, "inventory UI snapshots cannot mutate the transport manifest")
	var player := PlayerController.new()
	player.set_carried_weight(16.0)
	_check(is_equal_approx(player.get_carry_speed_multiplier(), 0.88), "16 kg applies a subtle twelve percent movement cost")
	player.set_carried_weight(200.0)
	_check(is_equal_approx(player.get_carry_speed_multiplier(), 0.84), "movement penalty is capped at sixteen percent")
	player.set_carried_weight(0.0)
	_check(player.get_carry_speed_multiplier() == 1.0 and player.dash_speed == 21.0 and player.dash_duration == 0.14, "empty bag restores movement without mutating base movement or dash tuning")
	player.free()

	var market := MarketService.new()
	market.companies.append(load("res://data/arc_energy.tres") as CompanyDefinition)
	market.companies.append(load("res://data/vita_medical.tres") as CompanyDefinition)
	root.add_child(market)
	market.open_short("arc_energy")
	market.open_short("vita_medical")
	market._set_current_price("arc_energy", 35.0)
	market._set_current_price("vita_medical", 38.0)
	market.close_short("arc_energy")
	_check(market.get_cash() == 18700.0 and market.get_total_unrealized_pnl() == 1200.0, "carried valuables never inflate cash before extraction")
	var manifest := inventory.get_items()
	manifest.append(manifest[0].duplicate(true))
	var statement := market.settle_all_positions(manifest)
	_check(statement["market_profit"] == 9900.0 and statement["realized_pnl"] == 9900.0 and statement["stolen_assets"] == 12000.0, "service separates realized trading from a deduplicated asset sale")
	_check(statement["run_profit"] == 21900.0 and statement["cash"] == 31900.0 and statement["sold_items"].size() == 2, "combined result is $21,900 profit and $31,900 cash")
	market.settle_all_positions(manifest)
	_check(market.get_cash() == 31900.0, "repeated extraction cannot sell the same manifest twice")
	inventory.finish_run()
	_check(inventory.get_items().is_empty() and inventory.get_weight() == 0.0 and not inventory.collect("late", prototype)["accepted"], "terminal inventory clears its load and rejects late pickups")
	inventory.queue_free()
	market.queue_free()
	await process_frame
	print("Loot logic test complete.")
	quit(1 if _failed else 0)
