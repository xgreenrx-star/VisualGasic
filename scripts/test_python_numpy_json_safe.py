#!/usr/bin/env python3
"""Unit-test python_worker._make_json_safe (numpy / pandas / torch / structured).

Does not start the worker loop. Optional libraries are skipped when not installed.
Same helper runs on Linux, macOS, and Windows.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "addons" / "visual_gasic" / "python_worker.py"


def load_worker():
    spec = importlib.util.spec_from_file_location("vg_python_worker", WORKER)
    mod = importlib.util.module_from_spec(spec)
    # Avoid executing main(); worker only loops under __main__.
    spec.loader.exec_module(mod)
    return mod


def main() -> int:
    worker = load_worker()
    safe = worker._make_json_safe
    assert safe(None) is None
    assert safe([1, "a"]) == [1, "a"]

    try:
        import numpy as np
    except ImportError:
        print("SKIP numpy (not installed)")
    else:
        arr = np.array([[1, 2], [3, 4]], dtype=np.int64)
        assert safe(arr) == [[1, 2], [3, 4]]
        assert safe(np.float64(1.5)) == 1.5
        struct = np.array([(1, 2.5)], dtype=[("i", "i4"), ("f", "f8")])
        got = safe(struct)
        assert got == [{"i": 1, "f": 2.5}], got
        print("OK numpy ndarray, scalar, structured dtype")

    try:
        import pandas as pd
    except ImportError:
        print("SKIP pandas (not installed)")
    else:
        frame = pd.DataFrame([{"a": 1, "b": "x"}])
        assert safe(frame) == [{"a": 1, "b": "x"}]
        print("OK pandas DataFrame records")

    try:
        import torch
    except ImportError:
        print("SKIP torch (not installed)")
    else:
        t = torch.tensor([[1, 2], [3, 4]])
        assert safe(t) == [[1, 2], [3, 4]]
        print("OK torch tensor")

    print("python numpy json-safe checks done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
