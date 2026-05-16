extends MainLoop

const ACTOR_TASK_STATE_SCRIPT: GDScript = preload("res://simulation/ActorTaskState.gd")
const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const SIMULATION_SAVE_CODEC_SCRIPT: GDScript = preload("res://simulation/SimulationSaveCodec.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_actor_task_lifecycle()
    _test_party_tracks_actor_task_busy_rules()
    _test_save_load_preserves_actor_tasks()
    _test_load_rejects_bad_actor_task_references()

    if not _failed:
        print("[ActorTaskStateTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Actor task state test failed.")
    return _is_finished


func _test_actor_task_lifecycle() -> void:
    var task: RefCounted = ACTOR_TASK_STATE_SCRIPT.new()
    _expect(task.is_idle(), "Expected new actor task to be idle.")

    task.start_ask_local_information("companion_01", "player_party", "wroclaw_city", "goods_source", "food", 0.5, 2.0, "player_caravan_leader", false)
    _expect(not task.is_idle(), "Expected started actor task to be active.")
    _expect(task.actor_id == "companion_01", "Expected actor id to be set.")
    _expect(task.party_id == "player_party", "Expected party id to be set.")
    _expect(task.started_day == 2.0, "Expected started day to be set.")

    task.tick(0.25)
    _expect(is_equal_approx(task.remaining_days, 0.25), "Expected actor task to tick down.")
    task.tick(1.0)
    _expect(is_equal_approx(task.remaining_days, 0.0), "Expected actor task remaining days to clamp at zero.")

    task.mark_completed()
    _expect(task.is_idle(), "Expected completed actor task to be idle for scheduling.")

    var restored_task: RefCounted = ACTOR_TASK_STATE_SCRIPT.from_dictionary(task.to_dictionary())
    _expect(restored_task.actor_id == task.actor_id, "Expected actor task roundtrip to preserve actor id.")
    _expect(restored_task.status == task.status, "Expected actor task roundtrip to preserve status.")


func _test_party_tracks_actor_task_busy_rules() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)

    var actor_task: RefCounted = ACTOR_TASK_STATE_SCRIPT.new()
    actor_task.start_ask_local_information("player_companion_01", party.party_id, "wroclaw_city", "goods_source", "food", 0.25, server.current_day, party.manager_actor_id, false)
    party.set_actor_task(actor_task)

    _expect(party.has_actor_task("player_companion_01"), "Expected party to track actor task.")
    _expect(party.has_active_actor_task("player_companion_01"), "Expected active actor task to make actor busy.")
    _expect(party.is_idle(), "Expected non-locking actor task not to lock party.")

    var lock_task: RefCounted = ACTOR_TASK_STATE_SCRIPT.new()
    lock_task.start_ask_local_information("player_caravan_leader", party.party_id, "wroclaw_city", "goods_source", "food", 0.25, server.current_day, party.manager_actor_id, true)
    party.set_actor_task(lock_task)
    _expect(not party.is_idle(), "Expected party-lock actor task to make party non-idle.")

    lock_task.mark_completed()
    _expect(party.is_idle(), "Expected completed party-lock actor task to release party.")


func _test_save_load_preserves_actor_tasks() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)

    var actor_task: RefCounted = ACTOR_TASK_STATE_SCRIPT.new()
    actor_task.start_ask_local_information("player_companion_01", party.party_id, "wroclaw_city", "goods_source", "food", 0.25, server.current_day, party.manager_actor_id, false)
    party.set_actor_task(actor_task)

    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(bool(load_result.get("accepted", false)), "Expected save with actor task to load.")
    if not bool(load_result.get("accepted", false)):
        return

    var loaded_server: RefCounted = load_result.get("server")
    var loaded_party: RefCounted = loaded_server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    _expect(loaded_party.has_actor_task("player_companion_01"), "Expected loaded party to preserve actor task.")
    _expect(loaded_party.has_active_actor_task("player_companion_01"), "Expected loaded actor task to remain active.")
    _expect(loaded_party.get_actor_task("player_companion_01").goods_id == "food", "Expected loaded actor task goods id.")


func _test_load_rejects_bad_actor_task_references() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)

    var actor_task: RefCounted = ACTOR_TASK_STATE_SCRIPT.new()
    actor_task.start_ask_local_information("player_companion_01", party.party_id, "missing_location", "goods_source", "food", 0.25, server.current_day, party.manager_actor_id, false)
    party.set_actor_task(actor_task)

    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(not bool(load_result.get("accepted", false)), "Expected save with bad actor task location to be rejected.")
    _expect(str(load_result.get("error_code", "")) == SIMULATION_SAVE_CODEC_SCRIPT.ERROR_INVALID_FIELD, "Expected invalid field error for bad actor task location.")


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
