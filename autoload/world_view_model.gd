extends Node

signal player_changed(player: Dictionary)
signal location_changed(location: Dictionary)

var players := [
	{"name": "Player A", "info": "A brave merchant traveling the lands."},
	{"name": "Player B", "info": "A cunning trader with many secrets."}
]

var locations := [
	{"name": "Central Keep", "info": "The heart of the realm and a bustling town."},
	{"name": "Harbor", "info": "Ships from afar visit this busy port."}
]

var selected_player: int = -1
var selected_location: int = -1

func get_players() -> Array:
	return players

func get_locations() -> Array:
	return locations

func set_player(index: int) -> void:
	selected_player = index
	var data := {}
	if index >= 0 and index < players.size():
		data = players[index]
	emit_signal("player_changed", data)

func set_location(index: int) -> void:
	selected_location = index
	var data := {}
	if index >= 0 and index < locations.size():
		data = locations[index]
	emit_signal("location_changed", data)

func get_selected_player() -> Dictionary:
	if selected_player >= 0 and selected_player < players.size():
		return players[selected_player]
	return {}

func get_selected_location() -> Dictionary:
	if selected_location >= 0 and selected_location < locations.size():
		return locations[selected_location]
	return {}
