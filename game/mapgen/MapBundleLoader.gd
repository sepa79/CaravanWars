extends RefCounted
class_name MapBundleLoader

const SchemaPath := "res://mapgen/MapBundle_Schema.json"
const MapNodeModule = preload("res://mapview/MapNode.gd")
const EdgeModule = preload("res://mapview/Edge.gd")
const RegionModule = preload("res://mapview/Region.gd")

func load(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Failed to open %s" % path)
        return {}
    var text := file.get_as_text()
    file.close()
    var data = JSON.parse_string(text)
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid JSON in %s" % path)
        return {}
    var bundle: Dictionary = data
    if not _validate(bundle):
        push_error("Schema validation failed for %s" % path)
        return {}
    return _convert(bundle)

func _validate(bundle: Dictionary) -> bool:
    var schema_file := FileAccess.open(SchemaPath, FileAccess.READ)
    if schema_file:
        var schema_data = JSON.parse_string(schema_file.get_as_text())
        schema_file.close()
        if typeof(schema_data) == TYPE_DICTIONARY:
            var required: Array = schema_data.get("required", [])
            for key in required:
                if not bundle.has(key):
                    push_warning("Missing key %s" % key)
                    return false
            var meta_schema: Dictionary = schema_data.get("properties", {}).get("meta", {})
            var meta_required: Array = meta_schema.get("required", [])
            var meta: Dictionary = bundle.get("meta", {})
            for key in meta_required:
                if not meta.has(key):
                    push_warning("Missing meta.%s" % key)
                    return false
            return true
    # Fallback basic check
    var fallback := ["meta", "nodes", "edges", "cities", "villages", "crossings", "forts", "kingdoms", "climate_cells"]
    for key in fallback:
        if not bundle.has(key):
            push_warning("Missing key %s" % key)
            return false
    return bundle.get("meta", {}).has("version") and bundle.get("meta", {}).has("seed") and bundle.get("meta", {}).has("map_size")

func _convert(bundle: Dictionary) -> Dictionary:
    var map: Dictionary = {}
    var meta: Dictionary = bundle.get("meta", {})
    map["meta"] = meta
    var size: float = float(meta.get("map_size", 100))
    map["width"] = size
    map["height"] = size
    var nodes: Dictionary = {}
    for n in bundle.get("nodes", []):
        var pos := Vector2(n.get("x", 0.0), n.get("y", 0.0))
        nodes[n.get("id")] = MapNodeModule.new(n.get("id"), MapNodeModule.TYPE_CROSSROAD, pos, {})
    var cities: Array = []
    for c in bundle.get("cities", []):
        var pos := Vector2(c.get("x", 0.0), c.get("y", 0.0))
        nodes[c.get("id")] = MapNodeModule.new(c.get("id"), MapNodeModule.TYPE_CITY, pos, {"kingdom_id": c.get("kingdom_id", 0), "is_capital": c.get("is_capital", false)})
        cities.append(pos)
    for v in bundle.get("villages", []):
        var pos := Vector2(v.get("x", 0.0), v.get("y", 0.0))
        nodes[v.get("id")] = MapNodeModule.new(v.get("id"), MapNodeModule.TYPE_VILLAGE, pos, {"city_id": v.get("city_id", 0), "road_node_id": v.get("road_node_id", 0), "production": v.get("production", {})})
    for cr in bundle.get("crossings", []):
        var pos := Vector2(cr.get("x", 0.0), cr.get("y", 0.0))
        var ntype := MapNodeModule.TYPE_BRIDGE if cr.get("type", "bridge") == "bridge" else MapNodeModule.TYPE_FORD
        nodes[cr.get("id")] = MapNodeModule.new(cr.get("id"), ntype, pos, {"river_id": cr.get("river_id", null)})
    for f in bundle.get("forts", []):
        var pos := Vector2(f.get("x", 0.0), f.get("y", 0.0))
        nodes[f.get("id")] = MapNodeModule.new(f.get("id"), MapNodeModule.TYPE_FORT, pos, {"edge_id": f.get("edge_id", null), "crossing_id": f.get("crossing_id", null), "pair_id": f.get("pair_id", null)})
    var edges: Dictionary = {}
    for e in bundle.get("edges", []):
        var a: int = e.get("a")
        var b: int = e.get("b")
        var poly := [nodes[a].pos2d, nodes[b].pos2d]
        var cls: String = String(e.get("class", "Road")).to_lower()
        var attrs: Dictionary = {}
        if e.has("crossing_id") and e.get("crossing_id") != null:
            attrs["crossing_id"] = e.get("crossing_id")
        edges[e.get("id")] = EdgeModule.new(e.get("id"), "road", poly, [a, b], cls, attrs)
    map["roads"] = {"nodes": nodes, "edges": edges}
    map["cities"] = cities
    var rivers: Array = []
    for r in bundle.get("rivers", []):
        var poly: Array = []
        for p in r.get("polyline", []):
            poly.append(Vector2(p[0], p[1]))
        rivers.append(poly)
    map["rivers"] = rivers
    var regions: Dictionary = {}
    var kingdom_names: Dictionary = {}
    for k in bundle.get("kingdoms", []):
        var poly: Array = []
        for p in k.get("polygon", []):
            poly.append(Vector2(p[0], p[1]))
        var region := RegionModule.new(k.get("id"), poly, "", k.get("id"))
        regions[region.id] = region
        kingdom_names[region.id] = k.get("name", "")
    map["regions"] = regions
    map["kingdom_names"] = kingdom_names
    return map
