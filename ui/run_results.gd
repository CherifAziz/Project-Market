class_name RunResults
extends CanvasLayer

signal restart_requested

@onready var panel: PanelContainer = %ResultPanel
@onready var title_label: Label = %ResultTitle
@onready var subtitle_label: Label = %ResultSubtitle
@onready var starting_cash_label: Label = %StartingCash
@onready var company_rows: VBoxContainer = %CompanyResults
@onready var revenue_rows: VBoxContainer = %RevenueRows
@onready var market_profit_label: Label = %MarketProfit
@onready var loot_profit_label: Label = %LootProfit
@onready var sold_items_label: Label = %SoldItems
@onready var profit_caption: Label = %ProfitCaption
@onready var profit_label: Label = %RunProfit
@onready var cash_caption: Label = %CashCaption
@onready var cash_label: Label = %NetCash
@onready var rule_label: Label = %RuleLabel
@onready var restart_button: Button = %RestartButton

var _summary: Dictionary = {}
var _success := false
var _presentation: Tween

func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())

func present(success: bool, summary: Dictionary) -> void:
	_summary = summary.duplicate(true)
	_success = success
	visible = true
	if _presentation != null and _presentation.is_valid():
		_presentation.kill()
	for child in company_rows.get_children():
		child.free()
	title_label.text = "EXTRACTION COMPLETE" if success else "RUN LOST"
	subtitle_label.text = "POSITIONS SETTLED  //  PROFITS SECURED" if success else "NO EXTRACTION  //  RUN GAINS FORFEITED"
	starting_cash_label.text = MoneyFormat.cash(summary["starting_cash"])
	profit_caption.text = "RUN PROFIT" if success else "PROFIT RETAINED"
	cash_caption.text = "NEW NET CASH" if success else "NEXT RUN CASH"
	profit_label.text = "$0"
	profit_label.add_theme_color_override("font_color", Color("9fc49f") if summary["run_profit"] >= 0.0 else Color("c77c60"))
	cash_label.text = MoneyFormat.cash(summary["starting_cash"])
	rule_label.text = "Run settled. No permanent progression.\nA new run starts with %s." % MoneyFormat.cash(summary["starting_cash"]) if success else "All cargo and all run gains — even closed gains — are lost.\nPositions discarded. A new run starts with %s." % MoneyFormat.cash(summary["starting_cash"])
	market_profit_label.text = "$0"
	loot_profit_label.text = "$0"
	var sold_lines := PackedStringArray()
	for item in summary["sold_items"]:
		sold_lines.append("%s  ·  %s" % [item["name"], MoneyFormat.cash(item["value"])])
	sold_items_label.text = "\n".join(sold_lines)
	sold_items_label.visible = not sold_lines.is_empty()
	title_label.add_theme_color_override("font_color", Color("c9d8c6") if success else Color("d7a58d"))
	panel.modulate.a = 0.0
	_presentation = create_tween().set_ignore_time_scale(true)
	_presentation.tween_property(panel, "modulate:a", 1.0, 0.24)
	if success:
		for entry_value in summary["companies"]:
			var entry: Dictionary = entry_value
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 40)
			var name_label := Label.new()
			name_label.text = "%s SHORT" % entry["ticker"]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", 17)
			name_label.add_theme_color_override("font_color", Color("bdbdae"))
			var value_label := Label.new()
			value_label.text = "$0"
			value_label.add_theme_font_size_override("font_size", 20)
			value_label.add_theme_color_override("font_color", Color("9fc49f") if entry["realized_pnl"] >= 0.0 else Color("c77c60"))
			row.add_child(name_label)
			row.add_child(value_label)
			company_rows.add_child(row)
			_presentation.tween_callback(func() -> void: _play_cue(&"profit_tick", -5.0))
			_presentation.tween_method(func(value: float) -> void: value_label.text = MoneyFormat.pnl(value), 0.0, float(entry["realized_pnl"]), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_presentation.tween_interval(0.08)
		_presentation.tween_method(func(value: float) -> void: market_profit_label.text = MoneyFormat.pnl(value), 0.0, float(summary["market_profit"]), 0.25)
		_presentation.tween_method(func(value: float) -> void: loot_profit_label.text = MoneyFormat.pnl(value), 0.0, float(summary["stolen_assets"]), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_presentation.tween_method(func(value: float) -> void: profit_label.text = MoneyFormat.pnl(value), 0.0, float(summary["run_profit"]), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_presentation.tween_method(func(value: float) -> void: cash_label.text = MoneyFormat.cash(value), float(summary["starting_cash"]), float(summary["cash"]), 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_presentation.tween_callback(func() -> void: _play_cue(&"run_settled", 0.0))
	company_rows.visible = success
	revenue_rows.visible = success
	restart_button.grab_focus()

func get_summary() -> Dictionary:
	return _summary.duplicate(true)

func was_successful() -> bool:
	return _success

func _play_cue(cue: StringName, volume_offset: float) -> void:
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_ui(cue, 0.0, volume_offset)
