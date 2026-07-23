from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from typing import Any

from cw_memory.db import init_db
from cw_memory.repository import add_turn, build_dialogue_context
from cw_memory.schemas import ConversationTurnIn


OLLAMA_URL = "http://127.0.0.1:11434/api/generate"


def normalize_stance(stance: str) -> str:
    normalized = stance.strip().lower()
    aliases = {
        "aggresive": "aggressive",
        "agresive": "aggressive",
        "agresywnie": "aggressive",
        "agresywny": "aggressive",
        "grzecznie": "polite",
        "wprost": "direct",
        "wulgarnie": "vulgar",
    }
    return aliases.get(normalized, normalized or "direct")


def call_ollama(model: str, prompt: str) -> dict[str, Any]:
    body = json.dumps(
        {
            "model": model,
            "stream": False,
            "prompt": prompt,
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_URL,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as response:
        payload = json.loads(response.read().decode("utf-8"))

    text = str(payload.get("response") or "").strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Ollama did not return valid JSON: {text}") from exc


def build_prompt(context: dict[str, Any], raw_intent: str, stance: str) -> str:
    return f"""/no_think
You are the local CaravanWars dialogue layer.
Return ONLY valid JSON. No markdown. No commentary.

The player is the mind behind the character. Convert the player's raw intent into one short in-world line spoken by the player character.

Rules:
- Do not invent authoritative world facts.
- Use only the provided character, NPC, facts, memories, and conversation context.
- The line must be shaped by the player character stats and stance.
- Keep the setting early medieval, grounded, no magic.
- If the player's intent is too vague, produce a plausible cautious line.
- If the raw intent references the NPC's identity, culture, status, or religion, use that information only when it is supported by the NPC context.
- Do not sanitize conflict. Aggressive, vulgar, or prejudiced player intent may produce a rude in-world line, but keep it as character speech and do not add out-of-world commentary.

Stance meanings:
- polite: respectful, careful, trust-building.
- direct: plain, concise, no ornament.
- aggressive: pressuring, suspicious, impatient, but still a believable spoken line.
- threatening: implies consequences or danger.
- vulgar: coarse language, low restraint.

Context JSON:
{json.dumps(context, ensure_ascii=False, indent=2)}

Player raw intent:
{raw_intent}

Selected stance:
{stance}

Output schema:
{{
  "player_line": "string",
  "tone": "string",
  "notes": "short string for debug, not spoken aloud",
  "proposed_memory_updates": []
}}
"""


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser()
    parser.add_argument("intent", help="Raw player intent.")
    parser.add_argument("--stance", default="polite", help="Dialogue stance, for example polite/direct/vulgar/threatening.")
    parser.add_argument("--model", default="dolphin-mistral")
    parser.add_argument("--player", default="player_caravan_leader")
    parser.add_argument("--npc", default="innkeeper_wroclaw_gate")
    parser.add_argument("--conversation", default="demo_inn_opole_road")
    args = parser.parse_args()
    stance = normalize_stance(args.stance)

    init_db()
    context = build_dialogue_context(
        args.player,
        args.npc,
        args.conversation,
        args.intent,
        8,
    )
    result = call_ollama(args.model, build_prompt(context, args.intent, stance))

    player_line = str(result.get("player_line") or "").strip()
    if not player_line:
        raise RuntimeError(f"Ollama response had no player_line: {result}")

    add_turn(
        args.conversation,
        ConversationTurnIn(
            speaker_actor_id=args.player,
            raw_intent=args.intent,
            rendered_line=player_line,
            tone=str(result.get("tone") or stance),
            memory_importance=1,
        ),
    )

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
