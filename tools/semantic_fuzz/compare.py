"""Strict observation comparison for semantic fuzz."""

from __future__ import annotations

from typing import Any


class CompareError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def normalize_obs(obs: list[dict[str, Any]]) -> list[dict[str, str]]:
    out = []
    for i, o in enumerate(obs):
        if not isinstance(o, dict):
            raise CompareError("malformed", f"observation {i} not an object")
        for key in ("name", "type", "value"):
            if key not in o:
                raise CompareError("malformed", f"observation {i} missing {key}")
        out.append({"name": str(o["name"]), "type": str(o["type"]), "value": str(o["value"])})
    return out


def compare_observations(expected: list[dict[str, Any]], actual: list[dict[str, Any]]) -> None:
    exp = normalize_obs(expected)
    act = normalize_obs(actual)
    if len(act) != len(exp):
        raise CompareError(
            "count_mismatch",
            f"observation count expected {len(exp)} got {len(act)}: expected={exp} actual={act}",
        )
    for i, (e, a) in enumerate(zip(exp, act)):
        if e["name"] != a["name"]:
            raise CompareError("reordered_or_missing", f"index {i} name expected {e['name']} got {a['name']}")
        if e["type"] != a["type"]:
            raise CompareError("wrong_type", f"index {i} ({e['name']}) type expected {e['type']} got {a['type']}")
        if e["value"] != a["value"]:
            raise CompareError(
                "wrong_value",
                f"index {i} ({e['name']}) value expected {e['value']} got {a['value']}",
            )
