extends Node

func _is_server() -> bool:
	return get_tree() != null and get_tree().get_multiplayer().is_server()

func _send_cmd_to_server(action:Dictionary) -> void:
	var s = get_node_or_null("/root/Server")
	if s != null:
		# server has peer id 1 in our setup
		s.rpc_id(1, "cmd", action)

func move(player_id: String, to_loc: String) -> void:
	if not _is_server():
		_send_cmd_to_server({"type": "move", "payload": {"player_id": player_id, "to": to_loc}})
		return
	print("[ORDERS] move", player_id, "->", to_loc)
	var ok := PlayerMgr.start_travel(int(player_id), to_loc)
	if ok:
		var p = PlayerMgr.players.get(int(player_id), {})
		var srv = get_node_or_null("/root/Server")
		if srv != null and p.has("name"):
			srv.call_deferred("broadcast_log", "MoveQueued %s -> %s" % [p["name"], DB.get_loc_name(to_loc)])

func trade(player_id: String, action: String, good: String, amount: int, at_loc: String) -> void:
	if not _is_server():
		_send_cmd_to_server({
			"type": "trade",
			"payload": {"player_id": player_id, "action": action, "good": good, "amount": amount, "at": at_loc}
		})
		return
	print("[ORDERS] trade", player_id, action, good, amount, "at", at_loc)
	var pid := int(player_id)
	var gid := int(good)
	if action == "buy":
		_buy(pid, gid, amount, at_loc)
	elif action == "sell":
		_sell(pid, gid, amount, at_loc)

func _buy(pid: int, good: int, amount: int, loc_code: String) -> void:
	var p = PlayerMgr.players.get(pid, null)
	if p == null or p.get("moving", false):
		return
	var market = DB.get_loc(loc_code)
	if market == null:
		return
	if not market.has_good(good):
		return
	var available: int = market.get_stock(good)
	if available < amount:
		var srv = get_node_or_null("/root/Server")
		if srv != null:
			srv.call_deferred("broadcast_log", tr("[color=red]Not enough goods in stock.[/color]"))
		return
	var price: int = market.get_price(good)
	var cost: int = price * amount
	if p.get("gold", 0) < cost:
		var srv2 = get_node_or_null("/root/Server")
		if srv2 != null:
			srv2.call_deferred("broadcast_log", tr("[color=red]Not enough gold.[/color]"))
		return
	if PlayerMgr.cargo_free(pid) < amount:
		var srv3 = get_node_or_null("/root/Server")
		if srv3 != null:
			srv3.call_deferred("broadcast_log", tr("[color=red]Not enough cargo space.[/color]"))
		return
	p["gold"] -= cost
	p["cargo"][good] = p["cargo"].get(good, 0) + amount
	# Update stock in location
	market.stock[good] = max(0, available - amount)
	var srv4 = get_node_or_null("/root/Server")
	if srv4 != null:
		srv4.call_deferred("broadcast_log", tr("Trade %s buy %d %s @%s = %d") % [p["name"], amount, tr(DB.goods_names[good]), DB.get_loc_name(loc_code), cost])

func _sell(pid: int, good: int, amount: int, loc_code: String) -> void:
	var p = PlayerMgr.players.get(pid, null)
	if p == null or p.get("moving", false):
		return
	var cargo: Dictionary = p.get("cargo", {})
	var have: int = cargo.get(good, 0)
	if have < amount:
		var srv = get_node_or_null("/root/Server")
		if srv != null:
			srv.call_deferred("broadcast_log", tr("[color=red]Not enough goods to sell.[/color]"))
		return
	var market = DB.get_loc(loc_code)
	if market == null:
		return
	var price: int = market.get_price(good)
	var revenue: int = price * amount
	p["gold"] += revenue
	cargo[good] = have - amount
	if cargo[good] <= 0:
		cargo.erase(good)
	# Update stock in location
	market.stock[good] = market.get_stock(good) + amount
	var srv2 = get_node_or_null("/root/Server")
	if srv2 != null:
		srv2.call_deferred("broadcast_log", tr("Trade %s sell %d %s @%s = %d") % [p["name"], amount, tr(DB.goods_names[good]), DB.get_loc_name(loc_code), revenue])

func wait(player_id: String, seconds: float) -> void:
	if not _is_server():
		_send_cmd_to_server({"type": "wait", "payload": {"player_id": player_id, "seconds": seconds}})
		return
	print("[ORDERS] wait", player_id, seconds)
	var pid := int(player_id)
	var p = PlayerMgr.players.get(pid, null)
	if p != null:
		p["wait_left"] = max(0.0, seconds)

func stop(player_id: String) -> void:
	if not _is_server():
		_send_cmd_to_server({"type": "stop", "payload": {"player_id": player_id}})
		return
	print("[ORDERS] stop", player_id)
	var pid := int(player_id)
	var p = PlayerMgr.players.get(pid, null)
	if p != null and p.get("moving", false):
		p["loc"] = p.get("from", p.get("loc", ""))
		p["moving"] = false
		p.erase("from"); p.erase("to"); p.erase("eta_left"); p.erase("eta_total")
		p["progress"] = 0.0
		var srv = get_node_or_null("/root/Server")
		if srv != null:
			srv.call_deferred("broadcast_log", tr("[%s] stopped traveling.") % [p["name"]])

func process(delta: float) -> void:
	if not _is_server():
		return
	for p in PlayerMgr.players.values():
		if p.has("wait_left"):
			p["wait_left"] = max(0.0, p["wait_left"] - delta)
			if p["wait_left"] == 0.0:
				p.erase("wait_left")
