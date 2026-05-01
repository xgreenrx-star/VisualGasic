#!/usr/bin/env python3
"""
AI Correctness Benchmark — runner.

For each (prompt, language) pair, ask a model to write the program, save the
raw output, run a parse-check, and write a per-attempt JSON record.

Usage:
    python run_bench.py --model gpt-4o --prompts 3 --langs all
    python run_bench.py --model claude-3-5-sonnet-latest --prompts all --langs vg,python
    python run_bench.py --model llama3:8b --provider ollama --prompts all

Provider auto-detection is by env var:
    OPENAI_API_KEY      -> openai
    ANTHROPIC_API_KEY   -> anthropic
    GEMINI_API_KEY      -> gemini
    OLLAMA_URL          -> ollama (defaults to http://localhost:11434)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from urllib import request as urlreq
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parent.parent  # bench/ai_correctness/
PROMPTS_FILE = ROOT / "prompts" / "prompts.json"
RESULTS_DIR = ROOT / "results"
CHECKERS_DIR = ROOT / "checkers"

LANG_INFO = {
    "vg":         {"ext": ".vg",  "name": "VisualGasic", "checker": "check_vg.sh",
                   "note": "Use Sub Main() as the entry point. Output via Print. String concat with &."},
    "gdscript":   {"ext": ".gd",  "name": "GDScript",    "checker": "check_gdscript.sh",
                   "note": "Use a class extending SceneTree with func _init(). Output via print(). Use quit() to exit."},
    "python":     {"ext": ".py",  "name": "Python",      "checker": "check_python.sh",
                   "note": "Use a top-level if __name__ == '__main__': block. Output via print()."},
    "typescript": {"ext": ".ts",  "name": "TypeScript",  "checker": "check_typescript.sh",
                   "note": "Compile-checked under --strict. Output via console.log()."},
}

PROMPT_TEMPLATE = """Write a complete, self-contained {language} program that performs the following task:

{task}

