class_name RegionGraphLoader
extends RefCounted

const REGION_GRAPH_SCRIPT: GDScript = preload("res://world/RegionGraph.gd")


static func load_from_file(resource_path: String) -> RefCounted:
    var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
    if file == null:
        push_error("Could not open region graph file: %s" % resource_path)
        return REGION_GRAPH_SCRIPT.new()

    var file_text: String = file.get_as_text()
    var parsed_json: Variant = JSON.parse_string(file_text)
    if typeof(parsed_json) != TYPE_DICTIONARY:
        push_error("Region graph file is not a JSON object: %s" % resource_path)
        return REGION_GRAPH_SCRIPT.new()

    return REGION_GRAPH_SCRIPT.from_dictionary(parsed_json)
