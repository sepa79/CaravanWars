extends Node

signal player_changed(player: Dictionary)
signal location_changed(location: Dictionary)

var player_descriptions := {
        1: "A brave merchant traveling the lands.",
        2: "A cunning trader with many secrets.",
        101: "A shrewd guild strategist controlling trade routes."
}

var location_defs := [
        {"code": "CENTRAL_KEEP", "info": "The heart of the realm and a bustling town."},
        {"code": "HARBOR", "info": "Ships from afar visit this busy port."},
        {"code": "SOUTHERN_SHRINE", "info": "A tranquil shrine in the south."},
        {"code": "FOREST_SPRING", "info": "A spring hidden deep within the forest."},
        {"code": "MILLS", "info": "Windmills that grind grain for the region."},
        {"code": "FOREST_HAVEN", "info": "A safe haven amid towering trees."},
        {"code": "MINE", "info": "Rich veins of ore run through these tunnels."}
]

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
        for def in location_defs:
                var code: String = def["code"]
                var loc: Dictionary = DB.locations.get(code, {})
                var goods := {}
                var stock: Dictionary = loc.get("stock", {})
                for g in stock.keys():
                        var qty: int = stock[g]
                        var base: int = DB.goods_base_price.get(g, 0)
                        var demand: float = loc.get("demand", {}).get(g, 1.0)
                        goods[DB.goods_names.get(g, str(g))] = {
                                "qty": int(qty),
                                "price": int(round(base * demand))
                        }
                list.append({
                        "code": code,
                        "name": DB.get_loc_name(code),
                        "info": tr(def.get("info", "")),
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

