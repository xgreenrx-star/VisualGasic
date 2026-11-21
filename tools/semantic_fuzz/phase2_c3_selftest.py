"""C3 collection model — pure oracle/harness selftests (no Godot / no .so)."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path
from typing import List

from .compare import CompareError, compare_observations
from .generator import shape_fingerprint
from .generator_c3 import (
    UNSUPPORTED_PAIRS,
    classify_coverage_shapes,
    generate_c3_batch,
    generate_c3_case,
)
from .ir import (
    ArrGet,
    ArrSet,
    DictCount,
    DictExists,
    DictGet,
    DictMissCheck,
    DictSet,
    Lit,
    NestedSlotGet,
    NestedSlotSet,
    Observe,
    Program,
    UdtCopy,
    UdtFieldGet,
    UdtFieldSet,
    dumps_program,
)
from .path_contract import check_required_path_events, parse_path_event_line
from .reference import ReferenceError, evaluate_program
from .validate import ValidationError, validate_program


def _hand_array() -> Program:
    return Program(
        case_id="hand_c3_array",
        seed=0,
        index=0,
        family="c3_array_slot",
        module_arrays={"arr": [10, 20, 30]},
        main=[
            ArrSet("arr", 1, Lit(120)),
            Observe("left", ArrGet("arr", 0)),
            Observe("mid", ArrGet("arr", 1)),
            Observe("right", ArrGet("arr", 2)),
        ],
        required_path={
            "forced_ast": "ast",
            "interpreter": "bytecode",
            "default": "bytecode",
            "tier3": "bytecode",
        },
        path_target="SemMain",
        notes="hand: [10,20,30] write mid=120 → [10,120,30]",
    )


def _hand_dict_miss() -> Program:
    return Program(
        case_id="hand_c3_dict_miss",
        seed=0,
        index=1,
        family="c3_dict_missing",
        module_dicts={"d": {"a": 10, "b": 20}},
        main=[
            DictMissCheck("d", "nope", "miss"),
            Observe("neighbor_a", DictGet("d", "a")),
            Observe("neighbor_b", DictGet("d", "b")),
        ],
        required_path={
            "forced_ast": "ast",
            "interpreter": "bytecode",
            "default": "bytecode",
            "tier3": "bytecode",
        },
        path_target="SemMain",
        notes="hand: miss nope → err_before/vt/is_nothing/err/err_type; neighbors",
    )


def _hand_dict_present() -> Program:
    return Program(
        case_id="hand_c3_dict_present",
        seed=0,
        index=2,
        family="c3_dict_present",
        module_dicts={"d": {"a": 10, "b": 20}},
        main=[
            Observe("before_a", DictGet("d", "a")),
            DictSet("d", "a", Lit(7)),
            Observe("after_a", DictGet("d", "a")),
            Observe("after_b", DictGet("d", "b")),
        ],
        required_path={
            "forced_ast": "ast",
            "interpreter": "bytecode",
            "default": "bytecode",
            "tier3": "bytecode",
        },
        path_target="SemMain",
        notes="hand: a 10→7; b stays 20",
    )


def _miss_expect() -> list:
    return [
        {"kind": "value", "name": "miss_err_before", "type": "Integer", "value": "0"},
        {"kind": "value", "name": "miss_vt", "type": "Integer", "value": "1"},
        {"kind": "value", "name": "miss_is_nothing", "type": "Integer", "value": "1"},
        {"kind": "value", "name": "miss_err", "type": "Integer", "value": "0"},
        {"kind": "value", "name": "miss_err_type", "type": "String", "value": "Integer"},
        {"kind": "value", "name": "neighbor_a", "type": "Integer", "value": "10"},
        {"kind": "value", "name": "neighbor_b", "type": "Integer", "value": "20"},
    ]


def run_phase2_c3_selftests() -> List[str]:
    """Engine-independent C3 tests. Must not require Godot or an extension .so."""
    fails: List[str] = []

    for label, prog, expect in (
        (
            "hand_array",
            _hand_array(),
            [
                {"kind": "value", "name": "left", "type": "Integer", "value": "10"},
                {"kind": "value", "name": "mid", "type": "Integer", "value": "120"},
                {"kind": "value", "name": "right", "type": "Integer", "value": "30"},
            ],
        ),
        ("hand_dict_miss", _hand_dict_miss(), _miss_expect()),
        (
            "hand_dict_present",
            _hand_dict_present(),
            [
                {"kind": "value", "name": "before_a", "type": "Integer", "value": "10"},
                {"kind": "value", "name": "after_a", "type": "Integer", "value": "7"},
                {"kind": "value", "name": "after_b", "type": "Integer", "value": "20"},
            ],
        ),
    ):
        got = [o.to_dict() for o in evaluate_program(prog).observations]
        try:
            compare_observations(expect, got)
        except CompareError as exc:
            fails.append(f"{label}: {exc}")

    good = [o.to_dict() for o in evaluate_program(_hand_array()).observations]
    try:
        compare_observations(good, [{**good[0], "value": "999"}, *good[1:]])
        fails.append("detector: wrong_value accepted")
    except CompareError as exc:
        if exc.code != "wrong_value":
            fails.append(f"detector: wrong_value code={exc.code}")

    try:
        compare_observations(good, [{**good[0], "type": "String"}, *good[1:]])
        fails.append("detector: wrong_type accepted")
    except CompareError as exc:
        if exc.code != "wrong_type":
            fails.append(f"detector: wrong_type code={exc.code}")

    try:
        compare_observations(good, good[:-1])
        fails.append("detector: missing observation accepted")
    except CompareError as exc:
        if exc.code != "count_mismatch":
            fails.append(f"detector: missing code={exc.code}")

    try:
        compare_observations(good, good + [good[-1]])
        fails.append("detector: duplicate/extra observation accepted")
    except CompareError as exc:
        if exc.code != "count_mismatch":
            fails.append(f"detector: duplicate code={exc.code}")

    mod = "res://sem_fuzz_ir/hand/case.vg"
    good_ev = [
        parse_path_event_line(f'VG_SEM_PATH path=bytecode fn=SemMain mod="{mod}"')
    ]
    if check_required_path_events(
        mode="interpreter",
        target="SemMain",
        want="bytecode",
        events=good_ev,
        required_mod=mod,
    ):
        fails.append("path: qualified SemMain rejected")
    bad_ev = good_ev + [parse_path_event_line("VG_SEM_PATH path=ast fn=SemMain")]
    err = check_required_path_events(
        mode="interpreter",
        target="SemMain",
        want="bytecode",
        events=bad_ev,
        required_mod=mod,
    )
    if not err or "unqualified" not in err:
        fails.append(f"path: unqualified not rejected: {err}")

    wrong = [
        parse_path_event_line(
            'VG_SEM_PATH path=bytecode fn=SemMain mod="res://other.vg"'
        )
    ]
    err = check_required_path_events(
        mode="interpreter",
        target="SemMain",
        want="bytecode",
        events=wrong,
        required_mod=mod,
    )
    if not err or "wrong module" not in err:
        fails.append(f"path: wrong module not rejected: {err}")

    bad_get = Program(
        case_id="bad_dict_get",
        seed=0,
        index=0,
        family="c3_dict_missing",
        module_dicts={"d": {"a": 1}},
        main=[Observe("x", DictGet("d", "nope"))],
    )
    try:
        evaluate_program(bad_get)
        fails.append("ref: DictGet missing key accepted")
    except ReferenceError as exc:
        if "DictGet on missing key" not in str(exc):
            fails.append(f"ref: unexpected ReferenceError {exc}")
    except Exception as exc:
        fails.append(f"ref: expected ReferenceError got {type(exc).__name__}: {exc}")

    # --- Shape relationship proofs ---
    base = dict(
        family="c3_dict_missing",
        module_dicts={"d": {"a": 1, "b": 2}},
        required_path={
            "forced_ast": "ast",
            "interpreter": "bytecode",
            "default": "bytecode",
            "tier3": "bytecode",
        },
        path_target="SemMain",
    )
    a1 = Program(
        case_id="s1",
        seed=1,
        index=0,
        main=[DictMissCheck("d", "m1", "miss"), Observe("n", DictGet("d", "a"))],
        **base,
    )
    a2 = Program(
        case_id="s2",
        seed=2,
        index=1,
        module_dicts={"d": {"a": 99, "b": 88}},
        main=[DictMissCheck("d", "m99", "miss"), Observe("n", DictGet("d", "a"))],
        family="c3_dict_missing",
        required_path=base["required_path"],
        path_target="SemMain",
    )
    if shape_fingerprint(a1) != shape_fingerprint(a2):
        fails.append("shape: consistent miss/present rename altered shape")

    # Same miss key twice vs two different miss keys.
    same_twice = Program(
        case_id="st",
        seed=0,
        index=0,
        family="c3_dict_missing",
        module_dicts={"d": {"a": 1}},
        main=[
            DictMissCheck("d", "nope", "m0"),
            DictMissCheck("d", "nope", "m1"),
        ],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    two_miss = Program(
        case_id="tm",
        seed=0,
        index=1,
        family="c3_dict_missing",
        module_dicts={"d": {"a": 1}},
        main=[
            DictMissCheck("d", "nope", "m0"),
            DictMissCheck("d", "other", "m1"),
        ],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    if shape_fingerprint(same_twice) == shape_fingerprint(two_miss):
        fails.append("shape: different absent keys collapsed to same shape")
    # Multi-miss / write-new shapes: report whether the generator can emit them.
    cov = classify_coverage_shapes(generate_c3_batch(101, 48))
    for key, need in (
        ("a_two_miss_keys", 3),
        ("b_same_miss_twice", 3),
        ("c_write_new", 3),
        ("d_overwrite_count", 3),
    ):
        if cov.get(key, 0) < need:
            fails.append(f"shape: coverage {key}={cov.get(key, 0)} < {need}")

    # Detector negatives for new families (a–d).
    def _neg(label: str, prog: Program, mutate) -> None:
        good = [o.to_dict() for o in evaluate_program(prog).observations]
        bad = mutate([dict(o) for o in good])
        try:
            compare_observations(good, bad)
            fails.append(f"detector_{label}: accepted mutation")
        except CompareError as exc:
            if exc.code != "wrong_value":
                fails.append(f"detector_{label}: expected wrong_value got {exc.code}")

    two = Program(
        case_id="neg_two",
        seed=0,
        index=0,
        family="c3_dict_miss_two_keys",
        module_dicts={"d": {"a": 1}},
        main=[
            DictMissCheck("d", "x", "m0"),
            DictMissCheck("d", "y", "m1"),
        ],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    _neg("a_two_miss", two, lambda obs: [{**obs[0], "value": "1"}, *obs[1:]])

    same = Program(
        case_id="neg_same",
        seed=0,
        index=0,
        family="c3_dict_miss_same_twice",
        module_dicts={"d": {"a": 1}},
        main=[
            DictMissCheck("d", "x", "t0"),
            DictMissCheck("d", "x", "t1"),
        ],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    _neg("b_same_miss", same, lambda obs: [{**o, "value": "9"} if o["name"] == "t1_vt" else o for o in obs])

    neg_wn = Program(
        case_id="neg_wn",
        seed=0,
        index=0,
        family="c3_dict_write_new",
        module_dicts={"d": {"a": 1, "b": 2}},
        main=[
            Observe("count_before", DictCount("d")),
            DictSet("d", "z", Lit(3)),
            Observe("count_after", DictCount("d")),
            Observe("new_exists", DictExists("d", "z")),
        ],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    _neg(
        "c_write_new",
        neg_wn,
        lambda obs: [
            {**o, "value": "0"} if o["name"] == "new_exists" else o for o in obs
        ],
    )

    over = Program(
        case_id="neg_ov",
        seed=0,
        index=0,
        family="c3_dict_overwrite_count",
        module_dicts={"d": {"a": 1, "b": 2}},
        main=[
            Observe("count_before", DictCount("d")),
            DictSet("d", "a", Lit(9)),
            Observe("count_after", DictCount("d")),
        ],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    _neg(
        "d_overwrite_count",
        over,
        lambda obs: [
            {**o, "value": "3"} if o["name"] == "count_after" else o for o in obs
        ],
    )

    nested = Program(
        case_id="neg_nested",
        seed=0,
        index=0,
        family="c3b_nested_dict_array",
        module_dicts={"d": {"k": [10, 20, 30]}},
        main=[
            NestedSlotSet("d", "k", 1, Lit(99)),
            Observe("s1", NestedSlotGet("d", "k", 1)),
        ],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    _neg(
        "c3b_nested",
        nested,
        lambda obs: [{**o, "value": "20"} if o["name"] == "s1" else o for o in obs],
    )

    udt = Program(
        case_id="neg_udt",
        seed=0,
        index=0,
        family="c3b_udt_copy",
        module_udts={"p": {"a": 10, "c": 3}, "q": {"a": 0, "c": 0}},
        main=[
            UdtCopy("q", "p"),
            UdtFieldSet("q", "a", Lit(99)),
            Observe("p_a", UdtFieldGet("p", "a")),
            Observe("q_a", UdtFieldGet("q", "a")),
        ],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    _neg(
        "c3b_udt",
        udt,
        lambda obs: [{**o, "value": "99"} if o["name"] == "p_a" else o for o in obs],
    )
    # Present/write: DictSet new key then get differs from present-only get.
    write_new_shape = Program(
        case_id="wn",
        seed=0,
        index=0,
        family="c3_dict_present",
        module_dicts={"d": {"a": 1}},
        main=[DictSet("d", "z", Lit(3)), Observe("z", DictGet("d", "z"))],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    present_only = Program(
        case_id="po",
        seed=0,
        index=1,
        family="c3_dict_present",
        module_dicts={"d": {"a": 1, "z": 3}},
        main=[Observe("z", DictGet("d", "z"))],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    if shape_fingerprint(write_new_shape) == shape_fingerprint(present_only):
        fails.append("shape: write-then-get collapsed with initially-present get")

    arr3 = Program(
        case_id="sa",
        seed=0,
        index=0,
        family="c3_array_slot",
        module_arrays={"arr": [1, 2, 3]},
        main=[ArrSet("arr", 1, Lit(9)), Observe("s0", ArrGet("arr", 0))],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    arr4 = Program(
        case_id="sb",
        seed=0,
        index=1,
        family="c3_array_slot",
        module_arrays={"arr": [1, 2, 3, 4]},
        main=[ArrSet("arr", 1, Lit(9)), Observe("s0", ArrGet("arr", 0))],
        required_path=base["required_path"],
        path_target="SemMain",
    )
    if shape_fingerprint(arr3) == shape_fingerprint(arr4):
        fails.append("shape: different array length not distinct")

    try:
        batch = generate_c3_batch(7, 9)
        if len(batch) != 9:
            fails.append(f"batch size {len(batch)}")
        for p in batch:
            text = dumps_program(p)
            from .ir import loads_program

            p2 = loads_program(text)
            e1 = [o.to_dict() for o in evaluate_program(p).observations]
            e2 = [o.to_dict() for o in evaluate_program(p2).observations]
            compare_observations(e1, e2)
        if "impure_index_byref" not in UNSUPPORTED_PAIRS:
            fails.append("UNSUPPORTED_PAIRS missing impure_index_byref")
    except Exception as exc:
        fails.append(f"generator/serde: {type(exc).__name__}: {exc}")

    try:
        from .emitter import emit_program

        src = emit_program(_hand_array())
        if "arr(1) = 120" not in src or "Dim arr(2) As Integer" not in src:
            fails.append(f"emit array shape unexpected: {src[:200]}")
        src2 = emit_program(_hand_dict_miss())
        miss_i = src2.find('_c3_miss = d("nope")')
        err_i = src2.find("_c3_err = Err.Number")
        vt_i = src2.find("_sem_obs = VarType(_c3_miss)")
        if not (0 <= miss_i < err_i < vt_i):
            fails.append(f"emit err capture order miss={miss_i} err={err_i} vt={vt_i}")
    except Exception as exc:
        fails.append(f"emit: {type(exc).__name__}: {exc}")

    try:
        prog = generate_c3_case(11, 0)
        expected = [o.to_dict() for o in evaluate_program(prog).observations]
        with tempfile.TemporaryDirectory(prefix="vg-c3-replay-") as td:
            case = Path(td) / "case"
            case.mkdir()
            (case / "ir.json").write_text(dumps_program(prog), encoding="utf-8")
            (case / "expected.json").write_text(
                json.dumps(expected, indent=2) + "\n", encoding="utf-8"
            )
            from .ir import loads_program

            loaded = loads_program((case / "ir.json").read_text(encoding="utf-8"))
            saved = json.loads((case / "expected.json").read_text(encoding="utf-8"))
            fresh = [o.to_dict() for o in evaluate_program(loaded).observations]
            compare_observations(saved, fresh)
    except Exception as exc:
        fails.append(f"replay_oracle: {type(exc).__name__}: {exc}")

    try:
        validate_program(
            Program(
                case_id="x",
                seed=0,
                index=0,
                family="c3_array_slot",
                module_arrays={"arr": []},
                main=[Observe("z", Lit(0))],
            )
        )
        fails.append("validate: empty array accepted")
    except ValidationError:
        pass
    except Exception as exc:
        fails.append(f"validate empty: expected ValidationError got {exc}")

    # Version refuse: synthetic checkpoint-7 style meta (reference_version=4).
    from . import REFERENCE_VERSION
    from .provenance import check_schema_model

    if REFERENCE_VERSION < 5:
        fails.append(f"reference_version expected >=5 got {REFERENCE_VERSION}")
    refuse = check_schema_model({"schema_version": 1, "reference_version": 4, "generator_version": 1})
    if not refuse or "reference_version incompatible" not in refuse:
        fails.append(f"version refuse missing for v4 meta: {refuse}")

    return fails
