#!/usr/bin/env python3
"""
VisualGasic Python Worker — Tier A IPC Subprocess
==================================================

This worker is launched by the PyBridgeFacade C++ code. It reads
length-prefixed JSON messages from stdin, processes them, and writes
length-prefixed JSON responses to stdout.

Protocol:
  [uint32 payload_length (little-endian)][UTF-8 JSON payload]

Request payload:
  {
    "kind": "import" | "call" | "call_many" | "ping" | "shutdown",
    "request_id": <int>,
    "module": "<str>",
    "method": "<str>",
    "args": [<json values>]
  }

Response payload:
  {
    "kind": "result" | "error",
    "request_id": <int>,
    "status": "ok" | "error",
    "value": <json value>,
    "message": "<str>"
  }

Error behavior:
  - Worker never crashes silently. Every error is returned as a structured
    JSON error response.
  - Import errors, runtime errors, and unknown commands all produce
    error responses with traceback info.
  - Worker exits cleanly on "shutdown" command or EOF on stdin.

Exit codes:
  0  - Clean shutdown (shutdown command or EOF)
  1  - Unhandled exception (should not happen; indicates bug)
"""

import sys
import json
import struct
import traceback
import importlib

def send_response(response):
    """Write a JSON response to stdout with length-prefixed framing."""
    payload = json.dumps(response, ensure_ascii=False).encode("utf-8")
    header = struct.pack("<I", len(payload))
    sys.stdout.buffer.write(header)
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()


def read_message():
    """Read one length-prefixed JSON message from stdin.
    
    Returns the parsed JSON dict, or None if stdin is closed.
    """
    raw_len = sys.stdin.buffer.read(4)
    if not raw_len or len(raw_len) < 4:
        return None
    payload_len = struct.unpack("<I", raw_len)[0]
    if payload_len == 0:
        return {}
    payload = sys.stdin.buffer.read(payload_len)
    if not payload or len(payload) < payload_len:
        return None
    return json.loads(payload.decode("utf-8"))


def handle_import(request):
    """Import a Python module and cache it for future calls.
    
    Returns: {"kind": "result", "status": "ok"} on success.
    On error: {"kind": "error", "status": "error", "message": traceback}
    """
    module_name = request.get("module", "")
    if not module_name:
        return {"kind": "error", "request_id": request.get("request_id", 0),
                "status": "error", "message": "Empty module name"}
    try:
        importlib.import_module(module_name)
        return {"kind": "result", "request_id": request.get("request_id", 0),
                "status": "ok", "value": None}
    except Exception as e:
        tb = traceback.format_exc()
        return {"kind": "error", "request_id": request.get("request_id", 0),
                "status": "error", "message": tb}


def handle_call(request):
    """Call a method on a previously imported module.
    
    The module must have been imported first. The method is resolved
    from the module by name. Callable classes work too.
    
    Returns: {"kind": "result", "status": "ok", "value": <result>}
    On error: {"kind": "error", "status": "error", "message": traceback}
    """
    module_name = request.get("module", "")
    method_name = request.get("method", "")
    args = request.get("args", [])

    if not module_name or not method_name:
        return {"kind": "error", "request_id": request.get("request_id", 0),
                "status": "error", "message": "Module and method names required"}

    try:
        if module_name not in sys.modules:
            importlib.import_module(module_name)
        module = sys.modules[module_name]
        func = getattr(module, method_name)
        result = func(*args)
        return {"kind": "result", "request_id": request.get("request_id", 0),
                "status": "ok", "value": _make_json_safe(result)}
    except Exception as e:
        tb = traceback.format_exc()
        return {"kind": "error", "request_id": request.get("request_id", 0),
                "status": "error", "message": tb}


def handle_call_many(request):
    """Execute multiple calls in sequence, returning all results.
    
    Payload requires a "calls" array:
    { "calls": [{"module": ..., "method": ..., "args": [...]}, ...] }
    
    Returns an array of per-call result objects.
    """
    calls = request.get("calls", [])
    results = []
    for i, call_req in enumerate(calls):
        call_req["request_id"] = request.get("request_id", 0) + i
        if call_req.get("kind") == "import":
            results.append(handle_import(call_req))
        else:
            results.append(handle_call(call_req))
    return {"kind": "result", "request_id": request.get("request_id", 0),
            "status": "ok", "value": results}


def handle_ping(request):
    """Return worker metadata: Python version, available modules, etc."""
    import sys
    info = {
        "python_version": sys.version,
        "python_executable": sys.executable,
    }
    return {"kind": "result", "request_id": request.get("request_id", 0),
            "status": "ok", "value": info}


def _make_json_safe(obj):
    """Convert Python types to JSON-safe types recursively."""
    if obj is None:
        return None
    if isinstance(obj, (bool, int, float, str)):
        return obj
    if isinstance(obj, bytes):
        return obj.decode("utf-8", errors="replace")
    if isinstance(obj, (list, tuple)):
        return [_make_json_safe(item) for item in obj]
    if isinstance(obj, dict):
        return {str(k): _make_json_safe(v) for k, v in obj.items()}
    # For numpy types, try to convert to native Python type
    if hasattr(obj, "tolist"):
        return _make_json_safe(obj.tolist())
    if hasattr(obj, "item"):
        return _make_json_safe(obj.item())
    # Fallback: string representation
    return str(obj)


def main():
    """Main worker loop. Reads commands, dispatches, writes responses."""
    # Flush stderr so error messages are unbuffered
    sys.stderr.reconfigure(line_buffering=True)
    
    while True:
        try:
            request = read_message()
            if request is None:
                break  # EOF — stdin closed, exit cleanly

            kind = request.get("kind", "")

            if kind == "ping":
                response = handle_ping(request)
            elif kind == "import":
                response = handle_import(request)
            elif kind == "call":
                response = handle_call(request)
            elif kind == "call_many":
                response = handle_call_many(request)
            elif kind == "shutdown":
                send_response({"kind": "result", "request_id": request.get("request_id", 0),
                               "status": "ok", "value": "shutting down"})
                break
            else:
                response = {"kind": "error", "request_id": request.get("request_id", 0),
                            "status": "error", "message": f"Unknown command: {kind}"}

            send_response(response)

        except json.JSONDecodeError as e:
            send_response({"kind": "error", "request_id": 0,
                           "status": "error", "message": f"JSON parse error: {e}"})
            continue
        except Exception as e:
            tb = traceback.format_exc()
            send_response({"kind": "error", "request_id": 0,
                           "status": "error", "message": tb})
            continue

    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
