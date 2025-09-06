extends Node

const Logger = preload("res://scripts/Logger.gd")

func _is_server() -> bool:
    return get_tree() != null and get_tree().get_multiplayer().is_server()

func _send_cmd_to_server(action:Dictionary) -> void:
    var s = get_node_or_null("/root/Server")
    if s != null:
        # server has peer id 1 in our setup
        s.rpc_id(1, "cmd", action)

func order_move(player_id: String, to_loc: String) -> void:
    # Canonical move order, used by UI/AI/console
    move(player_id, to_loc)

func move(player_id: String, to_loc: String) -> void:
    if not _is_server():
        _send_cmd_to_server({"type": "move", "payload": {"player_id": player_id, "to": to_loc}})
        return
    Logger.log("Orders", "move %s -> %s" % [player_id, to_loc])
    var ok = PlayerMgr.start_travel(int(player_id), to_loc)
    if ok:
        var p = PlayerMgr.players.get(int(player_id), {})
        if p.has("name"):
            Logger.log("Orders", "MoveQueued %s -> %s" % [p["name"], DB.get_loc_name(to_loc)])

func order_buy(player_id: String, location_id: String, good: String, qty: int) -> void:
    # Canonical buy order, used by UI/AI/console
    trade(player_id, "buy", good, qty, location_id)

func order_sell(player_id: String, location_id: String, good: String, qty: int) -> void:
    # Canonical sell order, used by UI/AI/console
    trade(player_id, "sell", good, qty, location_id)

func trade(player_id: String, action: String, good: String, amount: int, at_loc: String) -> void:
    if not _is_server():
        _send_cmd_to_server({
            "type": "trade",
            "payload": {"player_id": player_id, "action": action, "good": good, "amount": amount, "at": at_loc}
        })
        return
    Logger.log("Orders", "trade %s %s %s %d at %s" % [player_id, action, good, amount, at_loc])
    var pid = int(player_id)
    var gid = int(good)
    if action == "buy":
        _buy(pid, gid, amount, at_loc)
    elif action == "sell":
        _sell(pid, gid, amount, at_loc)

func _buy(pid: int, good: int, amount: int, loc_code: String) -> void:
    var p = PlayerMgr.players.get(pid, null)
    if p == null:
        return
    # Must be stationary in the location
    if p.get("moving", false):
        return
    var market = DB.get_loc(loc_code)
    if market == null:
        return
    # qty > 0 and good must exist in DB
    if amount <= 0 or not DB.goods_base_price.has(good):
        return
    # Player must be physically in location
    if str(p.get("loc", "")) != str(loc_code):
        return
    var available: int = int(DB.stock_of(loc_code, good))
    if available < amount:
        Logger.log("Orders", tr("[color=red]Not enough goods in stock.[/color]"))
        return
    var price: int = int(DB.price_of(loc_code, good))
    var cost: int = price * amount
    if p.get("gold", 0) < cost:
        Logger.log("Orders", tr("[color=red]Not enough gold.[/color]"))
        return
    if PlayerMgr.cargo_free(pid) < amount:
        Logger.log("Orders", tr("[color=red]Not enough cargo space.[/color]"))
        return
    # Apply effects
    p["gold"] = int(p.get("gold", 0)) - cost
    PlayerMgr.cargo_add(pid, good, amount)
    # Update stock in location
    market.stock[good] = max(0, available - amount)
    Logger.log("Orders", tr("Trade %s buy %d %s @%s = %d") % [p["name"], amount, tr(DB.goods_names[good]), DB.get_loc_name(loc_code), cost])

func _sell(pid: int, good: int, amount: int, loc_code: String) -> void:
    var p = PlayerMgr.players.get(pid, null)
    if p == null:
        return
    # Must be stationary in the location
    if p.get("moving", false):
        return
    var cargo: Dictionary = p.get("cargo", {})
    var have: int = int(cargo.get(good, 0))
    if have < amount:
        Logger.log("Orders", tr("[color=red]Not enough goods to sell.[/color]"))
        return
    var market = DB.get_loc(loc_code)
    if market == null:
        return
    # qty > 0 and good must exist in DB
    if amount <= 0 or not DB.goods_base_price.has(good):
        return
    # Player must be physically in location
    if str(p.get("loc", "")) != str(loc_code):
        return
    var price: int = int(DB.price_of(loc_code, good))
    var revenue: int = price * amount
    p["gold"] = int(p.get("gold", 0)) + revenue
    PlayerMgr.cargo_remove(pid, good, amount)
    # Update stock in location
    market.stock[good] = int(market.get_stock(good)) + amount
    Logger.log("Orders", tr("Trade %s sell %d %s @%s = %d") % [p["name"], amount, tr(DB.goods_names[good]), DB.get_loc_name(loc_code), revenue])

func wait(player_id: String, seconds: float) -> void:
    if not _is_server():
        _send_cmd_to_server({"type": "wait", "payload": {"player_id": player_id, "seconds": seconds}})
        return
    Logger.log("Orders", "wait %s %f" % [player_id, seconds])
    var pid = int(player_id)
    var p = PlayerMgr.players.get(pid, null)
    if p != null:
        p["wait_left"] = max(0.0, seconds)

func stop(player_id: String) -> void:
    if not _is_server():
        _send_cmd_to_server({"type": "stop", "payload": {"player_id": player_id}})
        return
    Logger.log("Orders", "stop %s" % player_id)
    var pid = int(player_id)
    var p = PlayerMgr.players.get(pid, null)
    if p != null and p.get("moving", false):
        p["loc"] = p.get("from", p.get("loc", ""))
        p["moving"] = false
        p.erase("from"); p.erase("to"); p.erase("eta_left"); p.erase("eta_total")
        p["progress"] = 0.0
        Logger.log("Orders", tr("[%s] stopped traveling.") % [p["name"]])

func process(delta: float) -> void:
    if not _is_server():
        return
    for p in PlayerMgr.players.values():
        if p.has("wait_left"):
            p["wait_left"] = max(0.0, p["wait_left"] - delta)
            if p["wait_left"] == 0.0:
                p.erase("wait_left")
