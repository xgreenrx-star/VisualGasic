# Visual Gasic v2.6.0 Release Notes

**Release Date**: February 2026  
**Codename**: Developer Experience Update

---

## 🎨 Custom .vg File Icons

Your `.vg` files now have their own icon in the Godot FileSystem dock!

- **Blue file icon** with "VG" text — instantly distinguishes Visual Gasic scripts from other files
- **Purple plugin variant** for the VisualGasic addon itself
- SVG-based — crisp and scalable at any editor zoom level
- Auto-registered when the plugin loads (no configuration needed)

---

## 🧠 IntelliSense for New Builtins

All 11 built-in functions added in v2.5.0 now appear in autocomplete with full signatures and descriptions:

| Function | Category | Signature |
|----------|----------|-----------|
| `Weekday` | Date/Time | `Weekday(date) As Integer` |
| `WeekdayName` | Date/Time | `WeekdayName(day, [abbreviate]) As String` |
| `MonthName` | Date/Time | `MonthName(month, [abbreviate]) As String` |
| `QBColor` | Color | `QBColor(colorIndex) As Color` |
| `Environ` | System | `Environ(varName) As String` |
| `Beep` | System | `Beep` |

Plus the `Stop` keyword now gets proper syntax highlighting.

> **Note**: `FileCopy`, `MkDir`, `RmDir`, `ChDir`, and `CurDir` were already in the IntelliSense database.

---

## 📊 Integrated Profiler UI

A brand-new **VG Profiler** bottom panel provides bytecode-level performance analysis directly in the Godot editor.

### Functions Tab
- 7-column sortable tree: **Function**, **Category**, **Calls**, **Total ms**, **Avg ms**, **Min ms**, **Max ms**
- Sorted by total time (descending) to surface hot paths first
- **Hot-path coloring**:
  - 🔴 Red: ≥ 50ms (critical)
  - 🟠 Orange: ≥ 10ms (slow)
  - 🟡 Yellow: ≥ 1ms (moderate)
  - 🟢 Green: < 1ms (fast)

### Counters Tab
- 4-column display: **Counter**, **Value**, **Updates**, **Unit**
- Tracks performance counters like opcode counts, memory allocations, etc.

### Toolbar Controls
- **▶ Start / ⏹ Stop** — Toggle profiling on/off
- **↻ Refresh** — Manual data fetch
- **🗑 Clear** — Reset all profiling data
- **💾 Export** — Save profile to `user://vg_profile_export.json`

### Architecture
- Auto-refresh every 2 seconds while profiling is active
- Communication via `visualgasic:profiler_*` debug protocol messages
- C++ `VisualGasicProfiler` singleton provides high-precision timing data
- Exposed via `_vg_profiler_enable`, `_vg_profiler_get_report`, `_vg_profiler_clear` instance methods

---

## 🔧 Bug Fixes

- Added missing `VisualGasicProfiler::reset_memory_pool()` implementation in C++ (was declared in header but not defined)

---

## 📦 Binaries

All 6 pre-compiled binaries included:

| Target | Platform | File |
|--------|----------|------|
| Editor | Linux x86_64 | `libvisualgasic.linux.editor.x86_64.so` |
| Debug | Linux x86_64 | `libvisualgasic.linux.template_debug.x86_64.so` |
| Release | Linux x86_64 | `libvisualgasic.linux.template_release.x86_64.so` |
| Editor | Windows x86_64 | `libvisualgasic.windows.editor.x86_64.dll` |
| Debug | Windows x86_64 | `libvisualgasic.windows.template_debug.x86_64.dll` |
| Release | Windows x86_64 | `libvisualgasic.windows.template_release.x86_64.dll` |

---

## ⬆️ Upgrade Notes

Drop-in replacement for v2.5.0. No breaking changes. New features activate automatically when the plugin is enabled.

---

## 🗺️ What's Next (v2.7.0)

Potential candidates from the roadmap:
- Godot Asset Library submission
- Additional demo projects
- Performance optimization passes
- Community-requested features

See [ROADMAP.md](ROADMAP.md) for the full plan.
