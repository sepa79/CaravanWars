extends Node

func move(player_id: String, to_loc: String) -> void:
	print("[ORDERS] move", player_id, "->", to_loc)
	PlayerMgr.start_travel(int(player_id), to_loc)

func trade(player_id: String, action: String, good: String, amount: int, at_loc: String) -> void:
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
	var stock: Dictionary = market.stock
	var available: int = stock.get(good, 0)
	if available < amount:
		Commander.emit_signal("log", tr("[color=red]Not enough goods in stock.[/color]"))
		return
	var price: int = market.prices.get(good, 0)
	var cost: int = price * amount
	if p.get("gold", 0) < cost:
		Commander.emit_signal("log", tr("[color=red]Not enough gold.[/color]"))
		return
	if PlayerMgr.cargo_free(pid) < amount:
		Commander.emit_signal("log", tr("[color=red]Not enough cargo space.[/color]"))
		return
	p["gold"] -= cost
	p["cargo"][good] = p["cargo"].get(good, 0) + amount
	stock[good] = available - amount
	Commander.emit_signal("log", tr("[%s] bought %d %s for %d.") % [p["name"], amount, tr(DB.goods_names[good]), cost])

func _sell(pid: int, good: int, amount: int, loc_code: String) -> void:
	var p = PlayerMgr.players.get(pid, null)
	if p == null or p.get("moving", false):
		return
	var cargo: Dictionary = p.get("cargo", {})
	var have: int = cargo.get(good, 0)
	if have < amount:
		Commander.emit_signal("log", tr("[color=red]Not enough goods to sell.[/color]"))
		return
	var market = DB.get_loc(loc_code)
	if market == null:
		return
	var price: int = market.prices.get(good, 0)
	var revenue: int = price * amount
	p["gold"] += revenue
	cargo[good] = have - amount
	if cargo[good] <= 0:
		cargo.erase(good)
	var stock: Dictionary = market.stock
	stock[good] = stock.get(good, 0) + amount
	Commander.emit_signal("log", tr("[%s] sold %d %s for %d.") % [p["name"], amount, tr(DB.goods_names[good]), revenue])

func wait(player_id: String, seconds: float) -> void:
	print("[ORDERS] wait", player_id, seconds)
	var pid := int(player_id)
	var p = PlayerMgr.players.get(pid, null)
	if p != null:
		p["wait_left"] = max(0.0, seconds)

func stop(player_id: String) -> void:
	print("[ORDERS] stop", player_id)
	var pid := int(player_id)
	var p = PlayerMgr.players.get(pid, null)
	if p != null and p.get("moving", false):
		p["loc"] = p.get("from", p.get("loc", ""))
		p["moving"] = false
		p.erase("from"); p.erase("to"); p.erase("eta_left"); p.erase("eta_total")
		p["progress"] = 0.0
		Commander.emit_signal("log", tr("[%s] stopped traveling.") % [p["name"]])

func process(delta: float) -> void:
	for p in PlayerMgr.players.values():
		if p.has("wait_left"):
			p["wait_left"] = max(0.0, p["wait_left"] - delta)
			if p["wait_left"] == 0.0:
				p.erase("wait_left")

