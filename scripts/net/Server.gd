extends Node

const Logger = preload("res://scripts/Logger.gd")
@onready var world: Node = load("res://scripts/world/World.gd").new()
var tick_timer: Timer
var ready_peers: Dictionary = {}

func _init() -> void:
    print("Module Server loaded")

func _ready() -> void:
    add_child(world)
    world.observation_ready.connect(_on_observation_ready)
    world.event.connect(_on_world_event)
    multiplayer.peer_connected.connect(_on_peer_connected)
    if not _start_offline():
        return
    tick_timer = Timer.new()
    tick_timer.wait_time = 1.0
    tick_timer.timeout.connect(_on_tick)
    add_child(tick_timer)

func _start_offline() -> bool:
    var peer: OfflineMultiplayerPeer = OfflineMultiplayerPeer.new()
    if peer.has_method("create_server"):
        var err: int = peer.create_server(3)
        if err != OK:
            Logger.log("Server", "create_server failed: %s" % err)
            push_error("[Server] Offline server creation failed: %s" % err)
            return false
    else:
        Logger.log("Server", "OfflineMultiplayerPeer missing create_server")
        push_error("[Server] OfflineMultiplayerPeer missing create_server")
        return false

    multiplayer.multiplayer_peer = peer

    if peer.has_method("add_peer"):
        var err: int
        for pid in [2, 3]:
            err = peer.add_peer(pid)
            if err != OK:
                Logger.log("Server", "add_peer %d failed: %s" % [pid, err])
    else:
        Logger.log("Server", "OfflineMultiplayerPeer missing add_peer")

    var peers := Array(multiplayer.get_peers())
    peers.sort()
    Logger.log("Server", "Offline peers: %s" % [peers])
    if peers.is_empty():
        Logger.log("Server", "No offline peers registered; aborting startup")
        push_error("[Server] Offline multiplayer peer could not be created")
        return false
    if peers != [1, 2, 3]:
        Logger.log("Server", "Unexpected offline peers: %s" % [peers])
    return true

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

@rpc("authority")
func report_name(name: String) -> void:
    var sender: int = multiplayer.get_remote_sender_id()
    Logger.log("Server", "Peer %d reported name '%s'" % [sender, name])
    ready_peers[sender] = true
    var required: int = multiplayer.get_peers().size() - 1
    var count: int = ready_peers.size()
    if count >= required and tick_timer.is_stopped():
        Logger.log("Server", "All clients ready, starting tick timer")
        tick_timer.start()
    else:
        Logger.log("Server", "Waiting for clients: %d/%d ready" % [count, required])
    Logger.log("Server", "Sending ping to %s" % name)
    rpc_id(sender, "ping", "ping")

@rpc("authority")
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
        if peer_id == 1:
            continue
        var client := _get_client_node(peer_id)
        if client != null:
            client.rpc_id(peer_id, "push_log", msg)

func broadcast_snapshot() -> void:
    var snapshot := {
        "players": PlayerMgr.players,
        "locations": _make_locations_state()
    }
    for peer_id in multiplayer.get_peers():
        if peer_id == 1:
            continue
        var client := _get_client_node(peer_id)
        if client != null:
            client.rpc_id(peer_id, "push_snapshot", snapshot)
        else:
            Logger.log("Server", "No client node for peer %d" % peer_id)

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
    var client := _get_client_node(peer_id)
    if client != null:
        client.rpc_id(peer_id, "push_observation", obs)
    else:
        Logger.log("Server", "No client node for peer %d" % peer_id)

func _get_client_node(peer_id:int) -> Node:
    var nodes := get_tree().get_nodes_in_group("peer_%d" % peer_id)
    if nodes.size() > 0:
        return nodes[0]
    return null

func _on_world_event(event:Dictionary) -> void:
    GlobalNarrator.render(-1, [event])
