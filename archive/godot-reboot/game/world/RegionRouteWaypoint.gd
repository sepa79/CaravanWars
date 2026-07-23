class_name RegionRouteWaypoint
extends RefCounted

var id: String = ""
var kind: String = ""
var position: Vector2 = Vector2.ZERO
var distance_from_start_km: float = 0.0
var elevation_m: float = 0.0
var travel_time_modifier: float = 1.0
var terrain_area_ids: Array[String] = []
var landmark_ids: Array[String] = []
var landmark_tags: Array[String] = []
var notes: String = ""


static func from_dictionary(waypoint_dictionary: Dictionary) -> RefCounted:
    var waypoint: RefCounted = new()
    waypoint.id = str(waypoint_dictionary.get("id", ""))
    waypoint.kind = str(waypoint_dictionary.get("kind", "unknown"))
    waypoint.distance_from_start_km = float(waypoint_dictionary.get("distance_from_start_km", 0.0))
    waypoint.elevation_m = float(waypoint_dictionary.get("elevation_m", 0.0))
    waypoint.travel_time_modifier = float(waypoint_dictionary.get("travel_time_modifier", 1.0))
    waypoint.notes = str(waypoint_dictionary.get("notes", ""))

    var raw_position: Variant = waypoint_dictionary.get("position", [0.0, 0.0])
    if typeof(raw_position) == TYPE_ARRAY and raw_position.size() >= 2:
        waypoint.position = Vector2(float(raw_position[0]), float(raw_position[1]))

    var raw_terrain_area_ids: Variant = waypoint_dictionary.get("terrain_area_ids", [])
    if typeof(raw_terrain_area_ids) == TYPE_ARRAY:
        for raw_terrain_area_id: Variant in raw_terrain_area_ids:
            waypoint.terrain_area_ids.append(str(raw_terrain_area_id))

    var raw_landmark_ids: Variant = waypoint_dictionary.get("landmark_ids", [])
    if typeof(raw_landmark_ids) == TYPE_ARRAY:
        for raw_landmark_id: Variant in raw_landmark_ids:
            waypoint.landmark_ids.append(str(raw_landmark_id))

    var raw_landmark_tags: Variant = waypoint_dictionary.get("landmark_tags", [])
    if typeof(raw_landmark_tags) == TYPE_ARRAY:
        for raw_landmark_tag: Variant in raw_landmark_tags:
            waypoint.landmark_tags.append(str(raw_landmark_tag))

    return waypoint
