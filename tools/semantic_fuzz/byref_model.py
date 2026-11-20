"""Bounded independent Integer call / ByRef model (Checkpoint 3 — partial).

Represents:
  - storage Locations (caller/module cells and frame-local cells);
  - explicit ByRef / ByVal parameter binding;
  - call frames with locals + return slot;
  - ByRef = copy-in to a frame-local cell, write-back to the bound Location
    on return (matches observed f(x,x) and recursive ByRef-to-param);
  - nested/recursive restoration of frames.

Does not execute VG, port production write-back, or model indexed/import L-values.
Alias f(x,x)→13 is modeled as observed copy-in/write-back; not declared a
language-law for random oracles until the contract is locked separately.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Optional


@dataclass(frozen=True)
class Location:
    name: str
    id: int


@dataclass
class Store:
    _next: int = 0
    _cells: dict[int, int] = field(default_factory=dict)

    def alloc(self, name: str, value: int = 0) -> Location:
        loc = Location(name=name, id=self._next)
        self._next += 1
        self._cells[loc.id] = int(value)
        return loc

    def get(self, loc: Location) -> int:
        return self._cells[loc.id]

    def set(self, loc: Location, value: int) -> None:
        self._cells[loc.id] = int(value)


@dataclass
class ParamSpec:
    name: str
    mode: str  # "byref" | "byval"
    default: Optional[int] = None


@dataclass
class Frame:
    locals: dict[str, Location] = field(default_factory=dict)
    # ByRef writebacks: (frame_local Location, caller Location)
    writebacks: list[tuple[Location, Location]] = field(default_factory=list)
    return_slot: Optional[int] = None


@dataclass
class Procedure:
    name: str
    params: list[ParamSpec]
    body: Callable[["VM"], None]


class VM:
    """Tiny stack machine for Integer call semantics."""

    def __init__(self) -> None:
        self.store = Store()
        self.frames: list[Frame] = []
        self.events: list[str] = []

    @property
    def frame(self) -> Frame:
        return self.frames[-1]

    def note(self, ev: str) -> None:
        self.events.append(ev)

    def local(self, name: str) -> Location:
        return self.frame.locals[name]

    def get_local(self, name: str) -> int:
        return self.store.get(self.local(name))

    def set_local(self, name: str, value: int) -> None:
        self.store.set(self.local(name), value)

    def set_return(self, value: int) -> None:
        self.frame.return_slot = int(value)

    def call(
        self,
        proc: Procedure,
        args: list[Optional[Location]],
    ) -> Optional[int]:
        """Invoke proc. args[i] is a Location for variables, or None to use default."""
        frame = Frame()
        writebacks: list[tuple[Location, Location]] = []
        for i, spec in enumerate(proc.params):
            src: Optional[Location] = args[i] if i < len(args) else None
            if src is None:
                if spec.default is None:
                    raise ValueError(f"missing arg {spec.name}")
                val = int(spec.default)
                cell = self.store.alloc(f"{proc.name}.{spec.name}", val)
                frame.locals[spec.name] = cell
                # ByVal default / missing — no writeback
                continue
            if spec.mode == "byval":
                val = self.store.get(src)
                cell = self.store.alloc(f"{proc.name}.{spec.name}", val)
                frame.locals[spec.name] = cell
            elif spec.mode == "byref":
                # Copy-in to a fresh frame cell; write back to src on return.
                val = self.store.get(src)
                cell = self.store.alloc(f"{proc.name}.{spec.name}", val)
                frame.locals[spec.name] = cell
                writebacks.append((cell, src))
            else:
                raise ValueError(f"unknown mode {spec.mode}")
        frame.writebacks = writebacks
        self.frames.append(frame)
        try:
            proc.body(self)
            ret = frame.return_slot
        finally:
            # Write-backs in parameter order (last wins on alias).
            for cell, dest in frame.writebacks:
                self.store.set(dest, self.store.get(cell))
            self.frames.pop()
        return ret


# --- Hand-table procedures (built on the frame model) ---


def _standalone_byref(vm: VM) -> None:
    vm.set_local("n", vm.get_local("n") + 1)


def _standalone_byval(vm: VM) -> None:
    vm.set_local("n", vm.get_local("n") + 1)


def _expr_byref(vm: VM) -> None:
    vm.set_local("x", vm.get_local("x") + 2)
    vm.set_return(vm.get_local("x") * 2)


def _expr_byval(vm: VM) -> None:
    vm.set_local("x", vm.get_local("x") + 2)
    vm.set_return(vm.get_local("x") * 2)


def _two_distinct(vm: VM) -> None:
    vm.set_local("a", vm.get_local("a") + 1)
    vm.set_local("b", vm.get_local("b") + 10)


def _alias_twice(vm: VM) -> None:
    vm.set_local("a", vm.get_local("a") + 1)
    vm.set_local("b", vm.get_local("b") + 10)


def _nested_inner(vm: VM) -> None:
    vm.note("inner")
    vm.set_local("y", vm.get_local("y") + 100)


def _nested_outer(vm: VM) -> None:
    vm.note("outer_enter")
    vm.set_local("x", vm.get_local("x") + 1)
    # Pass ByRef to this frame's x cell (not only the ultimate caller).
    inner = Procedure(
        "NestedInner",
        [ParamSpec("y", "byref")],
        _nested_inner,
    )
    vm.call(inner, [vm.local("x")])
    vm.set_local("x", vm.get_local("x") + 10)
    vm.note("outer_exit")


def _rec_add(vm: VM) -> None:
    depth = vm.get_local("depth")
    if depth <= 0:
        vm.set_return(vm.get_local("n"))
        return
    vm.set_local("n", vm.get_local("n") + 1)
    proc = Procedure(
        "RecAdd",
        [ParamSpec("n", "byref"), ParamSpec("depth", "byval", default=2)],
        _rec_add,
    )
    # Recurse ByRef into this frame's n cell; depth is ByVal.
    depth_loc = vm.store.alloc("depth_arg", depth - 1)
    inner = vm.call(proc, [vm.local("n"), depth_loc])
    assert inner is not None
    vm.set_return(inner + vm.get_local("n"))


PROC_STANDALONE_BYREF = Procedure(
    "StandaloneByRef", [ParamSpec("n", "byref")], _standalone_byref
)
PROC_STANDALONE_BYVAL = Procedure(
    "StandaloneByVal", [ParamSpec("n", "byval")], _standalone_byval
)
PROC_EXPR_BYREF = Procedure("ExprByRef", [ParamSpec("x", "byref")], _expr_byref)
PROC_EXPR_BYVAL = Procedure("ExprByVal", [ParamSpec("x", "byval")], _expr_byval)
PROC_TWO = Procedure(
    "TwoDistinct",
    [ParamSpec("a", "byref"), ParamSpec("b", "byref")],
    _two_distinct,
)
PROC_ALIAS = Procedure(
    "AliasTwice",
    [ParamSpec("a", "byref"), ParamSpec("b", "byref")],
    _alias_twice,
)
PROC_NESTED = Procedure("NestedOuter", [ParamSpec("x", "byref")], _nested_outer)
PROC_REC = Procedure(
    "RecAdd",
    [ParamSpec("n", "byref"), ParamSpec("depth", "byval", default=2)],
    _rec_add,
)


def obs(name: str, typ: str, value) -> dict[str, str]:
    return {"name": name, "type": typ, "value": str(value), "kind": "value"}


def run_hand_tables() -> list[dict[str, str]]:
    """Independently computed observations for the C2 hand tables (excl. alias lock)."""
    out: list[dict[str, str]] = []

    vm = VM()
    x = vm.store.alloc("x", 3)
    vm.call(PROC_STANDALONE_BYREF, [x])
    out.append(obs("standalone_byref_x", "Integer", vm.store.get(x)))

    vm = VM()
    x = vm.store.alloc("x", 3)
    vm.call(PROC_STANDALONE_BYVAL, [x])
    out.append(obs("standalone_byval_x", "Integer", vm.store.get(x)))

    vm = VM()
    x = vm.store.alloc("x", 3)
    r = vm.call(PROC_EXPR_BYREF, [x])
    out.append(obs("expr_byref_r", "Integer", r))
    out.append(obs("expr_byref_x", "Integer", vm.store.get(x)))

    vm = VM()
    x = vm.store.alloc("x", 3)
    r = vm.call(PROC_EXPR_BYVAL, [x])
    out.append(obs("expr_byval_r", "Integer", r))
    out.append(obs("expr_byval_x", "Integer", vm.store.get(x)))

    vm = VM()
    a = vm.store.alloc("a", 5)
    b = vm.store.alloc("b", 3)
    vm.call(PROC_TWO, [a, b])
    out.append(obs("two_a", "Integer", vm.store.get(a)))
    out.append(obs("two_b", "Integer", vm.store.get(b)))

    # Observed alias behavior (documented, not language-locked for generators).
    vm = VM()
    x = vm.store.alloc("x", 3)
    vm.call(PROC_ALIAS, [x, x])
    out.append(obs("alias_observed_x", "Integer", vm.store.get(x)))

    vm = VM()
    x = vm.store.alloc("x", 0)
    vm.call(PROC_NESTED, [x])
    out.append(obs("nested_x", "Integer", vm.store.get(x)))
    out.append(obs("nested_events", "String", ";".join(vm.events)))

    vm = VM()
    x = vm.store.alloc("x", 0)
    r = vm.call(PROC_REC, [x, None])  # depth default 2
    out.append(obs("rec_r", "Integer", r))
    out.append(obs("rec_x", "Integer", vm.store.get(x)))

    return out


# Back-compat thin wrappers used by older selftest imports.
def call_byref_mutate_add(store: Store, loc: Location, delta: int) -> None:
    vm = VM()
    vm.store = store
    proc = Procedure(
        "Bump",
        [ParamSpec("n", "byref")],
        lambda v: v.set_local("n", v.get_local("n") + delta),
    )
    vm.call(proc, [loc])


def call_byval_mutate_add(store: Store, loc: Location, delta: int) -> None:
    vm = VM()
    vm.store = store
    proc = Procedure(
        "BumpV",
        [ParamSpec("n", "byval")],
        lambda v: v.set_local("n", v.get_local("n") + delta),
    )
    vm.call(proc, [loc])


def call_expr_byref_double(store: Store, loc: Location) -> int:
    vm = VM()
    vm.store = store
    r = vm.call(PROC_EXPR_BYREF, [loc])
    assert r is not None
    return r


def call_expr_byval_double(store: Store, loc: Location) -> int:
    vm = VM()
    vm.store = store
    r = vm.call(PROC_EXPR_BYVAL, [loc])
    assert r is not None
    return r


def call_two_byref(store: Store, a: Location, b: Location) -> None:
    vm = VM()
    vm.store = store
    vm.call(PROC_TWO, [a, b])


def call_alias_twice(store: Store, a: Location, b: Location) -> None:
    vm = VM()
    vm.store = store
    vm.call(PROC_ALIAS, [a, b])


def call_nested(store: Store, x: Location) -> None:
    vm = VM()
    vm.store = store
    vm.call(PROC_NESTED, [x])


def call_rec_add(store: Store, n: Location, depth: int = 2) -> int:
    vm = VM()
    vm.store = store
    # When depth==2 use Optional default; else pass ByVal location.
    if depth == 2:
        r = vm.call(PROC_REC, [n, None])
    else:
        r = vm.call(PROC_REC, [n, store.alloc("d", depth)])
    assert r is not None
    return r
