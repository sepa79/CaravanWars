class_name SimulationSaveCodec
extends RefCounted

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const ACTOR_TASK_STATE_SCRIPT: GDScript = preload("res://simulation/ActorTaskState.gd")
const GOODS_CATALOG_SCRIPT: GDScript = preload("res://simulation/GoodsCatalog.gd")
const LOCATION_STATE_SCRIPT: GDScript = preload("res://simulation/LocationState.gd")
const LOCATION_ECONOMY_CONFIG_SCRIPT: GDScript = preload("res://simulation/LocationEconomyConfig.gd")
const PARTY_CARGO_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyCargoConfig.gd")
const PARTY_COMPOSITION_SCRIPT: GDScript = preload("res://simulation/PartyComposition.gd")
const PARTY_KNOWLEDGE_STATE_SCRIPT: GDScript = preload("res://simulation/PartyKnowledgeState.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const PARTY_STATE_SCRIPT: GDScript = preload("res://simulation/PartyState.gd")
const PARTY_STATS_CALCULATOR_SCRIPT: GDScript = preload("res://simulation/PartyStatsCalculator.gd")
const PARTY_TASK_STATE_SCRIPT: GDScript = preload("res://simulation/PartyTaskState.gd")
const PARTY_TRAVEL_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyTravelConfig.gd")
const REGION_GRAPH_LOADER_SCRIPT: GDScript = preload("res://world/RegionGraphLoader.gd")
const SIMULATION_EVENT_LOG_SCRIPT: GDScript = preload("res://simulation/SimulationEventLog.gd")
const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")
const SIMULATION_STATE_SCRIPT: GDScript = preload("res://simulation/SimulationState.gd")

const SCHEMA_VERSION: int = 0

const ERROR_INVALID_SCHEMA_VERSION: String = "invalid_schema_version"
const ERROR_MISSING_FIELD: String = "missing_field"
const ERROR_INVALID_FIELD: String = "invalid_field"
const ERROR_UNKNOWN_REGION_GRAPH: String = "unknown_region_graph"
const ERROR_UNKNOWN_NODE: String = "unknown_node"
const ERROR_UNKNOWN_ROUTE: String = "unknown_route"


static func to_dictionary(server: RefCounted) -> Dictionary:
    var parties: Array[Dictionary] = []
    for party: RefCounted in server.state.parties_by_id.values():
        parties.append(party.to_dictionary())

    var locations: Array[Dictionary] = []
    for location: RefCounted in server.state.locations_by_id.values():
        locations.append(location.to_dictionary())

    return {
        "schema_version": SCHEMA_VERSION,
        "current_day": server.current_day,
        "region_graph_id": server.state.region_graph.id,
        "parties": parties,
        "locations": locations,
        "runtime_event_log": server.event_log.to_dictionary_array(),
        "player_map_state": {}
    }


static func load_from_dictionary(save_dictionary: Dictionary) -> Dictionary:
    var validation_error: Dictionary = _validate_save_root(save_dictionary)
    if not validation_error.is_empty():
        return _rejected(validation_error.get("error_code", ERROR_INVALID_FIELD), validation_error.get("message", "Invalid save."))

    var region_graph_id: String = str(save_dictionary.get("region_graph_id", ""))
    var server: RefCounted = SIMULATION_SERVER_SCRIPT.new()
    server.state = SIMULATION_STATE_SCRIPT.new()
    server.state.region_graph = REGION_GRAPH_LOADER_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_REGION_GRAPH_PATH)
    if server.state.region_graph.id != region_graph_id:
        return _rejected(ERROR_UNKNOWN_REGION_GRAPH, "Save graph id %s does not match loaded graph id %s." % [region_graph_id, server.state.region_graph.id])

    server.travel_config = PARTY_TRAVEL_CONFIG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_TRAVEL_CONFIG_PATH)
    server.cargo_config = PARTY_CARGO_CONFIG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_PARTY_CARGO_CONFIG_PATH)
    server.goods_catalog = GOODS_CATALOG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_GOODS_CATALOG_PATH)
    server.location_economy_config = LOCATION_ECONOMY_CONFIG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_LOCATION_ECONOMY_PATH, server.goods_catalog)
    server.current_day = float(save_dictionary.get("current_day", 0.0))

    var locations_value: Variant = save_dictionary.get("locations", [])
    for location_value: Variant in locations_value:
        if typeof(location_value) != TYPE_DICTIONARY:
            return _rejected(ERROR_INVALID_FIELD, "Location entry must be a dictionary.")

        var location_result: Dictionary = _location_from_dictionary(location_value, server)
        if not bool(location_result.get("accepted", false)):
            return location_result

        var loaded_location: RefCounted = location_result.get("location")
        server.state.add_location(loaded_location)

    var parties_value: Variant = save_dictionary.get("parties", [])
    for party_value: Variant in parties_value:
        if typeof(party_value) != TYPE_DICTIONARY:
            return _rejected(ERROR_INVALID_FIELD, "Party entry must be a dictionary.")

        var party_result: Dictionary = _party_from_dictionary(party_value, server)
        if not bool(party_result.get("accepted", false)):
            return party_result

        var loaded_party: RefCounted = party_result.get("party")
        server.state.add_party(loaded_party)

    var events_value: Variant = save_dictionary.get("runtime_event_log", [])
    if typeof(events_value) != TYPE_ARRAY:
        return _rejected(ERROR_INVALID_FIELD, "runtime_event_log must be an array.")

    server.event_log = SIMULATION_EVENT_LOG_SCRIPT.new()
    for event_value: Variant in events_value:
        if typeof(event_value) != TYPE_DICTIONARY:
            return _rejected(ERROR_INVALID_FIELD, "Runtime event log entry must be a dictionary.")
        server.event_log.append_event(SIMULATION_EVENT_SCRIPT.from_dictionary(event_value))

    return {
        "accepted": true,
        "server": server,
        "error_code": "",
        "message": ""
    }


