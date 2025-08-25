extends Node

const GAME_VERSION := "0.3.3-alpha"

@onready var map_node: Control = $UI/Main/Left/MapBox/Map
@onready var zoom_in_btn: Button = $UI/Main/Left/MapBox/MapControls/ZoomIn
@onready var zoom_out_btn: Button = $UI/Main/Left/MapBox/MapControls/ZoomOut
@onready var trade_panel: VBoxContainer = $UI/Main/Right/Tabs/Trade/TradePanel
@onready var caravan_panel: VBoxContainer = $UI/Main/Right/Tabs/Caravan/CaravanPanel
@onready var help_box: RichTextLabel = $UI/Main/Right/Tabs/HelpOptions/HelpText
@onready var tab: TabContainer = $UI/Main/Right/Tabs

@onready var gold_label: Label = $UI/Status/Gold
@onready var caravans_label: Label = $UI/Status/Caravans
@onready var tick_label: Label = $UI/Status/Tick
@onready var loc_label: Label = $UI/Status/Loc
@onready var cap_label: Label = $UI/Status/Cap
@onready var speed_label: Label = $UI/Status/Speed

@onready var pause_btn: Button = $UI/Status/PauseBtn
@onready var play_btn: Button = $UI/Status/PlayBtn
@onready var fast_btn: Button = $UI/Status/FastBtn

@onready var lang_option: OptionButton = $UI/Main/Right/Tabs/HelpOptions/Lang

@onready var log_label: RichTextLabel = $UI/Main/Right/Log
@onready var cmd_box: LineEdit = $UI/Main/Right/Cmd
@onready var tick_timer: Timer = $Tick

var time_factor: float = 1.0

func _ready() -> void:
	# log / komendy
	Commander.connect("log", _on_log)
	cmd_box.text_submitted.connect(_on_cmd)

	# tick + mapa
	tick_timer.timeout.connect(_on_tick)
	if map_node.has_signal("location_clicked"):
		map_node.location_clicked.connect(_on_location_click)
		zoom_in_btn.pressed.connect(map_node.zoom_in)
		zoom_out_btn.pressed.connect(map_node.zoom_out)

	# trade panel
	if trade_panel.has_signal("buy_request"):
		trade_panel.buy_request.connect(_on_buy_request)
	if trade_panel.has_signal("sell_request"):
		trade_panel.sell_request.connect(_on_sell_request)

	# inne panele (opcjonalnie)
	if caravan_panel.has_signal("ask_ai_pressed"):
		caravan_panel.ask_ai_pressed.connect(_on_ask_ai)

	_fill_help()
	_setup_language_dropdown()
	_setup_time_controls()
	_set_tab_titles()
	_update_status()
	map_node.queue_redraw()
	_set_time_factor(time_factor)
	set_process(true)


func _fill_help() -> void:
	var t := ""
	t += "[b]" + tr("Caravan Wars {version}").format({"version": GAME_VERSION}) + "[/b]\n"
	t += tr("• Move by clicking on the map (your caravan travels between locations).") + "\n"
	t += tr("• Trade only in the current location.") + "\n"
	t += tr("• Console commands (EN codes only): [code]help, info, price <CODE>, move <CODE>[/code]") + "\n"
	t += tr("Codes: HARBOR, CENTRAL_KEEP, SOUTHERN_SHRINE, FOREST_SPRING, MILLS, FOREST_HAVEN, MINE") + "\n"
	help_box.bbcode_text = t

func _setup_language_dropdown() -> void:
	lang_option.clear()
	var langs := {"en": tr("English"), "pl": tr("Polski")}
	for code in langs.keys():
		lang_option.add_item(langs[code])
		lang_option.set_item_metadata(lang_option.item_count - 1, code)
	for i in range(lang_option.get_item_count()):
		if lang_option.get_item_metadata(i) == DB.current_language:
			lang_option.select(i)
			break
	lang_option.item_selected.connect(func(i):
		DB.set_language(lang_option.get_item_metadata(i))
		_fill_help()
		_set_tab_titles()
		caravan_panel.set_target(caravan_panel.selected_target)
		caravan_panel.ask_ai_btn.text = tr("Ask AI for advice")
		_update_status()
		trade_panel.call_deferred("populate")
		map_node.queue_redraw()
	)

func _setup_time_controls() -> void:
	pause_btn.pressed.connect(func(): _set_time_factor(0.0))
	play_btn.pressed.connect(func(): _set_time_factor(1.0))
	fast_btn.pressed.connect(func(): _set_time_factor(2.0))

func _set_time_factor(f: float) -> void:
	time_factor = f
	if f <= 0.0:
		tick_timer.stop()
	else:
		tick_timer.start(1.0 / f)

func _update_status() -> void:
	var pid = PlayerMgr.local_player_id
	var p = PlayerMgr.players.get(pid, null)
	if p == null:
		return
	var loc_obj := LocationsDB.get(p.get("loc", ""))
	var loc_name := loc_obj.displayName if loc_obj else ""
	loc_label.text = tr("Location: {loc}").format({"loc": loc_name})
	speed_label.text = tr("Speed: {value}").format({"value": str(PlayerMgr.calc_speed(pid))})
	tick_label.text = tr("Tick: {value}").format({"value": str(Sim.tick_count)})
	var used = PlayerMgr.cargo_used(pid)
	var total = PlayerMgr.capacity_total(pid)
	cap_label.text = tr("Cargo: {used}/{total}").format({"used": str(used), "total": str(total)})
	gold_label.text = tr("Gold: {value}").format({"value": str(p.get("gold", 0))})
	caravans_label.text = tr("Caravans: {value}").format({"value": str(p.get("units", []).size())})

func _set_tab_titles() -> void:
	tab.set_tab_title(0, tr("Chronicle"))
	tab.set_tab_title(1, tr("Caravan"))
	tab.set_tab_title(2, tr("Trade"))
	tab.set_tab_title(3, tr("World"))
	tab.set_tab_title(4, tr("Narrator"))
	tab.set_tab_title(5, tr("Help"))

func _process(delta: float) -> void:
	Sim.advance_players(delta * time_factor)
	_update_status()

func _on_location_click(loc_code: String) -> void:
	var pid = PlayerMgr.local_player_id
	if PlayerMgr.start_travel(pid, loc_code):
		_update_status()
		map_node.queue_redraw()

func _on_buy_request(good: int, amount: int) -> void:
	var pid = PlayerMgr.local_player_id
	if Commander.buy(pid, good, amount):
		_update_status()
		trade_panel.call_deferred("populate")

func _on_sell_request(good: int, amount: int) -> void:
	var pid = PlayerMgr.local_player_id
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
