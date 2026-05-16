from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class LLMOptions(BaseModel):
    provider: str = "ollama"
    model: str | None = None
    timeout_seconds: int = 120


class RumorRenderRequest(BaseModel):
    entry: dict[str, Any]
    speaker: dict[str, Any] = Field(default_factory=dict)
    listener: dict[str, Any] = Field(default_factory=dict)
    allowed_mutations: list[str] = Field(default_factory=list)
    forbidden_topics: list[str] = Field(default_factory=list)
    language: str = "English"
    llm: LLMOptions = Field(default_factory=lambda: LLMOptions(model="mistral"))


class NPCDecisionRequest(BaseModel):
    actor: dict[str, Any]
    memory: list[dict[str, Any]] = Field(default_factory=list)
    local_state: dict[str, Any] = Field(default_factory=dict)
    available_actions: list[str] = Field(default_factory=list)
    language: str = "English"
    llm: LLMOptions = Field(default_factory=lambda: LLMOptions(model="qwen3:8b"))


class ReportRenderRequest(BaseModel):
    speaker: dict[str, Any] = Field(default_factory=dict)
    task_result: dict[str, Any]
    style: str = "short in-character report"
    language: str = "English"
    llm: LLMOptions = Field(default_factory=lambda: LLMOptions(model="phi4"))


class PlayerIntentRequest(BaseModel):
    raw_input: str
    character: dict[str, Any] = Field(default_factory=dict)
    location: dict[str, Any] = Field(default_factory=dict)
    stance: str = "direct"
    language: str = "English"
    llm: LLMOptions = Field(default_factory=lambda: LLMOptions(model="qwen3:8b"))


class RawPromptRequest(BaseModel):
    prompt: str
    llm: LLMOptions = Field(default_factory=lambda: LLMOptions(model="qwen3:8b"))


class LLMResult(BaseModel):
    provider: str
    model: str
    elapsed_ms: int
    result: dict[str, Any]
    raw_text: str
