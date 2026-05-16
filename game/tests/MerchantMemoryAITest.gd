extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MERCHANT_MEMORY_AI_SCRIPT: GDScript = preload("res://simulation/managers/MerchantMemoryAI.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_merchant_uses_memory_to_withdraw_and_travel()
    _test_merchant_deposits_when_at_remembered_need()
    _test_merchant_does_nothing_without_need_memory()

    if not _failed:
        print("[MerchantMemoryAITest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Merchant memory AI test failed.")
    return _is_finished


func _test_merchant_uses_memory_to_withdraw_and_travel() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var merchant: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    var opole: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID)
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    var ai: RefCounted = MERCHANT_MEMORY_AI_SCRIPT.new()

    merchant.cargo.clear()
    opole.resources["food"] = 140
    wroclaw.resources["food"] = 0

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID, _merchant_memory_entries())

    _expect(bool(result.get("accepted", false)), "Expected memory AI action to be accepted.")
    _expect(result.get("action", "") == "withdraw_and_travel_to_remembered_need", "Expected merchant to act from remembered need.")
    _expect(merchant.travel_state == "traveling", "Expected merchant to start travel.")
    _expect(merchant.destination_node_id == "wroclaw", "Expected merchant to travel to remembered Wroclaw need.")
    _expect(int(merchant.cargo.get("food", 0)) == 10, "Expected merchant to withdraw remembered food amount.")
    _expect(int(opole.resources.get("food", 0)) == 130, "Expected Opole food to decrease through command.")


func _test_merchant_deposits_when_at_remembered_need() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var merchant: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    var ai: RefCounted = MERCHANT_MEMORY_AI_SCRIPT.new()

    merchant.current_node_id = "wroclaw"
    merchant.cargo.clear()
    merchant.cargo["food"] = 10
    wroclaw.resources["food"] = 0

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID, _merchant_memory_entries())

    _expect(bool(result.get("accepted", false)), "Expected deposit action to be accepted.")
    _expect(result.get("action", "") == "deposit_to_remembered_need", "Expected merchant to deposit at remembered need.")
    _expect(int(merchant.cargo.get("food", 0)) == 0, "Expected merchant food cargo to be deposited.")
    _expect(int(wroclaw.resources.get("food", 0)) == 10, "Expected Wroclaw food to increase through command.")


func _test_merchant_does_nothing_without_need_memory() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var merchant: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    var ai: RefCounted = MERCHANT_MEMORY_AI_SCRIPT.new()

    merchant.cargo.clear()
    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID, [_opole_observation_memory()])

    _expect(bool(result.get("accepted", false)), "Expected no-action result to be accepted.")
    _expect(result.get("action", "") == "none", "Expected no action without need memory.")
    _expect(result.get("reason", "") == "no_food_need_memory", "Expected no need memory reason.")


func _merchant_memory_entries() -> Array[Dictionary]:
    return [
        _opole_observation_memory(),
        {
            "id": "mem_merchant_need_wroclaw",
            "kind": "need_ledger",
            "metadata": {
                "location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
                "node_id": "wroclaw",
                "goods_id": "food",
                "needed_amount": 75,
                "reason": "food_below_floor"
            }
        }
    ]


func _opole_observation_memory() -> Dictionary:
    return {
        "id": "mem_merchant_observed_opole",
        "kind": "location_observation",
        "metadata": {
            "owner_id": GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
            "node_id": "opole",
            "observed_location_id": GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID,
            "observed_resources": {
                "food": 140
            }
        }
    }


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
