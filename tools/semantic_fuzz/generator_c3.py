"""Bounded C3 collection generator (fixed arrays + dict present/missing).

Independent of VG execution: expected observations come from
``reference.evaluate_program``. Excludes ReDim identity, missing-key ByRef,
MemoryBuffer, impure indexed ByRef, alias, and named-order (see contracts).
"""

from __future__ import annotations

import hashlib
from random import Random
from typing import List

from .generator import case_id_for, shape_fingerprint, structural_fingerprint
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
)
from .reference import evaluate_program

C3_FAMILIES = (
    "c3_array_slot",
    "c3_dict_present",
    "c3_dict_missing",
    "c3_dict_miss_two_keys",
    "c3_dict_miss_same_twice",
    "c3_dict_write_new",
    "c3_dict_overwrite_count",
    "c3b_nested_dict_array",
    "c3b_udt_copy",
)

# Structural pairs we refuse to generate (align with C2 / C3 contract exclusions).
UNSUPPORTED_PAIRS = (
    "impure_index_byref",
    "redim_container_identity",
    "missing_key_byref_writeback",
    "memorybuffer_indexed_byref",
    "alias_repeated_byref_args",
    "named_arg_order",
)


def _req_path() -> dict:
    return {
        "forced_ast": "ast",
        "interpreter": "bytecode",
        "default": "bytecode",
        "tier3": "bytecode",
    }


def _req_path_ast() -> dict:
    """C3b nested/UDT currently compile to AST under non-forced modes."""
    return {
        "forced_ast": "ast",
        "interpreter": "ast",
        "default": "ast",
        "tier3": "ast",
    }


def _fresh_miss(rng: Random, *forbidden: str) -> str:
    miss = f"m{rng.randint(0, 99)}"
    while miss in forbidden:
        miss = f"m{rng.randint(0, 99)}"
    return miss


def gen_array_slot(rng: Random, seed: int, index: int) -> Program:
    """Hand-shaped: fixed array; write one slot; observe neighbors + slot."""
    size = rng.choice((3, 4))  # shape diversity: UBound 2 vs 3
    slots = [rng.randint(1, 40) for _ in range(size)]
    target = 1 if size == 3 else rng.choice((1, 2))
    delta = rng.randint(1, 20)
    new_val = slots[target] + delta
    expected = list(slots)
    expected[target] = new_val
    family = "c3_array_slot"
    main = [ArrSet("arr", target, Lit(new_val))]
    for i in range(size):
        main.append(Observe(f"s{i}", ArrGet("arr", i)))
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3", "array"],
        module_arrays={"arr": slots},
        main=main,
        required_path=_req_path(),
        path_target="SemMain",
        notes=(
            f"hand: start={slots} write idx={target} val={new_val} → {expected}. "
            "Sources: test_sem_c3_array_slot.vg neighbor table; "
            "SEMANTIC_FUZZ_CONTRACTS.md Phase 2 C3."
        ),
    )


def gen_dict_present(rng: Random, seed: int, index: int) -> Program:
    """Present read, write, neighbor unchanged."""
    av = rng.randint(1, 50)
    bv = rng.randint(1, 50)
    nv = rng.randint(1, 50)
    family = "c3_dict_present"
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3", "dict"],
        module_dicts={"d": {"a": av, "b": bv}},
        main=[
            Observe("before_a", DictGet("d", "a")),
            Observe("before_b", DictGet("d", "b")),
            DictSet("d", "a", Lit(nv)),
            Observe("after_a", DictGet("d", "a")),
            Observe("after_b", DictGet("d", "b")),
        ],
        required_path=_req_path(),
        path_target="SemMain",
        notes=(
            f"hand: d(a)={av} d(b)={bv}; write a={nv}; expect after_b={bv}. "
            "Sources: test_sem_c3_dict_keys.vg; R12 present-key path."
        ),
    )


def gen_dict_missing(rng: Random, seed: int, index: int) -> Program:
    """Missing-key R12 probe + present neighbor unchanged."""
    av = rng.randint(1, 50)
    bv = rng.randint(1, 50)
    miss = _fresh_miss(rng, "a", "b")
    family = "c3_dict_missing"
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3", "dict", "r12"],
        module_dicts={"d": {"a": av, "b": bv}},
        main=[
            DictMissCheck("d", miss, "miss"),
            Observe("neighbor_a", DictGet("d", "a")),
            Observe("neighbor_b", DictGet("d", "b")),
        ],
        required_path=_req_path(),
        path_target="SemMain",
        notes=(
            f"hand: miss key={miss!r} → vt=1 is_nothing=1 err=0; "
            f"neighbors a={av} b={bv}. Sources: R12; test_sem_c3_dict_keys.vg."
        ),
    )