static func _validate_save_root(save_dictionary: Dictionary) -> Dictionary:
    for field_name: String in ["schema_version", "current_day", "region_graph_id", "parties", "locations", "runtime_event_log"]:
        if not save_dictionary.has(field_name):
            return _error(ERROR_MISSING_FIELD, "Save is missing required field: %s." % field_name)

    if int(save_dictionary.get("schema_version", -1)) != SCHEMA_VERSION:
        return _error(ERROR_INVALID_SCHEMA_VERSION, "Unsupported save schema version: %s." % str(save_dictionary.get("schema_version", "")))

    if typeof(save_dictionary.get("parties")) != TYPE_ARRAY:
        return _error(ERROR_INVALID_FIELD, "parties must be an array.")

    if typeof(save_dictionary.get("locations")) != TYPE_ARRAY:
        return _error(ERROR_INVALID_FIELD, "locations must be an array.")

    return {}


static func _party_from_dictionary(party_dictionary: Dictionary, server: RefCounted) -> Dictionary:
    for field_name: String in ["party_id", "party_type", "manager_actor_id", "authorized_issuer_actor_ids", "current_node_id", "travel_state", "composition", "cargo", "knowledge", "order", "task", "actor_tasks"]:
        if not party_dictionary.has(field_name):
            return _rejected(ERROR_MISSING_FIELD, "Party is missing required field: %s." % field_name)

    var current_node_id: String = str(party_dictionary.get("current_node_id", ""))
    if not server.state.region_graph.has_node(current_node_id):
        return _rejected(ERROR_UNKNOWN_NODE, "Party current node does not exist: %s." % current_node_id)

    var party: RefCounted = PARTY_STATE_SCRIPT.new()
    party.party_id = str(party_dictionary.get("party_id", ""))
    party.party_type = str(party_dictionary.get("party_type", ""))
    party.manager_actor_id = str(party_dictionary.get("manager_actor_id", ""))
    party.authorized_issuer_actor_ids = _string_array_from_variant(party_dictionary.get("authorized_issuer_actor_ids", []))
    party.current_node_id = current_node_id
    party.travel_state = str(party_dictionary.get("travel_state", ""))
    party.origin_node_id = str(party_dictionary.get("origin_node_id", ""))
    party.destination_node_id = str(party_dictionary.get("destination_node_id", ""))
    party.travel_progress_km = float(party_dictionary.get("travel_progress_km", 0.0))
    party.travel_distance_km = float(party_dictionary.get("travel_distance_km", 0.0))
    party.travel_speed_km_per_day = float(party_dictionary.get("travel_speed_km_per_day", 0.0))
    party.travel_intent_destination_node_id = str(party_dictionary.get("travel_intent_destination_node_id", ""))
    party.travel_path_node_ids = _string_array_from_variant(party_dictionary.get("travel_path_node_ids", []))
    party.travel_path_edge_ids = _string_array_from_variant(party_dictionary.get("travel_path_edge_ids", []))
    party.travel_path_index = int(party_dictionary.get("travel_path_index", 0))
    if party.travel_state != PARTY_STATE_SCRIPT.TRAVEL_STATE_IDLE and party.travel_state != PARTY_STATE_SCRIPT.TRAVEL_STATE_TRAVELING and party.travel_state != PARTY_STATE_SCRIPT.TRAVEL_STATE_INTERRUPTED:
        return _rejected(ERROR_INVALID_FIELD, "Party travel_state is invalid: %s." % party.travel_state)

    var composition_value: Variant = party_dictionary.get("composition", {})
    if typeof(composition_value) != TYPE_DICTIONARY:
        return _rejected(ERROR_INVALID_FIELD, "Party composition must be a dictionary.")
    party.composition = PARTY_COMPOSITION_SCRIPT.from_dictionary(composition_value)

    var cargo_value: Variant = party_dictionary.get("cargo", {})
    if typeof(cargo_value) != TYPE_DICTIONARY:
        return _rejected(ERROR_INVALID_FIELD, "Party cargo must be a dictionary.")
    party.cargo = _int_dictionary_from_variant(cargo_value)
    var cargo_validation_errors: Array[String] = server.goods_catalog.validate_resource_dictionary(party.cargo)
    if not cargo_validation_errors.is_empty():
        return _rejected(ERROR_INVALID_FIELD, "Party cargo is invalid: %s." % str(cargo_validation_errors))
    if not PARTY_STATS_CALCULATOR_SCRIPT.is_cargo_within_capacity(party.cargo, party.composition, server.goods_catalog, server.cargo_config):
        return _rejected(ERROR_INVALID_FIELD, "Party cargo exceeds capacity: %s." % party.party_id)

    var knowledge_value: Variant = party_dictionary.get("knowledge", {})
    if typeof(knowledge_value) != TYPE_DICTIONARY:
        return _rejected(ERROR_INVALID_FIELD, "Party knowledge must be a dictionary.")
    party.knowledge = PARTY_KNOWLEDGE_STATE_SCRIPT.from_dictionary(knowledge_value)

    var order_value: Variant = party_dictionary.get("order", {})
    if typeof(order_value) != TYPE_DICTIONARY:
        return _rejected(ERROR_INVALID_FIELD, "Party order must be a dictionary.")
    party.order = PARTY_ORDER_STATE_SCRIPT.from_dictionary(order_value)

    var task_value: Variant = party_dictionary.get("task", {})
    if typeof(task_value) != TYPE_DICTIONARY:
        return _rejected(ERROR_INVALID_FIELD, "Party task must be a dictionary.")
    party.task = PARTY_TASK_STATE_SCRIPT.from_dictionary(task_value)

    var actor_tasks_value: Variant = party_dictionary.get("actor_tasks", [])
    if typeof(actor_tasks_value) != TYPE_ARRAY:
        return _rejected(ERROR_INVALID_FIELD, "Party actor_tasks must be an array.")
    for actor_task_value: Variant in actor_tasks_value:
        if typeof(actor_task_value) != TYPE_DICTIONARY:
            return _rejected(ERROR_INVALID_FIELD, "Party actor task must be a dictionary.")
        var actor_task: RefCounted = ACTOR_TASK_STATE_SCRIPT.from_dictionary(actor_task_value)
        if actor_task.actor_id.is_empty():
            return _rejected(ERROR_INVALID_FIELD, "Party actor task is missing actor_id.")
        if party.actor_tasks_by_actor_id.has(actor_task.actor_id):
            return _rejected(ERROR_INVALID_FIELD, "Party actor task actor_id is duplicated: %s." % actor_task.actor_id)
        if actor_task.party_id != party.party_id:
            return _rejected(ERROR_INVALID_FIELD, "Party actor task party_id does not match party: %s." % actor_task.actor_id)
        party.set_actor_task(actor_task)

    var validation_error: Dictionary = _validate_party_references(party, server)
    if not validation_error.is_empty():
        return validation_error

    return {
        "accepted": true,
        "party": party,
        "error_code": "",
        "message": ""
    }


