# Multi-file projects and `Import`

Visual Gasic modules are ordinary `.vg` files linked with **`Import "res://path/Module.vg"`** (VB6-style standard modules). Use them to split gameplay, rendering, and data without GDScript.

---

## Root script owns the import list (not transitive)

At runtime, the engine loads **`Import` statements only from the `.vg` script attached to the scene node** that Godot is running (usually **`Main.vg` on your entry scene root**). It does **not** automatically load imports-of-imports.

| File | `Import "Grid.vg"` | Loaded at runtime when F5 runs `Main.vg`? |
|------|-------------------|-------------------------------------------|
| `Main.vg` | yes | **Yes** — Grid subs and module `Dim`/`Const` are registered |
| `Play.vg` | yes (only here) | **No** — helps compile/edit `Play.vg`, but Grid is invisible to the running instance unless `Main.vg` also imports Grid |

If a nested module calls `Call InitDemoLevel()` and Grid defines that Sub only in `Grid.vg` imported from `Play.vg`, you get:

**Runtime Error 35: Sub or Function not defined: InitDemoLevel**

### Fix

List **every module** whose Subs/Functions (or module-level state) the game needs on the **root** script:

```vb
' Main.vg — entry script on the scene root
Import "res://scripts/Grid.vg"
Import "res://scripts/Play.vg"
Import "res://scripts/Render.vg"
```

Reference: `samples/apps/vector_fathom/VectorFathom.vg` imports all gameplay modules directly; `samples/showcases/circuit_breaker/Main.vg` does the same.

Child modules may still `Import` each other for **readability and IDE navigation** (Procedure dropdown, Go to Definition). That does not replace listing shared modules on the root when they must run at runtime.

---

## Calling imported code

- **Bare name** — `Call PlayInit()` works when the Sub lives in a module imported from the root (or in the root file).
- **Qualified name** — `Call Grid.InitDemoLevel()` or `Grid.GetCell(x, y)` when you want the module prefix explicit (module name = file basename, e.g. `Grid.vg` → `Grid`).

---

## Other rules (short)

- **`Import` adds Subs/Functions and module symbols** — it does **not** add new statement keywords (QB `SCREEN` / `LINE` are engine builtins, not imports).
- **Module-level `Dim` / `Public`** in an imported file are tied to **that script instance** (the node running the root `.vg`). They are **not** shared across unrelated nodes; use a **Godot autoload** for cross-scene shared state (see Narcea / autoload patterns).
- **`Global Const` / `Global Dim`** (v4.4+) publish process-wide bare names without `Import`; classes and most multi-file Sub calls still need the import graph on the root script.
- **Circular imports** are detected and skipped with a console warning.

---

## Scene setup checklist

1. Entry scene root (e.g. `Node2D`) has **one** `.vg` script (e.g. `Main.vg`).
2. **`Import` on `Main.vg`** includes every module the run will call into.
3. The `.tscn` only references that root script; other `.vg` files live under `scripts/` (or your layout) and are pulled in via `Import`.

See also: [QuickBASIC graphics setup](qb_graphics_mode.md#godot-project-setup-classic-screen-games), [IDE Tools](ide_tools.md).
