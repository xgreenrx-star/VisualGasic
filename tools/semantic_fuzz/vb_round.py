"""VB6-style banker's rounding (ties to even) — independent of the VG runtime."""

from __future__ import annotations

import math


def vb_round_half_even(x: float) -> int:
    """Round half to nearest even integer (IEEE 754 round-ties-to-even / VB6 CInt).

    Examples: 2.5→2, 3.5→4, -2.5→-2, -3.5→-4, 3.7→4, -3.7→-4.
    """
    if math.isnan(x) or math.isinf(x):
        raise ValueError(f"vb_round_half_even domain excludes NaN/Inf: {x!r}")
    return int(round(x))  # Python 3 round uses banker's rounding
