extends RefCounted
class_name MapGenerator

## Parameter container for map generation.
class MapGenParams:
    var rng_seed: int
    var seed_terrain: int
    var seed_climate: int
    var seed_hydrology: int
    var seed_settlements: int
    var seed_roads: int
    var city_count: int
    var max_river_count: int
    var min_connections: int
    var max_connections: int
    var min_city_distance: float
    var max_city_distance: float
    var crossroad_detour_margin: float
    var width: float
    var height: float
    var kingdom_count: int
    var max_forts_per_kingdom: int
    var min_villages_per_city: int
    var max_villages_per_city: int
    var village_downgrade_threshold: int

    func _init(
        p_rng_seed: int = 0,
        p_city_count: int = 3,
        p_max_river_count: int = 1,
        p_min_connections: int = 1,
        p_max_connections: int = 3,
        p_min_city_distance: float = 20.0,
        p_max_city_distance: float = 40.0,
        p_crossroad_detour_margin: float = 5.0,
        p_width: float = 100.0,
        p_height: float = 100.0,
        p_kingdom_count: int = 1,
        p_max_forts_per_kingdom: int = 1,
        p_min_villages_per_city: int = 0,
        p_max_villages_per_city: int = 2,
        p_village_downgrade_threshold: int = 1,
        p_seed_terrain: int = 0,
        p_seed_climate: int = 0,
        p_seed_hydrology: int = 0,
        p_seed_settlements: int = 0,
        p_seed_roads: int = 0
    ) -> void:
        rng_seed = p_rng_seed if p_rng_seed != 0 else Time.get_ticks_msec()
        var base_rng := RandomNumberGenerator.new()
        base_rng.seed = rng_seed
        seed_terrain = p_seed_terrain if p_seed_terrain != 0 else base_rng.randi()
        seed_climate = p_seed_climate if p_seed_climate != 0 else base_rng.randi()
        seed_hydrology = p_seed_hydrology if p_seed_hydrology != 0 else base_rng.randi()
        seed_settlements = p_seed_settlements if p_seed_settlements != 0 else base_rng.randi()
        seed_roads = p_seed_roads if p_seed_roads != 0 else base_rng.randi()
        city_count = p_city_count
        max_river_count = p_max_river_count
        var max_possible: int = min(7, max(1, p_city_count - 1))
        min_connections = clamp(p_min_connections, 1, max_possible)
        max_connections = clamp(p_max_connections, min_connections, max_possible)
        min_city_distance = min(p_min_city_distance, p_max_city_distance)
        max_city_distance = max(p_min_city_distance, p_max_city_distance)
        crossroad_detour_margin = p_crossroad_detour_margin
        width = clamp(p_width, 20.0, 500.0)
        height = clamp(p_height, 20.0, 500.0)
        kingdom_count = max(1, p_kingdom_count)
        max_forts_per_kingdom = max(0, p_max_forts_per_kingdom)
        min_villages_per_city = max(0, p_min_villages_per_city)
        max_villages_per_city = max(min_villages_per_city, p_max_villages_per_city)
        village_downgrade_threshold = max(1, p_village_downgrade_threshold)

var params: MapGenParams
var rngs: Dictionary = {}

const CityPlacerModule = preload("res://map/CityPlacer.gd")
const RoadNetworkModule = preload("res://map/RoadNetwork.gd")
const RiverGeneratorModule: Script = preload("res://map/RiverGenerator.gd")
const RegionGeneratorModule: Script = preload("res://map/RegionGenerator.gd")
const WorldDataModule: Script = preload("res://map/WorldData.gd")

func _init(_params: MapGenParams = MapGenParams.new()) -> void:
    params = _params
    rngs["terrain"] = RandomNumberGenerator.new()
    rngs["terrain"].seed = params.seed_terrain
    rngs["climate"] = RandomNumberGenerator.new()
    rngs["climate"].seed = params.seed_climate
    rngs["hydrology"] = RandomNumberGenerator.new()
    rngs["hydrology"].seed = params.seed_hydrology
    rngs["settlements"] = RandomNumberGenerator.new()
    rngs["settlements"].seed = params.seed_settlements
    rngs["roads"] = RandomNumberGenerator.new()
    rngs["roads"].seed = params.seed_roads

func generate() -> Dictionary:
    var map_data: Dictionary = {
        "width": params.width,
        "height": params.height,
    }
    var world := WorldDataModule.new(params.width, params.height)

    var city_stage := CityPlacerModule.new(rngs["settlements"])
    var cities := city_stage.place_cities(
        params.city_count,
        params.min_city_distance,
        params.max_city_distance,
        params.width,
        params.height
    )
    map_data["cities"] = cities
    var city_guids: Array[String] = []
    for pos in cities:
        var guid := world.add_vector("cities", {"pos": pos}, "")
        city_guids.append(guid)
    print("[MapGenerator] placed %s cities" % cities.size())

    var region_stage = RegionGeneratorModule.new()
    var regions: Dictionary = region_stage.generate_regions(cities, params.kingdom_count, params.width, params.height)
    map_data["regions"] = regions
    world.add_graph("regions", regions)
    print("[MapGenerator] generated %s regions" % regions.size())

    var road_stage := RoadNetworkModule.new(rngs["roads"])
    var roads := road_stage.build_roads(
        cities,
        params.min_connections,
        params.max_connections,
        params.crossroad_detour_margin,
        "roman",
    )
    road_stage.insert_villages(roads, params.min_villages_per_city, params.max_villages_per_city, 5.0, params.width, params.height, params.village_downgrade_threshold)
    road_stage.insert_border_forts(roads, regions, 10.0, params.max_forts_per_kingdom, params.width, params.height)

    var river_stage = RiverGeneratorModule.new(rngs["hydrology"])
    var rivers: Array = river_stage.generate_rivers(roads, params.max_river_count, params.width, params.height)
    map_data["rivers"] = rivers
    for poly in rivers:
        world.add_vector("rivers", {"polyline": poly}, "")

    for i in range(city_guids.size()):
        var node_id: int = i + 1
        if roads["nodes"].has(node_id):
            roads["nodes"][node_id].attrs["guid"] = city_guids[i]

    world.add_graph("roads", roads)

    for edge in roads.get("edges", {}).values():
        var a_id: int = edge.endpoints[0]
        var b_id: int = edge.endpoints[1]
        var a_guid: String = roads["nodes"][a_id].attrs.get("guid", "")
        var b_guid: String = roads["nodes"][b_id].attrs.get("guid", "")
        if a_guid != "" and b_guid != "":
            edge.attrs["derived_from"] = "%s,%s" % [a_guid, b_guid]

    map_data["roads"] = roads
    map_data["world_data"] = world

    return map_data
