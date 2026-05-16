class_name PartyComposition
extends RefCounted

var foot_count: int = 0
var horse_count: int = 0
var wagon_count: int = 0
var pack_animal_count: int = 0
var guard_count: int = 0


static func from_dictionary(composition_dictionary: Dictionary) -> RefCounted:
    var composition: RefCounted = new()
    composition.foot_count = int(composition_dictionary.get("foot_count", 0))
    composition.horse_count = int(composition_dictionary.get("horse_count", 0))
    composition.wagon_count = int(composition_dictionary.get("wagon_count", 0))
    composition.pack_animal_count = int(composition_dictionary.get("pack_animal_count", 0))
    composition.guard_count = int(composition_dictionary.get("guard_count", 0))
    return composition


func to_dictionary() -> Dictionary:
    return {
        "foot_count": foot_count,
        "horse_count": horse_count,
        "wagon_count": wagon_count,
        "pack_animal_count": pack_animal_count,
        "guard_count": guard_count
    }
