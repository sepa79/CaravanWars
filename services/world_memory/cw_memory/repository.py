from __future__ import annotations

import json
import re
import uuid
from typing import Any

from .db import connect, row_to_dict, rows_to_dicts
from .schemas import (
    ActorIn,
    ConversationStartIn,
    ConversationTurnIn,
    FactIn,
    KnownFactIn,
    MemoryEventIn,
    MemoryEntryIn,
    MemoryTransferIn,
    RelationshipIn,
    DomainEventIn,
    WorldEventIn,
    WorldEventMemoryIn,
)


def _clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def _json_list(value: str | None) -> list[Any]:
    if not value:
        return []
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        return []
    return parsed if isinstance(parsed, list) else []


def _json_dict(value: str | None) -> dict[str, Any]:
    if not value:
        return {}
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _decode_memory_entry(row: Any) -> dict[str, Any]:
    entry = row_to_dict(row) or {}
    if not entry:
        return entry
    entry["tags"] = _json_list(entry.pop("tags_json", "[]"))
    entry["source_chain"] = _json_list(entry.pop("source_chain_json", "[]"))
    entry["metadata"] = _json_dict(entry.pop("metadata_json", "{}"))
    return entry


def _decode_world_event(row: Any) -> dict[str, Any]:
    event = row_to_dict(row) or {}
    if not event:
        return event
    event["tags"] = _json_list(event.pop("tags_json", "[]"))
    event["metadata"] = _json_dict(event.pop("metadata_json", "{}"))
    return event


def upsert_actor(payload: ActorIn) -> dict[str, Any]:
    stats_json = json.dumps(payload.stats, ensure_ascii=False)
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO actors(id, name, kind, persona, stats_json)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                kind = excluded.kind,
                persona = excluded.persona,
                stats_json = excluded.stats_json,
                updated_at = CURRENT_TIMESTAMP
            """,
            (payload.id, payload.name, payload.kind, payload.persona, stats_json),
        )
    return get_actor(payload.id)


def get_actor(actor_id: str) -> dict[str, Any]:
    with connect() as conn:
        row = conn.execute("SELECT * FROM actors WHERE id = ?", (actor_id,)).fetchone()
    actor = row_to_dict(row)
    if actor is None:
        raise KeyError(f"actor {actor_id!r} not found")
    actor["stats"] = json.loads(actor.pop("stats_json") or "{}")
    return actor


def list_actors() -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute("SELECT * FROM actors ORDER BY id").fetchall()
    actors = rows_to_dicts(rows)
    for actor in actors:
        actor["stats"] = json.loads(actor.pop("stats_json") or "{}")
    return actors


def upsert_fact(payload: FactIn) -> dict[str, Any]:
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO world_facts(id, subject, predicate, object, truth_status, reliability, source, valid_from, valid_to)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                subject = excluded.subject,
                predicate = excluded.predicate,
                object = excluded.object,
                truth_status = excluded.truth_status,
                reliability = excluded.reliability,
                source = excluded.source,
                valid_from = excluded.valid_from,
                valid_to = excluded.valid_to,
                updated_at = CURRENT_TIMESTAMP
            """,
            (
                payload.id,
                payload.subject,
                payload.predicate,
                payload.object,
                payload.truth_status,
                payload.reliability,
                payload.source,
                payload.valid_from,
                payload.valid_to,
            ),
        )
        row = conn.execute("SELECT * FROM world_facts WHERE id = ?", (payload.id,)).fetchone()
    return row_to_dict(row) or {}