static func _location_from_dictionary(location_dictionary: Dictionary, server: RefCounted) -> Dictionary:
    for field_name: String in ["location_id", "location_type", "manager_actor_id", "node_id", "resources"]:
        if not location_dictionary.has(field_name):
            return _rejected(ERROR_MISSING_FIELD, "Location is missing required field: %s." % field_name)

    var location: RefCounted = LOCATION_STATE_SCRIPT.from_dictionary(location_dictionary)
    if not server.state.region_graph.has_node(location.node_id):
        return _rejected(ERROR_UNKNOWN_NODE, "Location node does not exist: %s." % location.node_id)

    return {
        "accepted": true,
        "location": location,
        "error_code": "",
        "message": ""
    }


static func _validate_party_references(party: RefCounted, server: RefCounted) -> Dictionary:
    for node_id: String in party.knowledge.known_node_ids:
        if not server.state.region_graph.has_node(node_id):
            return _rejected(ERROR_UNKNOWN_NODE, "Party knowledge references missing node: %s." % node_id)

    for edge_id: String in party.knowledge.known_edge_ids:
        if not server.state.region_graph.edges_by_id.has(edge_id):
            return _rejected(ERROR_UNKNOWN_ROUTE, "Party knowledge references missing route: %s." % edge_id)

    for node_id: String in party.travel_path_node_ids:
        if not server.state.region_graph.has_node(node_id):
            return _rejected(ERROR_UNKNOWN_NODE, "Party travel path references missing node: %s." % node_id)

    for edge_id: String in party.travel_path_edge_ids:
        if not server.state.region_graph.edges_by_id.has(edge_id):
            return _rejected(ERROR_UNKNOWN_ROUTE, "Party travel path references missing route: %s." % edge_id)

    if not party.origin_node_id.is_empty() and not server.state.region_graph.has_node(party.origin_node_id):
        return _rejected(ERROR_UNKNOWN_NODE, "Party origin node does not exist: %s." % party.origin_node_id)

    if not party.destination_node_id.is_empty() and not server.state.region_graph.has_node(party.destination_node_id):
        return _rejected(ERROR_UNKNOWN_NODE, "Party destination node does not exist: %s." % party.destination_node_id)

    if not party.travel_intent_destination_node_id.is_empty() and not server.state.region_graph.has_node(party.travel_intent_destination_node_id):
        return _rejected(ERROR_UNKNOWN_NODE, "Party travel intent destination does not exist: %s." % party.travel_intent_destination_node_id)

    if not party.order.target_node_id.is_empty() and not server.state.region_graph.has_node(party.order.target_node_id):
        return _rejected(ERROR_UNKNOWN_NODE, "Party order target node does not exist: %s." % party.order.target_node_id)

    if not party.order.target_location_id.is_empty() and not server.state.has_location(party.order.target_location_id):
        return _rejected(ERROR_INVALID_FIELD, "Party order target location does not exist: %s." % party.order.target_location_id)

    if not party.order.goods_id.is_empty() and not server.goods_catalog.has_goods(party.order.goods_id):
        return _rejected(ERROR_INVALID_FIELD, "Party order goods does not exist: %s." % party.order.goods_id)

    if not party.task.location_id.is_empty() and not server.state.has_location(party.task.location_id):
        return _rejected(ERROR_INVALID_FIELD, "Party task location does not exist: %s." % party.task.location_id)

    if not party.task.goods_id.is_empty() and not server.goods_catalog.has_goods(party.task.goods_id):
        return _rejected(ERROR_INVALID_FIELD, "Party task goods does not exist: %s." % party.task.goods_id)

    for actor_task: RefCounted in party.actor_tasks_by_actor_id.values():
        if not actor_task.location_id.is_empty() and not server.state.has_location(actor_task.location_id):
            return _rejected(ERROR_INVALID_FIELD, "Actor task location does not exist: %s." % actor_task.location_id)
        if not actor_task.goods_id.is_empty() and not server.goods_catalog.has_goods(actor_task.goods_id):
            return _rejected(ERROR_INVALID_FIELD, "Actor task goods does not exist: %s." % actor_task.goods_id)

    return {}


static func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings


static func _int_dictionary_from_variant(value: Variant) -> Dictionary[String, int]:
    var values: Dictionary[String, int] = {}
    if typeof(value) != TYPE_DICTIONARY:
        return values

    for key: Variant in value.keys():
        values[str(key)] = int(value.get(key))
    return values


static func _error(error_code: String, message: String) -> Dictionary:
    return {
        "error_code": error_code,
        "message": message
    }


static func _rejected(error_code: String, message: String) -> Dictionary:
    return {
        "accepted": false,
        "server": null,
        "error_code": error_code,
        "message": message
    }
