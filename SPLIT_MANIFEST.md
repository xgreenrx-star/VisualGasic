# SPLIT_MANIFEST.md — Complete File Classification for July 1 Repo Split

**Date**: Jun 22 2026  
**Target**: xgreenrx-star/vg-core repository  
**Scope**: Every file in `src/` (142 C++), `addons/visual_gasic/` top-level (133 GDScript), and subdirectories  
**Action**: This IS the day-1 extraction checklist. No guessing — copy only CORE files.

---

## Executive Summary

| Category | C++ Count | GDScript Count | Total |
|----------|-----------|---|---|
| **CORE** (keep for vg-core) | 130 | 28 | **158** |
| **IDE** (remove for vg-core) | 11 | 99 | **110** |
| **SHARED** (two versions) | 1 | 2 | **3** |
| **DELETE** | 0 | 4 | **4** |
| **TOTAL** | 142 | 133 | **275** |

---

## C++ Files (src/) — 142 Total

### CORE (130 files) — Copy to vg-core

**Language Frontend** (Tokenizer, Parser, AST)
```
visual_gasic_tokenizer.cpp
visual_gasic_tokenizer.h
visual_gasic_parser.cpp
visual_gasic_parser.h
visual_gasic_parser_format.cpp
visual_gasic_ast.h
visual_gasic_ast_arena.h
whenever_ast_temp.h
```

**Compiler & Optimization**
```
visual_gasic_compiler.cpp
visual_gasic_compiler.h
visual_gasic_optimizer.cpp
visual_gasic_optimizer.h
```

**Bytecode & VM**
```
visual_gasic_bytecode.h
visual_gasic_bytecode_cache.h
visual_gasic_instance.cpp
visual_gasic_instance.h
visual_gasic_instance_internal.h
visual_gasic_instance_bytecode_vm.cpp
visual_gasic_instance_statement.cpp
visual_gasic_instance_expression.cpp
visual_gasic_instance_builtins.cpp
visual_gasic_instance_class.cpp
visual_gasic_instance_multitask.cpp
visual_gasic_instance_fileio.cpp
```

**JIT (All Tiers)**
```
visual_gasic_jit.cpp
visual_gasic_jit.h
visual_gasic_jit_tier2.cpp
visual_gasic_jit_tier2.h
visual_gasic_jit_tier3.cpp
visual_gasic_jit_tier3.h
```

**Godot Integration**
```
visual_gasic_language.cpp
visual_gasic_language.h
visual_gasic_script.cpp
visual_gasic_script.h
visual_gasic_loader.cpp
visual_gasic_loader.h
```

**Built-in Classes & Functions**
```
visual_gasic_builtins.cpp
visual_gasic_builtins.h
```

**Runtime Extensions** (30+ files)
```
visual_gasic_async.cpp
visual_gasic_async.h
visual_gasic_timer.cpp
visual_gasic_timer.h
visual_gasic_task.cpp
visual_gasic_task.h
visual_gasic_signal_handler.cpp
visual_gasic_signal_handler.h
visual_gasic_collection.cpp
visual_gasic_collection.h
visual_gasic_regex.cpp
visual_gasic_regex.h
visual_gasic_crypto.cpp
visual_gasic_crypto.h
visual_gasic_http.cpp
visual_gasic_http.h
visual_gasic_socket.cpp
visual_gasic_socket.h
visual_gasic_xml.cpp
visual_gasic_xml.h
visual_gasic_zip.cpp
visual_gasic_zip.h
visual_gasic_ffi.cpp
visual_gasic_ffi.h
visual_gasic_odbc.cpp
visual_gasic_odbc.h
visual_gasic_database.cpp
visual_gasic_database.h
visual_gasic_recordset.cpp
visual_gasic_recordset.h
visual_gasic_memory_buffer.cpp
visual_gasic_memory_buffer.h
visual_gasic_ipc.cpp
visual_gasic_ipc.h
visual_gasic_fswatcher.cpp
visual_gasic_fswatcher.h
visual_gasic_file_permissions.cpp
visual_gasic_file_permissions.h
visual_gasic_process.cpp
visual_gasic_process.h
visual_gasic_gpu.cpp
visual_gasic_gpu.h
visual_gasic_ecs.cpp
visual_gasic_ecs.h
visual_gasic_system.cpp
visual_gasic_system.h
visual_gasic_android_bridge.cpp
visual_gasic_android_bridge.h
visual_gasic_comm.h
visual_gasic_vector_canvas.cpp
visual_gasic_vector_canvas.h
visual_gasic_com_interop.cpp
visual_gasic_com_interop.h
visual_gasic_package.cpp
visual_gasic_package.h
visual_gasic_package_manager.cpp
visual_gasic_package_manager.h
```

