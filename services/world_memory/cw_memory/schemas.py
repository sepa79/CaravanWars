from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class ActorIn(BaseModel):
    id: str
    name: str
    kind: str = "npc"
    persona: str = ""
    stats: dict[str, Any] = Field(default_factory=dict)


class FactIn(BaseModel):
    id: str
    subject: str
    predicate: str
    object: str
    truth_status: str = "true"
    reliability: float = 1.0
    source: str = "simulation"
    valid_from: str | None = None
    valid_to: str | None = None


class KnownFactIn(BaseModel):
    actor_id: str
    fact_id: str
    belief_status: str = "believes"
    confidence: float = 0.5
    learned_from_actor_id: str | None = None
    notes: str = ""


class RelationshipIn(BaseModel):
    actor_id: str
    target_actor_id: str
    trust: int = 0
    fear: int = 0
    respect: int = 0
    notes: str = ""


class ConversationStartIn(BaseModel):
    id: str
    participant_actor_ids: list[str]
    location_id: str = ""


class ConversationTurnIn(BaseModel):
    speaker_actor_id: str
    rendered_line: str
    raw_intent: str = ""
    tone: str = ""
    memory_importance: int = 1


class MemoryEventIn(BaseModel):
    actor_id: str | None = None
    event_type: str
    text: str
    importance: int = 1


class DialogueContextRequest(BaseModel):
    player_actor_id: str
    npc_actor_id: str
    conversation_id: str | None = None
    query: str = ""
    limit: int = 8


class WorldEventIn(BaseModel):
    id: str
    event_type: str
    text: str
    location_id: str = ""
    occurred_at: str | None = None
    importance: float = 0.5
    reliability: float = 1.0
    tags: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class DomainEventIn(BaseModel):
    world_event: WorldEventIn


class MemoryEntryIn(BaseModel):
    id: str | None = None
    owner_id: str
    owner_kind: str = "actor"
    text: str
    kind: str = "heard_rumor"
    source_owner_id: str | None = None
    source_event_id: str | None = None
    heard_at_location_id: str = ""
    heard_at_time: str | None = None
    tags: list[str] = Field(default_factory=list)
    credibility: float = 0.5
    salience: float = 0.5
    freshness: float = 1.0
    repeat_chance: float = 0.5
    distortion: float = 0.0
    hop_count: int = 0
    source_chain: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class WorldEventMemoryIn(BaseModel):
    owner_id: str
    owner_kind: str = "actor"
    kind: str = "direct_knowledge"
    salience: float | None = None
    credibility: float | None = None


class MemoryTransferIn(BaseModel):
    from_owner_id: str
    to_owner_id: str
    to_owner_kind: str = "actor"
    location_id: str = ""
    occurred_at: str | None = None
    entry_ids: list[str] = Field(default_factory=list)
    max_entries: int = 3
    trust: float = 0.5
    listener_interest_tags: list[str] = Field(default_factory=list)
    distortion_noise: float = 0.08
    notes: str = ""


class DecisionContextRequest(BaseModel):
    owner_id: str
    limit: int = 12
    tags: list[str] = Field(default_factory=list)
