extends Node

const GAME_VERSION := "0.3.5-alpha"
const ClientClass := preload("res://scripts/net/Client.gd")

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
@onready var tick_timer: Timer = $Tick
@onready var client: ClientClass = get_node_or_null("/root/Client")

var time_factor: float = 1.0

var last_loc: String = ""
var last_stock: Dictionary = {}
var last_moving: bool = false

func _ready() -> void:
    # log setup (console removed; logs come from Server/Client)

    # tick + mapa
    if map_node.has_signal("location_clicked"):
        map_node.location_clicked.connect(_on_location_click)
        zoom_in_btn.pressed.connect(map_node.zoom_in)
        zoom_out_btn.pressed.connect(map_node.zoom_out)

    # trade panel
    trade_panel.buy_request.connect(_on_buy_request)
    trade_panel.sell_request.connect(_on_sell_request)

    # inne panele (opcjonalnie)
    if WorldViewModel.has_signal("player_changed"):
        WorldViewModel.player_changed.connect(_on_player_changed)

    _fill_help()
    _setup_language_dropdown()
    _setup_time_controls()
    _set_tab_titles()
    _update_status()
    map_node.queue_redraw()
    _refresh_trade_panel()
    if client:
        client.snapshot_applied.connect(_on_snapshot_applied)

func _fill_help() -> void:
    var t := ""
    t += "[b]" + tr("Caravan Wars {version}").format({"version": GAME_VERSION}) + "[/b]\n"
    t += tr("• Move by clicking on the map (your caravan travels between locations).") + "\n"
    t += tr("• Trade only in the current location.") + "\n"
    t += tr("Codes: HARBOR, CENTRAL_KEEP, SOUTHERN_SHRINE, FOREST_SPRING, MILLS, FOREST_HAVEN, MINE") + "\n"
    help_box.bbcode_enabled = true
    help_box.clear()
    help_box.append_text(t)

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
        _update_status()
        _refresh_trade_panel()
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

func _store_trade_state() -> void:
    var pid = PlayerMgr.local_player_id
    var p = PlayerMgr.players.get(pid, {})
    last_loc = p.get("loc", "")
    last_moving = p.get("moving", false)
    var loc_obj = DB.get_loc(last_loc)
    last_stock = loc_obj.stock.duplicate() if loc_obj else {}

func _refresh_trade_panel() -> void:
    trade_panel.call_deferred("populate")
    _store_trade_state()

func _check_trade_refresh() -> void:
    var pid = PlayerMgr.local_player_id
    var p = PlayerMgr.players.get(pid, null)
    if p == null:
        return
    var loc = p.get("loc", "")
    var moving = p.get("moving", false)
    var loc_obj = DB.get_loc(loc)
    var stock = loc_obj.stock.duplicate() if loc_obj else {}
    if moving != last_moving or loc != last_loc or stock != last_stock:
        _refresh_trade_panel()

func _update_status() -> void:
        var pid = PlayerMgr.local_player_id
        var p = PlayerMgr.players.get(pid, null)
        if p == null:
                return
        loc_label.text = tr("Location: {loc}").format({"loc": DB.get_loc_name(p.get("loc", ""))})
        var speed_val: float = PlayerMgr.calc_speed(pid)
        speed_label.text = tr("Speed: {value}").format({"value": str(speed_val)})
        tick_label.text = tr("Tick: {value}").format({"value": str(Sim.tick_count)})
        var used: int = PlayerMgr.cargo_used(pid)
        var total: int = PlayerMgr.capacity_total(pid)
        cap_label.text = tr("Cargo: {used}/{total}").format({"used": str(used), "total": str(total)})
        gold_label.text = tr("Gold: {value}").format({"value": str(p.get("gold", 0))})
        caravans_label.text = tr("Caravans: {value}").format({"value": str(p.get("units", []).size())})

        var target: String = ""
        if p.get("moving", false):
                target = DB.get_loc_name(p.get("to", ""))
        else:
                target = DB.get_loc_name(p.get("loc", ""))
        caravan_panel.set_target(target)

        var goods_text: Array[String] = []
        var cargo: Dictionary = p.get("cargo", {})
        for g in cargo.keys():
                var name: String = tr(DB.goods_names.get(g, str(g)))
                goods_text.append("%s:%d" % [name, int(cargo[g])])
        var status: Dictionary = {
                "goods": ", ".join(goods_text),
                "food_rate": PlayerMgr.food_rate(pid),
                "speed": speed_val
        }
        caravan_panel.show_status(status)

func _set_tab_titles() -> void:
    tab.set_tab_title(0, tr("Chronicle"))
    tab.set_tab_title(1, tr("Caravan"))
    tab.set_tab_title(2, tr("Trade"))
    tab.set_tab_title(3, tr("World"))
    tab.set_tab_title(4, tr("Narrator"))
    tab.set_tab_title(5, tr("Help"))

func _on_location_click(loc_code: String) -> void:
    var pid = PlayerMgr.local_player_id
    Orders.order_move(str(pid), loc_code)
    _update_status()
    map_node.queue_redraw()
    _refresh_trade_panel()

func _on_buy_request(good: int, amount: int) -> void:
    var pid = PlayerMgr.local_player_id
    var loc: String = PlayerMgr.players.get(pid, {}).get("loc", "")
    Orders.order_buy(str(pid), loc, str(good), amount)
    _update_status()
    _refresh_trade_panel()

func _on_sell_request(good: int, amount: int) -> void:
    var pid = PlayerMgr.local_player_id
    var loc: String = PlayerMgr.players.get(pid, {}).get("loc", "")
    Orders.order_sell(str(pid), loc, str(good), amount)
    _update_status()
    _refresh_trade_panel()

func _on_snapshot_applied() -> void:
    _update_status()
    _check_trade_refresh()
    map_node.queue_redraw()

func _on_log(msg: String) -> void:
    log_label.append_text(msg + "\n")

func _on_player_changed(_data: Dictionary) -> void:
    _update_status()
    _refresh_trade_panel()
    map_node.queue_redraw()
