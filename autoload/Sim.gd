extends Node

var caravans := []
var tick_count := 0

func _ready():
        randomize()
        for loc in DB.locations.values():
                loc.update_prices(DB.goods_base_price)

func tick():
	tick_count += 1
	if tick_count % 3 == 0:
		tick_economy()

func tick_economy():
        for loc in DB.locations.values():
                loc.update_prices(DB.goods_base_price)

func advance_players(delta: float) -> void:
	for id in PlayerMgr.order:
		var p = PlayerMgr.players[id]
		if not p.get("moving", false):
			continue
		p["eta_left"] = max(0.0, p.get("eta_left", 0.0) - delta)
		var total_eta = max(0.001, p.get("eta_total", 1.0))
		var traveled = p["eta_total"] - p["eta_left"]
		p["progress"] = clamp(traveled / total_eta, 0.0, 1.0)
		if p["eta_left"] <= 0.0:
			p["moving"] = false
			p["loc"] = p["to"]
			p.erase("from"); p.erase("to")
			p["progress"] = 0.0
			Commander.emit_signal("log", tr("[%s] arrived at %s.") % [p["name"], DB.get_loc_name(p["loc"])])
