# VB6 Importer Test Fixtures

This directory contains hand-crafted VB6 project fixtures used by
[test_vb6_importer.gd](../test_vb6_importer.gd) to exercise specific
importer code paths. Each fixture is small (one form, ~30 lines) and
focuses on a single feature so regressions are easy to localize.

| Fixture | What it exercises |
|---------|-------------------|
| `01_form_only/` | Bare-bones form: one button, one label, basic Click event. Smoke test for the entire pipeline. |
| `02_control_array/` | `Index =` control array (`Btn(0)`–`Btn(2)`) with a parameterized event handler. Covers literal-index and dynamic-index code paths in `_transform_line`. |
| `03_menus/` | `Begin VB.Menu` blocks with submenus, separators, shortcuts. Verifies `MenuBar` + `PopupMenu` tree construction and signal wiring. |
| `04_ocx_warnings/` | References a `Object=...` OCX (RichTextBox). Verifies graceful fallback + warning emission. |
| `05_encoding_cp1252/` | A `.frm` saved as Windows-1252 with extended characters in `Caption`. Verifies encoding detection + transcoding. |

Fixtures are read-only inputs. The test suite does not modify them.
