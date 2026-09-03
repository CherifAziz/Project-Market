class_name MarketPanel
extends CanvasLayer

const COMPANY_CARD_SCENE := preload("res://ui/market_company_card.tscn")

@onready var company_list: VBoxContainer = %CompanyList
@onready var cash_label: Label = %AccountCash
@onready var unrealized_label: Label = %AccountUnrealized
@onready var realized_label: Label = %AccountRealized

var _market: MarketService
var _cards: Dictionary = {}

func _ready() -> void:
	_market = get_tree().get_first_node_in_group("market_service") as MarketService
	if _market != null:
		_populate_cards()
		_market.market_updated.connect(_on_market_updated)
		_market.position_opened.connect(_on_position_opened)
		_market.account_updated.connect(_refresh_account)
	_refresh_all()

func open_market() -> void:
	visible = true
	_refresh_all()
	_focus_first_available_button()

func close_market() -> void:
	visible = false
	for card_value in _cards.values():
		var card := card_value as MarketCompanyCard
		card.short_button.release_focus()
		card.close_button.release_focus()

func is_open() -> bool:
	return visible

func open_short_for(company_id: String) -> bool:
	if _market == null or not _market.open_short(company_id, _market.default_short_shares):
		return false
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null and audio.has_method("play_ui"):
		audio.play_ui(&"market_confirm", 0.02)
	return true

func get_company_card(company_id: String) -> MarketCompanyCard:
	return _cards.get(company_id) as MarketCompanyCard

func close_short_for(company_id: String) -> bool:
	if _market == null or not _market.close_short(company_id):
		return false
	var audio := get_tree().get_first_node_in_group("audio_service")
	if audio != null:
		audio.play_ui(&"market_confirm", 0.0)
	return true

func _populate_cards() -> void:
	for child in company_list.get_children():
		child.queue_free()
	_cards.clear()
	for company_id in _market.get_company_ids():
		var card := COMPANY_CARD_SCENE.instantiate() as MarketCompanyCard
		company_list.add_child(card)
		card.bind(_market, company_id)
		card.short_requested.connect(_on_short_requested)
		card.close_requested.connect(close_short_for)
		_cards[company_id] = card

func _on_short_requested(company_id: String) -> void:
	open_short_for(company_id)

func _on_market_updated(company_id: String) -> void:
	var card := get_company_card(company_id)
	if card != null:
		card.refresh()
	_refresh_account()

func _on_position_opened(company_id: String) -> void:
	_on_market_updated(company_id)

func _refresh_all() -> void:
	for card_value in _cards.values():
		(card_value as MarketCompanyCard).refresh()
	_refresh_account()

func _refresh_account() -> void:
	if _market == null:
		return
	cash_label.text = MoneyFormat.cash(_market.get_cash())
	unrealized_label.text = MoneyFormat.pnl(_market.get_total_unrealized_pnl())
	realized_label.text = MoneyFormat.pnl(_market.get_total_realized_pnl())

func _focus_first_available_button() -> void:
	if _market == null:
		return
	for company_id in _market.get_company_ids():
		var card := get_company_card(company_id)
		if card != null and not card.short_button.disabled:
			card.short_button.grab_focus()
			return
		if card != null and card.close_button.visible and not card.close_button.disabled:
			card.close_button.grab_focus()
			return