def add_known_fact(payload: KnownFactIn) -> dict[str, Any]:
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO actor_known_facts(actor_id, fact_id, belief_status, confidence, learned_from_actor_id, notes)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(actor_id, fact_id) DO UPDATE SET
                belief_status = excluded.belief_status,
                confidence = excluded.confidence,
                learned_from_actor_id = excluded.learned_from_actor_id,
                notes = excluded.notes
            """,
            (
                payload.actor_id,
                payload.fact_id,
                payload.belief_status,
                payload.confidence,
                payload.learned_from_actor_id,
                payload.notes,
            ),
        )
        row = conn.execute(
            """
            SELECT akf.*, wf.subject, wf.predicate, wf.object, wf.truth_status, wf.reliability, wf.source
            FROM actor_known_facts akf
            JOIN world_facts wf ON wf.id = akf.fact_id
            WHERE akf.actor_id = ? AND akf.fact_id = ?
            """,
            (payload.actor_id, payload.fact_id),
        ).fetchone()
    return row_to_dict(row) or {}


def list_known_facts(actor_id: str, limit: int = 20) -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT akf.*, wf.subject, wf.predicate, wf.object, wf.truth_status, wf.reliability, wf.source
            FROM actor_known_facts akf
            JOIN world_facts wf ON wf.id = akf.fact_id
            WHERE akf.actor_id = ?
            ORDER BY akf.learned_at DESC
            LIMIT ?
            """,
            (actor_id, limit),
        ).fetchall()
    return rows_to_dicts(rows)


def upsert_relationship(payload: RelationshipIn) -> dict[str, Any]:
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO relationships(actor_id, target_actor_id, trust, fear, respect, notes)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(actor_id, target_actor_id) DO UPDATE SET
                trust = excluded.trust,
                fear = excluded.fear,
                respect = excluded.respect,
                notes = excluded.notes,
                updated_at = CURRENT_TIMESTAMP
            """,
            (
                payload.actor_id,
                payload.target_actor_id,
                payload.trust,
                payload.fear,
                payload.respect,
                payload.notes,
            ),
        )
        row = conn.execute(
            "SELECT * FROM relationships WHERE actor_id = ? AND target_actor_id = ?",
            (payload.actor_id, payload.target_actor_id),
        ).fetchone()
    return row_to_dict(row) or {}


def start_conversation(payload: ConversationStartIn) -> dict[str, Any]:
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO conversations(id, location_id)
            VALUES (?, ?)
            ON CONFLICT(id) DO UPDATE SET location_id = excluded.location_id
            """,
            (payload.id, payload.location_id),
        )
        for actor_id in payload.participant_actor_ids:
            conn.execute(
                """
                INSERT OR IGNORE INTO conversation_participants(conversation_id, actor_id)
                VALUES (?, ?)
                """,
                (payload.id, actor_id),
            )
        row = conn.execute("SELECT * FROM conversations WHERE id = ?", (payload.id,)).fetchone()
    return row_to_dict(row) or {}


def add_turn(conversation_id: str, payload: ConversationTurnIn) -> dict[str, Any]:
    with connect() as conn:
        cursor = conn.execute(
            """
            INSERT INTO conversation_turns(conversation_id, speaker_actor_id, raw_intent, rendered_line, tone)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                conversation_id,
                payload.speaker_actor_id,
                payload.raw_intent,
                payload.rendered_line,
                payload.tone,
            ),
        )
        conn.execute(
            """
            INSERT INTO memory_events(actor_id, event_type, text, importance)
            VALUES (?, 'conversation_turn', ?, ?)
            """,
            (
                payload.speaker_actor_id,
                f"{conversation_id}: {payload.rendered_line}",
                payload.memory_importance,
            ),
        )
        row = conn.execute("SELECT * FROM conversation_turns WHERE id = ?", (cursor.lastrowid,)).fetchone()
    return row_to_dict(row) or {}


def recent_turns(conversation_id: str, limit: int = 12) -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT ct.*, a.name AS speaker_name
            FROM conversation_turns ct
            JOIN actors a ON a.id = ct.speaker_actor_id
            WHERE ct.conversation_id = ?
            ORDER BY ct.id DESC
            LIMIT ?
            """,
            (conversation_id, limit),
        ).fetchall()
    return list(reversed(rows_to_dicts(rows)))


def add_memory_event(payload: MemoryEventIn) -> dict[str, Any]:
    with connect() as conn:
        cursor = conn.execute(
            """
            INSERT INTO memory_events(actor_id, event_type, text, importance)
            VALUES (?, ?, ?, ?)
            """,
            (payload.actor_id, payload.event_type, payload.text, payload.importance),
        )
        row = conn.execute("SELECT * FROM memory_events WHERE id = ?", (cursor.lastrowid,)).fetchone()
    return row_to_dict(row) or {}


