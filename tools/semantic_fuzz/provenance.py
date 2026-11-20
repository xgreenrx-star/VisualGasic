"""Shared schema/model and runtime-hash checks for replay and reduction.

Hard refuse: incompatible schema / generator / reference versions.
Soft label: VG library hash or Godot engine hash/path differs — still runnable,
but marked as an explicit changed-environment rerun (not identical reproduction).
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from . import GENERATOR_VERSION, REFERENCE_VERSION, SCHEMA_VERSION


ENV_LABEL_PREFIX = "changed_environment_rerun"


@dataclass
class ProvenanceVerdict:
    """Result of checking a saved case bundle against the current harness/runtime."""

    refuse: Optional[str] = None  # hard incompatibility (do not replay/reduce)
    environment_notes: list[str] = field(default_factory=list)

    @property
    def ok_to_run(self) -> bool:
        return self.refuse is None

    @property
    def environment_label(self) -> str:
        if not self.environment_notes:
            return ""
        return ENV_LABEL_PREFIX + ":" + ";".join(self.environment_notes)


def load_bundle_meta(case_dir: Path) -> dict[str, Any]:
    """Merge program.json then failure.json (failure fields win on overlap)."""
    case_dir = Path(case_dir)
    meta: dict[str, Any] = {}
    for name in ("program.json", "failure.json"):
        path = case_dir / name
        if path.is_file():
            meta.update(json.loads(path.read_text(encoding="utf-8")))
    return meta


def check_schema_model(meta: dict[str, Any]) -> Optional[str]:
    """Return a refuse message when schema/model versions are incompatible."""
    saved_schema = meta.get("schema_version")
    if saved_schema is not None and int(saved_schema) != SCHEMA_VERSION:
        return f"schema_version incompatible: saved={saved_schema} current={SCHEMA_VERSION}"
    for key, current in (
        ("generator_version", GENERATOR_VERSION),
        ("reference_version", REFERENCE_VERSION),
    ):
        if key in meta and int(meta[key]) != current:
            return f"{key} incompatible: saved={meta[key]} current={current}"
    return None


def compare_runtime_hashes(
    meta: dict[str, Any],
    *,
    binary_hash: Optional[str] = None,
    engine_hash: Optional[str] = None,
    engine_path: Optional[str] = None,
) -> list[str]:
    """Compare saved VG library / Godot hashes (and path) to the current run.

    Notes are short tokens for `environment_label`. Same pathname with a
    different engine_hash is reported as engine_hash_changed (not silent).
    """
    notes: list[str] = []
    saved_bin = meta.get("binary_hash") or meta.get("binary_sha256")
    if saved_bin and binary_hash and saved_bin != binary_hash:
        notes.append("binary_hash_changed")

    saved_path = meta.get("engine_path") or meta.get("godot")
    saved_engine_hash = meta.get("engine_hash") or meta.get("godot_sha256")
    same_path = False
    path_changed = False
    if saved_path and engine_path:
        try:
            same_path = Path(str(saved_path)).resolve() == Path(str(engine_path)).resolve()
        except OSError:
            same_path = str(saved_path) == str(engine_path)
        path_changed = not same_path

    if saved_engine_hash and engine_hash and saved_engine_hash != engine_hash:
        notes.append("engine_hash_changed")
        if same_path:
            # Same pathname, different content — not an identical historical engine.
            notes.append("engine_replaced_same_path")
        elif path_changed:
            notes.append("engine_path_changed")
    elif path_changed:
        notes.append("engine_path_changed")

    return notes


def check_bundle_provenance(
    case_dir: Path,
    *,
    binary_hash: Optional[str] = None,
    engine_hash: Optional[str] = None,
    engine_path: Optional[str] = None,
    compare_runtime: bool = True,
) -> ProvenanceVerdict:
    """Shared entry for replay and reduction."""
    meta = load_bundle_meta(case_dir)
    refuse = check_schema_model(meta)
    if refuse:
        return ProvenanceVerdict(refuse=refuse)
    notes: list[str] = []
    if compare_runtime:
        notes = compare_runtime_hashes(
            meta,
            binary_hash=binary_hash,
            engine_hash=engine_hash,
            engine_path=engine_path,
        )
    return ProvenanceVerdict(refuse=None, environment_notes=notes)


def bundle_version_fields() -> dict[str, int]:
    return {
        "schema_version": SCHEMA_VERSION,
        "generator_version": GENERATOR_VERSION,
        "reference_version": REFERENCE_VERSION,
    }