**Support & Analysis**
```
visual_gasic_error_reporter.h
visual_gasic_variable_scope.h
visual_gasic_expression_evaluator.cpp
visual_gasic_expression_evaluator.h
visual_gasic_linter.cpp
visual_gasic_linter.h
visual_gasic_lsp.cpp
visual_gasic_lsp.h
visual_gasic_settings.cpp
visual_gasic_settings.h
visual_gasic_script_cleanup.cpp
visual_gasic_immediate.cpp
visual_gasic_immediate.h
visual_gasic_repl.cpp
visual_gasic_repl.h
visual_gasic_test_runner.cpp
visual_gasic_test_runner.h
visual_gasic_performance.cpp
visual_gasic_profiler.cpp
visual_gasic_profiler.h
visual_gasic_benchmark.cpp
visual_gasic_benchmark.h
vg_fast_dict.h
```

### IDE (11 files) — DELETE for vg-core

```
visual_gasic_editor_plugin.cpp
visual_gasic_editor_plugin.h
visual_gasic_form_designer.cpp
visual_gasic_form_designer.h
visual_gasic_debugger.cpp
visual_gasic_debugger.h
visual_gasic_toolbox.cpp
visual_gasic_toolbox.h
gasic_ai_controller.cpp
gasic_ai_controller.h
gasic_form.cpp
gasic_form.h
visual_gasic_bracket_completion.cpp
visual_gasic_bracket_completion.h
visual_gasic_cbm_completion.cpp
visual_gasic_cbm_completion.h
visual_gasic_snippets.cpp
visual_gasic_snippets.h
visual_gasic_systray.cpp
visual_gasic_systray.h
visual_gasic_common_dialog.cpp
visual_gasic_common_dialog.h
```

### SHARED (1 file) — TWO VERSIONS NEEDED

```
register_types.cpp
register_types.h
```

**Action**: Create `register_types_core.cpp` (minimal Godot registration, no IDE UI) and `register_types_ide.cpp` (full IDE plugin registration). Both inherit common setup code if refactored into a header.

---

## GDScript Files (addons/visual_gasic/) — 133 Top-Level

### CORE (28 files) — Copy to addons/vg_core/

**Plugin Infrastructure**
```
plugin.cfg (NEEDS NEW VERSION — see docs)
plugin.gd (NEEDS NEW VERSION — see docs)
vg_plugin_base.gd
vg_plugin_manager.gd
vg_plugin_registry.gd
```

**Language-Facing Tools**
```
vb6_cli.gd (CLI runner — CORE)
vg_command_help.gd (Command Help dock)
vg_linter.gd (diagnostics surface)
vg_formatter.gd (optional code formatter)
vg_pkg_cli.gd (package CLI manager)
```

**Code Editor Integration** (minimal)
```
vg_code_edit.gd (syntax highlighting + completion bridge only)
```

**Intellisense & Analysis** (if needed)
```
vg_intellisense.gd (only if core dependency)
vg_goto_definition.gd (optional)
```

**Data Control Components** (runtime bindings)
```
vg_data_control.gd
vg_data_tips.gd
vg_dbcombo.gd
vg_dbgrid.gd
vg_controls_inspector.gd
```

**Simple UI Components** (if used by core)
```
vg_button.gd
vg_check_box.gd
vg_label.gd
vg_text_box.gd
vg_combo_box.gd
vg_list_box.gd
vg_scroll_bar.gd
vg_progress_bar.gd
vg_timer.gd
vg_shape.gd
```

**Context & Settings**
```
vg_context_broker.gd
vg_settings.gd (if exists; core-relevant settings)
```

### IDE (99 files) — DELETE for vg-core

**All Form Designers & VB6 UI**
```
form_editor_helper.gd
form_preview_toolbar.gd
form_preview_window.gd
custom_control_designer.gd
new_form_dialog.gd
menu_editor.gd
simple_inspector.gd
grid_arrange_dialog.gd
components_dialog.gd
vb6_importer.gd
vb6_layout_manager.gd
vb6_main_screen.gd
vb6_project_explorer.gd
vb6_toolbox_icons.gd
alignment_toolbar.gd
color_palette_toolbar.gd
vg_form_designer_theme.gd
```

**VB6 Asset Import**
```
frm_import_plugin.gd
doc_generator.gd
```

**Visual Editors**
```
vg_2d_editor.gd
vg_3d_editor.gd
vg_animation_editor.gd
vg_sprite_editor.gd
vg_hex_editor.gd
vg_input_map_editor.gd
```

**Debugger & Profiler**
```
vg_debugger_plugin.gd
vg_debug_handler.gd
vg_debug_handler.gd
call_stack_panel.gd
breakpoint_condition_dialog.gd
vg_breakpoint_conditions.gd
vg_profiler_panel.gd
vg_exception_assistant.gd
immediate_window.gd
```

