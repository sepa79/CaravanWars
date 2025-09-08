extends Node

const Logger = preload("res://scripts/Logger.gd")

@onready var world = load("res://scripts/world/World.gd").new()
var global_narrator
var mayor_narrator

func _init() -> void:
    print("Module Server loaded")

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
    timer.timeout.connect(_on_tick)
    add_child(timer)
    timer.start()

func _start_offline() -> void:
    var peer: OfflineMultiplayerPeer = OfflineMultiplayerPeer.new()
    if peer.has_method("create_server"):
        peer.create_server(2)
    multiplayer.multiplayer_peer = peer
    if peer.has_method("add_peer"):
        peer.add_peer(2)
    _on_peer_connected(1)
    _on_peer_connected(2)
    var peers := Array(multiplayer.get_peers())
    peers.sort()
    Logger.log("Server", "Offline peers: %s" % [peers])
    if peers != [1, 2]:
        Logger.log("Server", "Unexpected offline peers: %s" % [peers])

func _on_peer_connected(id:int) -> void:
    if not world.knowledge_db.has(id):
        world.register_player(id)

func _on_tick() -> void:
    Logger.log("Server", "Tick %d" % world.tick_count)
    # Authoritative tick: world + player sim + orders processing
    world.tick()
    Sim.tick()
    # Advance players roughly once per second; could be refined
    Sim.advance_players(1.0)
    # After server-side updates, broadcast a fresh snapshot
    broadcast_snapshot()

@rpc("any_peer")
func report_name(name: String) -> void:
    var sender: int = multiplayer.get_remote_sender_id()
    Logger.log("Server", "Peer %d reported name '%s'" % [sender, name])
    Logger.log("Server", "Sending ping to %s" % name)
    rpc_id(sender, "ping", "ping")

@rpc("any_peer")
func cmd(action:Dictionary) -> void:
    var sender := multiplayer.get_remote_sender_id()
    var atype := str(action.get("type", ""))
    Logger.log("Server", "Received %s from %d" % [atype, sender])
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

func broadcast_snapshot() -> void:
    var snapshot := {
        "players": PlayerMgr.players,
        "locations": _make_locations_state()
    }
    for peer_id in multiplayer.get_peers():
        rpc_id(peer_id, "push_snapshot", snapshot)

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
    var size := JSON.stringify(obs).length()
    var text := "Sending observation to peer {peer} ({size} bytes)".format({"peer": peer_id, "size": size})
    Logger.log("Server", text)
    rpc_id(peer_id, "push_observation", obs)

func _on_world_event(event:Dictionary) -> void:
    global_narrator.render(-1, [event])
    mayor_narrator.render(-1, [event])
