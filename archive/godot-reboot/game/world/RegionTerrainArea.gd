class_name RegionTerrainArea
extends RefCounted

var id: String = ""
var display_name: String = ""
var kind: String = ""
var shape: String = ""
var center: Vector2 = Vector2.ZERO
var radius: Vector2 = Vector2.ZERO
var polygon: Array[Vector2] = []
var notes: String = ""


static func from_dictionary(area_dictionary: Dictionary) -> RefCounted:
    var area: RefCounted = new()
    area.id = str(area_dictionary.get("id", ""))
    area.display_name = str(area_dictionary.get("display_name", area.id))
    area.kind = str(area_dictionary.get("kind", "unknown"))
    area.shape = str(area_dictionary.get("shape", "polygon"))
    area.notes = str(area_dictionary.get("notes", ""))

    var raw_center: Variant = area_dictionary.get("center", [0.0, 0.0])
    if typeof(raw_center) == TYPE_ARRAY and raw_center.size() >= 2:
        area.center = Vector2(float(raw_center[0]), float(raw_center[1]))

    var raw_radius: Variant = area_dictionary.get("radius", [0.0, 0.0])
    if typeof(raw_radius) == TYPE_ARRAY and raw_radius.size() >= 2:
        area.radius = Vector2(float(raw_radius[0]), float(raw_radius[1]))

    var raw_polygon: Variant = area_dictionary.get("polygon", [])
    if typeof(raw_polygon) == TYPE_ARRAY:
        for raw_point: Variant in raw_polygon:
            if typeof(raw_point) == TYPE_ARRAY and raw_point.size() >= 2:
                area.polygon.append(Vector2(float(raw_point[0]), float(raw_point[1])))

    return area
