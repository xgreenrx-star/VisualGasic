#!/usr/bin/env python3
"""Visual Gasic — Cursor SDK bridge for Narcea Vibe Code (Tier 2).

Reads a JSON request file, streams NDJSON events to stdout:
  {"type":"token","text":"..."}
  {"type":"done","status":"finished"|"error"|...}
  {"type":"error","message":"..."}

Install: Vibe Code → ⚙️ → Install cursor-sdk (venv)
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
                "message": "No Cursor API key. Set it in Vibe Code → ⚙️ (visual_gasic/ai/cursor_key).",
            }
        )
        return 1

    cwd = str(req.get("cwd", os.getcwd())).strip() or os.getcwd()
    prompt = build_prompt(req)
    if not prompt:
        emit({"type": "error", "message": "Empty prompt."})
        return 1

    raw_images = req.get("images") or []
    image_payloads: list = []
    if isinstance(raw_images, list):
        for item in raw_images:
            if isinstance(item, str) and item.strip():
                image_payloads.append(item.strip())
            elif isinstance(item, dict):
                data = str(item.get("data", "")).strip()
                if data:
                    image_payloads.append(data)

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
            if image_payloads:
                try:
                    from cursor_sdk import SDKImage, UserMessage

                    sdk_images = [
                        SDKImage.data_image(b64, "image/png") for b64 in image_payloads
                    ]
                    run = agent.send(UserMessage(text=prompt, images=sdk_images))
                except Exception:
                    run = agent.send(
                        {
                            "text": prompt,
                            "images": [
                                {"data": b64, "mime_type": "image/png"}
                                for b64 in image_payloads
                            ],
                        }
                    )
            else:
                run = agent.send(prompt)
            # Status ERROR often carries the real reason (usage limit, billing)
            # on the stream message — RunResult.result is frequently empty.
            stream_error_detail = ""
            for message in run.messages():
                msg_type = getattr(message, "type", "")
                if msg_type == "status":
                    st = str(getattr(message, "status", "") or "")
                    detail = str(getattr(message, "message", "") or "").strip()
                    if detail and (
                        st.upper() in {"ERROR", "FAILED", "CANCELLED", "EXPIRED"}
                        or "limit" in detail.lower()
                        or "billing" in detail.lower()
                    ):
                        stream_error_detail = detail
                    continue
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
            status_s = str(getattr(status, "value", status))
            if status_s.endswith("error") or status_s == "error":
                # Mid-flight failure: no exception was raised, so Godot used to
                # show only a generic "Cursor agent run failed." Surface id +
                # status-stream / result text when the SDK provides them.
                parts: list[str] = ["Cursor agent run failed"]
                run_id = getattr(result, "id", None) or getattr(result, "run_id", None)
                if run_id:
                    parts.append(f"run_id={run_id}")
                detail = (
                    stream_error_detail
                    or str(getattr(result, "result", "") or "").strip()
                )
                if not detail:
                    # Last resort: local agent store sometimes keeps error_code.
                    detail = _lookup_local_run_error(cwd, str(run_id or ""))
                if detail:
                    parts.append(detail[:800])
                else:
                    parts.append(
                        "No assistant output. Check Cursor dashboard usage/billing "
                        "(composer-2.5 spend limit), API key (Vibe Code → ⚙️), "
                        "and network. ↗ Cursor (IDE) can still work when SDK "
                        "usage is exhausted."
                    )
                emit({"type": "error", "message": " — ".join(parts)})
                emit({"type": "done", "status": "error"})
                return 2
            emit({"type": "done", "status": status_s})
            return 0
    except Exception as exc:  # noqa: BLE001 — surface to Godot panel
        err_name = type(exc).__name__
        msg = str(exc).strip() or err_name
        retryable = getattr(exc, "is_retryable", None)
        code = getattr(exc, "code", None)
        extras: list[str] = []
        if code:
            extras.append(f"code={code}")
        if retryable is not None:
            extras.append(f"retryable={retryable}")
        if extras:
            msg = f"{msg} ({', '.join(extras)})"
        emit({"type": "error", "message": f"{err_name}: {msg}"})
        traceback.print_exc(file=sys.stderr)
        return 1


def _lookup_local_run_error(cwd: str, run_id: str) -> str:
    """Read error_code from the local sdk-agent-store when RunResult is empty."""
    if not run_id:
        return ""
    try:
        import sqlite3
        from pathlib import Path

        home = Path.home()
        # Cursor hashes cwd into ~/.cursor/projects/<slug>/sdk-agent-store/*/index.db
        projects = home / ".cursor" / "projects"
        if not projects.is_dir():
            return ""
        for db in projects.glob("*/sdk-agent-store/*/index.db"):
            try:
                con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
                try:
                    row = con.execute(
                        "SELECT error_code, result FROM runs WHERE run_id = ? LIMIT 1",
                        (run_id,),
                    ).fetchone()
                finally:
                    con.close()
            except Exception:
                continue
            if not row:
                continue
            for cell in row:
                text = str(cell or "").strip()
                if text:
                    return text
        # Also try matching by cwd path in agents.workspace_ref
        cwd_norm = os.path.abspath(cwd).rstrip("/") + "/"
        for db in projects.glob("*/sdk-agent-store/*/index.db"):
            try:
                con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
                try:
                    row = con.execute(
                        "SELECT r.error_code, r.result FROM runs r "
                        "JOIN agents a ON a.agent_id = r.agent_id "
                        "WHERE r.run_id = ? OR a.workspace_ref = ? "
                        "ORDER BY r.updated_at DESC LIMIT 1",
                        (run_id, cwd_norm),
                    ).fetchone()
                finally:
                    con.close()
            except Exception:
                continue
            if not row:
                continue
            for cell in row:
                text = str(cell or "").strip()
                if text:
                    return text
    except Exception:
        return ""
    return ""


if __name__ == "__main__":
    sys.exit(main())
