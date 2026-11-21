"""Hand-worked oracle boundary tests (contract R1–R6, C1 R9) before campaigns."""

from __future__ import annotations

from .phase2_c1_selftest import run_phase2_c1_selftests
from .phase2_c2_selftest import run_phase2_c2_selftests
from .phase2_c3_selftest import run_phase2_c3_selftests
from .reference import ibin, icmp, idiv, imod


def run_oracle_selftests() -> list[str]:
    failures: list[str] = []

    def expect(label: str, got, want):
        if got != want:
            failures.append(f"{label}: got {got!r} want {want!r}")

    # R1
    expect("add", ibin("+", 7, 3), 10)
    expect("sub", ibin("-", 7, 3), 4)
    expect("sub_noncomm", ibin("-", 3, 7), -4)
    expect("mul", ibin("*", 7, 3), 21)

    # R2 toward-zero integer division
    expect("idiv_pos", idiv(10, 3), 3)
    expect("idiv_neg_num", idiv(-10, 3), -3)
    expect("idiv_neg_den", idiv(10, -3), -3)
    expect("idiv_both_neg", idiv(-10, -3), 3)

    # R3 Mod
    expect("mod_pos", imod(10, 3), 1)
    expect("mod_neg_num", imod(-10, 3), -1)
    expect("mod_neg_den", imod(10, -3), 1)

    # R4 comparisons
    expect("gt_true", icmp(">", 5, 3), True)
    expect("gt_false", icmp(">", 3, 5), False)
    expect("eq", icmp("=", 4, 4), True)

    # Select / For are covered via evaluate_program in harness; boundary arithmetic above is mandatory.

    # Noncommutative \\ pair
    expect("idiv_fwd", idiv(20, 6), 3)
    expect("idiv_rev", idiv(6, 20), 0)

    # Phase 2 C1 R9 — banker's rounding independent oracle
    failures.extend(run_phase2_c1_selftests())
    # Phase 2 C2 — Integer ByRef/ByVal hand tables
    failures.extend(run_phase2_c2_selftests())
    # Phase 2 C3 — fixed arrays + dict present/missing (R12)
    failures.extend(run_phase2_c3_selftests())

    return failures
