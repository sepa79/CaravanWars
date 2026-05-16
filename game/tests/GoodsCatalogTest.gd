extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const GOODS_CATALOG_SCRIPT: GDScript = preload("res://simulation/GoodsCatalog.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_goods_catalog_loads()
    _test_seed_location_resources_are_catalog_goods()
    _test_unknown_location_resource_is_rejected()

    if not _failed:
        print("[GoodsCatalogTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Goods catalog test failed.")
    return _is_finished


func _test_goods_catalog_loads() -> void:
    var catalog: RefCounted = GOODS_CATALOG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_GOODS_CATALOG_PATH)
    _expect(catalog.is_valid(), "Expected goods catalog to be valid.")
    _expect(catalog.has_goods("food"), "Expected food goods entry.")
    _expect(catalog.has_goods("grain"), "Expected grain goods entry.")
    _expect(catalog.has_goods("tools"), "Expected tools goods entry.")
    _expect(catalog.has_goods("coin"), "Expected coin goods entry.")
    _expect(catalog.has_goods("horses"), "Expected horses goods entry.")


func _test_seed_location_resources_are_catalog_goods() -> void:
    var catalog: RefCounted = GOODS_CATALOG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_GOODS_CATALOG_PATH)
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    for location: RefCounted in server.state.locations_by_id.values():
        var resource_errors: Array[String] = catalog.validate_resource_dictionary(location.resources)
        _expect(resource_errors.is_empty(), "Expected known resources for location %s: %s" % [location.location_id, resource_errors])


func _test_unknown_location_resource_is_rejected() -> void:
    var catalog: RefCounted = GOODS_CATALOG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_GOODS_CATALOG_PATH)
    var resources: Dictionary[String, int] = {
        "food": 1,
        "unknown_relics": 1
    }
    var resource_errors: Array[String] = catalog.validate_resource_dictionary(resources)
    _expect(resource_errors.size() == 1, "Expected one unknown goods error.")
    if resource_errors.size() == 1:
        _expect(resource_errors[0].contains("unknown_relics"), "Expected unknown goods id in error.")


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
