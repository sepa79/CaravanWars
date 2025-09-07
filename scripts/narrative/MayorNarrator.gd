extends Node

const Logger = preload("res://scripts/Logger.gd")
# Jeden narrator per miasto (produkcja/popyt + kara za brak FOOD)

var code: String = ""
var min_food: int = 5
var produce: Dictionary = {}   # { String -> int }
var consume: Dictionary = {}   # { String -> int }

var _loc: Variant = null       # obiekt Location (z DB)
var _loop: Variant = null      # /root/LoopbackServer

func setup(p_code: String, p_loc: Variant, p_loop: Variant, p_prod: Dictionary, p_cons: Dictionary, p_min_food: int = 5) -> void:
    code = p_code
    _loc = p_loc
    _loop = p_loop
    produce = (p_prod.duplicate() as Dictionary)
    consume = (p_cons.duplicate() as Dictionary)
    min_food = p_min_food
    Logger.log("MayorNarrator", "setup city=" + code + ", min_food=" + str(min_food) + ", produce=" + str(produce) + ", consume=" + str(consume))

func _food_amount() -> int:
    # Korzystaj z metod Location, aby unikać niespójności kluczy (int vs string)
    if _loc != null and _loc.has_method("get_stock"):
        return int(_loc.call("get_stock", "FOOD"))
    var stock: Dictionary = (_loc.get("stock") as Dictionary)
    # Fallback: spróbuj po int id (FOOD=0)
    return int(stock.get(0, stock.get("FOOD", 0)))

func _good_id_from_string(code: String) -> int:
    var s_up := code.to_upper()
    match s_up:
        "FOOD": return int(DB.Good.FOOD)
        "MEDS": return int(DB.Good.MEDS)
        "ORE": return int(DB.Good.ORE)
        "TOOLS": return int(DB.Good.TOOLS)
        "LUX": return int(DB.Good.LUX)
    # Spróbuj dopasować po DB.goods_names
    for id in DB.goods_names.keys():
        var name_low: String = str(DB.goods_names.get(id, ""))
        if s_up == name_low.to_upper():
            return int(id)
    return -1

func _apply_shortage_multiplier(base_amount: int) -> int:
    var f: int = _food_amount()
    if f <= 0:
        return int(floor(base_amount * 0.25))
    elif f < min_food:
        return int(floor(base_amount * 0.5))
    return base_amount

func process_tick() -> bool:
    if _loc == null:
        return false

    var changed: bool = false
    var stock: Dictionary = (_loc.get("stock") as Dictionary)
    var before := stock.duplicate(true)

    # Konsumpcja
    var cons_keys: Array = consume.keys()
    for key in cons_keys:
        var g: String = str(key)
        var need: int = int(consume[g])
        if need > 0:
            # Odczyt ilości przez Location, aby uwzględnić różne formaty kluczy
            var have: int = int(_loc.call("get_stock", g)) if _loc != null and _loc.has_method("get_stock") else int(stock.get(g, 0))
            var used: int = (have if have < need else need)
            if used > 0:
                var gid := _good_id_from_string(g)
                if gid != -1:
                    stock[gid] = max(0, have - used)
                    # Usuń ewentualny duplikat stringowy, by ujednolicić strukturę
                    if stock.has(g):
                        stock.erase(g)
                else:
                    # Brak znanego id — aktualizuj pod oryginalnym kluczem
                    stock[g] = max(0, have - used)
                changed = true
                Logger.log("MayorNarrator", "[" + code + "] consume " + g + " used=" + str(used) + " (have=" + str(have) + ", need=" + str(need) + ")")

    # Produkcja (z karą poza FOOD)
    var prod_keys: Array = produce.keys()
    for key in prod_keys:
        var g2: String = str(key)
        var amt: int = int(produce[g2])
        if amt > 0:
            if g2 != "FOOD":
                amt = _apply_shortage_multiplier(amt)
            var cur: int = int(_loc.call("get_stock", g2)) if _loc != null and _loc.has_method("get_stock") else int(stock.get(g2, 0))
            var gid2 := _good_id_from_string(g2)
            if gid2 != -1:
                stock[gid2] = cur + amt
                if stock.has(g2):
                    stock.erase(g2)
            else:
                stock[g2] = cur + amt
            changed = true
            Logger.log("MayorNarrator", "[" + code + "] produce " + g2 + " amount=" + str(amt) + " (cur=" + str(cur) + ")")

    if changed and _loop != null:
        var payload: Dictionary = {"city": code, "stock": stock.duplicate()}
        _loop.publish("market/stock_changed", payload)
        _loop.publish("market/stock_changed/%s" % code, payload)
        Logger.log("MayorNarrator", "[" + code + "] stock changed: before=" + str(before) + " after=" + str(stock))

    return changed
