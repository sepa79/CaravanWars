extends Node
class_name Server

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
    world.tick()

@rpc("any_peer")
func cmd(action:Dictionary) -> void:
    var sender := multiplayer.get_remote_sender_id()
    world.queue_command(sender, action)
    print("Queued command from", sender, action)

func _on_observation_ready(peer_id:int, obs:Dictionary) -> void:
    rpc_id(peer_id, "push_observation", obs)

func _on_world_event(event:Dictionary) -> void:
    global_narrator.render(-1, [event])
    mayor_narrator.render(-1, [event])
