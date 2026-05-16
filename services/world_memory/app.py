from __future__ import annotations

from typing import Any

from fastapi import FastAPI, HTTPException

from cw_memory.db import init_db
from cw_memory.repository import (
    add_known_fact,
    add_memory_event,
    add_turn,
    add_world_event_to_memory,
    build_dialogue_context,
    build_decision_context,
    list_actors,
    list_known_facts,
    list_memory_entries,
    list_world_events,
    search_memory,
    start_conversation,
    transfer_memory,
    upsert_actor,
    upsert_fact,
    upsert_memory_entry,
    upsert_relationship,
    upsert_world_event,
)
from cw_memory.schemas import (
    ActorIn,
    ConversationStartIn,
    ConversationTurnIn,
    DecisionContextRequest,
    DialogueContextRequest,
    FactIn,
    KnownFactIn,
    MemoryEventIn,
    MemoryEntryIn,
    MemoryTransferIn,
    RelationshipIn,
    WorldEventIn,
    WorldEventMemoryIn,
)


app = FastAPI(title="CaravanWars World Memory")


@app.on_event("startup")
async def startup() -> None:
    init_db()


@app.get("/health")
async def health() -> dict[str, str]:
    return {"ok": "true"}


@app.get("/actors")
async def api_list_actors() -> list[dict[str, Any]]:
    return list_actors()


@app.post("/actors")
async def api_upsert_actor(payload: ActorIn) -> dict[str, Any]:
    return upsert_actor(payload)


@app.post("/facts")
async def api_upsert_fact(payload: FactIn) -> dict[str, Any]:
    return upsert_fact(payload)


@app.post("/known-facts")
async def api_add_known_fact(payload: KnownFactIn) -> dict[str, Any]:
    try:
        return add_known_fact(payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/actors/{actor_id}/known-facts")
async def api_known_facts(actor_id: str, limit: int = 20) -> list[dict[str, Any]]:
    return list_known_facts(actor_id, limit)


@app.post("/relationships")
async def api_upsert_relationship(payload: RelationshipIn) -> dict[str, Any]:
    try:
        return upsert_relationship(payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/conversations")
async def api_start_conversation(payload: ConversationStartIn) -> dict[str, Any]:
    try:
        return start_conversation(payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/conversations/{conversation_id}/turns")
async def api_add_turn(conversation_id: str, payload: ConversationTurnIn) -> dict[str, Any]:
    try:
        return add_turn(conversation_id, payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/memory-events")
async def api_add_memory_event(payload: MemoryEventIn) -> dict[str, Any]:
    return add_memory_event(payload)


@app.get("/memory-search")
async def api_search_memory(query: str, actor_id: str | None = None, limit: int = 10) -> list[dict[str, Any]]:
    return search_memory(actor_id, query, limit)


@app.post("/world-events")
async def api_upsert_world_event(payload: WorldEventIn) -> dict[str, Any]:
    return upsert_world_event(payload)


@app.get("/world-events")
async def api_list_world_events(limit: int = 20, location_id: str | None = None) -> list[dict[str, Any]]:
    return list_world_events(limit, location_id)


@app.post("/world-events/{event_id}/remember")
async def api_add_world_event_to_memory(event_id: str, payload: WorldEventMemoryIn) -> dict[str, Any]:
    try:
        return add_world_event_to_memory(event_id, payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/memory-entries")
async def api_upsert_memory_entry(payload: MemoryEntryIn) -> dict[str, Any]:
    try:
        return upsert_memory_entry(payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/memory-entries")
async def api_list_memory_entries(
    owner_id: str | None = None,
    limit: int = 20,
    tags: str = "",
) -> list[dict[str, Any]]:
    tag_list = [tag.strip() for tag in tags.split(",") if tag.strip()]
    return list_memory_entries(owner_id, limit, tag_list)


@app.get("/owners/{owner_id}/memory")
async def api_owner_memory(owner_id: str, limit: int = 20, tags: str = "") -> list[dict[str, Any]]:
    tag_list = [tag.strip() for tag in tags.split(",") if tag.strip()]
    return list_memory_entries(owner_id, limit, tag_list)


@app.post("/memory-transfer")
async def api_memory_transfer(payload: MemoryTransferIn) -> dict[str, Any]:
    try:
        return transfer_memory(payload)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/decision-context")
async def api_decision_context(payload: DecisionContextRequest) -> dict[str, Any]:
    return build_decision_context(payload.owner_id, payload.limit, payload.tags)


@app.post("/dialogue-context")
async def api_dialogue_context(payload: DialogueContextRequest) -> dict[str, Any]:
    try:
        return build_dialogue_context(
            payload.player_actor_id,
            payload.npc_actor_id,
            payload.conversation_id,
            payload.query,
            payload.limit,
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
