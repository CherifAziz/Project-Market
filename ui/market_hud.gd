class_name MarketHUD
extends CanvasLayer

const MARKET_ROW_SCENE := preload("res://ui/market_hud_row.tscn")

@onready var market_rows: VBoxContainer = %MarketRows
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel
@onready var cash_label: Label = %CashLabel
@onready var unrealized_label: Label = %UnrealizedLabel
@onready var realized_label: Label = %RealizedLabel

var _market: MarketService
var _rows: Dictionary = {}
var _notification_tween: Tween

func _ready() -> void:
	_market = get_tree().get_first_node_in_group("market_service") as MarketService
	if _market != null:
		_populate_rows()
		_market.market_updated.connect(_on_market_updated)
		_market.operational_event.connect(_on_operational_event)
		_market.price_reaction_started.connect(_on_price_reaction_started)
		_market.sabotage_resolved.connect(_on_sabotage_resolved)
		_market.account_updated.connect(_refresh_account)
	_refresh_all()

func get_company_row(company_id: String) -> MarketHUDRow:
	return _rows.get(company_id) as MarketHUDRow

func _populate_rows() -> void:
	for child in market_rows.get_children():
		child.queue_free()
	_rows.clear()
	for company_id in _market.get_company_ids():
		var row := MARKET_ROW_SCENE.instantiate() as MarketHUDRow
		market_rows.add_child(row)
		row.bind(_market, company_id)
		_rows[company_id] = row

func _on_market_updated(company_id: String) -> void:
	var row := get_company_row(company_id)
	if row != null:
		row.refresh()
	_refresh_account()

func _refresh_all() -> void:
	for row_value in _rows.values():
		(row_value as MarketHUDRow).refresh()
	_refresh_account()

func _refresh_account() -> void:
	if _market == null:
		return
	cash_label.text = "CASH  %s" % MoneyFormat.cash(_market.get_cash())
	unrealized_label.text = "UNREALIZED  %s" % MoneyFormat.pnl(_market.get_total_unrealized_pnl())
	realized_label.text = "REALIZED  %s" % MoneyFormat.pnl(_market.get_total_realized_pnl())

func _on_operational_event(company_id: String, message: String, stage: int, total: int, cause_company_id: String) -> void:
	if _notification_tween != null and _notification_tween.is_valid():
		_notification_tween.kill()
	var notification_text := "%02d / %02d   %s" % [stage, total, message]
	if company_id != cause_company_id:
		var source := _market.get_company_definition(cause_company_id)
		if source != null:
			notification_text = "%s  →  %s" % [source.ticker, message]
	notification_label.text = notification_text
	notification_panel.visible = true
	notification_panel.modulate.a = 0.0
	notification_panel.position.y = -8.0
	_notification_tween = create_tween().set_ignore_time_scale(true)
	_notification_tween.set_parallel(true)
	_notification_tween.tween_property(notification_panel, "modulate:a", 1.0, 0.14)
	_notification_tween.tween_property(notification_panel, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_notification_tween.set_parallel(false)
	_notification_tween.tween_interval(1.35)
	_notification_tween.tween_property(notification_panel, "modulate:a", 0.0, 0.35)
	_notification_tween.finished.connect(func() -> void: notification_panel.visible = false)

func _on_price_reaction_started(company_id: String, _target_price: float, _cause_company_id: String) -> void:
	var row := get_company_row(company_id)
	if row != null:
		row.pulse_price()
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_ui"):
		audio.play_ui(&"market_drop", 0.018)

func _on_sabotage_resolved(company_id: String, _current_price: float, _unrealized_pnl: float, _cause_company_id: String, is_final_stage: bool) -> void:
	if _market == null or not _market.has_open_position(company_id):
		return
	var row := get_company_row(company_id)
	if row != null:
		row.pulse_pnl()
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_ui"):
		audio.play_ui(&"profit_final" if is_final_stage else &"profit_tick", 0.012)
