extends "res://scripts/brains/IPlayerBrain.gd"
class_name SimpleTraderBrain

const LOAD_QTY:int = 10

func think(observation:Dictionary) -> Array[Dictionary]:
    var cmds:Array[Dictionary] = []
    var self_id:int = observation.get("self_id", 0)
    var markets:Dictionary = observation.get("markets", {})
    var owned_convoys:Array[Dictionary] = []
    for entity in observation.get("entities", []):
        if entity.get("type") == "convoy" and entity.get("owner") == self_id:
            owned_convoys.append(entity)
    if owned_convoys.is_empty():
        cmds.append({"type": "CreateConvoy", "payload": {"city_id": "PORT"}})
        return cmds
    for convoy in owned_convoys:
        var convoy_id:int = convoy.get("id", 0)
        var path:Array = convoy.get("path", [])
        if path.size() > 0:
            continue
        var goods:Dictionary = convoy.get("goods", {})
        if goods.size() > 0:
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
            cmds.append({"type": "LoadGoods", "payload": {"convoy_id": convoy_id, "goods": {best_good: LOAD_QTY}}})
            cmds.append({"type": "PlanRoute", "payload": {"convoy_id": convoy_id, "path": [best_dest]}})
    return cmds
