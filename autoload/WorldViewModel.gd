extends Node

signal player_changed(player: Dictionary)
signal location_changed(location: Dictionary)

var player_descriptions := {
		1: "A brave merchant traveling the lands.",
		2: "A cunning trader with many secrets.",
		101: "A shrewd guild strategist controlling trade routes."
}

var player_ids: Array = []

var selected_player: int = -1
var selected_location: int = -1

func _ready() -> void:
		player_ids = PlayerMgr.order.duplicate()
		for id in PlayerMgr.players.keys():
				if id not in player_ids:
						player_ids.append(id)

func get_players() -> Array:
		var list: Array = []
		for id in player_ids:
				var p: Dictionary = PlayerMgr.players.get(id, {})
				if p.is_empty():
						continue
				var cargo := {}
				for g in p.get("cargo", {}).keys():
						cargo[g] = int(p["cargo"][g])
				list.append({
						"id": id,
						"name": p.get("name", ""),
						"info": tr(player_descriptions.get(id, "")),
						"gold": int(p.get("gold", 0)),
						"cargo": cargo
				})
		return list

func get_locations() -> Array:
		var list: Array = []
		var codes: Array = DB.locations.keys()
		codes.sort()
		for code in codes:
				var loc_obj = DB.get_loc(code)
				if loc_obj == null:
						continue
				var goods := {}
				for g in loc_obj.stock.keys():
						goods[DB.goods_names.get(g, str(g))] = {
								"qty": int(loc_obj.stock[g]),
								"price": int(loc_obj.prices.get(g, 0))
						}
				list.append({
						"code": code,
						"name": loc_obj.get_name(),
						"info": loc_obj.get_info(),
						"goods": goods
				})
		return list

func set_player(index: int) -> void:
		selected_player = index
		var data := {}
		if index >= 0 and index < player_ids.size():
				var id = player_ids[index]
				PlayerMgr.local_player_id = id
				var players = get_players()
				if index < players.size():
						data = players[index]
		player_changed.emit(data)

func set_location(index: int) -> void:
		selected_location = index
		var data := {}
		var locs = get_locations()
		if index >= 0 and index < locs.size():
				data = locs[index]
		location_changed.emit(data)

func get_selected_player() -> Dictionary:
		var players = get_players()
		if selected_player >= 0 and selected_player < players.size():
				return players[selected_player]
		return {}

func get_selected_location() -> Dictionary:
		var locs = get_locations()
		if selected_location >= 0 and selected_location < locs.size():
				return locs[selected_location]
		return {}

