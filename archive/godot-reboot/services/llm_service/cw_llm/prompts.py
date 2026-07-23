from __future__ import annotations

import json
from typing import Any


DEFAULT_FORBIDDEN = [
    "magic",
    "monsters",
    "treasure unless explicitly present",
    "war unless explicitly present",
    "bandits unless explicitly present",
    "modern wording",
]


def json_block(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2)


def render_rumor_prompt(
    entry: dict[str, Any],
    speaker: dict[str, Any],
    listener: dict[str, Any],
    allowed_mutations: list[str],
    forbidden_topics: list[str],
    language: str,
) -> str:
    mutations = allowed_mutations or [
        "time_uncertain",
        "more_wagons",
        "fewer_wagons",
        "hurry",
        "trade_goods",
        "valuable_goods",
        "empty_wagons",
        "price_higher",
        "delay",
        "suspicion",
        "patrol",
        "threat_uncertain",
    ]
    forbidden = forbidden_topics or DEFAULT_FORBIDDEN
    return f"""/no_think
Return raw JSON only. No markdown.

You rewrite one private memory entry as a rumor for an AD 750 caravan simulation.
Do not make objective world facts. This is only how the listener may hear the rumor.

Language: {language}

Rules:
- Keep the core anchors from the input entry recognizable.
- Use only allowed mutation families.
- Distortion controls how much the wording drifts, not permission to invent freely.
- Do not add forbidden topics.
- Do not include mutation tag names inside the spoken text.

Allowed mutations:
{json_block(mutations)}

Forbidden topics:
{json_block(forbidden)}

Memory entry:
{json_block(entry)}

Speaker:
{json_block(speaker)}

Listener:
{json_block(listener)}

Return schema:
{{
  "text": "rewritten rumor text",
  "used_mutations": ["mutation_name"],
  "added_tags": ["tag"],
  "warnings": [],
  "contract_ok": true
}}
"""


def npc_decision_prompt(
    actor: dict[str, Any],
    memory: list[dict[str, Any]],
    local_state: dict[str, Any],
    available_actions: list[str],
    language: str,
) -> str:
    return f"""/no_think
Return raw JSON only. No markdown.

You are proposing one action for an AD 750 CaravanWars NPC or party.
You do not know objective truth unless it appears in local_state.
Use the actor's private memory as beliefs, rumors, fears, and motives.

Language: {language}

Rules:
- Choose exactly one action from available_actions.
- Do not invent resources, routes, or enemies.
- If memory is uncertain, choose cautious actions such as scout, shadow, ask, wait, or ignore.
- The simulation will validate your proposal.

Actor:
{json_block(actor)}

Private memory:
{json_block(memory)}

Local state:
{json_block(local_state)}

Available actions:
{json_block(available_actions)}

Return schema:
{{
  "chosen_action": "one available action",
  "reasoning_summary": "short",
  "memory_used": ["short memory references"],
  "risk": "low|medium|high",
  "expected_payoff": "low|medium|high|unknown",
  "confidence": 0.0,
  "new_intent_memory": "short memory sentence"
}}
"""


def report_prompt(speaker: dict[str, Any], task_result: dict[str, Any], style: str, language: str) -> str:
    return f"""/no_think
Return raw JSON only. No markdown.

Render a report for an AD 750 CaravanWars character.
The task_result is already decided by simulation. Do not change facts.

Language: {language}
Style: {style}

Speaker:
{json_block(speaker)}

Task result:
{json_block(task_result)}

Return schema:
{{
  "report_line": "short in-character report",
  "private_note": "short debug note",
  "facts_preserved": true,
  "warnings": []
}}
"""


def player_intent_prompt(
    raw_input: str,
    character: dict[str, Any],
    location: dict[str, Any],
    stance: str,
    language: str,
) -> str:
    return f"""/no_think
Return raw JSON only. No markdown.

Parse raw player input into structured intent for an AD 750 CaravanWars simulation.
The player is the mind behind the character. Do not render final speech here.

Language: {language}
Selected stance: {stance}

Character:
{json_block(character)}

Location and available actions:
{json_block(location)}

Raw player input:
{raw_input}

Return schema:
{{
  "literal_intent": "string",
  "social_intent": "string",
  "speech_act": "request|command|threat|bribe|insult|question|delegate_task|other",
  "target": "string",
  "matched_actions": ["action_id"],
  "tone": "polite|direct|aggressive|threatening|vulgar|evasive",
  "needs_clarification": false,
  "clarification_question": "",
  "renderer_instruction": "short instruction"
}}
"""
