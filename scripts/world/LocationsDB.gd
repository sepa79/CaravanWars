extends Node

const Location = preload("res://scripts/world/Location.gd")

var _locations: Dictionary = {}

func register(loc: Location) -> void:
	if loc != null and loc.id != StringName():
		_locations[loc.id] = loc

@warning_ignore("native_method_override")
func get(id: StringName) -> Location:
	return _locations.get(id, null)

func all() -> Array:
	return _locations.values()

func _ready() -> void:
	_init_locations()

func _init_locations() -> void:
	var defs = [
		{"id": StringName("HARBOR"), "name": "Harbor", "desc": "Ships from afar visit this busy port.", "pos": Vector2i(1060, 840), "neighbors": [StringName("CENTRAL_KEEP")]},
		{"id": StringName("CENTRAL_KEEP"), "name": "Central Keep", "desc": "The heart of the realm and a bustling town.", "pos": Vector2i(910, 750), "neighbors": [StringName("HARBOR"), StringName("FOREST_SPRING"), StringName("SOUTHERN_SHRINE")]},
		{"id": StringName("SOUTHERN_SHRINE"), "name": "Southern Shrine", "desc": "A tranquil shrine in the south.", "pos": Vector2i(350, 840), "neighbors": [StringName("CENTRAL_KEEP")]},
		{"id": StringName("FOREST_SPRING"), "name": "Forest Spring", "desc": "A spring hidden deep within the forest.", "pos": Vector2i(690, 560), "neighbors": [StringName("CENTRAL_KEEP"), StringName("FOREST_HAVEN"), StringName("MINE")]},
		{"id": StringName("MILLS"), "name": "Mills", "desc": "Windmills that grind grain for the region.", "pos": Vector2i(1010, 185), "neighbors": [StringName("FOREST_HAVEN")]},
		{"id": StringName("FOREST_HAVEN"), "name": "Forest Haven", "desc": "A safe haven amid towering trees.", "pos": Vector2i(890, 360), "neighbors": [StringName("FOREST_SPRING"), StringName("MILLS")]},
		{"id": StringName("MINE"), "name": "Mine", "desc": "Rich veins of ore run through these tunnels.", "pos": Vector2i(440, 340), "neighbors": [StringName("FOREST_SPRING")]}
	]
	for d in defs:
		var loc := Location.new()
		loc.id = d["id"]
		loc.displayName = d["name"]
		loc.description = d["desc"]
		loc.mapPos = d["pos"]
		loc.neighbors.assign(d["neighbors"])
		register(loc)
