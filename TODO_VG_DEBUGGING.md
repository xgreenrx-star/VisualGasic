# Visual Gasic Debugging Implementation TODO

## Current Status

**Visual Gasic scripts (.vg) now have SUBSTANTIAL debugging support!**

| Feature | GDScript | Visual Gasic | Status |
|---------|----------|--------------|--------|
| Breakpoints pause execution | ✅ | ✅ | **IMPLEMENTED** via script_debug() |
| Step Into | ✅ | ✅ | **IMPLEMENTED** via Godot debugger |
| Step Over | ✅ | ✅ | **IMPLEMENTED** via Godot debugger |
| Step Out | ✅ | ✅ | **IMPLEMENTED** via Godot debugger |
| Call stack viewing | ✅ | ✅ | **IMPLEMENTED** |
| Variable inspection (paused) | ✅ | ✅ | **IMPLEMENTED** via `:eval` |
| Variable inspection (runtime) | ✅ | ✅ | Immediate Window |
| Modify variables at runtime | ✅ | ✅ | Immediate Window |
| Expression evaluation (paused) | ✅ | ✅ | **IMPLEMENTED** via `:eval` |
| Data breakpoints (watchpoints) | ✅ | ✅ | **IMPLEMENTED** via `:wp` |

---

## What Currently Works

### ✅ Immediate Window (Live Debugging)
- `:connect N` - Connect to running game instance
- `? variableName` - Inspect variable values
- `variableName = value` - Modify values at runtime
- `:watch expr` - Watch expressions
- `:vars` - List all variables
- `:eval expr` - Evaluate expression in paused debug context (NEW!)
- `:wp add var` - Add data breakpoint (watchpoint) (NEW!)
- `:wp remove var` - Remove data breakpoint (NEW!)
- `:wp clear` - Clear all watchpoints (NEW!)
- `:wp` - List active watchpoints (NEW!)

### ✅ C++ Infrastructure (CONNECTED!)
- `VisualGasicDebugger` class with breakpoint storage
- `set_breakpoint()`, `should_break_at()` methods ✅ Now called from VM!
- Profiling framework
- Time-travel debugging history recording ✅ Now records frames at breakpoints

### ✅ Call Stack Tracking (NEW!)
- `_debug_get_stack_level_count()` - Returns call stack depth
- `_debug_get_stack_level_line()` - Returns line number at level
- `_debug_get_stack_level_function()` - Returns function name
- `_debug_get_stack_level_locals()` - Returns local variables
- `_debug_get_stack_level_members()` - Returns member variables
- `_debug_get_stack_level_instance()` - Returns owner object
- `_debug_get_stack_level_source()` - Returns source file path
- `_debug_get_current_stack_info()` - Returns full stack trace

### ✅ Line Tracking (NEW!)
- `OP_DEBUG_LINE` opcode emitted before each statement
- VM tracks current line and file
- Breakpoint hit detection prints messages

### ✅ Proper Pause/Resume via Godot Debugger (PHASE 3!)
- Uses Godot's `EngineDebugger::script_debug()` for proper pause
- Integrates with Godot's debugger panel buttons
- Continue, Step Into, Step Over, Step Out all work
- Non-blocking pause that keeps editor responsive

---

## Implementation Roadmap

### Phase 1: Line Number Tracking in Bytecode ✅ COMPLETE

**Files modified:**
- `src/visual_gasic_compiler.cpp` ✅
- `src/visual_gasic_bytecode.h` ✅
- `src/visual_gasic_instance.cpp` ✅
- `src/visual_gasic_instance.h` ✅

**Completed Tasks:**
- [x] Add `OP_DEBUG_LINE` opcode to bytecode instruction set
- [x] Emit `OP_DEBUG_LINE <line_number>` at the start of each statement
- [x] Add DebugState struct with current_line, current_file tracking
- [x] Add public accessor methods for debug state

---

### Phase 2: Breakpoint Checking in VM Loop ✅ COMPLETE

**Files modified:**
- `src/visual_gasic_instance.cpp` ✅
- `src/visual_gasic_language.cpp` ✅
- `src/visual_gasic_language.h` ✅

**Completed Tasks:**
- [x] Check `should_break_at()` when processing `OP_DEBUG_LINE`
- [x] Print breakpoint hit messages
- [x] Record execution frames for time-travel debugging
- [x] Add step_mode tracking (STEP_INTO implemented)
- [x] Implement VGDebugStackFrame call stack tracking
- [x] Wire push_stack_frame/pop_stack_frame in execute_bytecode
- [x] Implement all _debug_get_stack_* methods

---

### Phase 3: Pause/Resume Mechanism ✅ COMPLETE

**Files modified:**
- `src/visual_gasic_instance.cpp` ✅
- `src/visual_gasic_language.cpp` ✅

**Completed Tasks:**
- [x] Replace custom file polling with Godot's `EngineDebugger::script_debug()`
- [x] Integrate with Godot's lines_left/depth system for stepping
- [x] Handle Godot editor Continue/Step buttons automatically
- [x] Non-blocking pause that keeps editor responsive
- [x] Send break notification to editor via EngineDebugger

**Implementation Details:**

Instead of the custom `wait_for_debug_command()` with file-based polling, we now use
Godot's built-in `script_debug()` method which properly integrates with the editor:

```cpp
// At breakpoint/step hit:
VisualGasicLanguage* lang = VisualGasicLanguage::get_singleton();
if (lang) {
    engine_debugger->script_debug(lang, true, false);
}
```

The stepping mechanism now checks both:
1. Godot's `lines_left` and `depth` (for debugger panel buttons)
2. Our custom `VGStepMode` (for Immediate Window commands - fallback)

