extends "res://scripts/brains/IPlayerBrain.gd"
class_name SimpleTraderBrain

const Logger = preload("res://scripts/Logger.gd")

const LOAD_QTY:int = 10

func _init() -> void:
    print("Module SimpleTraderBrain loaded")

func think(observation:Dictionary) -> Array[Dictionary]:
    var cmds:Array[Dictionary] = []
    var self_id:int = observation.get("self_id", 0)
    Logger.log("SimpleTraderBrain", "Received observation for peer %d" % self_id)
    var markets:Dictionary = observation.get("markets", {})
    var owned_convoys:Array[Dictionary] = []
    for entity in observation.get("entities", []):
        if entity.get("type") == "convoy" and entity.get("owner") == self_id:
            owned_convoys.append(entity)
    if owned_convoys.is_empty():
        Logger.log("SimpleTraderBrain", "No convoys owned. Creating one at PORT.")
        cmds.append({"type": "CreateConvoy", "payload": {"city_id": "PORT"}})
        return cmds
    for convoy in owned_convoys:
        var convoy_id:int = convoy.get("id", 0)
        var path:Array = convoy.get("path", [])
        if path.size() > 0:
            Logger.log("SimpleTraderBrain", "Convoy %d already en route, skipping." % convoy_id)
            continue
        var goods:Dictionary = convoy.get("goods", {})
        if goods.size() > 0:
            Logger.log("SimpleTraderBrain", "Convoy %d selling goods %s" % [convoy_id, str(goods)])
            cmds.append({"type": "LoadGoods", "payload": {"convoy_id": convoy_id, "goods": {}}})
        var current_city:String = convoy.get("pos", "")
        var city_market:Dictionary = markets.get(current_city, {})
        var best_good:String = ""
        var best_dest:String = ""
        var best_profit:int = 0
        for good in city_market.keys():
            var buy_price:int = int(city_market[good].get("price", 0))
            for dest in markets.keys():
                if dest == current_city:
                    continue
                var sell_price:int = int(markets[dest].get(good, {}).get("price", 0))
                var profit:int = sell_price - buy_price
                if profit > best_profit:
                    best_profit = profit
                    best_good = good
                    best_dest = dest
        if best_profit > 0 and best_good != "":
            Logger.log("SimpleTraderBrain", "Convoy %d buying %s in %s and heading to %s for profit %d" % [convoy_id, best_good, current_city, best_dest, best_profit])
            cmds.append({"type": "LoadGoods", "payload": {"convoy_id": convoy_id, "goods": {best_good: LOAD_QTY}}})
            cmds.append({"type": "PlanRoute", "payload": {"convoy_id": convoy_id, "path": [best_dest]}})
        else:
            Logger.log("SimpleTraderBrain", "Convoy %d found no profitable trade at %s" % [convoy_id, current_city])
    return cmds
