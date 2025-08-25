extends Node
signal log(msg: String)

func cmd_move(arg: String) -> void:
	var code: String
	if arg.strip_edges() != "":
		code = arg.strip_edges().to_upper()
	else:
		code = "HARBOR"

	if LocationsDB.get(code) == null:
		emit_signal("log", "[color=red]Unknown code:[/color] " + code)
		return

	var pid = PlayerMgr.local_player_id
	if PlayerMgr.start_travel(pid, code):
		var loc := LocationsDB.get(code)
		emit_signal("log", "Moving to " + loc.displayName)

func cmd_price(arg: String) -> void:
	var code: String = arg.strip_edges().to_upper()
	if LocationsDB.get(code) == null or not DB.locations.has(code):
		emit_signal("log", "[color=red]Unknown market code:[/color] " + code)
		return

	var loc_obj := LocationsDB.get(code)
	emit_signal("log", "Prices at " + loc_obj.displayName)
	# TODO: wypisz konkretne ceny
