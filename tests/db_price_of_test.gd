@tool
extends SceneTree

const LOCATION := preload("../scripts/models/Location.gd")
const DB_SCRIPT := preload("../autoload/DB.gd")

class PlayerMgrStub:
    var local_player_id: int = 0
    var players: Dictionary = {}

class DBStub:
    var goods_names: Dictionary = {}
    class Good:
        const FOOD := 0
        const MEDS := 1

var PlayerMgr := PlayerMgrStub.new()
var DB: Variant = DBStub.new()

func _init() -> void:
    test_price_of()
    print("All tests passed")
    quit()

func test_price_of() -> void:
    DB = DB_SCRIPT.new()
    DB.goods_base_price = {
        DB.Good.FOOD: 10,
        DB.Good.MEDS: 16,
    }

    var loc_high := LOCATION.new("HIGH", "", "", Vector2.ZERO, {}, {DB.Good.FOOD: 1.5})
    loc_high.update_prices(DB.goods_base_price)

    var loc_low := LOCATION.new("LOW", "", "", Vector2.ZERO, {}, {DB.Good.MEDS: 0.5})
    loc_low.update_prices(DB.goods_base_price)

    var loc_none := LOCATION.new("NONE", "", "", Vector2.ZERO, {}, {})
    loc_none.update_prices(DB.goods_base_price)

    DB.locations = {
        "HIGH": loc_high,
        "LOW": loc_low,
        "NONE": loc_none,
    }

    var base_food: int = DB.goods_base_price[DB.Good.FOOD]
    var expected_high_food: int = base_food + int(round(base_food * (1.5 - 1.0)))
    assert(DB.price_of("HIGH", DB.Good.FOOD) == expected_high_food)

    var base_meds: int = DB.goods_base_price[DB.Good.MEDS]
    var expected_low_meds: int = base_meds + int(round(base_meds * (0.5 - 1.0)))
    assert(DB.price_of("LOW", DB.Good.MEDS) == expected_low_meds)

    assert(DB.price_of("HIGH", DB.Good.MEDS) == base_meds)
    assert(DB.price_of("NONE", DB.Good.MEDS) == base_meds)

    assert(DB.price_of("HIGH", "UNKNOWN") == 0)
