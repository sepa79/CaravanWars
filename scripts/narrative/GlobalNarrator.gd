extends Node

@onready var loop: Node = get_node_or_null("/root/LoopbackServer")
var _tick_timer: Timer = null  # (nieużywany — zostawiony tylko dla kompatybilności)

const CITY_PRESETS := {
	"HARBOR":          {"produce": {"LUX": 2},   "consume": {"FOOD": 2, "MEDS": 1, "TOOLS": 1}, "min_food": 5},
	"CENTRAL_KEEP":    {"produce": {"FOOD": 2},  "consume": {"FOOD": 6, "MEDS": 2, "TOOLS": 2}, "min_food": 8},
	"SOUTHERN_SHRINE": {"produce": {"MEDS": 4},  "consume": {"FOOD": 2},                         "min_food": 5},
	"FOREST_SPRING":   {"produce": {"FOOD": 3},  "consume": {"FOOD": 1},                         "min_food": 4},
	"MILLS":           {"produce": {"FOOD": 10}, "consume": {"TOOLS": 1, "FOOD": 1},             "min_food": 5},
	"FOREST_HAVEN":    {"produce": {"TOOLS": 2}, "consume": {"FOOD": 1},                         "min_food": 4},
	"MINE":            {"produce": {"ORE": 8},   "consume": {"FOOD": 3},                         "min_food": 5},
}

const MAYOR_SCRIPT_PATH := "res://scripts/narrative/MayorNarrator.gd"

func _srv() -> Variant:
	return get_node_or_null("/root/Server")

func _ready() -> void:
	if loop != null:
		loop.publish("system/ready", {"who": "GlobalNarrator"})
	else:
		push_warning("[GlobalNarrator] LoopbackServer not found at /root/LoopbackServer")

	_init_city_narrators()
	_register_endpoints()
	# Brak własnego timera — ekonomię napędza Sim przez econ_tick()
	var s = _srv()
	if s != null:
		s.call_deferred("broadcast_log", "[GlobalNarrator] ready; city narrators initialized: " + str(get_child_count()))

func _locations_as_array() -> Array:
	# DB.locations może być Dictionary (code->Location) albo Array
	var result: Array = []
	var locs_src: Variant = DB.locations

	if typeof(locs_src) == TYPE_DICTIONARY:
		var d: Dictionary = (locs_src as Dictionary)
		var keys: Array = d.keys()
		for i in keys.size():
			var k: Variant = keys[i]
			result.append(d[k])
	elif typeof(locs_src) == TYPE_ARRAY:
		result = (locs_src as Array)
	else:
		push_error("[GlobalNarrator] DB.locations has unexpected type")
	return result

func _init_city_narrators() -> void:
	var locs: Array = _locations_as_array()
	var mayor_script: Script = load(MAYOR_SCRIPT_PATH)
	if mayor_script == null:
		push_error("[GlobalNarrator] MayorNarrator script not found at %s" % MAYOR_SCRIPT_PATH)
		return

	for i in locs.size():
		var loc: Variant = locs[i]
		if loc == null:
			continue

		var code_val: Variant = loc.get("code")
		var stock_val: Variant = loc.get("stock")
		if typeof(code_val) == TYPE_NIL or typeof(stock_val) != TYPE_DICTIONARY:
			continue

		var code: String = String(code_val)

		var preset_any: Variant = CITY_PRESETS.get(code, {})
		var preset: Dictionary = (preset_any if typeof(preset_any) == TYPE_DICTIONARY else {}) as Dictionary
		var prod: Dictionary = (preset.get("produce", {}) as Dictionary)
		var cons: Dictionary = (preset.get("consume", {}) as Dictionary)
		var min_food: int = int(preset.get("min_food", 5))

		var n: Node = mayor_script.new()
		n.name = "MayorNarrator_%s" % code
		add_child(n)
		n.call("setup", code, loc, loop, prod, cons, min_food)

		print("[GlobalNarrator] attached MayorNarrator to ", code)

func _register_endpoints() -> void:
	if loop == null:
		return

	loop.register_endpoint("system.get_info", func (_args: Dictionary) -> Dictionary:
		return {
			"ok": true,
			"data": {
				"name": "CaravanWars",
				"component": "GlobalNarrator",
				"version": ProjectSettings.get_setting("application/config/version", "dev")
			}
		}
	)

	loop.register_endpoint("market.get_city_state", func (args: Dictionary) -> Dictionary:
		var code: String = String(args.get("city", ""))
		if code == "":
			return {"ok": false, "error": "bad_request"}

		var loc: Variant = _find_loc_by_code(code)
		if loc == null:
			return {"ok": false, "error": "city_not_found", "city": code}

		var stock: Dictionary = (loc.get("stock") as Dictionary)
		var resp: Dictionary = {"city": code, "stock": stock}

		var prices_val: Variant = loc.get("prices")
		if typeof(prices_val) == TYPE_DICTIONARY:
			resp["prices"] = (prices_val as Dictionary)
		elif loc.has_method("get_prices"):
			var p: Variant = loc.call("get_prices")
			if typeof(p) == TYPE_DICTIONARY:
				resp["prices"] = (p as Dictionary)

		return {"ok": true, "data": resp}
	)

func _find_loc_by_code(code: String) -> Variant:
	var locs: Array = _locations_as_array()
	for i in locs.size():
		var item: Variant = locs[i]
		if item != null:
			var c: Variant = item.get("code")
			if String(c) == code:
				return item
	return null

## Jedyny publiczny krok ekonomii — wołany przez Sim
func econ_tick() -> void:
	var any_changed: bool = false
	var s = _srv()
	if s != null:
		s.call_deferred("broadcast_log", "[GlobalNarrator] econ_tick begin (tick=" + str(Sim.tick_count) + ")")

	var kids: Array = get_children()
	for i in kids.size():
		var c: Variant = kids[i]
		if c != null and c.has_method("process_tick"):
			if bool(c.call("process_tick")):
				any_changed = true

	if any_changed:
		# Aktualizacja cen po zmianie stanów
		var basep: Variant = DB.goods_base_price
		var locs: Array = _locations_as_array()
		for i in locs.size():
			var loc: Variant = locs[i]
			if loc != null and loc.has_method("update_prices"):
				loc.update_prices(basep)
		if loop != null:
			loop.publish("market/updated", {})
		if s != null:
			s.call_deferred("broadcast_log", "[GlobalNarrator] econ_tick: markets updated")
	else:
		if s != null:
			s.call_deferred("broadcast_log", "[GlobalNarrator] econ_tick: no changes")