Requirements:
- Output ONLY the raw source code, no Markdown fences, no commentary, no prose.
- The code must be syntactically correct and ready to compile/run as-is.
- {note}
"""


# ----------------------------- providers ---------------------------------- #

def detect_provider() -> str:
    if os.environ.get("OPENAI_API_KEY"):
        return "openai"
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    if os.environ.get("GEMINI_API_KEY"):
        return "gemini"
    if os.environ.get("OLLAMA_URL"):
        return "ollama"
    return "ollama"  # default to local


def call_model(provider: str, model: str, prompt: str, temperature: float = 0.2) -> str:
    """Return the raw text the model emitted, or raise on transport error."""
    if provider == "openai":
        return _call_openai(model, prompt, temperature)
    if provider == "anthropic":
        return _call_anthropic(model, prompt, temperature)
    if provider == "gemini":
        return _call_gemini(model, prompt, temperature)
    if provider == "ollama":
        return _call_ollama(model, prompt, temperature)
    raise ValueError(f"Unknown provider {provider!r}")


def _http_post_json(url: str, headers: dict, body: dict, timeout: int = 120) -> dict:
    data = json.dumps(body).encode("utf-8")
    req = urlreq.Request(url, data=data, headers={**headers, "Content-Type": "application/json"})
    with urlreq.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _call_openai(model: str, prompt: str, temperature: float) -> str:
    key = os.environ["OPENAI_API_KEY"]
    out = _http_post_json(
        "https://api.openai.com/v1/chat/completions",
        {"Authorization": f"Bearer {key}"},
        {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": temperature,
        },
    )
    return out["choices"][0]["message"]["content"]


def _call_anthropic(model: str, prompt: str, temperature: float) -> str:
    key = os.environ["ANTHROPIC_API_KEY"]
    out = _http_post_json(
        "https://api.anthropic.com/v1/messages",
        {"x-api-key": key, "anthropic-version": "2023-06-01"},
        {
            "model": model,
            "max_tokens": 2048,
            "temperature": temperature,
            "messages": [{"role": "user", "content": prompt}],
        },
    )
    return out["content"][0]["text"]


def _call_gemini(model: str, prompt: str, temperature: float) -> str:
    key = os.environ["GEMINI_API_KEY"]
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
    out = _http_post_json(
        url,
        {},
        {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": temperature},
        },
    )
    return out["candidates"][0]["content"]["parts"][0]["text"]


def _call_ollama(model: str, prompt: str, temperature: float) -> str:
    base = os.environ.get("OLLAMA_URL", "http://localhost:11434").rstrip("/")
    out = _http_post_json(
        f"{base}/api/generate",
        {},
        {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": temperature},
        },
        timeout=600,
    )
    return out.get("response", "")


# ----------------------------- post-processing ---------------------------- #

_FENCE = re.compile(r"```[a-zA-Z0-9_+-]*\n([\s\S]*?)```")


def strip_code_fence(text: str) -> str:
    """If the model wrapped output in ```...``` despite instructions, strip it."""
    text = text.strip()
    m = _FENCE.search(text)
    if m:
        return m.group(1).strip()
    return text


# ----------------------------- check loop --------------------------------- #

def run_checker(lang: str, file_path: Path) -> tuple[bool, str]:
    checker = CHECKERS_DIR / LANG_INFO[lang]["checker"]
    if not checker.exists():
        return False, f"checker missing: {checker}"
    try:
        proc = subprocess.run(
            ["bash", str(checker), str(file_path)],
            capture_output=True, text=True, timeout=60,
            cwd=ROOT.parent.parent,  # repo root, so check_vg.sh sees ./bin etc.
        )
    except subprocess.TimeoutExpired:
        return False, "timeout"
    ok = proc.returncode == 0
    msg = (proc.stderr or proc.stdout).strip()[:500]
    return ok, msg if not ok else "ok"


def render_prompt(lang: str, task: str) -> str:
    info = LANG_INFO[lang]
    return PROMPT_TEMPLATE.format(language=info["name"], task=task, note=info["note"])


# ----------------------------- main --------------------------------------- #

def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, help="Model identifier (e.g. gpt-4o-2024-08-06)")
    ap.add_argument("--provider", default=None, help="openai|anthropic|gemini|ollama (auto-detect if omitted)")
    ap.add_argument("--prompts", default="all", help="all | <int> | comma-list of IDs")
    ap.add_argument("--langs", default="all", help="all | comma-list of: vg,gdscript,python,typescript")
    ap.add_argument("--temperature", type=float, default=0.2)
    ap.add_argument("--out", default=None, help="Output dir (default: results/<model-slug>/)")
    args = ap.parse_args(argv)

    provider = args.provider or detect_provider()
    print(f"[bench] provider={provider} model={args.model}", file=sys.stderr)

    prompts = json.loads(PROMPTS_FILE.read_text())["prompts"]
    if args.prompts != "all":
        if args.prompts.isdigit():
            prompts = prompts[: int(args.prompts)]
        else:
            ids = set(args.prompts.split(","))
            prompts = [p for p in prompts if p["id"] in ids]

    if args.langs == "all":
        langs = list(LANG_INFO.keys())
    else:
        langs = [x.strip() for x in args.langs.split(",")]

    slug = re.sub(r"[^a-zA-Z0-9_-]+", "_", args.model)
    out_dir = Path(args.out) if args.out else RESULTS_DIR / slug
    out_dir.mkdir(parents=True, exist_ok=True)

    summary: list[dict] = []
    total = len(prompts) * len(langs)
    n = 0

    for prompt in prompts:
        for lang in langs:
            n += 1
            attempt_id = f"{prompt['id']}_{lang}"
            print(f"[{n}/{total}] {attempt_id}", file=sys.stderr)

            rendered = render_prompt(lang, prompt["task"])
            t0 = time.time()
            try:
                raw = call_model(provider, args.model, rendered, args.temperature)
                gen_err = None
            except (HTTPError, URLError, KeyError, IndexError, json.JSONDecodeError) as e:
                raw = ""
                gen_err = f"{type(e).__name__}: {e}"
            t_gen = time.time() - t0

            code = strip_code_fence(raw)
            ext = LANG_INFO[lang]["ext"]
            code_path = out_dir / f"{attempt_id}{ext}"
            code_path.write_text(code)

            if gen_err is not None or not code.strip():
                ok, msg = False, gen_err or "empty output"
            else:
                ok, msg = run_checker(lang, code_path)

            record = {
                "id": prompt["id"],
                "category": prompt["category"],
                "language": lang,
                "model": args.model,
                "provider": provider,
                "temperature": args.temperature,
                "task": prompt["task"],
                "code_file": code_path.name,
                "parse_ok": ok,
                "checker_msg": msg,
                "gen_seconds": round(t_gen, 2),
            }
            (out_dir / f"{attempt_id}.json").write_text(json.dumps(record, indent=2))
            summary.append(record)
            print(f"    -> parse_ok={ok}  ({msg if not ok else 'ok'})", file=sys.stderr)

    # Write a summary index
    (out_dir / "_summary.json").write_text(json.dumps(summary, indent=2))
    total_ok = sum(1 for r in summary if r["parse_ok"])
    print(f"\n[bench] DONE: {total_ok}/{len(summary)} parsed OK ({100*total_ok/max(1,len(summary)):.1f}%)",
          file=sys.stderr)
    print(f"[bench] results in: {out_dir}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
