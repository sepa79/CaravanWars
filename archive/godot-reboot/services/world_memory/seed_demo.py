from __future__ import annotations

from cw_memory.db import init_db
from cw_memory.repository import (
    add_known_fact,
    add_memory_event,
    add_world_event_to_memory,
    start_conversation,
    upsert_actor,
    upsert_fact,
    upsert_memory_entry,
    upsert_relationship,
    upsert_world_event,
)
from cw_memory.schemas import (
    ActorIn,
    ConversationStartIn,
    FactIn,
    KnownFactIn,
    MemoryEntryIn,
    MemoryEventIn,
    RelationshipIn,
    WorldEventIn,
    WorldEventMemoryIn,
)


def main() -> None:
    init_db()

    upsert_actor(
        ActorIn(
            id="player_caravan_leader",
            name="Miroslav",
            kind="player_character",
            persona="Drobny kupiec prowadzący małą karawanę. Ostrożny, ale ciekawy wieści z dróg.",
            stats={"diplomacy": 7, "intelligence": 6, "knowledge": 5, "intimidation": 3},
        )
    )
    upsert_actor(
        ActorIn(
            id="innkeeper_wroclaw_gate",
            name="Izaak",
            kind="npc",
            persona=(
                "Żydowski dzierżawca karczmy przy drodze do Wrocławia. "
                "Słucha podróżnych, pamięta długi i nie ufa obcym od razu. "
                "Jest przyzwyczajony do niechęci i ostrożnie waży każde słowo."
            ),
            stats={"caution": 8, "greed": 5, "local_knowledge": 8, "pride": 6},
        )
    )
    upsert_actor(
        ActorIn(
            id="zenek_escort_captain",
            name="Zenek",
            kind="retainer",
            persona=(
                "Dowódca eskorty Miroslava. Najemnik, który rozumie karczmy, przemoc i rachunek zysków. "
                "Nie jest rycerzem ani idealistą. Ma dopilnować, żeby ludzie zjedli, żeby pan był zadowolony, "
                "i żeby nie przepłacić więcej niż musi. Jeśli coś zostaje z powierzonych pieniędzy, traktuje to "
                "jako uczciwą premię za załatwienie sprawy."
            ),
            stats={
                "intimidation": 7,
                "bargaining": 6,
                "loyalty": 6,
                "greed": 6,
                "streetwise": 8,
                "violence": 7,
            },
        )
    )
    upsert_actor(
        ActorIn(
            id="party_boruta",
            name="Ludzie Boruty",
            kind="party",
            persona=(
                "Mała grupa drogowych ludzi pod wodzą Boruty. Szukają okazji przy trakcie do Opola, "
                "ale nie chcą frontalnej walki z silną eskortą."
            ),
            stats={"caution": 7, "hunger": 6, "violence": 6, "scouting": 6, "greed": 7},
        )
    )

    upsert_fact(
        FactIn(
            id="road_opole_bandit_rumor",
            subject="road:wroclaw_opole",
            predicate="has_rumor",
            object="Two merchant wagons disappeared three days ago near a wooded stretch.",
            truth_status="rumor",
            reliability=0.55,
            source="traveler gossip",
        )
    )
    add_known_fact(
        KnownFactIn(
            actor_id="innkeeper_wroclaw_gate",
            fact_id="road_opole_bandit_rumor",
            confidence=0.65,
            notes="He heard it from two separate wagoners, but neither saw the attack.",
        )
    )
    upsert_relationship(
        RelationshipIn(
            actor_id="innkeeper_wroclaw_gate",
            target_actor_id="player_caravan_leader",
            trust=-1,
            fear=0,
            respect=1,
            notes="New face, appears to be a minor merchant. Izaak expects outsiders to test how much disrespect he will tolerate.",
        )
    )
    upsert_relationship(
        RelationshipIn(
            actor_id="zenek_escort_captain",
            target_actor_id="player_caravan_leader",
            trust=3,
            fear=1,
            respect=4,
            notes="Miroslav pays Zenek and his men. Zenek is loyal while paid, fed, and not humiliated.",
        )
    )
    upsert_relationship(
        RelationshipIn(
            actor_id="innkeeper_wroclaw_gate",
            target_actor_id="zenek_escort_captain",
            trust=-1,
            fear=2,
            respect=1,
            notes="Izaak recognizes Zenek as a practical armed man, dangerous but easier to bargain with than a drunk noble.",
        )
    )
    start_conversation(
        ConversationStartIn(
            id="demo_inn_opole_road",
            participant_actor_ids=["player_caravan_leader", "innkeeper_wroclaw_gate", "zenek_escort_captain"],
            location_id="wroclaw_gate_inn",
        )
    )
    add_memory_event(
        MemoryEventIn(
            actor_id="innkeeper_wroclaw_gate",
            event_type="npc_memory",
            text="Radomir dislikes being pressed for names of informants.",
            importance=2,
        )
    )

    upsert_world_event(
        WorldEventIn(
            id="event_miroslav_depart_opole",
            event_type="caravan_departure_plan",
            text="Miroslav's caravan leaves for Opole tomorrow morning.",
            location_id="wroclaw_gate_inn",
            importance=0.8,
            reliability=1.0,
            tags=["caravan", "miroslav", "opole", "departure"],
            metadata={"objective": True},
        )
    )
    add_world_event_to_memory(
        "event_miroslav_depart_opole",
        WorldEventMemoryIn(
            owner_id="zenek_escort_captain",
            kind="direct_knowledge",
            credibility=1.0,
            salience=0.85,
        ),
    )
    upsert_memory_entry(
        MemoryEntryIn(
            id="mem_zenek_opole_missing_wagons",
            owner_id="zenek_escort_captain",
            text="Two wagons are said to have vanished on the road to Opole last week.",
            kind="heard_rumor",
            source_owner_id="unknown_wagoners",
            heard_at_location_id="wroclaw_gate_inn",
            tags=["opole_road", "danger", "missing_wagons"],
            credibility=0.45,
            salience=0.7,
            freshness=0.8,
            repeat_chance=0.55,
            distortion=0.18,
            hop_count=1,
            source_chain=["unknown_wagoners"],
        )
    )
    upsert_memory_entry(
        MemoryEntryIn(
            id="mem_izaak_northern_merchants_rain",
            owner_id="innkeeper_wroclaw_gate",
            text="Northern merchants pay better when they are hurrying before rain.",
            kind="tavern_rumor",
            source_owner_id="regular_guests",
            heard_at_location_id="wroclaw_gate_inn",
            tags=["merchants", "weather", "money"],
            credibility=0.5,
            salience=0.4,
            freshness=0.7,
            repeat_chance=0.45,
            distortion=0.22,
            hop_count=2,
            source_chain=["regular_guests"],
        )
    )
    upsert_memory_entry(
        MemoryEntryIn(
            id="mem_boruta_opole_easy_profit",
            owner_id="party_boruta",
            owner_kind="party",
            text="The Opole road sometimes gives easy profit to men who watch from the trees.",
            kind="party_memory",
            source_owner_id="old_experience",
            heard_at_location_id="opole_road",
            tags=["opole_road", "money", "opportunity"],
            credibility=0.6,
            salience=0.55,
            freshness=0.5,
            repeat_chance=0.5,
            distortion=0.1,
            hop_count=0,
            source_chain=["old_experience"],
        )
    )

    print("Seeded demo memory database.")


if __name__ == "__main__":
    main()
