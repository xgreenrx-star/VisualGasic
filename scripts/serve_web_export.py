#!/usr/bin/env python3
"""Serve a Godot HTML5 export with headers required for GDExtension (WASM) builds."""
from __future__ import annotations

import argparse
import functools
import http.server
import os
import sys


class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        # Godot 4.6+ web exports with GDExtension set ensureCrossOriginIsolationHeaders.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # Required for COEP: every wasm/pck/js subresource must be CORP-marked.
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve Godot web export (COOP/COEP for GDExtension)")
    parser.add_argument("directory", nargs="?", default=".", help="Folder containing index.html")
    parser.add_argument("-p", "--port", type=int, default=8080)
    args = parser.parse_args()
    root = os.path.abspath(args.directory)
    if not os.path.isfile(os.path.join(root, "index.html")):
        print(f"error: no index.html in {root}", file=sys.stderr)
        return 1
    os.chdir(root)
    handler = functools.partial(GodotWebHandler, directory=root)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Serving {root} at http://127.0.0.1:{args.port}/index.html (COOP/COEP enabled)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
