"""Phase 2 C1 oracle probes (no Godot). Fixture .vg is run separately under Godot."""

from __future__ import annotations

from .vb_round import vb_round_half_even


def run_phase2_c1_selftests() -> list[str]:
    fails: list[str] = []

    def expect(label: str, got, want) -> None:
        if got != want:
            fails.append(f"C1:{label}: got {got!r} want {want!r}")

    # R9 banker's rounding — hand-derived, must not use VG as oracle.
    cases = [
        (2.5, 2),
        (3.5, 4),
        (-2.5, -2),
        (-3.5, -4),
        (3.7, 4),
        (-3.7, -4),
        (2.5000001, 3),
        (2.0, 2),
        (-4.0, -4),
        (0.5, 0),
        (1.5, 2),
    ]
    for x, want in cases:
        expect(f"vb_round({x})", vb_round_half_even(x), want)

    # Sanity: Python round matches the contract helper for these ties.
    if round(2.5) != 2 or round(3.5) != 4:
        fails.append("C1:python_round_not_bankers")

    return fails
