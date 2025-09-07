extends "res://scripts/narrative/INarrativeSource.gd"
class_name World

signal observation_ready(peer_id:int, obs:Dictionary)

const Logger = preload("res://scripts/Logger.gd")

var truth_db := {
    "tick": 0,
    "next_convoy_id": 1,
    "cities": {
        "PORT": {"neighbors": ["MILLS"]},
        "MILLS": {"neighbors": ["PORT"]}
    },
    "markets": {
        "PORT": {"salt": {"price": 12, "qty": 90}},
        "MILLS": {"salt": {"price": 8, "qty": 110}}
    },
    "convoys": {}
}

var tick_count: int:
    get:
        return int(truth_db.get("tick", 0))

var knowledge_db:Dictionary = {}
var rumor_queue:Array = []
var queued_cmds:Array = []

func _init() -> void:
    print("Module World loaded")

func register_player(peer_id:int) -> void:
    knowledge_db[peer_id] = {}
    for city_id in truth_db["markets"].keys():
        knowledge_db[peer_id][city_id] = {}
        for good in truth_db["markets"][city_id].keys():
            var info = truth_db["markets"][city_id][good].duplicate(true)
            info["age_days"] = 0
            knowledge_db[peer_id][city_id][good] = info

func queue_command(peer_id:int, action:Dictionary) -> void:
    queued_cmds.append({"peer": peer_id, "action": action})

func tick() -> void:
    truth_db["tick"] += 1
    _apply_commands()
    _simulate_convoys()
    _age_knowledge()
    for pid in knowledge_db.keys():
        var obs := make_observation_for(pid)
        Logger.log("World", "Emitting observation for peer %d" % pid)
        observation_ready.emit(pid, obs)

func make_observation_for(peer_id:int) -> Dictionary:
    var entities:Array = []
    for cid in truth_db["convoys"].keys():
        var c = truth_db["convoys"][cid]
        entities.append({"id": cid, "type": "convoy", "pos": c["pos"], "owner": c["owner"]})
    var obs := {
        "time": {"tick": truth_db["tick"]},
        "entities": entities,
        "markets": knowledge_db.get(peer_id, {}),
        "rumors": [],
        "self_id": peer_id
    }
    return obs

func _apply_commands() -> void:
    for entry in queued_cmds:
        var pid:int = entry["peer"]
        var action:Dictionary = entry["action"]
        match action.get("type", ""):
            "CreateConvoy":
                var city_id:String = action["payload"].get("city_id", "PORT")
                var cid:int = truth_db["next_convoy_id"]
                truth_db["next_convoy_id"] += 1
                truth_db["convoys"][cid] = {"id": cid, "owner": pid, "pos": city_id, "path": [], "goods": {}}
            "PlanRoute":
                var cid:int = action["payload"].get("convoy_id", 0)
                if truth_db["convoys"].has(cid) and truth_db["convoys"][cid]["owner"] == pid:
                    truth_db["convoys"][cid]["path"] = action["payload"].get("path", []).duplicate()
            "LoadGoods":
                var cid:int = action["payload"].get("convoy_id", 0)
                if truth_db["convoys"].has(cid) and truth_db["convoys"][cid]["owner"] == pid:
                    truth_db["convoys"][cid]["goods"] = action["payload"].get("goods", {}).duplicate(true)
            "HireCourier":
                pass
            "ShareIntel":
                pass
    queued_cmds.clear()

func _simulate_convoys() -> void:
    for cid in truth_db["convoys"].keys():
        var convoy = truth_db["convoys"][cid]
        var path:Array = convoy["path"]
        if path.size() > 0:
            convoy["pos"] = path.pop_front()
            convoy["path"] = path
            var pid:int = convoy["owner"]
            _update_player_market_knowledge(pid, convoy["pos"])
            event.emit({"type": "ConvoyArrived", "convoy_id": cid, "city": convoy["pos"], "owner": pid})

func _update_player_market_knowledge(peer_id:int, city_id:String) -> void:
    if not knowledge_db.has(peer_id):
        return
    if not knowledge_db[peer_id].has(city_id):
        knowledge_db[peer_id][city_id] = {}
    for good in truth_db["markets"][city_id].keys():
        var info = truth_db["markets"][city_id][good].duplicate(true)
        info["age_days"] = 0
        knowledge_db[peer_id][city_id][good] = info

func _age_knowledge() -> void:
    for pid in knowledge_db.keys():
        for city in knowledge_db[pid].keys():
            for good in knowledge_db[pid][city].keys():
                knowledge_db[pid][city][good]["age_days"] += 1