def gen_dict_miss_two_keys(rng: Random, seed: int, index: int) -> Program:
    """(a) Two DictMissCheck on different missing keys."""
    av = rng.randint(1, 50)
    bv = rng.randint(1, 50)
    m0 = _fresh_miss(rng, "a", "b")
    m1 = _fresh_miss(rng, "a", "b", m0)
    family = "c3_dict_miss_two_keys"
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3", "dict", "r12", "multi_miss"],
        module_dicts={"d": {"a": av, "b": bv}},
        main=[
            DictMissCheck("d", m0, "m0"),
            DictMissCheck("d", m1, "m1"),
            Observe("neighbor_a", DictGet("d", "a")),
        ],
        required_path=_req_path(),
        path_target="SemMain",
        notes=f"hand: two distinct miss keys {m0!r}/{m1!r}; neighbor a={av}.",
    )


def gen_dict_miss_same_twice(rng: Random, seed: int, index: int) -> Program:
    """(b) Same missing key checked twice."""
    av = rng.randint(1, 50)
    miss = _fresh_miss(rng, "a", "b")
    family = "c3_dict_miss_same_twice"
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3", "dict", "r12", "same_miss"],
        module_dicts={"d": {"a": av}},
        main=[
            DictMissCheck("d", miss, "t0"),
            DictMissCheck("d", miss, "t1"),
            Observe("neighbor_a", DictGet("d", "a")),
        ],
        required_path=_req_path(),
        path_target="SemMain",
        notes=f"hand: same miss key {miss!r} twice; neighbor a={av}.",
    )


def gen_dict_write_new(rng: Random, seed: int, index: int) -> Program:
    """(c) DictSet new key, then get/Exists, plus Count."""
    av = rng.randint(1, 50)
    bv = rng.randint(1, 50)
    nv = rng.randint(1, 50)
    new_key = _fresh_miss(rng, "a", "b")
    family = "c3_dict_write_new"
    use_exists = rng.random() < 0.5
    main = [
        Observe("count_before", DictCount("d")),
        DictSet("d", new_key, Lit(nv)),
        Observe("count_after", DictCount("d")),
    ]
    if use_exists:
        main.append(Observe("new_exists", DictExists("d", new_key)))
    else:
        main.append(Observe("new_val", DictGet("d", new_key)))
    main.append(Observe("neighbor_a", DictGet("d", "a")))
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3", "dict", "write_new"],
        module_dicts={"d": {"a": av, "b": bv}},
        main=main,
        required_path=_req_path(),
        path_target="SemMain",
        notes=(
            f"hand: insert {new_key!r}={nv}; count 2→3; "
            f"{'Exists' if use_exists else 'Get'}; neighbor a={av}."
        ),
    )


def gen_dict_overwrite_count(rng: Random, seed: int, index: int) -> Program:
    """(d) DictSet overwrite existing key; Count unchanged."""
    av = rng.randint(1, 50)
    bv = rng.randint(1, 50)
    nv = rng.randint(1, 50)
    family = "c3_dict_overwrite_count"
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3", "dict", "overwrite_count"],
        module_dicts={"d": {"a": av, "b": bv}},
        main=[
            Observe("count_before", DictCount("d")),
            DictSet("d", "a", Lit(nv)),
            Observe("count_after", DictCount("d")),
            Observe("after_a", DictGet("d", "a")),
            Observe("after_b", DictGet("d", "b")),
        ],
        required_path=_req_path(),
        path_target="SemMain",
        notes=f"hand: overwrite a {av}→{nv}; count stays 2; b={bv}.",
    )


def gen_c3b_nested_dict_array(rng: Random, seed: int, index: int) -> Program:
    """Dictionary→Array write-through + neighbor slots (OBSERVED shared inner)."""
    size = 3
    slots = [rng.randint(1, 40) for _ in range(size)]
    target = rng.choice((0, 1, 2))
    new_val = rng.randint(50, 90)
    family = "c3b_nested_dict_array"
    main = [
        NestedSlotSet("d", "k", target, Lit(new_val)),
        Observe("s0", NestedSlotGet("d", "k", 0)),
        Observe("s1", NestedSlotGet("d", "k", 1)),
        Observe("s2", NestedSlotGet("d", "k", 2)),
        Observe("count", DictCount("d")),
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3b", "nested"],
        module_dicts={"d": {"k": list(slots)}},
        main=main,
        required_path=_req_path_ast(),
        path_target="SemMain",
        notes=f"c3b nested: start={slots} write idx={target} val={new_val}.",
    )


