extends Node
signal log(msg:String)
var server_url: String = ""
var auth_token: String = ""

func configure(url:String, token:String=""):
	server_url = url
	auth_token = token
	emit_signal("log", tr("[Net] configured: {url}").format({"url": url}))

func request_assistant_move(player_id:int):
	var aibr = get_node_or_null("/root/AiBridge")
	if aibr:
		aibr.suggest_for_player(player_id)