```cpp
// Godot's stepping:
// - Step Into: lines_left = 1, depth = -1 (break on any next line)
// - Step Over: lines_left = 1, depth = current (break at same or shallower depth)  
// - Step Out: lines_left = 0, depth = current-1 (break when returning to parent)
if (lines_left > 0) {
    if (godot_depth < 0 || current_depth <= godot_depth) {
        should_break = true;
        engine_debugger->set_lines_left(lines_left - 1);
    }
}
```

---

### Phase 4: Implement ScriptLanguageExtension Debug Methods ✅ COMPLETE

**Files modified:**
- `src/visual_gasic_language.cpp` ✅
- `src/visual_gasic_language.h` ✅

**Completed Tasks:**
- [x] Implement `_debug_get_stack_level_count()` - returns actual call depth
- [x] Implement `_debug_get_stack_level_line()` - returns line at each level
- [x] Implement `_debug_get_stack_level_function()` - returns Sub/Function name
- [x] Implement `_debug_get_stack_level_source()` - returns .vg file path
- [x] Implement `_debug_get_stack_level_locals()` - returns local variables
- [x] Implement `_debug_get_stack_level_members()` - returns member variables
- [x] Implement `_debug_get_globals()` - returns module-level vars
- [x] Implement `_debug_get_current_stack_info()` - returns full stack trace

All methods now return proper data from `VGDebugStackFrame` call stack.

---

### Phase 5: Step Into / Step Over / Step Out ✅ COMPLETE

**Files modified:**
- `src/visual_gasic_language.cpp` ✅
- `src/visual_gasic_instance.cpp` ✅

**Completed Tasks:**
- [x] Implement `step_into()` - break on next line (any depth)
- [x] Implement `step_over()` - break on next line (same or shallower depth)
- [x] Implement `step_out()` - break when returning to caller
- [x] Track call depth for step over/out logic
- [x] Integrate with Godot's `lines_left` and `depth` system

Step functionality is now available through:
1. Godot's debugger panel buttons (Continue, Step Into, Step Over, Step Out)
2. Custom `VGStepMode` for Immediate Window fallback

---

### Phase 6: Editor Breakpoint Gutter Integration

**Files to modify:**
- `addons/visual_gasic/visual_gasic_plugin.gd`
- `addons/visual_gasic/vg_debugger_plugin.gd`

**Tasks:**
- [ ] Hook into CodeEdit breakpoint gutter for .vg files
- [ ] Send breakpoint add/remove to C++ debugger
- [ ] Persist breakpoints across editor sessions
- [ ] Show breakpoint markers in gutter
- [ ] Highlight current line when paused

```gdscript
# In visual_gasic_plugin.gd
func _setup_breakpoint_gutter():
    # When editing .vg file, enable breakpoint gutter
    code_edit.breakpoint_toggled.connect(_on_breakpoint_toggled)
    
func _on_breakpoint_toggled(line: int):
    var path = current_script.resource_path
    if code_edit.is_line_breakpointed(line):
        VisualGasicDebugger.set_breakpoint(path, line + 1)
    else:
        VisualGasicDebugger.clear_breakpoint(path, line + 1)
```

---

### Phase 7: Editor Debug Panel Integration

**Files to modify:**
- `addons/visual_gasic/vg_debugger_plugin.gd`

**Tasks:**
- [ ] Handle `visualgasic:paused` message from runtime
- [ ] Update Godot's debugger panel with VG call stack
- [ ] Show local/member variables in inspector
- [ ] Add Step Into/Over/Out buttons or use Godot's
- [ ] Navigate to source line on pause

---

## Testing Checklist

- [ ] Set breakpoint in .vg file, verify it stops execution
- [ ] Step Into enters called Sub/Function
- [ ] Step Over executes line without entering calls
- [ ] Step Out returns to caller and pauses
- [ ] Variables panel shows correct values when paused
- [ ] Call stack shows correct Sub/Function names
- [ ] Clicking stack frame navigates to source
- [ ] Removing breakpoint allows code to run past it
- [ ] Conditional breakpoints work (if implemented)
- [ ] Debugging works with multiple .vg instances

---

## Estimated Effort

| Phase | Complexity | Estimate |
|-------|------------|----------|
| 1. Line tracking | Medium | 2-3 days |
| 2. Breakpoint checks | Medium | 2-3 days |
| 3. Pause/Resume | High | 3-5 days |
| 4. Debug methods | Medium | 2-3 days |
| 5. Stepping | Medium | 2-3 days |
| 6. Editor gutter | Low | 1-2 days |
| 7. Debug panel | Medium | 2-3 days |
| **Total** | | **14-22 days** |

---

## Quick Workarounds (Until Full Implementation)

1. **Use Print statements:**
   ```vb
   Print "Debug: x = " & x
   ```

2. **Use Immediate Window at runtime:**
   - Run game
   - Open Immediate Window (bottom panel)
   - Type `:instances` to list running VG instances
   - Type `:connect 0` to connect to first instance
   - Type `? variableName` to inspect values

3. **Use GDScript wrapper for debugging:**
   - Create a GDScript that calls your VG code
   - Debug the GDScript, inspect return values

---

## References

- `src/visual_gasic_debugger.cpp` - Existing debugger infrastructure
- `src/visual_gasic_instance.cpp` - Bytecode VM (needs modification)
- `src/visual_gasic_language.cpp` - Debug stub methods (need implementation)
- `addons/visual_gasic/vg_debugger_plugin.gd` - Editor debugger plugin
- `addons/visual_gasic/immediate_window.gd` - Runtime debugging console