def gen_c3b_udt_copy(rng: Random, seed: int, index: int) -> Program:
    """UDT value copy then mutate copy or original (VB6 copy semantics)."""
    pa = rng.randint(1, 40)
    pc = rng.randint(1, 40)
    nv = rng.randint(50, 90)
    mut_copy = rng.random() < 0.5
    family = "c3b_udt_copy"
    main = [
        UdtCopy("q", "p"),
        UdtFieldSet("q" if mut_copy else "p", "a", Lit(nv)),
        Observe("p_a", UdtFieldGet("p", "a")),
        Observe("p_c", UdtFieldGet("p", "c")),
        Observe("q_a", UdtFieldGet("q", "a")),
        Observe("q_c", UdtFieldGet("q", "c")),
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c3b", "udt"],
        module_udts={"p": {"a": pa, "c": pc}, "q": {"a": 0, "c": 0}},
        main=main,
        # Generated Integer-only UDT copy stays on bytecode (fixture UDT with
        # String/ByRef helpers may still AST-bail — path is not a language contract).
        required_path=_req_path(),
        path_target="SemMain",
        notes=f"c3b udt: p=({pa},{pc}) mut_{'copy' if mut_copy else 'orig'} a={nv}.",
    )


_GENERATORS = {
    "c3_array_slot": gen_array_slot,
    "c3_dict_present": gen_dict_present,
    "c3_dict_missing": gen_dict_missing,
    "c3_dict_miss_two_keys": gen_dict_miss_two_keys,
    "c3_dict_miss_same_twice": gen_dict_miss_same_twice,
    "c3_dict_write_new": gen_dict_write_new,
    "c3_dict_overwrite_count": gen_dict_overwrite_count,
    "c3b_nested_dict_array": gen_c3b_nested_dict_array,
    "c3b_udt_copy": gen_c3b_udt_copy,
}


def generate_c3_case(seed: int, index: int) -> Program:
    rng = Random((seed << 16) ^ (index * 0x9E3779B9) ^ 0xC30001)
    family = C3_FAMILIES[index % len(C3_FAMILIES)]
    # Salt family pick with rng so shapes diversify beyond pure rotation.
    if rng.random() < 0.15:
        family = rng.choice(list(C3_FAMILIES))
    prog = _GENERATORS[family](rng, seed, index)
    # Force reference acceptance before returning.
    evaluate_program(prog)
    return prog


def generate_c3_batch(seed: int, count: int) -> List[Program]:
    if count < 1:
        raise ValueError("empty batch refused")
    out: List[Program] = []
    seen = set()
    i = 0
    attempts = 0
    while len(out) < count and attempts < count * 40:
        attempts += 1
        prog = generate_c3_case(seed, i)
        i += 1
        fp = structural_fingerprint(prog)
        if fp in seen:
            continue
        seen.add(fp)
        out.append(prog)
    if len(out) < count:
        raise RuntimeError(f"c3 batch under-generated: {len(out)}/{count}")
    return out


def covered_pairs(programs: List[Program]) -> list[str]:
    pairs = set()
    for p in programs:
        if p.family == "c3_array_slot":
            pairs.add("array_literal_index_write_neighbor")
        elif p.family == "c3_dict_present":
            pairs.add("dict_present_read_write_neighbor")
        elif p.family == "c3_dict_missing":
            pairs.add("dict_missing_r12_neighbor")
        elif p.family == "c3_dict_miss_two_keys":
            pairs.add("dict_miss_two_keys")
        elif p.family == "c3_dict_miss_same_twice":
            pairs.add("dict_miss_same_twice")
        elif p.family == "c3_dict_write_new":
            pairs.add("dict_write_new_count")
        elif p.family == "c3_dict_overwrite_count":
            pairs.add("dict_overwrite_count_unchanged")
        elif p.family == "c3b_nested_dict_array":
            pairs.add("c3b_nested_dict_array_write_neighbor")
        elif p.family == "c3b_udt_copy":
            pairs.add("c3b_udt_value_copy_mutate")
    return sorted(pairs)


def classify_coverage_shapes(programs: List[Program]) -> dict[str, int]:
    """Count programs matching task-2 shapes a–d (and legacy families)."""
    counts = {
        "a_two_miss_keys": 0,
        "b_same_miss_twice": 0,
        "c_write_new": 0,
        "d_overwrite_count": 0,
    }
    for gp in programs:
        miss_keys = [
            s.key for s in gp.main if type(s).__name__ == "DictMissCheck"
        ]
        if len(miss_keys) >= 2 and len(set(miss_keys)) >= 2:
            counts["a_two_miss_keys"] += 1
        if len(miss_keys) >= 2 and len(set(miss_keys)) == 1:
            counts["b_same_miss_twice"] += 1
        if gp.family == "c3_dict_write_new":
            counts["c_write_new"] += 1
        if gp.family == "c3_dict_overwrite_count":
            counts["d_overwrite_count"] += 1
    return counts


def batch_shape_digest(programs: List[Program]) -> str:
    blob = "|".join(sorted(shape_fingerprint(p) for p in programs))
    return hashlib.sha256(blob.encode()).hexdigest()[:16]
