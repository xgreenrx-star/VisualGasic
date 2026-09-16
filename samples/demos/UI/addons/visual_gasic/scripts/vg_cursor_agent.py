#!/usr/bin/env python3
"""Visual Gasic — Cursor SDK bridge for Narcea AI Pair (Tier 2).

Reads a JSON request file, streams NDJSON events to stdout:
  {"type":"token","text":"..."}
  {"type":"done","status":"finished"|"error"|...}
  {"type":"error","message":"..."}

Install: AI Pair → ⚙️ → Install cursor-sdk (venv)
  Windows:  py -3 -m venv <user_data>/vg_cursor_venv && Scripts\\pip install cursor-sdk
  Linux/mac: python3 -m venv <user_data>/vg_cursor_venv && bin/pip install cursor-sdk
API key: Cursor Dashboard → Integrations (CURSOR_API_KEY)
"""

from __future__ import annotations

import json
import os
import sys
import traceback


def emit(obj: dict) -> None:
    print(json.dumps(obj, ensure_ascii=False), flush=True)


def build_prompt(req: dict) -> str:
    system = str(req.get("system_prompt", "")).strip()
    user_prompt = str(req.get("user_prompt", "")).strip()
    history = req.get("conversation_history") or []
    parts: list[str] = []
    if system:
        parts.append(system)
        parts.append("")
    if history:
        parts.append("Previous conversation:")
        for entry in history[-6:]:
            if not isinstance(entry, dict):
                continue
            role = str(entry.get("role", "user")).capitalize()
            content = str(entry.get("content", "")).strip()
            if content:
                parts.append(f"{role}: {content}")
        parts.append("")
    parts.append("Current request:")
    parts.append(user_prompt)
    return "\n".join(parts).strip()


def resolve_model(req: dict):
    model_id = str(req.get("model", "composer-2.5"))
    use_fast = bool(req.get("use_fast", False))
    if model_id.endswith("-fast"):
        use_fast = True
        model_id = model_id.removesuffix("-fast")
    try:
        from cursor_sdk import ModelParameterValue, ModelSelection

        return ModelSelection(
            id=model_id,
            params=(ModelParameterValue(id="fast", value="true" if use_fast else "false"),),
        )
    except Exception:
        return model_id


def main() -> int:
    if len(sys.argv) < 2:
        emit({"type": "error", "message": "Usage: vg_cursor_agent.py <request.json>"})
        return 1

    request_path = sys.argv[1]
    try:
        with open(request_path, encoding="utf-8") as fh:
            req = json.load(fh)
    except OSError as exc:
        emit({"type": "error", "message": f"Could not read request file: {exc}"})
        return 1
    except json.JSONDecodeError as exc:
        emit({"type": "error", "message": f"Invalid request JSON: {exc}"})
        return 1

    api_key = str(req.get("api_key", "")).strip() or os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key:
        emit(
            {
                "type": "error",
                "message": "No Cursor API key. Set it in AI Pair → ⚙️ (visual_gasic/ai/cursor_key).",
            }
        )
        return 1

    cwd = str(req.get("cwd", os.getcwd())).strip() or os.getcwd()
    prompt = build_prompt(req)
    if not prompt:
        emit({"type": "error", "message": "Empty prompt."})
        return 1

    try:
        from cursor_sdk import Agent, LocalAgentOptions
    except ImportError:
        emit(
            {
                "type": "error",
                "message": "cursor-sdk not installed. Run: pip install cursor-sdk",
            }
        )
        return 1

    model = resolve_model(req)

    try:
        with Agent.create(
            api_key=api_key,
            model=model,
            local=LocalAgentOptions(cwd=cwd),
        ) as agent:
            run = agent.send(prompt)
            for message in run.messages():
                msg_type = getattr(message, "type", "")
                if msg_type != "assistant":
                    continue
                content = getattr(getattr(message, "message", None), "content", None)
                if not content:
                    continue
                for block in content:
                    block_type = getattr(block, "type", "")
                    if block_type != "text":
                        continue
                    text = getattr(block, "text", "")
                    if text:
                        emit({"type": "token", "text": text})
            result = run.wait()
            status = getattr(result, "status", "finished")
            emit({"type": "done", "status": str(status)})
            if str(status) == "error":
                return 2
            return 0
    except Exception as exc:  # noqa: BLE001 — surface to Godot panel
        emit({"type": "error", "message": str(exc)})
        traceback.print_exc(file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
