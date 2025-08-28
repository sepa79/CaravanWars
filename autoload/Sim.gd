extends Node

signal player_arrived(player_id: int, location_id: String)

var caravans := []
var tick_count := 0

# Co ile ticków logiki wykonywać krok ekonomii (przez GlobalNarrator)
@export var econ_every_n_ticks: int = 2

func _is_server() -> bool:
	return get_tree() != null and get_tree().get_multiplayer().is_server()

func _ready():
	randomize()
	# Początkowe przeliczenie cen na starcie
	for loc in DB.locations.values():
		loc.update_prices(DB.goods_base_price)

# GŁÓWNY TICK SYMULACJI — jedyny zegar gry
func tick():
	if not _is_server():
		return
	tick_count += 1

	# Ekonomia napędzana wyłącznie przez Sim: co N ticków
	if econ_every_n_ticks > 0 and (tick_count % econ_every_n_ticks) == 0:
		_tick_economy()

# Delegat ekonomii do GlobalNarrator (bez własnych timerów)
func _tick_economy() -> void:
	var gn := get_node_or_null("/root/GlobalNarrator")
	if gn != null and gn.has_method("econ_tick"):
		gn.econ_tick()
	else:
		# Fallback (awaryjnie): tylko przelicz ceny, jeśli Narratora nie ma
		for loc in DB.locations.values():
			if loc != null and loc.has_method("update_prices"):
				loc.update_prices(DB.goods_base_price)

func advance_players(delta: float) -> void:
	if not _is_server():
		return
	var srv = get_node_or_null("/root/Server")
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
			if srv != null:
				srv.call_deferred("broadcast_log", tr("Arrived %s at %s.") % [p.get("name", ""), DB.get_loc_name(p.get("loc", ""))])
			# Notify listeners about player arrival (UI may react as needed)
			emit_signal("player_arrived", int(id), str(p.get("loc", "")))
	Orders.process(delta)
