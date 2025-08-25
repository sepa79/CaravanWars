extends Node
signal log(msg: String)

func cmd_move(arg: String) -> void:
	var code: String
	if arg.strip_edges() != "":
		code = arg.strip_edges().to_upper()
	else:
		code = "HARBOR"

		if DB.get_loc(code) == null:
				emit_signal("log", "[color=red]Unknown code:[/color] " + code)
				return

	var pid = PlayerMgr.local_player_id
	if PlayerMgr.start_travel(pid, code):
		emit_signal("log", "Moving to " + DB.get_loc_name(code))

func cmd_price(arg: String) -> void:
	var code: String = arg.strip_edges().to_upper()
		var loc = DB.get_loc(code)
		if loc == null:
				emit_signal("log", "[color=red]Unknown market code:[/color] " + code)
				return
		emit_signal("log", "Prices at " + DB.get_loc_name(code))
	# TODO: wypisz konkretne ceny

func buy(pid:int, good:int, amount:int) -> bool:
	var p = PlayerMgr.players.get(pid, null)
	if p == null or p.get("moving", false):
		return false
		var loc:String = p.get("loc", "")
		var market = DB.get_loc(loc)
		if market == null:
				return false
		var stock:Dictionary = market.stock
	var available:int = stock.get(good, 0)
	if available < amount:
		emit_signal("log", tr("[color=red]Not enough goods in stock.[/color]"))
		return false
		var price:int = market.prices.get(good, 0)
	var cost:int = price * amount
	if p.get("gold", 0) < cost:
		emit_signal("log", tr("[color=red]Not enough gold.[/color]"))
		return false
	if PlayerMgr.cargo_free(pid) < amount:
		emit_signal("log", tr("[color=red]Not enough cargo space.[/color]"))
		return false
	p["gold"] -= cost
	p["cargo"][good] = p["cargo"].get(good, 0) + amount
	stock[good] = available - amount
	emit_signal("log", tr("[%s] bought %d %s for %d.") % [p["name"], amount, tr(DB.goods_names[good]), cost])
	return true

func sell(pid:int, good:int, amount:int) -> bool:
	var p = PlayerMgr.players.get(pid, null)
	if p == null or p.get("moving", false):
		return false
	var cargo:Dictionary = p.get("cargo", {})
	var have:int = cargo.get(good, 0)
	if have < amount:
		emit_signal("log", tr("[color=red]Not enough goods to sell.[/color]"))
		return false
		var loc:String = p.get("loc", "")
		var market = DB.get_loc(loc)
		if market == null:
				return false
		var price:int = market.prices.get(good, 0)
		var revenue:int = price * amount
	p["gold"] += revenue
	cargo[good] = have - amount
	if cargo[good] <= 0:
		cargo.erase(good)
		var stock:Dictionary = market.stock
	stock[good] = stock.get(good, 0) + amount
	emit_signal("log", tr("[%s] sold %d %s for %d.") % [p["name"], amount, tr(DB.goods_names[good]), revenue])
	return true