**AI Assistants** (all)
```
vg_ai_action_settings.gd
vg_ai_code_spec.gd
vg_ai_diff_dialog.gd
vg_ai_form_spec.gd
vg_ai_function_calling.gd
vg_ai_help.gd
vg_ai_lesson_spec.gd
vg_ai_model_picker.gd
vg_ai_narcea.gd
vg_ai_patch_spec.gd
vg_ai_project_spec.gd
vg_ai_providers.gd
vg_ai_realtime.gd
vg_ai_repair.gd
vg_ai_run_session.gd
vg_ai_safe_write.gd
vg_ai_speech_filter.gd
vg_ai_test_spec.gd
vg_ai_tools.gd
vg_ai_voice.gd
vg_ai_wnodes_spec.gd
gdai.gd
gdai_example.gd
gdai_local_provider.gd
gdai_openai_provider.gd
gdai_provider.gd
gdai_test.gd
```

**Dashboard & Tray**
```
vg_dashboard_headless.gd
vg_dashboard_server.gd
vg_dashboard_tray.gd
vg_recent_projects.gd
recent_projects_menu.gd
vg_first_run_dialog.gd
```

**Asset Management**
```
vg_asset_bus.gd
vg_asset_watcher.gd
import_dock.gd
vg_package_browser.gd
vg_file_browser.gd
vg_embedded_code_editor.gd
```

**Themes & UI Customization**
```
vg_theme_manager.gd
vg_theme_picker.gd
vg_theme_utils.gd
vg_tweak_overlay.gd
```

**Code Navigation & Browsing**
```
code_navigator.gd
object_browser.gd
find_references_panel.gd
vg_ref_rewriter.gd
vg_snippet_browser.gd
vg_snippet_manager.gd
vg_command_palette.gd
```

**Utilities & Extras**
```
menu_bar_helper.gd
project_properties.gd
vg_external_change_prompt.gd
vg_live_preview_manager.gd
vg_mcp_server.gd
vg_node_inspector.gd
vg_websocket_controls.gd
visual_gasic_plugin.gd
```

### SHARED (2 files) — MODIFY FOR BOTH

```
plugin.cfg (create minimal core version)
plugin.gd (create minimal core version)
```

See `docs/development/VG_CORE_PLUGIN_MINIMAL.md` for drafted core versions.

### DELETE (4 files)

```
vg_settings.gd (if it's IDE-specific)
visual_gasic_plugin.gd (unless it's the main bootstrap)
(Audit remaining config files on day 1)
```

---

## Subdirectories

### `addons/visual_gasic/plugins/` — ALL IDE

- `agck/` — Action Game Kit plugin (IDE-specific for now, move to separate repo later)
- `form_designer/` — Form Designer (IDE-specific, move to separate repo)
- `working_nodes/` — Graph editor (IDE-specific, move to separate repo)
- `ai/` — AI plugins (IDE-specific)
- (other plugin folders)

**Action**: Do NOT copy to vg-core. Plugins stay in Visual Gasic Studio IDE. Minimal plugin system bootstrapped in vg-core stays minimal until M3.

### `addons/visual_gasic/asset_browser/` — IDE

**Delete for vg-core.**

### Other nested directories

Audit on day 1. Most are IDE-specific UI code.

---

## Day 1 Extraction Checklist

```
[ ] Step 1: Create vg-core repo locally and on GitHub (xgreenrx-star/vg-core)
[ ] Step 2: Copy 130 CORE C++ files from src/ → vg-core/src/
[ ] Step 3: Copy 28 CORE GDScript files → vg-core/addons/vg_core/
[ ] Step 4: Create register_types_core.cpp (minimal Godot registration)
[ ] Step 5: Create plugin.cfg (core minimal version)
[ ] Step 6: Create plugin.gd (core minimal bootstrap)
[ ] Step 7: Update SConstruct (add IDE exclusions, parameterize mirror path)
[ ] Step 8: Build with: scons platform=linux target=editor vg_core=1
[ ] Step 9: Enable .vg language in test Godot project
[ ] Step 10: Verify Hello World.vg loads and executes (Day-1 exit criteria)
```

---

## Notes

- **register_types**: Split is required. Core version excludes editor UI, node types, and IDE services.
- **plugin.cfg / plugin.gd**: Draft versions already exist in conversation memory (lines 462-470). New minimal versions needed.
- **SConstruct**: Edit SConstruct in place with conditional logic, don't create a new file.
- **Subdirectories** under addons/visual_gasic/: Do NOT copy. These are IDE plugin bundles, not core.
- **Binary output**: Core build goes to `addons/vg_core/bin/` (via mirror), IDE goes to `addons/visual_gasic/bin/`.

---

## File Count Verification

Count your work on day 1:

```bash
# Core C++
find vg-core/src -name "*.cpp" -o -name "*.h" | wc -l  # Should be ~260 (130 pairs)

# Core GDScript
find vg-core/addons/vg_core -name "*.gd" | wc -l  # Should be ~28

# Verify no IDE files were copied
grep -r "editor_plugin\|form_designer\|debugger\|toolbox\|ai_controller" vg-core/src 2>/dev/null | wc -l  # Should be 0
```

