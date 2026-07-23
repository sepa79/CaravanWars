from __future__ import annotations

from typing import Any

from fastapi import FastAPI, HTTPException

from cw_llm.ollama_client import LLMCallError, call_ollama
from cw_llm.prompts import npc_decision_prompt, player_intent_prompt, render_rumor_prompt, report_prompt
from cw_llm.schemas import (
    LLMResult,
    NPCDecisionRequest,
    PlayerIntentRequest,
    RawPromptRequest,
    ReportRenderRequest,
    RumorRenderRequest,
)


app = FastAPI(title="CaravanWars LLM Service")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"ok": "true"}


@app.post("/raw", response_model=LLMResult)
async def raw_prompt(payload: RawPromptRequest) -> dict[str, Any]:
    return _call(payload.llm.model or "qwen3:8b", payload.prompt, payload.llm.timeout_seconds)


@app.post("/render-rumor", response_model=LLMResult)
async def render_rumor(payload: RumorRenderRequest) -> dict[str, Any]:
    prompt = render_rumor_prompt(
        payload.entry,
        payload.speaker,
        payload.listener,
        payload.allowed_mutations,
        payload.forbidden_topics,
        payload.language,
    )
    return _call(payload.llm.model or "mistral", prompt, payload.llm.timeout_seconds)


@app.post("/npc-decision", response_model=LLMResult)
async def npc_decision(payload: NPCDecisionRequest) -> dict[str, Any]:
    prompt = npc_decision_prompt(
        payload.actor,
        payload.memory,
        payload.local_state,
        payload.available_actions,
        payload.language,
    )
    response = _call(payload.llm.model or "qwen3:8b", prompt, payload.llm.timeout_seconds)
    chosen = response["result"].get("chosen_action")
    if payload.available_actions and chosen not in payload.available_actions:
        response["result"]["contract_warning"] = f"chosen_action {chosen!r} is not in available_actions"
    return response


@app.post("/render-report", response_model=LLMResult)
async def render_report(payload: ReportRenderRequest) -> dict[str, Any]:
    prompt = report_prompt(payload.speaker, payload.task_result, payload.style, payload.language)
    return _call(payload.llm.model or "phi4", prompt, payload.llm.timeout_seconds)


@app.post("/parse-player-intent", response_model=LLMResult)
async def parse_player_intent(payload: PlayerIntentRequest) -> dict[str, Any]:
    prompt = player_intent_prompt(
        payload.raw_input,
        payload.character,
        payload.location,
        payload.stance,
        payload.language,
    )
    return _call(payload.llm.model or "qwen3:8b", prompt, payload.llm.timeout_seconds)


def _call(model: str, prompt: str, timeout_seconds: int) -> dict[str, Any]:
    try:
        return call_ollama(model, prompt, timeout_seconds=timeout_seconds)
    except LLMCallError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
