extends Node

@onready var map_node: Control = $UI/Left/Map
@onready var trade_panel: VBoxContainer = $UI/Right/Tabs/Trade/TradePanel
@onready var caravan_panel: VBoxContainer = $UI/Right/Tabs/Caravan/CaravanPanel
@onready var help_box: RichTextLabel = $UI/Right/Tabs/Help/HelpText
@onready var tab: TabContainer = $UI/Right/Tabs

@onready var player_selector: OptionButton = $UI/Right/Status/PlayerSel
@onready var gold_label: Label = $UI/Right/Status/Gold
@onready var caravans_label: Label = $UI/Right/Status/Caravans
@onready var tick_label: Label = $UI/Right/Status/Tick
@onready var loc_label: Label = $UI/Right/Status/Loc
@onready var cap_label: Label = $UI/Right/Status/Cap
@onready var speed_label: Label = $UI/Right/Status/Speed

@onready var log_label: RichTextLabel = $UI/Right/Log
@onready var cmd_box: LineEdit = $UI/Right/Cmd
@onready var tick_timer: Timer = $Tick

func _ready() -> void:
	# log / komendy
	Commander.connect("log", _on_log)
	cmd_box.text_submitted.connect(_on_cmd)

	# tick + mapa
	tick_timer.timeout.connect(_on_tick)
	if map_node.has_signal("location_clicked"):
		map_node.location_clicked.connect(_on_location_click)

	# trade panel
	if trade_panel.has_signal("buy_request"):
		trade_panel.buy_request.connect(_on_buy_request)
	if trade_panel.has_signal("sell_request"):
		trade_panel.sell_request.connect(_on_sell_request)

	# inne panele (opcjonalnie)
	if caravan_panel.has_signal("ask_ai_pressed"):
		caravan_panel.ask_ai_pressed.connect(_on_ask_ai)

	_populate_player_selector()
	_fill_help()
	_update_status()
	map_node.queue_redraw()

func _populate_player_selector() -> void:
	player_selector.clear()
	for id in PlayerMgr.order:
		var p = PlayerMgr.players[id]
		player_selector.add_item(p["name"], id)
	player_selector.item_selected.connect(func(_i):
		PlayerMgr.local_player_id = player_selector.get_selected_id()
		_update_status()
		trade_panel.call_deferred("populate") # bezpiecznie po zmianie gracza
		map_node.queue_redraw()
	)

func _fill_help() -> void:
	var t := ""
	t += "[b]Caravan Wars 0.3.4-alpha[/b]\n"
	t += "• Move by clicking on the map (your caravan travels between locations).\n"
	t += "• Trade only in the current location.\n"
	t += "• Console commands (EN codes only): [code]help, info, price <CODE>, move <CODE>[/code]\n"
	t += "Codes: HARBOR, CENTRAL_KEEP, SOUTHERN_SHRINE, FOREST_SPRING, MILLS, FOREST_HAVEN, MINE\n"
	help_box.bbcode_text = t

func _update_status() -> void:
	var pid := PlayerMgr.local_player_id
	var p = PlayerMgr.players.get(pid, null)
	if p == null:
		return
	# uzupełnij tutaj swoje liczniki/etykiety wg danych z PlayerMgr
	loc_label.text = DB.get_loc_name(p.get("loc", ""))
	speed_label.text = str(p.get("speed", 0.0))
	tick_label.text = str(Sim.get("tick")) 
	# cap/gold/caravans — przykładowo:
	cap_label.text = str(p.get("cap_used", 0)) + "/" + str(p.get("cap_total", 0))
	gold_label.text = str(p.get("gold", 0))
	caravans_label.text = str(p.get("caravans", 1))

func _on_location_click(loc_code: String) -> void:
	var pid := PlayerMgr.local_player_id
	if PlayerMgr.start_travel(pid, loc_code):
		_update_status()
		map_node.queue_redraw()

func _on_buy_request(good: int, amount: int) -> void:
	var pid := PlayerMgr.local_player_id
	if Commander.buy(pid, good, amount):
		_update_status()
		trade_panel.call_deferred("populate")

func _on_sell_request(good: int, amount: int) -> void:
	var pid := PlayerMgr.local_player_id
	if Commander.sell(pid, good, amount):
		_update_status()
		trade_panel.call_deferred("populate")

func _on_ask_ai(player_id: int) -> void:
	var aibr = get_node_or_null("/root/AiBridge")
	if aibr:
		aibr.suggest_for_player(player_id)

func _on_tick() -> void:
        Sim.tick()
        _update_status()
        map_node.queue_redraw()

func _on_cmd(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	cmd_box.text = ""
	Commander.exec(t) # zakładam, że masz metodę exec w Commander

func _on_log(msg: String) -> void:
	log_label.append_text(msg + "\n")
