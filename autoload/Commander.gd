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
	Orders.move(str(pid), code)
	emit_signal("log", "Moving to " + DB.get_loc_name(code))

func cmd_price(player_id: int, loc_code: String) -> void:
	var loc := DB.get_loc(loc_code)
	if loc == null:
		emit_signal("log", "[price] Unknown location: %s" % loc_code)
		return

	var header := "Prices @ %s" % (loc.name if "name" in loc else loc_code)
	emit_signal("log", header)
	emit_signal("log", "Good        | Price | Stock")
	emit_signal("log", "------------+-------+------")

	for g in DB.goods_base_price.keys():
		var name_str := ""
		if DB.goods_names.has(g):
			# if you want translations, use: name_str = tr(DB.goods_names[g])
			name_str = str(DB.goods_names[g])
		else:
			name_str = "GOOD_%d" % int(g)

		var price := int(loc.prices.get(g, 0))
		var stock := int(loc.stock.get(g, 0))
		var short_name := name_str.substr(0, 11)
		emit_signal("log", "%-11s | %5d | %5d" % [short_name, price, stock])

func buy(pid:int, good:int, amount:int) -> void:
	var loc: String = PlayerMgr.players.get(pid, {}).get("loc", "")
	Orders.trade(str(pid), "buy", str(good), amount, loc)

func sell(pid:int, good:int, amount:int) -> void:
	var loc: String = PlayerMgr.players.get(pid, {}).get("loc", "")
	Orders.trade(str(pid), "sell", str(good), amount, loc)

