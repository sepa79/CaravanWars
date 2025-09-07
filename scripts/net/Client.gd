extends Node
class_name Client

const Logger = preload("res://scripts/Logger.gd")

@export var peer_id: int = 1
@export var use_simple_ai: bool = false

var brain
@onready var chronicle = get_node_or_null("Game/UI/Main/Right/Tabs/Chronicle")
@onready var tabs: TabContainer = get_node_or_null("Game/UI/Main/Right/Tabs")

func _init() -> void:
    print("Module Client loaded")

func _good_id_from_key(k: Variant) -> int:
    if typeof(k) == TYPE_INT:
        return int(k)
    if typeof(k) == TYPE_STRING:
        var s_up := str(k).to_upper()
        match s_up:
            "FOOD":
                return int(DB.Good.FOOD)
            "MEDS":
                return int(DB.Good.MEDS)
            "ORE":
                return int(DB.Good.ORE)
            "TOOLS":
                return int(DB.Good.TOOLS)
            "LUX":
                return int(DB.Good.LUX)
        for id in DB.goods_names.keys():
            var name_low: String = str(DB.goods_names.get(id, ""))
            if s_up == name_low.to_upper():
                return int(id)
    return -1

func _normalize_stock_dict(d: Dictionary) -> Dictionary:
    var out := {}
    for k in d.keys():
        var id := _good_id_from_key(k)
        if id != -1:
            out[id] = int(d[k])
        else:
            out[k] = int(d[k])
    return out

func _ready() -> void:
    set_multiplayer_authority(peer_id)
    if use_simple_ai:
        brain = load("res://scripts/brains/SimpleTraderBrain.gd").new()
        Logger.log("Client", "Loaded SimpleTraderBrain for peer %d" % peer_id)
    else:
        brain = load("res://scripts/brains/HumanBrain.gd").new()
        Logger.log("Client", "Loaded HumanBrain for peer %d" % peer_id)
    var pname: String = str(PlayerMgr.players.get(peer_id, {}).get("name", "Unnamed"))
    rpc_id(1, "report_name", pname)
    Logger.log("Client", "Reported name '%s' to server" % pname)

@rpc("authority")
func push_observation(obs: Dictionary) -> void:
    Logger.log("Client", "peer %d push_observation: %s" % [peer_id, str(obs)])
    if chronicle:
        chronicle.show_observation(obs)
        chronicle.show_knowledge(obs.get("markets", {}))
    if tabs:
        var in_city := true
        for e in obs.get("entities", []):
            if e.get("type") == "convoy" and e.get("owner") == peer_id:
                if e.get("path", []).size() > 0:
                    in_city = false
                break
        tabs.set_tab_disabled(2, not in_city) # Trade tab at index 2
    if brain:
        var cmds = brain.think(obs)
        for c in cmds:
            rpc_id(1, "cmd", c)

@rpc("authority")
func push_log(msg:String) -> void:
    if chronicle:
        chronicle.add_log_entry(msg)
    var game = get_node_or_null("Game")
    if game != null and game.has_method("_on_log"):
        game._on_log(msg)

@rpc("authority")
func ping(msg: String) -> void:
    Logger.log("Client", "Received ping: %s" % msg)

@rpc("authority")
func push_snapshot(snapshot:Dictionary) -> void:
    # Update local state from server snapshot
    var players: Dictionary = snapshot.get("players", {})
    for k in players.keys():
        PlayerMgr.players[k] = players[k]
    var locs: Dictionary = snapshot.get("locations", {})
    for code in locs.keys():
        var loc = DB.get_loc(code)
        if loc != null:
            var s: Dictionary = locs[code]
            var raw_stock: Dictionary = s.get("stock", {}).duplicate(true)
            loc.stock = _normalize_stock_dict(raw_stock)
            loc.prices = s.get("prices", {}).duplicate(true)
    # Notify UI viewmodels to refresh current selections
    if WorldViewModel and WorldViewModel.has_method("notify_data_changed"):
        WorldViewModel.notify_data_changed()
