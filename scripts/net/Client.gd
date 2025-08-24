extends Node
class_name Client

@export var peer_id:int = 1
@export var use_builtin_ai:bool = false

var brain
@onready var hud = get_node_or_null("Hud")

func _ready() -> void:
    set_multiplayer_authority(peer_id)
    if use_builtin_ai:
        brain = load("res://scripts/brains/BuiltinAIBrain.gd").new()
    else:
        brain = load("res://scripts/brains/HumanBrain.gd").new()

@rpc("authority")
func push_observation(obs:Dictionary) -> void:
    if hud:
        hud.show_observation(obs)
        hud.show_knowledge(obs.get("markets", {}))
    if brain:
        var cmds = brain.think(obs)
        for c in cmds:
            rpc_id(1, "cmd", c)
