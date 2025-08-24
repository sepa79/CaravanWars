extends IPlayerBrain
class_name BuiltinAIBrain

var rng := RandomNumberGenerator.new()

func think(observation:Dictionary) -> Array[Dictionary]:
    var cmds:Array = []
    var my_id:int = observation.get("self_id", 0)
    var owned_convoys:Array = []
    for e in observation.get("entities", []):
        if e.get("type") == "convoy" and e.get("owner") == my_id:
            owned_convoys.append(e)
    if owned_convoys.size() == 0:
        cmds.append({"type": "CreateConvoy", "payload": {"city_id": "PORT"}})
    else:
        var convoy = owned_convoys[0]
        if convoy.get("path", []).size() == 0:
            cmds.append({"type": "LoadGoods", "payload": {"convoy_id": convoy["id"], "goods": {"salt": 10}}})
            cmds.append({"type": "PlanRoute", "payload": {"convoy_id": convoy["id"], "path": ["MILLS", "PORT"]}})
    return cmds
