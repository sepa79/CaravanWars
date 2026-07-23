extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MOVE_PARTY_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/MovePartyCommand.gd")
const TRANSFER_GOODS_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TransferGoodsCommand.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_withdraw_goods_from_current_location()
    _test_deposit_goods_to_current_location()
    _test_transfer_rejects_different_node_location()
    _test_transfer_rejects_unknown_goods()
    _test_transfer_rejects_insufficient_location_goods()
    _test_transfer_rejects_insufficient_party_goods()
    _test_transfer_rejects_over_capacity_withdraw()
    _test_transfer_rejects_traveling_party()

    if not _failed:
        print("[TransferGoodsCommandTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Transfer goods command test failed.")
    return _is_finished


func _test_withdraw_goods_from_current_location() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    var location: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)

    var result: RefCounted = server.submit_transfer_goods(_create_transfer_command(
        party.party_id,
        location.location_id,
        "food",
        3,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    ))

    _expect(result.accepted, "Expected withdraw transfer to be accepted.")
    _expect(int(location.resources.get("food", 0)) == 117, "Expected location food to decrease.")
    _expect(int(party.cargo.get("food", 0)) == 15, "Expected party food cargo to increase.")
    _expect(_event_types(server).has("goods_transferred"), "Expected goods transfer event.")


func _test_deposit_goods_to_current_location() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    var location: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)

    var result: RefCounted = server.submit_transfer_goods(_create_transfer_command(
        party.party_id,
        location.location_id,
        "food",
        5,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_DEPOSIT_TO_LOCATION
    ))

    _expect(result.accepted, "Expected deposit transfer to be accepted.")
    _expect(int(location.resources.get("food", 0)) == 125, "Expected location food to increase.")
    _expect(int(party.cargo.get("food", 0)) == 7, "Expected party food cargo to decrease.")


func _test_transfer_rejects_different_node_location() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_transfer_goods(_create_transfer_command(
        GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID,
        GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID,
        "food",
        1,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    ))

    _expect(not result.accepted, "Expected transfer at different node to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_LOCATION_MISMATCH, "Expected location_mismatch error.")


func _test_transfer_rejects_unknown_goods() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_transfer_goods(_create_transfer_command(
        GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        "missing_goods",
        1,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    ))

    _expect(not result.accepted, "Expected unknown goods to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_GOODS_NOT_FOUND, "Expected goods_not_found error.")


func _test_transfer_rejects_insufficient_location_goods() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_transfer_goods(_create_transfer_command(
        GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        "food",
        999,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    ))

    _expect(not result.accepted, "Expected insufficient location goods to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_INSUFFICIENT_LOCATION_GOODS, "Expected insufficient_location_goods error.")


func _test_transfer_rejects_insufficient_party_goods() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_transfer_goods(_create_transfer_command(
        GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        "food",
        999,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_DEPOSIT_TO_LOCATION
    ))

    _expect(not result.accepted, "Expected insufficient party goods to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_INSUFFICIENT_PARTY_GOODS, "Expected insufficient_party_goods error.")


func _test_transfer_rejects_over_capacity_withdraw() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var location: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    location.resources["food"] = 1000

    var result: RefCounted = server.submit_transfer_goods(_create_transfer_command(
        GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        "food",
        100,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    ))

    _expect(not result.accepted, "Expected over-capacity withdraw to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_CARGO_CAPACITY_EXCEEDED, "Expected cargo_capacity_exceeded error.")


func _test_transfer_rejects_traveling_party() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var move_command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    move_command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    move_command.from_node_id = "wroclaw"
    move_command.to_node_id = "opole"
    var move_result: RefCounted = server.submit_move_party(move_command)
    _expect(move_result.accepted, "Expected setup move to be accepted.")

    var transfer_result: RefCounted = server.submit_transfer_goods(_create_transfer_command(
        GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        "food",
        1,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_DEPOSIT_TO_LOCATION
    ))

    _expect(not transfer_result.accepted, "Expected traveling party transfer to be rejected.")
    _expect(transfer_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_PARTY_BUSY, "Expected party_busy error.")


func _create_transfer_command(party_id: String, location_id: String, goods_id: String, amount: int, direction: String) -> RefCounted:
    var command: RefCounted = TRANSFER_GOODS_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.location_id = location_id
    command.goods_id = goods_id
    command.amount = amount
    command.direction = direction
    return command


func _event_types(server: RefCounted) -> Array[String]:
    var event_types: Array[String] = []
    for event_dictionary: Dictionary in server.get_recent_events(20):
        event_types.append(str(event_dictionary.get("event_type", "")))
    return event_types


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
