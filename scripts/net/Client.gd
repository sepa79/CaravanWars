extends Node
class_name Client

@export var peer_id:int = 1
@export var use_builtin_ai:bool = false

var brain
@onready var chronicle = get_node_or_null("Game/UI/Main/Right/Tabs/Chronicle")
@onready var tabs:TabContainer = get_node_or_null("Game/UI/Main/Right/Tabs")

func _ready() -> void:
	set_multiplayer_authority(peer_id)
	if use_builtin_ai:
		brain = load("res://scripts/brains/BuiltinAIBrain.gd").new()
	else:
		brain = load("res://scripts/brains/HumanBrain.gd").new()

@rpc("authority")
func push_observation(obs:Dictionary) -> void:
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
func push_snapshot(snapshot:Dictionary) -> void:
	# Update local state from server snapshot
	var players:Dictionary = snapshot.get("players", {})
	for k in players.keys():
		PlayerMgr.players[k] = players[k]
	var locs:Dictionary = snapshot.get("locations", {})
	for code in locs.keys():
		var loc = DB.get_loc(code)
		if loc != null:
			var s:Dictionary = locs[code]
			loc.stock = s.get("stock", {}).duplicate(true)
			loc.prices = s.get("prices", {}).duplicate(true)