class_name GameSessionFactory
extends RefCounted

const PARTY_COMPOSITION_SCRIPT: GDScript = preload("res://simulation/PartyComposition.gd")
const LOCATION_STATE_SCRIPT: GDScript = preload("res://simulation/LocationState.gd")
const GOODS_CATALOG_SCRIPT: GDScript = preload("res://simulation/GoodsCatalog.gd")
const LOCATION_ECONOMY_CONFIG_SCRIPT: GDScript = preload("res://simulation/LocationEconomyConfig.gd")
const PARTY_CARGO_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyCargoConfig.gd")
const PARTY_STATE_SCRIPT: GDScript = preload("res://simulation/PartyState.gd")
const PARTY_TRAVEL_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyTravelConfig.gd")
const REGION_GRAPH_LOADER_SCRIPT: GDScript = preload("res://world/RegionGraphLoader.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")
const SIMULATION_STATE_SCRIPT: GDScript = preload("res://simulation/SimulationState.gd")

const PLAYER_PARTY_ID: String = "player_party"
const BANDIT_PARTY_ID: String = "bandit_party_01"
const MERCHANT_PARTY_ID: String = "merchant_party_01"
const WROCLAW_LOCATION_ID: String = "wroclaw_city"
const OPOLE_LOCATION_ID: String = "opole_stronghold"
const NYSA_LOCATION_ID: String = "nysa_monastery"
const DEFAULT_REGION_GRAPH_PATH: String = "res://data/regions/silesia.json"
const DEFAULT_TRAVEL_CONFIG_PATH: String = "res://data/simulation/party_travel.json"
const DEFAULT_GOODS_CATALOG_PATH: String = "res://data/simulation/goods_catalog.json"
const DEFAULT_LOCATION_ECONOMY_PATH: String = "res://data/simulation/location_economy.json"
const DEFAULT_PARTY_CARGO_CONFIG_PATH: String = "res://data/simulation/party_cargo.json"


static func create_new_game_server() -> RefCounted:
    var server: RefCounted = SIMULATION_SERVER_SCRIPT.new()
    server.state = SIMULATION_STATE_SCRIPT.new()
    server.state.region_graph = REGION_GRAPH_LOADER_SCRIPT.load_from_file(DEFAULT_REGION_GRAPH_PATH)
    server.travel_config = PARTY_TRAVEL_CONFIG_SCRIPT.load_from_file(DEFAULT_TRAVEL_CONFIG_PATH)
    server.cargo_config = PARTY_CARGO_CONFIG_SCRIPT.load_from_file(DEFAULT_PARTY_CARGO_CONFIG_PATH)
    server.goods_catalog = GOODS_CATALOG_SCRIPT.load_from_file(DEFAULT_GOODS_CATALOG_PATH)
    server.location_economy_config = LOCATION_ECONOMY_CONFIG_SCRIPT.load_from_file(DEFAULT_LOCATION_ECONOMY_PATH, server.goods_catalog)
    server.current_day = 0.0
    server.state.add_party(create_player_party())
    server.state.add_party(create_bandit_party())
    server.state.add_party(create_merchant_party())
    server.state.add_location(create_wroclaw_location())
    server.state.add_location(create_opole_location())
    server.state.add_location(create_nysa_location())
    return server


static func create_player_party() -> RefCounted:
    var party: RefCounted = PARTY_STATE_SCRIPT.new()
    party.party_id = PLAYER_PARTY_ID
    party.party_type = "caravan"
    party.manager_actor_id = "player_caravan_leader"
    party.current_node_id = "wroclaw"
    party.composition = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 8,
        "horse_count": 2,
        "wagon_count": 1,
        "pack_animal_count": 1,
        "guard_count": 2
    })
    party.cargo["food"] = 12
    party.cargo["coin"] = 30
    party.knowledge.add_known_node("wroclaw")
    party.knowledge.add_known_node("opole")
    party.knowledge.add_known_node("legnica")
    party.knowledge.add_known_node("glogow")
    party.knowledge.add_known_edge("wroclaw_opole")
    party.knowledge.add_known_edge("wroclaw_legnica")
    party.knowledge.add_known_edge("wroclaw_glogow")
    return party


static func create_bandit_party() -> RefCounted:
    var party: RefCounted = PARTY_STATE_SCRIPT.new()
    party.party_id = BANDIT_PARTY_ID
    party.party_type = "bandit_band"
    party.manager_actor_id = "bandit_chief_boruta"
    party.current_node_id = "great_forest"
    party.composition = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 6,
        "horse_count": 1,
        "wagon_count": 0,
        "pack_animal_count": 0,
        "guard_count": 0
    })
    party.cargo["food"] = 2
    party.knowledge.add_known_node("great_forest")
    party.knowledge.add_known_node("opole")
    party.knowledge.add_known_edge("great_forest_opole")
    return party


static func create_merchant_party() -> RefCounted:
    var party: RefCounted = PARTY_STATE_SCRIPT.new()
    party.party_id = MERCHANT_PARTY_ID
    party.party_type = "merchant_caravan"
    party.manager_actor_id = "merchant_miroslaw"
    party.current_node_id = "opole"
    party.composition = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 5,
        "horse_count": 3,
        "wagon_count": 2,
        "pack_animal_count": 1,
        "guard_count": 2
    })
    party.cargo["food"] = 8
    party.cargo["coin"] = 80
    party.knowledge.add_known_node("opole")
    party.knowledge.add_known_node("wroclaw")
    party.knowledge.add_known_node("raciborz")
    party.knowledge.add_known_edge("wroclaw_opole")
    party.knowledge.add_known_edge("opole_raciborz")
    return party


static func create_wroclaw_location() -> RefCounted:
    return LOCATION_STATE_SCRIPT.from_dictionary({
        "location_id": WROCLAW_LOCATION_ID,
        "location_type": "city",
        "manager_actor_id": "mayor_wroclaw",
        "node_id": "wroclaw",
        "resources": {
            "food": 120,
            "coin": 300,
            "horses": 12
        }
    })


static func create_opole_location() -> RefCounted:
    return LOCATION_STATE_SCRIPT.from_dictionary({
        "location_id": OPOLE_LOCATION_ID,
        "location_type": "stronghold",
        "manager_actor_id": "castellan_opole",
        "node_id": "opole",
        "resources": {
            "food": 70,
            "coin": 160,
            "horses": 5
        }
    })


static func create_nysa_location() -> RefCounted:
    return LOCATION_STATE_SCRIPT.from_dictionary({
        "location_id": NYSA_LOCATION_ID,
        "location_type": "monastery",
        "manager_actor_id": "abbot_nysa",
        "node_id": "nysa",
        "resources": {
            "food": 90,
            "coin": 80,
            "horses": 2
        }
    })
