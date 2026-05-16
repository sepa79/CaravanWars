from __future__ import annotations

import json
import time
import urllib.request
from typing import Any


OLLAMA_URL = "http://127.0.0.1:11434/api/generate"


class LLMCallError(RuntimeError):
    pass


def call_ollama(model: str, prompt: str, timeout_seconds: int = 120, force_json: bool = True) -> dict[str, Any]:
    body: dict[str, Any] = {
        "model": model,
        "stream": False,
        "prompt": prompt,
    }
    if force_json:
        body["format"] = "json"

    request = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    started = time.perf_counter()
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        payload = json.loads(response.read().decode("utf-8"))
    elapsed_ms = int((time.perf_counter() - started) * 1000)

    raw_text = str(payload.get("response") or "").strip()
    try:
        result = json.loads(_strip_markdown_json(raw_text))
    except json.JSONDecodeError as exc:
        raise LLMCallError(f"Ollama returned non-JSON text: {raw_text}") from exc

    if not isinstance(result, dict):
        raise LLMCallError(f"Ollama JSON result must be an object: {raw_text}")

    return {
        "provider": "ollama",
        "model": model,
        "elapsed_ms": elapsed_ms,
        "result": result,
        "raw_text": raw_text,
    }


def _strip_markdown_json(text: str) -> str:
    stripped = text.strip()
    if stripped.startswith("```"):
        lines = stripped.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        return "\n".join(lines).strip()
    return stripped
