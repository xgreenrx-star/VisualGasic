#!/usr/bin/env python3
"""Headless Chrome CDP debug for Godot web export."""
from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVE = ROOT / "scripts" / "serve_web_export.py"
DEFAULT_EXPORT = ROOT / "build" / "web" / "web_hello"

CHROME_CANDIDATES = (
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
)


def find_chrome() -> str | None:
    import shutil

    for name in CHROME_CANDIDATES:
        path = shutil.which(name)
        if path:
            return path
    return None

try:
    import websocket
except ImportError:
    print("Run: scripts/.venv-web-debug/bin/pip install websocket-client", file=sys.stderr)
    sys.exit(2)


def wait_url(url: str, timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status == 200:
                    return
        except (urllib.error.URLError, TimeoutError):
            time.sleep(0.2)
    raise TimeoutError(url)


def cdp_call(ws, msg_id: int, method: str, params: dict | None = None, timeout: float = 30.0):
    payload = {"id": msg_id, "method": method}
    if params:
        payload["params"] = params
    ws.send(json.dumps(payload))
    deadline = time.time() + timeout
    while time.time() < deadline:
        ws.settimeout(max(0.1, deadline - time.time()))
        try:
            raw = ws.recv()
        except websocket.WebSocketTimeoutException:
            continue
        msg = json.loads(raw)
        if msg.get("id") == msg_id:
            return msg_id + 1, msg
    raise TimeoutError(f"CDP timeout: {method}")


def main() -> int:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8777
    wait_ms = int(sys.argv[2]) if len(sys.argv) > 2 else 120_000
    export = Path(sys.argv[3]).resolve() if len(sys.argv) > 3 else DEFAULT_EXPORT
    cdp_port = 9224
    page_url = f"http://127.0.0.1:{port}/index.html"

    chrome_bin = find_chrome()
    if not chrome_bin:
        print("Chrome/Chromium not found (install google-chrome or chromium).", file=sys.stderr)
        return 2

    if not (export / "index.html").is_file():
        print(f"missing export: {export}", file=sys.stderr)
        return 1

    server = subprocess.Popen(
        [sys.executable, str(SERVE), str(export), "-p", str(port)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    chrome = subprocess.Popen(
        [
            chrome_bin,
            "--headless=new",
            "--no-sandbox",
            "--disable-gpu",
            "--enable-unsafe-swiftshader",
            f"--remote-debugging-port={cdp_port}",
            "--remote-allow-origins=*",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    logs: list[str] = []

    try:
        wait_url(page_url)
        time.sleep(1.5)
        req = urllib.request.Request(
            f"http://127.0.0.1:{cdp_port}/json/new?{page_url}",
            method="PUT",
        )
        with urllib.request.urlopen(req, timeout=30) as r:
            target = json.loads(r.read().decode())
        ws = websocket.create_connection(target["webSocketDebuggerUrl"], timeout=10)

        mid = 1
        for method in ("Runtime.enable", "Log.enable", "Page.enable"):
            mid, _ = cdp_call(ws, mid, method)

        print(f"Loading {page_url} — waiting {wait_ms} ms for WASM…")
        time.sleep(wait_ms / 1000.0)

        # Collect pending events
        ws.settimeout(0.2)
        for _ in range(200):
            try:
                msg = json.loads(ws.recv())
            except websocket.WebSocketTimeoutException:
                break
            if "method" not in msg:
                continue
            m = msg["method"]
            p = msg.get("params", {})
            if m == "Runtime.consoleAPICalled":
                args = " ".join(
                    str(a.get("value", a.get("description", a))) for a in p.get("args", [])
                )
                logs.append(f"[console.{p.get('type')}] {args}")
            elif m == "Log.entryAdded":
                e = p.get("entry", {})
                logs.append(f"[log.{e.get('level')}] {e.get('text', '')}")
            elif m == "Runtime.exceptionThrown":
                logs.append(f"[exception] {p.get('exceptionDetails', {})}")

        mid, res = cdp_call(
            ws,
            mid,
            "Runtime.evaluate",
            {
                "expression": """(() => {
                    const splash = !!document.getElementById('status-splash');
                    const notice = (document.getElementById('status-notice')||{}).innerText||'';
                    const isolated = typeof crossOriginIsolated!=='undefined'&&crossOriginIsolated;
                    let weatherOk = false;
                    try {
                        const xhr = new XMLHttpRequest();
                        xhr.open('GET', 'https://api.open-meteo.com/v1/forecast?latitude=40.7128&longitude=-74.0060&current_weather=true', false);
                        xhr.send();
                        weatherOk = xhr.status === 200 && (xhr.responseText||'').includes('current_weather');
                    } catch (e) {}
                    return { splash, notice, isolated, weatherOk };
                })()""",
                "returnByValue": True,
            },
        )
        state = res.get("result", {}).get("result", {}).get("value")
        ws.close()

        print("\n=== Page state ===")
        print(json.dumps(state, indent=2))
        print("\n=== Console / CDP (first 30) ===")
        for line in logs[:30]:
            print(line)
        print("\n=== Console / CDP (last 80) ===")
        for line in logs[-80:]:
            print(line)

        if not state:
            return 1
        if state.get("notice"):
            print("\nFAIL notice:", state["notice"], file=sys.stderr)
            return 1
        if state.get("splash"):
            print("\nFAIL: still on Godot splash.", file=sys.stderr)
            return 1
        http_fail = any(
            "VGHttpRequest" in line and ("timeout" in line or "Web fetch failed" in line)
            for line in logs
        )
        asyncify_abort = any("emscripten_sleep" in line for line in logs)
        xhr_block = any("InvalidAccessError" in line for line in logs)
        if http_fail or asyncify_abort or xhr_block:
            print("\nFAIL: HTTP / Asyncify error in console.", file=sys.stderr)
            return 1
        if state and not state.get("weatherOk"):
            print("\nFAIL: browser could not reach Open-Meteo (network/CORS).", file=sys.stderr)
            return 1
        print("\nOK: splash dismissed, Open-Meteo reachable.")
        return 0
    finally:
        chrome.terminate()
        server.terminate()
        for p in (chrome, server):
            try:
                p.wait(timeout=3)
            except subprocess.TimeoutExpired:
                p.kill()


if __name__ == "__main__":
    raise SystemExit(main())
