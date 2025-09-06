extends Node

const Logger = preload("res://scripts/Logger.gd")

enum Kind { HUMAN, AI, NARRATOR }

var players := {}
var order := []
var local_player_id : int = 1

func _ready():
    add_player(1, "Player A", Kind.HUMAN, "CENTRAL_KEEP")
    add_player(2, "Guild AI", Kind.AI, "MINE")
    order = [1,2]

func add_player(id:int, name:String, kind:int, start_loc:String):
    players[id] = {
        "name":name, "kind":kind, "loc":start_loc, "gold":150,
        "units":["hand_cart"],
        "cargo":{},
        "moving":false, "progress":0.0
    }

func is_moving(id:int) -> bool:
    var p = players.get(id, null)
    return p != null and p.get("moving", false)

func calc_speed(id:int) -> float:
    var p = players[id]
    var defs = DB.unit_defs
    var sp := 9999.0
    for u in p["units"]:
        var d = defs.get(u, null)
        if d == null: continue
        sp = min(sp, float(d.get("speed", 1.0)))
    if sp == 9999.0: sp = 1.0
    return sp

func capacity_total(id:int) -> int:
    var p = players[id]
    var defs = DB.unit_defs
    var cap := 0
    for u in p["units"]:
        var d = defs.get(u, null)
        if d == null: continue
        cap += int(d.get("capacity", 0))
    return cap

func cargo_used(id:int) -> int:
    var p = players[id]
    var used := 0
    for g in p["cargo"].keys():
        used += int(p["cargo"][g])
    return used

func cargo_free(id:int) -> int:
    return max(0, capacity_total(id) - cargo_used(id))

func cargo_amount(id:int, good:int) -> int:
    var p = players.get(id, {})
    return int(p.get("cargo", {}).get(good, 0))

func cargo_add(id:int, good:int, qty:int) -> void:
    if qty <= 0:
        return
    var p = players.get(id, {})
    var c: Dictionary = p.get("cargo", {})
    c[good] = int(c.get(good, 0)) + qty
    p["cargo"] = c

func cargo_remove(id:int, good:int, qty:int) -> void:
        if qty <= 0:
                return
        var p = players.get(id, {})
        var c: Dictionary = p.get("cargo", {})
        var have := int(c.get(good, 0))
        var left = int(max(0, have - qty))
        if left > 0:
                c[good] = left
        else:
                if c.has(good):
                        c.erase(good)
        p["cargo"] = c

func food_rate(id: int) -> int:
        var p: Dictionary = players.get(id, {})
        var defs: Dictionary = DB.unit_defs
        var total: int = 0
        for u in p.get("units", []):
                var d: Dictionary = defs.get(u, {})
                if d.is_empty():
                        continue
                total += int(d.get("upkeep_food", 0))
        return total

func start_travel(id:int, to_loc:String) -> bool:
        var p = players[id]
        if p.get("moving", false): return false
        var from_loc = p["loc"]
        if from_loc == to_loc: return false
        var key = "%s->%s" % [from_loc, to_loc]
        if not DB.routes.has(key): return false
        var base_ticks = int(DB.routes[key]["ticks"]) * 5
        var speed = max(0.1, calc_speed(id))
        var eta = float(base_ticks) / speed
        p["moving"] = true
        p["from"] = from_loc
        p["to"] = to_loc
        p["eta_left"] = eta
        p["eta_total"] = eta
        p["progress"] = 0.0
        Logger.log("PlayerMgr", tr("[%s] traveling %s -> %s (ETA %.1f).") % [p["name"], DB.get_loc_name(from_loc), DB.get_loc_name(to_loc), eta])
        return true
