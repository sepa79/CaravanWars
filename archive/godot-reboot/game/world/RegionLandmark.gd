class_name RegionLandmark
extends RefCounted

var id: String = ""
var display_name: String = ""
var kind: String = ""
var position: Vector2 = Vector2.ZERO
var elevation_m: float = 0.0
var visibility_class: String = ""
var notes: String = ""


static func from_dictionary(landmark_dictionary: Dictionary) -> RefCounted:
    var landmark: RefCounted = new()
    landmark.id = str(landmark_dictionary.get("id", ""))
    landmark.display_name = str(landmark_dictionary.get("display_name", landmark.id))
    landmark.kind = str(landmark_dictionary.get("kind", "unknown"))
    landmark.elevation_m = float(landmark_dictionary.get("elevation_m", 0.0))
    landmark.visibility_class = str(landmark_dictionary.get("visibility_class", "local"))
    landmark.notes = str(landmark_dictionary.get("notes", ""))

    var raw_position: Variant = landmark_dictionary.get("position", [0.0, 0.0])
    if typeof(raw_position) == TYPE_ARRAY and raw_position.size() >= 2:
        landmark.position = Vector2(float(raw_position[0]), float(raw_position[1]))

    return landmark
