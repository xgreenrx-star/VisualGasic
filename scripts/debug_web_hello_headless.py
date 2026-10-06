#!/usr/bin/env python3
"""Headless browser smoke for build/web/web_hello — logs console + splash state."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVE = ROOT / "scripts" / "serve_web_export.py"


def wait_http(url: str, timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status == 200:
                    return
        except (urllib.error.URLError, TimeoutError):
            time.sleep(0.25)
    raise TimeoutError(f"server not up: {url}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dir",
        type=Path,
        default=ROOT / "build" / "web" / "web_hello",
        help="Export folder with index.html",
    )
    parser.add_argument("--port", type=int, default=8777)
    parser.add_argument("--wait-ms", type=int, default=120_000)
    args = parser.parse_args()

    export_dir = args.dir.resolve()
    if not (export_dir / "index.html").is_file():
        print(f"error: missing {export_dir}/index.html", file=sys.stderr)
        return 1

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "playwright not installed. Run: pip install playwright && playwright install chromium",
            file=sys.stderr,
        )
        return 2

    server = subprocess.Popen(
        [sys.executable, str(SERVE), str(export_dir), "-p", str(args.port)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    url = f"http://127.0.0.1:{args.port}/index.html"
    logs: list[str] = []

    try:
        wait_http(url)
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True, args=["--enable-unsafe-swiftshader"])
            page = browser.new_page()

            def on_console(msg):
                logs.append(f"[console.{msg.type}] {msg.text}")

            def on_page_error(err):
                logs.append(f"[pageerror] {err}")

            def on_request_failed(req):
                logs.append(f"[requestfailed] {req.url} — {req.failure}")

            page.on("console", on_console)
            page.on("pageerror", on_page_error)
            page.on("requestfailed", on_request_failed)

            print(f"Loading {url} (wait {args.wait_ms} ms)...")
            page.goto(url, wait_until="domcontentloaded", timeout=60_000)
            page.wait_for_timeout(args.wait_ms)

            state = page.evaluate(
                """() => ({
                    splash: !!document.getElementById('status-splash'),
                    notice: (document.getElementById('status-notice') || {}).innerText || '',
                    isolated: typeof crossOriginIsolated !== 'undefined' && crossOriginIsolated,
                    title: document.title,
                    canvas: !!document.querySelector('canvas'),
                })"""
            )
            browser.close()

        print("\n=== Page state ===")
        print(json.dumps(state, indent=2))
        print("\n=== Console / errors (last 80) ===")
        for line in logs[-80:]:
            print(line)
        if state.get("splash") and not state.get("notice"):
            print("\nFAIL: still on Godot splash (no status notice).", file=sys.stderr)
            return 1
        if state.get("notice"):
            print("\nFAIL: status notice shown:", state["notice"], file=sys.stderr)
            return 1
        print("\nOK: splash dismissed.")
        return 0
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()


if __name__ == "__main__":
    raise SystemExit(main())
