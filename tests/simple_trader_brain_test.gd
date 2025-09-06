@tool
extends SceneTree

const BRAIN := preload("res://scripts/brains/SimpleTraderBrain.gd")

func _init() -> void:
    test_create_convoy()
    test_buy_and_plan()
    test_sell_then_replan()
    print("All tests passed")
    quit()

func test_create_convoy() -> void:
    var brain := BRAIN.new()
    var obs := {
        "self_id": 1,
        "entities": [],
        "markets": {}
    }
    var cmds := brain.think(obs)
    assert(cmds.size() == 1)
    assert(cmds[0]["type"] == "CreateConvoy")

func test_buy_and_plan() -> void:
    var brain := BRAIN.new()
    var obs := {
        "self_id": 1,
        "entities": [
            {"id": 1, "type": "convoy", "owner": 1, "pos": "MILLS", "path": [], "goods": {}}
        ],
        "markets": {
            "PORT": {"salt": {"price": 12}},
            "MILLS": {"salt": {"price": 8}}
        }
    }
    var cmds := brain.think(obs)
    assert(cmds.size() == 2)
    assert(cmds[0]["type"] == "LoadGoods")
    assert(cmds[0]["payload"]["goods"]["salt"] == 10)
    assert(cmds[1]["type"] == "PlanRoute")
    assert(cmds[1]["payload"]["path"][0] == "PORT")

func test_sell_then_replan() -> void:
    var brain := BRAIN.new()
    var obs := {
        "self_id": 1,
        "entities": [
            {"id": 1, "type": "convoy", "owner": 1, "pos": "PORT", "path": [], "goods": {"salt": 10}}
        ],
        "markets": {
            "PORT": {"salt": {"price": 12}, "wine": {"price": 5}},
            "MILLS": {"salt": {"price": 8}, "wine": {"price": 15}}
        }
    }
    var cmds := brain.think(obs)
    assert(cmds.size() == 3)
    assert(cmds[0]["type"] == "LoadGoods")
    assert(cmds[0]["payload"]["goods"].is_empty())
    assert(cmds[1]["type"] == "LoadGoods")
    assert(cmds[1]["payload"]["goods"]["wine"] == 10)
    assert(cmds[2]["type"] == "PlanRoute")
    assert(cmds[2]["payload"]["path"][0] == "MILLS")
