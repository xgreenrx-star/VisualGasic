"""Source-derived C2 fixture expectations (not derived from the log under test)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Optional, Tuple

from .path_contract import PathRequirement


@dataclass(frozen=True)
class FixtureExpect:
    """Expected PASS identities and optional known-failure / summary contracts."""

    pass_labels: Tuple[str, ...]
    summary_pass: Optional[str] = None
    require_c2_summary: bool = False
    require_known_index_evals: Optional[int] = None
    # Module-qualified path contracts (empty = request-lane only for paths).
    path_requirements: Tuple[PathRequirement, ...] = ()

    def expected_pass_line_count(self) -> int:
        n = len(self.pass_labels)
        if self.summary_pass:
            n += 1
        return n


PRIMARY_PASS_LABELS: Tuple[str, ...] = (
    "standalone ByRef caller after",
    "expression ByRef return",
    "expression ByRef caller mutation",
    "standalone ByVal caller unchanged",
    "expression ByVal return",
    "expression ByVal caller unchanged",
    "default bare param is ByRef",
    "two distinct left",
    "two distinct right",
    "alias same var twice OBSERVED copy-in/write-back",
    "nested ByRef final caller",
    "nested event order",
    "recursive ByRef return",
    "recursive ByRef final caller",
    "indexed ByRef write-back slot",
    "indexed ByRef index once",
)

# forced_ast → ast; interpreter → bytecode; default/tier3 → bytecode or native
# (Tier-3 request may still only hit native_t2 / bytecode — not claimed as t3).
_MODE_AST_BC_NATIVE = {
    "forced_ast": "ast",
    "interpreter": "bytecode",
    "default": "bytecode_or_native",
    "tier3": "bytecode_or_native",
}

PRIMARY_MOD = "res://test_suite/test_sem_c2_calls_byref.vg"
IMPORT_HELPER = "res://test_suite/byref_import_helper.vg"
AST_IMPORT_HELPER = "res://test_suite/byref_ast_import_helper.vg"
CALLER_HELPER = "res://test_suite/byref_caller_helper.vg"
MOD_A = "res://test_suite/c2_path_mod_a.vg"
MOD_B = "res://test_suite/c2_path_mod_b.vg"
MOD_ID = "res://test_suite/test_sem_c2_mod_identity.vg"


def _req(fn: str, mod: str) -> PathRequirement:
    return PathRequirement(fn=fn, mod=mod, mode_paths=dict(_MODE_AST_BC_NATIVE))


FIXTURE_EXPECT: Dict[str, FixtureExpect] = {
    "test_sem_c2_calls_byref": FixtureExpect(
        pass_labels=PRIMARY_PASS_LABELS,
        summary_pass="sem_c2_calls_byref",
        require_c2_summary=True,
        path_requirements=(
            _req("StandaloneByRef", PRIMARY_MOD),
            _req("ExprByRef", PRIMARY_MOD),
            _req("NestedOuter", PRIMARY_MOD),
            _req("RecAdd", PRIMARY_MOD),
            _req("IdxSide", PRIMARY_MOD),
            _req("BumpSlot", PRIMARY_MOD),
        ),
    ),
    "test_byref_byval": FixtureExpect(
        pass_labels=(
            "byref_modifies_caller",
            "byval_no_modify",
            "byref_swap",
            "byref_string",
            "byref_in_loop",
            "mixed_byref_byval",
            "byref_with_function",
        ),
        # Prior-art: assertion coverage only (path request-lane unless listed).
    ),
    "test_byref_array_slot": FixtureExpect(
        pass_labels=("ByRef array slot write-back",),
    ),
    "test_byref_computed_index": FixtureExpect(
        pass_labels=("ByRef writeback survives computed index",),
    ),
    "test_byref_import": FixtureExpect(
        pass_labels=(
            "byref_import_stmt_accum",
            "byref_import_expr_flag",
            "byref_import_expr_return",
        ),
        path_requirements=(_req("StepOnce", IMPORT_HELPER),),
    ),
    "test_byref_ast_import": FixtureExpect(
        pass_labels=(
            "byref_ast_import",
            "byref_ast_import_slot",
            "byref_import_expression_slots",
            "byref_import_temporary_arguments",
        ),
        # Caller _Ready stays AST (2D grid); imported FillBox is compiled/native
        # under non-forced modes — both must carry defining-module tags.
        path_requirements=(
            PathRequirement(
                fn="_Ready",
                mod="res://test_suite/test_byref_ast_import.vg",
                mode_paths={
                    "forced_ast": "ast",
                    "interpreter": "ast",
                    "default": "ast",
                    "tier3": "ast",
                },
            ),
            _req("FillBox", AST_IMPORT_HELPER),
        ),
    ),
    "test_byref_caller_import": FixtureExpect(
        pass_labels=("byref_caller_import_path",),
        path_requirements=(_req("BumpPath", CALLER_HELPER),),
    ),
    "test_sem_c2_mod_identity": FixtureExpect(
        pass_labels=(
            "entry_a_from_mod_a",
            "entry_b_from_mod_b",
            "caller_callboth_sum",
        ),
        summary_pass="sem_c2_mod_identity",
        require_c2_summary=True,
        path_requirements=(
            _req("EntryA", MOD_A),
            _req("EntryB", MOD_B),
            _req("CallBoth", MOD_ID),
        ),
    ),
    "test_sem_c2_twin_a_only": FixtureExpect(
        pass_labels=("twin_a_only",),
        summary_pass="sem_c2_twin_a_only",
        path_requirements=(_req("Twin", MOD_A),),
    ),
    "test_sem_c2_twin_b_only": FixtureExpect(
        pass_labels=("twin_b_only",),
        summary_pass="sem_c2_twin_b_only",
        path_requirements=(_req("Twin", MOD_B),),
    ),
    "test_sem_c2_alt_basename": FixtureExpect(
        pass_labels=("alt_basename_twin",),
        summary_pass="sem_c2_alt_basename",
        path_requirements=(
            _req("Twin", "res://c2_alt_mods/c2_path_mod_a.vg"),
        ),
    ),
}

ALLOWED_RESOURCES: Dict[str, str] = {
    f"res://test_suite/{base}.vg": base for base in FIXTURE_EXPECT
}


def expect_for(base: str) -> Optional[FixtureExpect]:
    return FIXTURE_EXPECT.get(base)


def resolve_resource(resource: str) -> Optional[Tuple[str, FixtureExpect]]:
    base = ALLOWED_RESOURCES.get(resource)
    if base is None:
        return None
    return base, FIXTURE_EXPECT[base]
