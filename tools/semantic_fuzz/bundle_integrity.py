"""Shared bound-bundle integrity checks for replay and reduce."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any, Optional

from .emitter import emit_helper, emit_program
from .ir import Helper, loads_program


# Single-segment module filenames safe for Import "…" and Attribute VB_Name.
_REL_PATH_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\.vg$")


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def validate_rel_path_name(rel: str) -> Optional[str]:
    """Return refusal reason if rel_path is unsafe/reserved; else None."""
    if not isinstance(rel, str) or not rel:
        return "empty rel_path"
    if rel != rel.strip():
        return f"rel_path has leading/trailing space: {rel!r}"
    if any(ord(c) < 32 for c in rel) or '"' in rel or "\n" in rel or "\r" in rel:
        return f"rel_path has forbidden characters: {rel!r}"
    if rel.startswith("/") or rel.startswith("\\") or ".." in rel.split("/"):
        return f"unsafe rel_path: {rel}"
    if "/" in rel or "\\" in rel:
        return f"path separator in rel_path: {rel}"
    if rel.lower() == "case.vg":
        return f"reserved rel_path forbidden: {rel}"
    if not _REL_PATH_RE.match(rel):
        return f"rel_path grammar refused: {rel}"
    return None


def validate_bundle_integrity(case_dir: Path) -> Optional[str]:
    """Return refusal message if the bound bundle is inconsistent/tampered."""
    case_dir = Path(case_dir)
    ir_path = case_dir / "ir.json"
    prog_path = case_dir / "program.json"
    if not ir_path.is_file():
        return "missing ir.json"
    if not prog_path.is_file():
        return "missing program.json"
    try:
        ir = json.loads(ir_path.read_text(encoding="utf-8"))
        pmeta = json.loads(prog_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return f"bundle_json_error:{exc}"

    for key in ("mode", "schema_version", "generator_version", "reference_version"):
        if key not in pmeta:
            return f"program.json missing {key}"
        if key != "mode" and key in ir and ir[key] != pmeta[key]:
            return f"ir/program mismatch on {key}"

    mode = pmeta["mode"]
    if mode not in ("forced_ast", "interpreter", "default", "tier3"):
        return f"program.json invalid mode {mode!r}"

    modules = list(ir.get("source_modules") or [])
    # Bound contract: path fields must be present (no None/absent agreement).
    strict = bool(modules) or ("path_module_key" in ir) or ("path_module_key" in pmeta)
    contract_keys = (
        "path_target",
        "path_targets",
        "path_module_key",
        "path_module",
        "required_path",
    )
    for key in contract_keys:
        if strict:
            if key not in ir:
                return f"ir.json missing {key}"
            if key not in pmeta:
                return f"program.json missing {key}"
            if ir[key] is None and key != "fallback_contract":
                # path_module may be rebound at replay clear; key/target must exist.
                if key in ("path_module_key", "path_target", "path_targets", "required_path"):
                    if ir[key] is None:
                        return f"ir.json {key} is None"
            if ir[key] != pmeta[key]:
                return f"ir/program mismatch on {key}"
        elif key in ir and key in pmeta and ir[key] != pmeta[key]:
            return f"ir/program mismatch on {key}"

    if "fallback_contract" not in pmeta:
        return "program.json missing fallback_contract"
    if "fallback_contract" in ir and ir["fallback_contract"] != pmeta["fallback_contract"]:
        return "ir/program fallback_contract mismatch"

    # Logical/physical mapping must match runner naming helpers exactly.
    if strict:
        from .runner import case_dir_slug, logical_module_key

        pkey = pmeta.get("path_module_key")
        pmod = pmeta.get("path_module")
        case_id = pmeta.get("case_id") or ir.get("case_id")
        if not isinstance(case_id, str) or not case_id:
            return "case_id missing/empty"
        if ir.get("case_id") not in (None, case_id) and ir.get("case_id") != case_id:
            return "ir/program case_id mismatch"
        want_key = logical_module_key(case_id, mode)
        if not isinstance(pkey, str) or not pkey:
            return "path_module_key missing/empty"
        if pkey != want_key:
            return (
                f"path_module_key mismatch: got={pkey!r} "
                f"want={want_key!r} (from case_id/mode)"
            )
        targets = pmeta.get("path_targets")
        if not isinstance(targets, list) or not targets:
            return "path_targets must be nonempty list"
        if pmeta.get("path_target") not in targets:
            return "path_target not in path_targets"
        req = pmeta.get("required_path")
        if not isinstance(req, dict) or not req:
            return "required_path must be nonempty object"
        if mode not in req or not req[mode]:
            return f"required_path missing entry for mode {mode}"
        if not isinstance(pmod, str) or not pmod.startswith("res://sem_fuzz_runs/"):
            return f"path_module not under res://sem_fuzz_runs/: {pmod!r}"
        if not pmod.endswith("/case.vg"):
            return f"path_module must end with /case.vg: {pmod!r}"
        run_token = pmeta.get("run_token")
        if not isinstance(run_token, str) or not run_token:
            return "run_token missing/empty"
        slug = case_dir_slug(case_id)
        want_mod = f"res://sem_fuzz_runs/{run_token}/{slug}/{mode}/case.vg"
        if pmod != want_mod:
            return f"path_module mismatch: got={pmod!r} want={want_mod!r}"
        # fn_path_modules: imported helpers must live beside primary under same token.
        fn_mods = pmeta.get("fn_path_modules")
        defining = dict(
            pmeta.get("helper_defining_module")
            or ir.get("helper_defining_module")
            or {}
        )
        if defining:
            if not isinstance(fn_mods, dict) or not fn_mods:
                return "fn_path_modules missing for imported helpers"
            base = f"res://sem_fuzz_runs/{run_token}/{slug}/{mode}/"
            for hn, rel in defining.items():
                got = fn_mods.get(hn)
                want_fn = f"{base}{rel}"
                if got != want_fn:
                    return (
                        f"fn_path_modules[{hn}] mismatch: got={got!r} want={want_fn!r}"
                    )

    fail_path = case_dir / "failure.json"
    is_failure = fail_path.is_file()
    if is_failure:
        fmeta = json.loads(fail_path.read_text(encoding="utf-8"))
        for key in contract_keys:
            if key not in fmeta:
                return f"failure.json missing {key}"
            if fmeta[key] != ir.get(key):
                return f"ir/failure mismatch on {key}"
        if "fallback_contract" not in fmeta:
            return "failure.json missing fallback_contract"
        if fmeta.get("fallback_contract") != ir.get("fallback_contract"):
            return "ir/failure fallback_contract mismatch"
        if "failure_code" not in fmeta or not fmeta["failure_code"]:
            return "failure.json missing failure_code"
        for key in ("schema_version", "generator_version", "reference_version", "mode"):
            if key not in fmeta:
                return f"failure.json missing {key}"
            if key == "mode" and fmeta[key] != mode:
                return "failure/program mode mismatch"
            if key != "mode" and fmeta[key] != pmeta.get(key):
                return f"failure/program mismatch on {key}"
        if not (case_dir / "expected.json").is_file():
            return "failure bundle missing expected.json"
        if not (case_dir / "actual.json").is_file():
            return "failure bundle missing actual.json"

    # Primary source: must exist as a real file (not symlink); compare raw bytes.
    case_vg = case_dir / "case.vg"
    if case_vg.is_symlink():
        return "symlink primary case.vg refused"
    if not case_vg.is_file():
        return "missing primary case.vg"
    try:
        primary_raw = case_vg.read_bytes()
    except Exception as exc:
        return f"case.vg read error:{exc}"
    try:
        primary_text = primary_raw.decode("utf-8")
    except Exception as exc:
        return f"case.vg not utf-8:{exc}"

    if "primary_source" not in pmeta:
        return "program.json missing primary_source"
    ps = pmeta["primary_source"]
    if not isinstance(ps, dict):
        return "primary_source must be object"
    for fld in ("sha256", "bytes", "warmup_calls"):
        if fld not in ps:
            return f"primary_source missing {fld}"
    if not isinstance(ps["sha256"], str) or len(ps["sha256"]) != 64:
        return "primary_source.sha256 invalid"
    if not isinstance(ps["bytes"], int) or isinstance(ps["bytes"], bool):
        return "primary_source.bytes must be JSON int (no coercion)"
    if not isinstance(ps["warmup_calls"], int) or isinstance(ps["warmup_calls"], bool):
        return "primary_source.warmup_calls must be JSON int"
    if ps["bytes"] != len(primary_raw):
        return (
            f"primary source byte-count mismatch: "
            f"file={len(primary_raw)} meta={ps['bytes']}"
        )
    got_primary = _sha256_bytes(primary_raw)
    if got_primary != ps["sha256"]:
        return f"primary source hash mismatch: got={got_primary} want={ps['sha256']}"

    prog = loads_program(ir_path.read_text(encoding="utf-8"))
    emit_prog = loads_program(ir_path.read_text(encoding="utf-8"))
    emit_prog.path_module = prog.path_module
    try:
        emitted = emit_program(emit_prog, warmup_calls=int(ps["warmup_calls"]))
    except Exception as exc:
        return f"primary re-emit failed:{exc}"
    if emitted.encode("utf-8") != primary_raw:
        return "primary case.vg drift vs emitted IR"

    # Source module integrity
    manifest = list(pmeta.get("source_modules_manifest") or [])
    if bool(modules) != bool(manifest):
        return "source_modules vs manifest presence mismatch"
    if modules:
        if "helper_defining_module" not in ir or "helper_defining_module" not in pmeta:
            return "missing helper_defining_module"
        if ir["helper_defining_module"] != pmeta["helper_defining_module"]:
            return "ir/program helper_defining_module mismatch"
        if len(modules) != len(manifest):
            return f"source_modules count {len(modules)} != manifest {len(manifest)}"
        # Exact duplicate rel_path entries in IR list
        rels_list = [m.get("rel_path") for m in modules]
        if len(rels_list) != len(set(rels_list)):
            return f"duplicate source_modules entries: {rels_list}"

        by_rel = {m["rel_path"]: m for m in modules}
        # Case-insensitive duplicate detection
        lower_map: dict[str, str] = {}
        for rel in by_rel:
            bad = validate_rel_path_name(rel)
            if bad:
                return bad
            low = rel.lower()
            if low in lower_map:
                return f"duplicate rel_path case-insensitive: {rel} vs {lower_map[low]}"
            lower_map[low] = rel

        man_rels = {entry.get("rel_path") for entry in manifest}
        for rel in by_rel:
            if rel not in man_rels:
                return f"ir module missing from manifest: {rel}"

        for entry in manifest:
            rel = entry.get("rel_path")
            if rel not in by_rel:
                return f"manifest module missing from ir: {rel}"
            if "sha256" not in entry:
                return f"manifest {rel} missing sha256"
            if "bytes" not in entry:
                return f"manifest {rel} missing bytes"
            if not isinstance(entry["sha256"], str) or len(entry["sha256"]) != 64:
                return f"manifest {rel} sha256 invalid"
            if not isinstance(entry["bytes"], int) or isinstance(entry["bytes"], bool):
                return f"manifest {rel} bytes must be JSON int (no coercion)"
            content = by_rel[rel].get("content")
            if not isinstance(content, str):
                return f"module {rel} content not str"
            raw = content.encode("utf-8")
            got = _sha256_bytes(raw)
            if got != entry["sha256"]:
                return f"source hash mismatch for {rel}: got={got} want={entry['sha256']}"
            if entry["bytes"] != len(raw):
                return f"source byte-count mismatch for {rel}"

        # Re-emit imported helpers from typed IR and compare to saved content.
        emitted_mods = _emit_imported_bodies(prog)
        if set(emitted_mods) != set(by_rel):
            return (
                f"emitted module set {sorted(emitted_mods)} != "
                f"ir source set {sorted(by_rel)}"
            )
        for rel, body in emitted_mods.items():
            if body != by_rel[rel]["content"]:
                return f"imported source drift vs emitted IR for {rel}"

        # Every defining-module entry must have typed helper(s); every store key declared.
        defining = dict(ir.get("helper_defining_module") or {})
        for hn, rel in defining.items():
            if rel not in by_rel:
                return f"helper_defining_module[{hn}] undeclared module {rel}"
        for rel in by_rel:
            if rel not in defining.values():
                return f"source module {rel} has no typed helper"
        stores = dict(ir.get("module_stores") or {})
        for mk in stores:
            if mk not in by_rel and mk != "":
                return f"module_stores key {mk!r} not in source_modules"

        # Owned on-disk module files: declared set must match exactly (incl. empty).
        disk_mods = sorted(
            p.name
            for p in case_dir.iterdir()
            if p.is_file()
            and p.suffix.lower() == ".vg"
            and p.name.lower() != "case.vg"
            and not p.is_symlink()
        )
        for p in case_dir.iterdir():
            if p.is_symlink() and (
                p.name.lower().endswith(".vg") or p.name.lower() == "case.vg"
            ):
                return f"symlink source refused: {p.name}"
        if set(disk_mods) != set(by_rel):
            return (
                f"owned disk modules {disk_mods} != ir source set {sorted(by_rel)}"
            )
        for rel in by_rel:
            disk_path = case_dir / rel
            if not disk_path.is_file() or disk_path.is_symlink():
                return f"owned disk module missing: {rel}"
            disk_raw = disk_path.read_bytes()
            want_raw = by_rel[rel]["content"].encode("utf-8")
            if disk_raw != want_raw:
                return f"owned disk module byte drift: {rel}"

    else:
        # No declared imports: refuse unexpected sibling .vg / symlinks.
        unexpected = sorted(
            p.name
            for p in case_dir.iterdir()
            if (p.is_file() or p.is_symlink())
            and p.suffix.lower() == ".vg"
            and p.name.lower() != "case.vg"
        )
        if unexpected:
            return f"unexpected on-disk modules without IR source_modules: {unexpected}"
        for p in case_dir.iterdir():
            if p.is_symlink() and p.name.lower() == "case.vg":
                return "symlink primary case.vg refused"

    return None


def _emit_imported_bodies(prog) -> dict[str, str]:
    """Emit each imported module solely from typed Helper IR.

    Module scalar initials come from ``module_stores`` (oracle seeds Env from the
    same map). Emission injects a one-shot ready guard into every public entry so
    VG Dim starts match without a second hand-written helper body.
    """
    defining = dict(getattr(prog, "helper_defining_module", None) or {})
    by_rel: dict[str, list[Helper]] = {}
    for h in prog.helpers:
        rel = defining.get(h.name)
        if not rel:
            continue
        by_rel.setdefault(rel, []).append(h)
    out = {}
    for rel, helpers in by_rel.items():
        lines = [
            f"' SEMANTIC_FUZZ_MODULE {rel}",
            f'Attribute VB_Name = "{Path(rel).stem}"',
            "",
        ]
        mod_vars = (getattr(prog, "module_stores", None) or {}).get(rel) or {}
        for name in sorted(mod_vars):
            lines.append(f"Dim {name} As Integer")
        if mod_vars:
            lines.append("Dim _sem_mod_ready As Integer")
            lines.append("")
        init_block = []
        if mod_vars:
            init_block = [
                "\tIf _sem_mod_ready = 0 Then",
                *[f"\t\t{n} = {int(v)}" for n, v in sorted(mod_vars.items())],
                "\t\t_sem_mod_ready = 1",
                "\tEnd If",
            ]
        for h in helpers:
            h_lines = emit_helper(h)
            if init_block:
                out_h: list[str] = []
                injected = False
                for ln in h_lines:
                    out_h.append(ln)
                    if not injected and (
                        ln.startswith("Function ") or ln.startswith("Sub ")
                    ):
                        out_h.extend(init_block)
                        injected = True
                lines.extend(out_h)
            else:
                lines.extend(h_lines)
        out[rel] = "\n".join(lines) + "\n"
    return out


def sync_source_modules_from_ir(prog) -> None:
    """Replace source_modules contents with emitter output from Helper IR."""
    bodies = _emit_imported_bodies(prog)
    if not bodies:
        prog.source_modules = []
        return
    prog.source_modules = [
        {"rel_path": rel, "content": body} for rel, body in sorted(bodies.items())
    ]


def write_bound_test_bundle(
    case_dir: Path,
    prog,
    *,
    mode: str = "interpreter",
    run_token: str = "testtoken",
    warmup_calls: int = 0,
) -> Path:
    """Write a complete owned bundle for integrity/replay negatives (no Godot)."""
    import copy

    from .ir import dumps_program
    from .provenance import bundle_version_fields

    case_dir = Path(case_dir)
    case_dir.mkdir(parents=True, exist_ok=True)
    if getattr(prog, "helper_defining_module", None):
        sync_source_modules_from_ir(prog)
    snap = copy.deepcopy(prog)
    from .runner import case_dir_slug, logical_module_key

    slug = case_dir_slug(snap.case_id)
    snap.path_module_key = snap.path_module_key or logical_module_key(snap.case_id, mode)
    snap.path_module = f"res://sem_fuzz_runs/{run_token}/{slug}/{mode}/case.vg"
    if not list(snap.path_targets or []):
        snap.path_targets = [snap.path_target] if snap.path_target else ["SemMain"]
    if snap.path_target and snap.path_target not in snap.path_targets:
        snap.path_targets = [snap.path_target, *list(snap.path_targets)]
    source = emit_program(snap, warmup_calls=warmup_calls)
    raw = source.encode("utf-8")
    (case_dir / "case.vg").write_text(source, encoding="utf-8")
    for mod in getattr(snap, "source_modules", None) or []:
        (case_dir / mod["rel_path"]).write_text(mod["content"], encoding="utf-8")
    man = []
    for m in getattr(snap, "source_modules", None) or []:
        mraw = m["content"].encode("utf-8")
        man.append(
            {
                "rel_path": m["rel_path"],
                "sha256": hashlib.sha256(mraw).hexdigest(),
                "bytes": len(mraw),
            }
        )
    versions = bundle_version_fields()
    meta = {
        **versions,
        "case_id": snap.case_id,
        "mode": mode,
        "path_target": snap.path_target,
        "path_targets": list(snap.path_targets or []),
        "path_module_key": snap.path_module_key,
        "path_module": snap.path_module,
        "required_path": dict(snap.required_path or {}),
        "fallback_contract": snap.fallback_contract,
        "run_token": run_token,
        "primary_source": {
            "sha256": hashlib.sha256(raw).hexdigest(),
            "bytes": len(raw),
            "warmup_calls": int(warmup_calls),
        },
        "source_modules_manifest": man,
        "helper_defining_module": dict(
            getattr(snap, "helper_defining_module", None) or {}
        ),
        "fn_path_modules": {
            **{
                h.name: snap.path_module
                for h in snap.helpers
                if h.name not in (getattr(snap, "helper_defining_module", None) or {})
            },
            **{
                hn: f"res://sem_fuzz_runs/{run_token}/{slug}/{mode}/{rel}"
                for hn, rel in (
                    getattr(snap, "helper_defining_module", None) or {}
                ).items()
            },
        },
    }
    (case_dir / "program.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    (case_dir / "ir.json").write_text(dumps_program(snap), encoding="utf-8")
    from .reference import evaluate_program

    exp = [o.to_dict() for o in evaluate_program(snap).observations]
    (case_dir / "expected.json").write_text(json.dumps(exp, indent=2), encoding="utf-8")
    return case_dir
