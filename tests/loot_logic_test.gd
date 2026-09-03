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
	var shapes: Array[int] = []
	for asset in ["vita_prototype", "lab_analyzer", "sample_case", "arc_module", "copper_spool", "power_component"]:
		var definition := load("res://data/loot/%s.tres" % asset) as LootDefinition
		_check(definition != null and definition.is_valid() and not shapes.has(definition.visual_kind), "valid value and distinct visual identity: " + asset)
		shapes.append(definition.visual_kind)
	_check(MoneyFormat.short_cash(4800) == "$4.8k" and MoneyFormat.short_cash(7200) == "$7.2k", "compact prices preserve authored values")
	_check(not InputMap.has_action("inventory") and not InputMap.has_action("drop_loot"), "Tab inspection and G drop are removed")
	var inventory := RunInventory.new()
	root.add_child(inventory)
	_check(inventory.capacity == 3 and inventory.get_items().is_empty(), "three empty slots")
	_check(inventory.collect("prototype", prototype)["accepted"] and inventory.get_used_slots() == 1, "one object occupies exactly one slot")
	_check(not inventory.collect("prototype", prototype)["accepted"], "same physical item cannot be collected twice")
	inventory.collect("analyzer", analyzer)
	inventory.collect("component", component)
	_check(inventory.get_used_slots() == 3 and inventory.get_value() == 11400, "three objects fill the bag")
	_check(not inventory.collect("module", module)["accepted"] and not inventory.collect("module", module, 3)["accepted"], "full bag requires an explicit valid replacement")
	_check(inventory.get_items()[1]["id"] == "analyzer", "invalid exchange preserves cargo")
	var exchanged := inventory.collect("module", module, 1)
	_check(exchanged["accepted"] and exchanged["dropped"]["id"] == "analyzer", "atomic replacement returns old physical identity")
	_check(inventory.get_items()[0]["id"] == "prototype" and inventory.get_items()[1]["id"] == "module" and inventory.get_items()[2]["id"] == "component", "replacement preserves all slot positions")
	_check(inventory.get_used_slots() == 3 and inventory.get_value() == 15000, "industrial module now occupies one slot like every object")
	var snapshot := inventory.get_items()
	snapshot[0]["value"] = 1.0
	_check(inventory.get_value() == 15000, "UI snapshots cannot mutate the manifest")
	var swap_bag := RunInventory.new()
	root.add_child(swap_bag)
	for index in range(3):
		swap_bag.collect("original%d" % index, prototype)
	for index in range(3):
		var before := swap_bag.get_items()
		swap_bag.collect("replacement%d" % index, analyzer, index)
		var after := swap_bag.get_items()
		_check(after[index]["id"] == "replacement%d" % index and after[(index + 1) % 3] == before[(index + 1) % 3] and after[(index + 2) % 3] == before[(index + 2) % 3], "direct swap targets slot %d only" % (index + 1))
	swap_bag.queue_free()
	var market := MarketService.new()
	market.companies.append(load("res://data/arc_energy.tres") as CompanyDefinition)
	market.companies.append(load("res://data/vita_medical.tres") as CompanyDefinition)
	root.add_child(market)
	market.open_short("arc_energy")
	market.open_short("vita_medical")
	market._set_current_price("arc_energy", 35.0)
	market._set_current_price("vita_medical", 38.0)
	market.close_short("arc_energy")
	_check(market.get_cash() == 18700 and market.get_total_unrealized_pnl() == 1200, "cargo creates no cash before extraction")
	var manifest := inventory.get_items()
	manifest.append(manifest[0].duplicate(true))
	var statement := market.settle_all_positions(manifest)
	_check(statement["market_profit"] == 9900 and statement["realized_pnl"] == 9900 and statement["stolen_assets"] == 15000, "unchanged service separates trading and deduplicated asset sale")
	_check(statement["run_profit"] == 24900 and statement["cash"] == 34900 and statement["sold_items"].size() == 3, "three-item result settles exactly")
	market.settle_all_positions(manifest)
	_check(market.get_cash() == 34900, "repeated extraction cannot pay twice")
	inventory.finish_run()
	_check(inventory.get_items().is_empty() and not inventory.collect("late", prototype)["accepted"], "terminal bag clears and rejects late pickups")
	inventory.queue_free()
	market.queue_free()
	await process_frame
	print("Loot logic test complete.")
	quit(1 if _failed else 0)
