extends Node

var price := {}
var caravans := []
var tick_count := 0

func _ready():
	randomize()
	for loc in DB.locations.keys():
		price[loc] = {}
		for g in DB.goods_base_price.keys():
			price[loc][g] = DB.goods_base_price[g]

func tick():
	tick_count += 1
	if tick_count % 3 == 0:
	tick_economy()

func tick_economy():
	for loc in DB.locations.keys():
		var st = DB.locations[loc]["stock"]
		var dm = DB.locations[loc].get("demand", {})
		for g in DB.goods_base_price.keys():
			var base = DB.goods_base_price[g]
			var s = float(st.get(g, 0))
			var d = float(dm.get(g, 1.0))
			var factor = clamp(d * (1.5 - min(s, 100.0)/200.0), 0.5, 2.0)
			price[loc][g] = int(round(base * factor))

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
	Commander.emit_signal("log", "[%s] arrived at %s." % [p["name"], DB.get_loc_name(p["loc"])] )
