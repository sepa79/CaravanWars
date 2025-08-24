extends Node
signal log(msg: String)

func cmd_move(arg: String) -> void:
	var code: String
	if arg.strip_edges() != "":
		code = arg.strip_edges().to_upper()
	else:
		code = "HARBOR"

	if not DB.positions.has(code):
		emit_signal("log", "[color=red]Unknown code:[/color] " + code)
		return

	var pid = PlayerMgr.local_player_id
	if PlayerMgr.start_travel(pid, code):
		emit_signal("log", "Moving to " + DB.get_loc_name(code))

func cmd_price(arg: String) -> void:
	var code: String = arg.strip_edges().to_upper()
	if not DB.locations.has(code):
		emit_signal("log", "[color=red]Unknown market code:[/color] " + code)
		return

	var loc = DB.locations[code]
	emit_signal("log", "Prices at " + DB.get_loc_name(code))
	# TODO: wypisz konkretne ceny
