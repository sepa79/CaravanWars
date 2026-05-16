class_name WorldSimObservationService
extends RefCounted

const MIN_RESOURCE_DETAIL_SCORE: int = 2


func observe_local_context(server: RefCounted, observer_party_id: String) -> Dictionary:
    if not server.state.has_party(observer_party_id):
        return {
            "accepted": false,
            "error_code": "observer_party_not_found"
        }

    var observer_party: RefCounted = server.state.get_party(observer_party_id)
    var observation_score: int = _observation_score(observer_party)
    var emitted_event_count: int = 0

    for location: RefCounted in server.state.get_locations_at_node(observer_party.current_node_id):
        var observed_resources: Dictionary = {}
        if observation_score >= MIN_RESOURCE_DETAIL_SCORE:
            observed_resources = location.resources.duplicate(true)
        server.record_worldsim_observation(
            "worldsim_location_observed",
            observer_party_id,
            "Party %s observed location %s." % [observer_party_id, location.location_id],
            {
                "observer_party_id": observer_party_id,
                "owner_id": observer_party_id,
                "owner_kind": "party",
                "node_id": observer_party.current_node_id,
                "observed_location_id": location.location_id,
                "observed_location_type": location.location_type,
                "observed_manager_actor_id": location.manager_actor_id,
                "observation_score": observation_score,
                "observed_resources": observed_resources
            }
        )
        emitted_event_count += 1

    for visible_party: Dictionary in server.get_visible_parties_for_party(observer_party_id):
        server.record_worldsim_observation(
            "worldsim_party_observed",
            observer_party_id,
            "Party %s observed party %s." % [observer_party_id, str(visible_party.get("party_id", ""))],
            {
                "observer_party_id": observer_party_id,
                "owner_id": observer_party_id,
                "owner_kind": "party",
                "node_id": observer_party.current_node_id,
                "observed_party_id": str(visible_party.get("party_id", "")),
                "observed_party_type": str(visible_party.get("party_type", "")),
                "observed_manager_actor_id": str(visible_party.get("manager_actor_id", "")),
                "observation_score": observation_score
            }
        )
        emitted_event_count += 1

    return {
        "accepted": true,
        "observer_party_id": observer_party_id,
        "observation_score": observation_score,
        "emitted_event_count": emitted_event_count
    }


func _observation_score(party: RefCounted) -> int:
    var score: int = 1
    score += mini(int(party.composition.guard_count), 2)
    if int(party.composition.horse_count) > 0:
        score += 1
    return score
