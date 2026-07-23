extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const GOODS_CATALOG_SCRIPT: GDScript = preload("res://simulation/GoodsCatalog.gd")
const PARTY_CARGO_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyCargoConfig.gd")
const PARTY_COMPOSITION_SCRIPT: GDScript = preload("res://simulation/PartyComposition.gd")
const PARTY_STATS_CALCULATOR_SCRIPT: GDScript = preload("res://simulation/PartyStatsCalculator.gd")
const SIMULATION_SAVE_CODEC_SCRIPT: GDScript = preload("res://simulation/SimulationSaveCodec.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_party_cargo_config_loads()
    _test_capacity_depends_on_composition()
    _test_cargo_used_uses_goods_bulk()
    _test_new_game_seed_cargo_fits_capacity()
    _test_save_load_preserves_party_cargo()
    _test_load_rejects_over_capacity_cargo()

    if not _failed:
        print("[PartyCargoTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Party cargo test failed.")
    return _is_finished


func _test_party_cargo_config_loads() -> void:
    var cargo_config: RefCounted = PARTY_CARGO_CONFIG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_PARTY_CARGO_CONFIG_PATH)
    _expect(cargo_config.is_valid(), "Expected party cargo config to be valid.")
    _expect(cargo_config.wagon_capacity_bulk > cargo_config.pack_animal_capacity_bulk, "Expected wagon to carry more than one pack animal.")


func _test_capacity_depends_on_composition() -> void:
    var cargo_config: RefCounted = PARTY_CARGO_CONFIG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_PARTY_CARGO_CONFIG_PATH)
    var walking_composition: RefCounted = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 8,
        "horse_count": 0,
        "wagon_count": 0,
        "pack_animal_count": 0,
        "guard_count": 2
    })
    var wagon_composition: RefCounted = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 8,
        "horse_count": 2,
        "wagon_count": 1,
        "pack_animal_count": 1,
        "guard_count": 2
    })

    var walking_capacity: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_cargo_capacity_bulk(walking_composition, cargo_config)
    var wagon_capacity: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_cargo_capacity_bulk(wagon_composition, cargo_config)
    _expect(wagon_capacity > walking_capacity, "Expected wagon party to have higher cargo capacity.")


func _test_cargo_used_uses_goods_bulk() -> void:
    var goods_catalog: RefCounted = GOODS_CATALOG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_GOODS_CATALOG_PATH)
    var cargo: Dictionary[String, int] = {
        "food": 10,
        "coin": 100
    }
    var used_bulk: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_cargo_used_bulk(cargo, goods_catalog)
    _expect(is_equal_approx(used_bulk, 11.0), "Expected cargo used bulk to include goods bulk values.")


func _test_new_game_seed_cargo_fits_capacity() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    for party: RefCounted in server.state.parties_by_id.values():
        var fits_capacity: bool = PARTY_STATS_CALCULATOR_SCRIPT.is_cargo_within_capacity(party.cargo, party.composition, server.goods_catalog, server.cargo_config)
        _expect(fits_capacity, "Expected seed cargo to fit party capacity: %s" % party.party_id)


func _test_save_load_preserves_party_cargo() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var player_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    player_party.cargo["food"] = 7

    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(bool(load_result.get("accepted", false)), "Expected save with party cargo to load.")
    if not bool(load_result.get("accepted", false)):
        return

    var loaded_server: RefCounted = load_result.get("server")
    var loaded_party: RefCounted = loaded_server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    _expect(int(loaded_party.cargo.get("food", 0)) == 7, "Expected loaded cargo food to match saved cargo.")


func _test_load_rejects_over_capacity_cargo() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    var parties: Array = saved_dictionary.get("parties", [])
    for index: int in range(parties.size()):
        var party_value: Variant = parties[index]
        if typeof(party_value) != TYPE_DICTIONARY:
            continue
        var party_dictionary: Dictionary = party_value
        if str(party_dictionary.get("party_id", "")) == GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID:
            party_dictionary["cargo"] = {
                "food": 999
            }
            parties[index] = party_dictionary
    saved_dictionary["parties"] = parties

    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(not bool(load_result.get("accepted", false)), "Expected overloaded party cargo to be rejected.")
    _expect(str(load_result.get("error_code", "")) == SIMULATION_SAVE_CODEC_SCRIPT.ERROR_INVALID_FIELD, "Expected invalid_field for overloaded cargo.")


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
