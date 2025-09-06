extends Node
class_name Server

const Logger = preload("res://scripts/Logger.gd")

@onready var world = load("res://scripts/world/World.gd").new()
var global_narrator
var mayor_narrator

func _ready() -> void:
    add_child(world)
    world.observation_ready.connect(_on_observation_ready)
    world.event.connect(_on_world_event)
    global_narrator = load("res://scripts/narrative/GlobalNarrator.gd").new()
    mayor_narrator = load("res://scripts/narrative/MayorNarrator.gd").new()
    add_child(global_narrator)
    add_child(mayor_narrator)
    multiplayer.peer_connected.connect(_on_peer_connected)
    _start_offline()
    var timer := Timer.new()
    timer.wait_time = 1.0
    timer.autostart = true
    timer.timeout.connect(_on_tick)
    add_child(timer)

func _start_offline() -> void:
    var peer := OfflineMultiplayerPeer.new()
    peer.create_server(2)
    multiplayer.multiplayer_peer = peer
    world.register_player(1)
    world.register_player(2)

func _on_peer_connected(id:int) -> void:
    if not world.knowledge_db.has(id):
        world.register_player(id)

func _on_tick() -> void:
    # Authoritative tick: world + player sim + orders processing
    world.tick()
    Sim.tick()
    # Advance players roughly once per second; could be refined
    Sim.advance_players(1.0)
    # After server-side updates, broadcast a fresh snapshot
    broadcast_snapshot()

@rpc("any_peer")
func cmd(action:Dictionary) -> void:
    var sender := multiplayer.get_remote_sender_id()
    var atype := str(action.get("type", ""))
    match atype:
        "move":
            var p = action.get("payload", {})
            Orders.move(str(p.get("player_id", "")), str(p.get("to", "")))
            broadcast_snapshot()
        "trade":
            var p = action.get("payload", {})
            Orders.trade(str(p.get("player_id", "")), str(p.get("action", "")), str(p.get("good", "")), int(p.get("amount", 0)), str(p.get("at", "")))
            broadcast_snapshot()
        "wait":
            var p = action.get("payload", {})
            Orders.wait(str(p.get("player_id", "")), float(p.get("seconds", 0.0)))
            broadcast_snapshot()
        "stop":
            var p = action.get("payload", {})
            Orders.stop(str(p.get("player_id", "")))
            broadcast_snapshot()
        _:
            # Forward unrecognized actions to the World simulation
            world.queue_command(sender, action)
            Logger.log("Server", "Queued world command from %s %s" % [str(sender), str(action)])

func broadcast_log(msg:String) -> void:
    for peer_id in multiplayer.get_peers():
        rpc_id(peer_id, "push_log", msg)
    # Also send to local authority clients if any
    rpc("push_log", msg)

func broadcast_snapshot() -> void:
    var snapshot := {
        "players": PlayerMgr.players,
        "locations": _make_locations_state()
    }
    for peer_id in multiplayer.get_peers():
        rpc_id(peer_id, "push_snapshot", snapshot)
    # Also to local authority
    rpc("push_snapshot", snapshot)

func _make_locations_state() -> Dictionary:
    var data := {}
    for code in DB.locations.keys():
        var loc = DB.get_loc(code)
        if loc == null:
            continue
        data[code] = {
            "stock": loc.stock.duplicate(true),
            "prices": loc.prices.duplicate(true)
        }
    return data

func _on_observation_ready(peer_id:int, obs:Dictionary) -> void:
    rpc_id(peer_id, "push_observation", obs)

func _on_world_event(event:Dictionary) -> void:
    global_narrator.render(-1, [event])
    mayor_narrator.render(-1, [event])