def search_memory(actor_id: str | None, query: str, limit: int = 10) -> list[dict[str, Any]]:
    words = re.findall(r"[\w-]+", query, flags=re.UNICODE)
    match_query = " OR ".join(words[:12])
    if not match_query:
        return []
    with connect() as conn:
        if actor_id:
            rows = conn.execute(
                """
                SELECT me.*
                FROM memory_entries_search ms
                JOIN memory_entries me ON me.rowid = ms.rowid
                WHERE memory_entries_search MATCH ? AND ms.owner_id = ?
                ORDER BY bm25(memory_entries_search)
                LIMIT ?
                """,
                (match_query, actor_id, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT me.*
                FROM memory_entries_search ms
                JOIN memory_entries me ON me.rowid = ms.rowid
                WHERE memory_entries_search MATCH ?
                ORDER BY bm25(memory_entries_search)
                LIMIT ?
                """,
                (match_query, limit),
            ).fetchall()
    return [_decode_memory_entry(row) for row in rows]


def upsert_world_event(payload: WorldEventIn) -> dict[str, Any]:
    tags_json = json.dumps(payload.tags, ensure_ascii=False)
    metadata_json = json.dumps(payload.metadata, ensure_ascii=False)
    with connect() as conn:
        if payload.occurred_at:
            conn.execute(
                """
                INSERT INTO world_events(id, event_type, text, location_id, occurred_at, importance, reliability, tags_json, metadata_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    event_type = excluded.event_type,
                    text = excluded.text,
                    location_id = excluded.location_id,
                    occurred_at = excluded.occurred_at,
                    importance = excluded.importance,
                    reliability = excluded.reliability,
                    tags_json = excluded.tags_json,
                    metadata_json = excluded.metadata_json
                """,
                (
                    payload.id,
                    payload.event_type,
                    payload.text,
                    payload.location_id,
                    payload.occurred_at,
                    payload.importance,
                    payload.reliability,
                    tags_json,
                    metadata_json,
                ),
            )
        else:
            conn.execute(
                """
                INSERT INTO world_events(id, event_type, text, location_id, importance, reliability, tags_json, metadata_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    event_type = excluded.event_type,
                    text = excluded.text,
                    location_id = excluded.location_id,
                    importance = excluded.importance,
                    reliability = excluded.reliability,
                    tags_json = excluded.tags_json,
                    metadata_json = excluded.metadata_json
                """,
                (
                    payload.id,
                    payload.event_type,
                    payload.text,
                    payload.location_id,
                    payload.importance,
                    payload.reliability,
                    tags_json,
                    metadata_json,
                ),
            )
        row = conn.execute("SELECT * FROM world_events WHERE id = ?", (payload.id,)).fetchone()
    return _decode_world_event(row)


def list_world_events(limit: int = 20, location_id: str | None = None) -> list[dict[str, Any]]:
    with connect() as conn:
        if location_id:
            rows = conn.execute(
                """
                SELECT * FROM world_events
                WHERE location_id = ?
                ORDER BY occurred_at DESC, created_at DESC
                LIMIT ?
                """,
                (location_id, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT * FROM world_events
                ORDER BY occurred_at DESC, created_at DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
    return [_decode_world_event(row) for row in rows]


def upsert_memory_entry(payload: MemoryEntryIn) -> dict[str, Any]:
    entry_id = payload.id or f"mem_{uuid.uuid4().hex[:16]}"
    tags_json = json.dumps(payload.tags, ensure_ascii=False)
    source_chain = payload.source_chain or ([payload.source_owner_id] if payload.source_owner_id else [])
    source_chain_json = json.dumps(source_chain, ensure_ascii=False)
    metadata_json = json.dumps(payload.metadata, ensure_ascii=False)
    with connect() as conn:
        columns = """
            id, owner_id, owner_kind, text, kind, source_owner_id, source_event_id,
            heard_at_location_id, tags_json, credibility, salience, freshness,
            repeat_chance, distortion, hop_count, source_chain_json, metadata_json
        """
        values = (
            entry_id,
            payload.owner_id,
            payload.owner_kind,
            payload.text,
            payload.kind,
            payload.source_owner_id,
            payload.source_event_id,
            payload.heard_at_location_id,
            tags_json,
            _clamp(payload.credibility),
            _clamp(payload.salience),
            _clamp(payload.freshness),
            _clamp(payload.repeat_chance),
            _clamp(payload.distortion),
            max(0, payload.hop_count),
            source_chain_json,
            metadata_json,
        )
        if payload.heard_at_time:
            conn.execute(
                f"""
                INSERT INTO memory_entries({columns}, heard_at_time)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    owner_id = excluded.owner_id,
                    owner_kind = excluded.owner_kind,
                    text = excluded.text,
                    kind = excluded.kind,
                    source_owner_id = excluded.source_owner_id,
                    source_event_id = excluded.source_event_id,
                    heard_at_location_id = excluded.heard_at_location_id,
                    heard_at_time = excluded.heard_at_time,
                    tags_json = excluded.tags_json,
                    credibility = excluded.credibility,
                    salience = excluded.salience,
                    freshness = excluded.freshness,
                    repeat_chance = excluded.repeat_chance,
                    distortion = excluded.distortion,
                    hop_count = excluded.hop_count,
                    source_chain_json = excluded.source_chain_json,
                    metadata_json = excluded.metadata_json,
                    updated_at = CURRENT_TIMESTAMP
                """,
                (*values, payload.heard_at_time),
            )
        else:
            conn.execute(
                f"""
                INSERT INTO memory_entries({columns})
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    owner_id = excluded.owner_id,
                    owner_kind = excluded.owner_kind,
                    text = excluded.text,
                    kind = excluded.kind,
                    source_owner_id = excluded.source_owner_id,
                    source_event_id = excluded.source_event_id,
                    heard_at_location_id = excluded.heard_at_location_id,
                    tags_json = excluded.tags_json,
                    credibility = excluded.credibility,
                    salience = excluded.salience,
                    freshness = excluded.freshness,
                    repeat_chance = excluded.repeat_chance,
                    distortion = excluded.distortion,
                    hop_count = excluded.hop_count,
                    source_chain_json = excluded.source_chain_json,
                    metadata_json = excluded.metadata_json,
                    updated_at = CURRENT_TIMESTAMP
                """,
                values,
            )
        row = conn.execute("SELECT * FROM memory_entries WHERE id = ?", (entry_id,)).fetchone()
    return _decode_memory_entry(row)


def add_world_event_to_memory(event_id: str, payload: WorldEventMemoryIn) -> dict[str, Any]:
    with connect() as conn:
        row = conn.execute("SELECT * FROM world_events WHERE id = ?", (event_id,)).fetchone()
    event = _decode_world_event(row)
    if not event:
        raise KeyError(f"world event {event_id!r} not found")
    return upsert_memory_entry(
        MemoryEntryIn(
            id=f"mem_{payload.owner_id}_{event_id}",
            owner_id=payload.owner_id,
            owner_kind=payload.owner_kind,
            text=event["text"],
            kind=payload.kind,
            source_event_id=event_id,
            heard_at_location_id=event["location_id"],
            tags=event["tags"],
            credibility=payload.credibility if payload.credibility is not None else event["reliability"],
            salience=payload.salience if payload.salience is not None else event["importance"],
            freshness=1.0,
            repeat_chance=_clamp(event["importance"] * 0.8),
            distortion=0.0,
            hop_count=0,
            source_chain=[event_id],
            metadata={"event_type": event["event_type"], "source": "world_event"},
        )
    )


def ingest_domain_event(payload: DomainEventIn) -> dict[str, Any]:
    world_event = upsert_world_event(payload.world_event)
    created_entries: list[dict[str, Any]] = []
    if world_event["event_type"] == "goods_transferred":
        created_entries = _memory_entries_for_goods_transferred(world_event)
    elif world_event["event_type"] == "location_economy_ticked":
        created_entries = _memory_entries_for_location_economy_ticked(world_event)
    elif world_event["event_type"] == "location_need_declared":
        created_entries = _memory_entries_for_location_need_declared(world_event)
    elif world_event["event_type"] == "worldsim_location_observed":
        created_entries = _memory_entries_for_worldsim_observation(world_event, "location_observation")
    elif world_event["event_type"] == "worldsim_party_observed":
        created_entries = _memory_entries_for_worldsim_observation(world_event, "party_observation")
    elif world_event["event_type"] == "worldsim_local_information_received":
        created_entries = _memory_entries_for_worldsim_local_information(world_event)
    elif world_event["event_type"] == "party_travel_started":
        created_entries = _memory_entries_for_party_travel_started(world_event)
    elif world_event["event_type"] == "party_arrived":
        created_entries = _memory_entries_for_party_arrived(world_event)
    elif world_event["event_type"] == "party_order_assigned":
        created_entries = _memory_entries_for_party_order_assigned(world_event)

    return {
        "world_event": world_event,
        "memory_entries": created_entries,
    }


def _memory_entries_for_goods_transferred(world_event: dict[str, Any]) -> list[dict[str, Any]]:
    metadata = world_event["metadata"]
    party_id = str(metadata.get("party_id", ""))
    location_id = str(metadata.get("location_id", world_event.get("location_id", "")))
    direction = str(metadata.get("direction", ""))
    if not party_id or not location_id:
        return []

    party_delta = int(metadata.get("amount", 0))
    location_delta = -party_delta
    if direction == "deposit_to_location":
        party_delta = -party_delta
        location_delta = -party_delta

    base_metadata = {
        **metadata,
        "source": "domain_event",
        "event_type": world_event["event_type"],
    }
    return [
        upsert_memory_entry(
            MemoryEntryIn(
                id=f"mem_{party_id}_{world_event['id']}",
                owner_id=party_id,
                owner_kind="party",
                text=_technical_text(world_event),
                kind="direct_observation",
                source_event_id=world_event["id"],
                heard_at_location_id=location_id,
                heard_at_time=world_event["occurred_at"],
                tags=world_event["tags"],
                credibility=world_event["reliability"],
                salience=world_event["importance"],
                freshness=1.0,
                repeat_chance=0.15,
                distortion=0.0,
                hop_count=0,
                source_chain=[world_event["id"]],
                metadata={
                    **base_metadata,
                    "perspective": "party",
                    "owner_goods_delta": party_delta,
                    "counterparty_id": location_id,
                    "counterparty_kind": "location",
                },
            )
        ),
        upsert_memory_entry(
            MemoryEntryIn(
                id=f"mem_{location_id}_{world_event['id']}",
                owner_id=location_id,
                owner_kind="location",
                text=_technical_text(world_event),
                kind="direct_observation",
                source_event_id=world_event["id"],
                heard_at_location_id=location_id,
                heard_at_time=world_event["occurred_at"],
                tags=world_event["tags"],
                credibility=world_event["reliability"],
                salience=world_event["importance"],
                freshness=1.0,
                repeat_chance=0.1,
                distortion=0.0,
                hop_count=0,
                source_chain=[world_event["id"]],
                metadata={
                    **base_metadata,
                    "perspective": "location",
                    "owner_goods_delta": location_delta,
                    "counterparty_id": party_id,
                    "counterparty_kind": "party",
                },
            )
        ),
    ]


def _memory_entries_for_location_economy_ticked(world_event: dict[str, Any]) -> list[dict[str, Any]]:
    metadata = world_event["metadata"]
    location_id = str(metadata.get("location_id", world_event.get("location_id", "")))
    if not location_id:
        return []
    return [
        upsert_memory_entry(
            MemoryEntryIn(
                id=f"mem_{location_id}_{world_event['id']}",
                owner_id=location_id,
                owner_kind="location",
                text=_technical_text(world_event),
                kind="resource_ledger",
                source_event_id=world_event["id"],
                heard_at_location_id=location_id,
                heard_at_time=world_event["occurred_at"],
                tags=world_event["tags"],
                credibility=world_event["reliability"],
                salience=world_event["importance"],
                freshness=1.0,
                repeat_chance=0.05,
                distortion=0.0,
                hop_count=0,
                source_chain=[world_event["id"]],
                metadata={**metadata, "source": "domain_event", "event_type": world_event["event_type"], "perspective": "location"},
            )
        )
    ]


def _memory_entries_for_location_need_declared(world_event: dict[str, Any]) -> list[dict[str, Any]]:
    metadata = world_event["metadata"]
    location_id = str(metadata.get("location_id", world_event.get("location_id", "")))
    if not location_id:
        return []
    return [
        upsert_memory_entry(
            MemoryEntryIn(
                id=f"mem_{location_id}_{world_event['id']}",
                owner_id=location_id,
                owner_kind="location",
                text=_technical_text(world_event),
                kind="need_ledger",
                source_event_id=world_event["id"],
                heard_at_location_id=location_id,
                heard_at_time=world_event["occurred_at"],
                tags=world_event["tags"],
                credibility=world_event["reliability"],
                salience=world_event["importance"],
                freshness=1.0,
                repeat_chance=0.2,
                distortion=0.0,
                hop_count=0,
                source_chain=[world_event["id"]],
                metadata={**metadata, "source": "domain_event", "event_type": world_event["event_type"], "perspective": "location"},
            )
        )
    ]


def _memory_entries_for_worldsim_observation(world_event: dict[str, Any], kind: str) -> list[dict[str, Any]]:
    metadata = world_event["metadata"]
    owner_id = str(metadata.get("owner_id", metadata.get("observer_party_id", "")))
    owner_kind = str(metadata.get("owner_kind", "party"))
    location_id = str(metadata.get("node_id", world_event.get("location_id", "")))
    if not owner_id:
        return []

    return [
        upsert_memory_entry(
            MemoryEntryIn(
                id=f"mem_{owner_id}_{world_event['id']}",
                owner_id=owner_id,
                owner_kind=owner_kind,
                text=_technical_text(world_event),
                kind=kind,
                source_event_id=world_event["id"],
                heard_at_location_id=location_id,
                heard_at_time=world_event["occurred_at"],
                tags=world_event["tags"],
                credibility=world_event["reliability"],
                salience=world_event["importance"],
                freshness=1.0,
                repeat_chance=0.1,
                distortion=0.0,
                hop_count=0,
                source_chain=[world_event["id"]],
                metadata={**metadata, "source": "worldsim_observation", "event_type": world_event["event_type"], "perspective": owner_kind},
            )
        )
    ]


def _memory_entries_for_worldsim_local_information(world_event: dict[str, Any]) -> list[dict[str, Any]]:
    metadata = world_event["metadata"]
    party_id = str(metadata.get("party_id", ""))
    location_id = str(metadata.get("location_id", world_event.get("location_id", "")))
    if not party_id:
        return []
    return [
        upsert_memory_entry(
            MemoryEntryIn(
                id=f"mem_{party_id}_{world_event['id']}",
                owner_id=party_id,
                owner_kind="party",
                text=_technical_text(world_event),
                kind="local_information",
                source_event_id=world_event["id"],
                heard_at_location_id=location_id,
                heard_at_time=world_event["occurred_at"],
                tags=world_event["tags"],
                credibility=world_event["reliability"],
                salience=world_event["importance"],
                freshness=1.0,
                repeat_chance=0.2,
                distortion=0.05,
                hop_count=0,
                source_chain=[world_event["id"]],
                metadata={**metadata, "source": "worldsim_local_information", "event_type": world_event["event_type"], "perspective": "party"},
            )
        )
    ]


def _memory_entries_for_party_travel_started(world_event: dict[str, Any]) -> list[dict[str, Any]]:
    metadata = world_event["metadata"]
    party_id = str(metadata.get("party_id", ""))
    if not party_id:
        return []
    return [_party_memory_entry(world_event, party_id, "travel_ledger", metadata)]


def _memory_entries_for_party_arrived(world_event: dict[str, Any]) -> list[dict[str, Any]]:
    metadata = world_event["metadata"]
    party_id = str(metadata.get("party_id", ""))
    if not party_id:
        return []
    return [_party_memory_entry(world_event, party_id, "travel_ledger", metadata)]


def _memory_entries_for_party_order_assigned(world_event: dict[str, Any]) -> list[dict[str, Any]]:
    metadata = world_event["metadata"]
    party_id = str(metadata.get("party_id", ""))
    issued_by_actor_id = str(metadata.get("issued_by_actor_id", ""))
    manager_actor_id = str(metadata.get("manager_actor_id", ""))
    target_location_id = str(metadata.get("target_location_id", ""))
    if not party_id:
        return []

    owner_specs: list[tuple[str, str, str]] = [(party_id, "party", "order_recipient")]
    if issued_by_actor_id:
        owner_specs.append((issued_by_actor_id, "actor", "order_issuer"))
    if manager_actor_id and manager_actor_id != issued_by_actor_id:
        owner_specs.append((manager_actor_id, "actor", "order_manager"))
    if target_location_id:
        owner_specs.append((target_location_id, "location", "order_target_location"))

    entries: list[dict[str, Any]] = []
    seen_owner_ids: set[str] = set()
    for owner_id, owner_kind, perspective in owner_specs:
        if owner_id in seen_owner_ids:
            continue
        seen_owner_ids.add(owner_id)
        entries.append(
            upsert_memory_entry(
                MemoryEntryIn(
                    id=f"mem_{owner_id}_{world_event['id']}",
                    owner_id=owner_id,
                    owner_kind=owner_kind,
                    text=_technical_text(world_event),
                    kind="order_ledger",
                    source_event_id=world_event["id"],
                    heard_at_location_id=world_event["location_id"],
                    heard_at_time=world_event["occurred_at"],
                    tags=world_event["tags"],
                    credibility=world_event["reliability"],
                    salience=world_event["importance"],
                    freshness=1.0,
                    repeat_chance=0.05,
                    distortion=0.0,
                    hop_count=0,
                    source_chain=[world_event["id"]],
                    metadata={**metadata, "source": "domain_event", "event_type": world_event["event_type"], "perspective": perspective},
                )
            )
        )
    return entries


def _party_memory_entry(world_event: dict[str, Any], party_id: str, kind: str, metadata: dict[str, Any]) -> dict[str, Any]:
    return upsert_memory_entry(
        MemoryEntryIn(
            id=f"mem_{party_id}_{world_event['id']}",
            owner_id=party_id,
            owner_kind="party",
            text=_technical_text(world_event),
            kind=kind,
            source_event_id=world_event["id"],
            heard_at_location_id=world_event["location_id"],
            heard_at_time=world_event["occurred_at"],
            tags=world_event["tags"],
            credibility=world_event["reliability"],
            salience=world_event["importance"],
            freshness=1.0,
            repeat_chance=0.1,
            distortion=0.0,
            hop_count=0,
            source_chain=[world_event["id"]],
            metadata={**metadata, "source": "domain_event", "event_type": world_event["event_type"], "perspective": "party"},
        )
    )


def _technical_text(world_event: dict[str, Any]) -> str:
    return world_event["text"] or f"{world_event['event_type']}:{world_event['id']}"


def list_memory_entries(
    owner_id: str | None = None,
    limit: int = 20,
    tags: list[str] | None = None,
) -> list[dict[str, Any]]:
    tags = tags or []
    with connect() as conn:
        if owner_id:
            rows = conn.execute(
                """
                SELECT * FROM memory_entries
                WHERE owner_id = ?
                ORDER BY salience DESC, freshness DESC, updated_at DESC
                LIMIT ?
                """,
                (owner_id, limit * 3 if tags else limit),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT * FROM memory_entries
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                (limit * 3 if tags else limit,),
            ).fetchall()
    entries = [_decode_memory_entry(row) for row in rows]
    if tags:
        wanted = set(tags)
        entries = [entry for entry in entries if wanted.intersection(entry["tags"])]
    deduped: list[dict[str, Any]] = []
    seen: set[tuple[str, str | None]] = set()
    for entry in entries:
        key = (entry["text"], entry.get("source_event_id"))
        if key in seen:
            continue
        seen.add(key)
        deduped.append(entry)
    return deduped[:limit]


def transfer_memory(payload: MemoryTransferIn) -> dict[str, Any]:
    if payload.entry_ids:
        placeholders = ",".join("?" for _ in payload.entry_ids)
        with connect() as conn:
            rows = conn.execute(
                f"""
                SELECT * FROM memory_entries
                WHERE owner_id = ? AND id IN ({placeholders})
                ORDER BY salience DESC, freshness DESC
                """,
                (payload.from_owner_id, *payload.entry_ids),
            ).fetchall()
        source_entries = [_decode_memory_entry(row) for row in rows]
    else:
        source_entries = list_memory_entries(payload.from_owner_id, payload.max_entries)

    interest = set(payload.listener_interest_tags)
    created: list[dict[str, Any]] = []
    for source in source_entries[: payload.max_entries]:
        tags = list(source["tags"])
        interest_bonus = 0.12 if interest.intersection(tags) else 0.0
        credibility = _clamp(float(source["credibility"]) * (0.55 + 0.45 * _clamp(payload.trust)))
        salience = _clamp(float(source["salience"]) + interest_bonus - 0.04)
        freshness = _clamp(float(source["freshness"]) * 0.92)
        distortion = _clamp(float(source["distortion"]) + payload.distortion_noise + (0.08 * (1.0 - _clamp(payload.trust))))
        repeat_chance = _clamp((salience * 0.65) + (freshness * 0.2) + 0.1)
        source_chain = list(source["source_chain"])
        if payload.from_owner_id not in source_chain:
            source_chain.append(payload.from_owner_id)
        transfer_entry_id = f"mem_{payload.to_owner_id}_{source['id']}_via_{payload.from_owner_id}"
        created.append(
            upsert_memory_entry(
                MemoryEntryIn(
                    id=transfer_entry_id,
                    owner_id=payload.to_owner_id,
                    owner_kind=payload.to_owner_kind,
                    text=source["text"],
                    kind="heard_rumor" if source["kind"] != "direct_knowledge" else "heard_report",
                    source_owner_id=payload.from_owner_id,
                    source_event_id=source.get("source_event_id"),
                    heard_at_location_id=payload.location_id or source["heard_at_location_id"],
                    heard_at_time=payload.occurred_at,
                    tags=tags,
                    credibility=credibility,
                    salience=salience,
                    freshness=freshness,
                    repeat_chance=repeat_chance,
                    distortion=distortion,
                    hop_count=int(source["hop_count"]) + 1,
                    source_chain=source_chain,
                    metadata={
                        **source["metadata"],
                        "transfer_notes": payload.notes,
                        "needs_rerender": distortion >= 0.35,
                    },
                )
            )
        )

    with connect() as conn:
        cursor = conn.execute(
            """
            INSERT INTO memory_transfer_jobs(
                from_owner_id, to_owner_id, location_id, occurred_at,
                selected_entry_ids_json, created_entry_ids_json, status, notes
            )
            VALUES (?, ?, ?, coalesce(?, CURRENT_TIMESTAMP), ?, ?, 'done', ?)
            """,
            (
                payload.from_owner_id,
                payload.to_owner_id,
                payload.location_id,
                payload.occurred_at,
                json.dumps([entry["id"] for entry in source_entries], ensure_ascii=False),
                json.dumps([entry["id"] for entry in created], ensure_ascii=False),
                payload.notes,
            ),
        )
        row = conn.execute("SELECT * FROM memory_transfer_jobs WHERE id = ?", (cursor.lastrowid,)).fetchone()
    job = row_to_dict(row) or {}
    job["selected_entry_ids"] = _json_list(job.pop("selected_entry_ids_json", "[]"))
    job["created_entry_ids"] = _json_list(job.pop("created_entry_ids_json", "[]"))
    return {"job": job, "created_entries": created}


def build_decision_context(owner_id: str, limit: int = 12, tags: list[str] | None = None) -> dict[str, Any]:
    return {
        "owner_id": owner_id,
        "memory": list_memory_entries(owner_id, limit, tags),
    }


def build_dialogue_context(
    player_actor_id: str,
    npc_actor_id: str,
    conversation_id: str | None,
    query: str,
    limit: int,
) -> dict[str, Any]:
    player = get_actor(player_actor_id)
    npc = get_actor(npc_actor_id)
    return {
        "player": player,
        "npc": npc,
        "npc_known_facts": list_known_facts(npc_actor_id, limit),
        "player_known_facts": list_known_facts(player_actor_id, limit),
        "npc_relevant_memories": search_memory(npc_actor_id, query, limit) if query else [],
        "recent_turns": recent_turns(conversation_id, limit) if conversation_id else [],
    }
