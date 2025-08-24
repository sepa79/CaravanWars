extends Node
signal log(msg:String)

func suggest_for_player(player_id:int):
	var p = PlayerMgr.players[player_id]
	var loc = p["loc"]
	var best_txt := ""
	var best_profit := -99999
	for to in DB.locations.keys():
		if to == loc: continue
		for g in DB.goods_base_price.keys():
			var buy = Sim.price[loc].get(g, 9999)
			var sell = Sim.price[to].get(g, 0)
			var pr = sell - buy
			if pr > best_profit:
				best_profit = pr
				best_txt = "Buy %s at %s (%d) and sell at %s (%d). Profit %d." % [
					DB.goods_names[g], loc, buy, to, sell, pr]
	if best_txt != "":
		emit_signal("log", "[Assistant] " + best_txt)
