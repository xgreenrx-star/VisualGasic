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


def read_exact(size):
    """Read exactly size bytes from stdin, or None on EOF."""
    chunks = bytearray()
    while len(chunks) < size:
        chunk = sys.stdin.buffer.read(size - len(chunks))
        if not chunk:
            return None
        chunks.extend(chunk)
    return bytes(chunks)


def send_response(response, binary_blob=None):
    """Write a JSON response to stdout with optional trailing binary blob."""
    payload = json.dumps(response, ensure_ascii=False).encode("utf-8")
    header = struct.pack("<I", len(payload))
    sys.stdout.buffer.write(header)
    sys.stdout.buffer.write(payload)
    if binary_blob is not None:
        sys.stdout.buffer.write(struct.pack("<I", len(binary_blob)))
        sys.stdout.buffer.write(binary_blob)
    sys.stdout.buffer.flush()


def read_message():
    """Read one length-prefixed JSON message from stdin, with optional blob."""
    raw_len = read_exact(4)
    if not raw_len:
        return None
    payload_len = struct.unpack("<I", raw_len)[0]
    if payload_len == 0:
        request = {}
    else:
        payload = read_exact(payload_len)
        if payload is None:
            return None
        request = json.loads(payload.decode("utf-8"))

    blob_size = request.get("blob_size")
    if blob_size is not None:
        blob = read_exact(int(blob_size))
        if blob is None:
            raise EOFError("Unexpected EOF while reading binary blob")
        request["_blob"] = blob
    return request


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


def _coerce_blob_arg(blob, args):
    """Convert raw binary bytes into a useful Python object tailored for method calls."""
    metadata = args[0] if args and isinstance(args[0], dict) else None
    if metadata is None:
        return blob
    dtype = str(metadata.get("dtype", "uint8")).lower()
    shape = metadata.get("shape", [])

    try:
        import numpy as np
        if dtype == "uint8":
            arr = np.frombuffer(blob, dtype=np.uint8)
            if shape:
                arr = arr.reshape(shape)
            return arr.tolist() if hasattr(arr, "tolist") else list(arr)
        if dtype == "float32":
            arr = np.frombuffer(blob, dtype=np.float32)
            if shape:
                arr = arr.reshape(shape)
            return arr.tolist() if hasattr(arr, "tolist") else list(arr)
        if dtype == "float64":
            arr = np.frombuffer(blob, dtype=np.float64)
            if shape:
                arr = arr.reshape(shape)
            return arr.tolist() if hasattr(arr, "tolist") else list(arr)
    except Exception:
        pass
    return list(blob)


def handle_call_binary(request):
    """Dispatch a call whose raw binary payload is passed alongside JSON metadata."""
    module_name = request.get("module", "")
    method_name = request.get("method", "")
    args = request.get("args", [])
    blob = request.get("_blob", b"")

    if not module_name or not method_name:
        return {"kind": "error", "request_id": request.get("request_id", 0),
                "status": "error", "message": "Module and method names required"}

    try:
        if module_name not in sys.modules:
            importlib.import_module(module_name)
        module = sys.modules[module_name]
        func = getattr(module, method_name)

        blob_value = _coerce_blob_arg(blob, args)
        call_args = list(args)
        if call_args and isinstance(call_args[0], dict):
            call_args = call_args[1:]

        try:
            if blob_value is not None:
                result = func(*call_args, blob_value)
            else:
                result = func(*call_args)
        except TypeError:
            if blob_value is not None:
                result = func(blob_value, *call_args)
            else:
                result = func(*call_args)

        if isinstance(result, (bytes, bytearray, memoryview)):
            blob_result = bytes(result)
            return ({"kind": "result_binary", "request_id": request.get("request_id", 0),
                     "status": "ok", "value": {"dtype": "uint8", "size": len(blob_result)}},
                    blob_result)

        if hasattr(result, "tobytes"):
            try:
                blob_result = result.tobytes()
                return ({"kind": "result_binary", "request_id": request.get("request_id", 0),
                         "status": "ok", "value": {"dtype": "uint8", "size": len(blob_result)}},
                        blob_result)
            except Exception:
                pass

        return {"kind": "result", "request_id": request.get("request_id", 0),
                "status": "ok", "value": _make_json_safe(result)}
    except Exception:
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
        kind = call_req.get("kind")
        if kind == "import":
            results.append(handle_import(call_req))
        elif kind == "call_binary":
            results.append(handle_call_binary(call_req))
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
            elif kind == "call_binary":
                response = handle_call_binary(request)
                if isinstance(response, tuple):
                    send_response(response[0], response[1])
                    continue
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
