# Visual Gasic Debugging Implementation TODO

## Current Status

**Visual Gasic scripts (.vg) do NOT support traditional debugging like GDScript.**

| Feature | GDScript | Visual Gasic | Status |
|---------|----------|--------------|--------|
| Breakpoints pause execution | ✅ | ❌ | Not wired |
| Step Into | ✅ | ❌ | Not implemented |
| Step Over | ✅ | ❌ | Not implemented |
| Step Out | ✅ | ❌ | Not implemented |
| Call stack viewing | ✅ | ❌ | Returns empty |
| Variable inspection (paused) | ✅ | ❌ | No pause state |
| Variable inspection (runtime) | ✅ | ✅ | Immediate Window |
| Modify variables at runtime | ✅ | ✅ | Immediate Window |

---

## What Currently Works

### ✅ Immediate Window (Live Debugging)
- `:connect N` - Connect to running game instance
- `? variableName` - Inspect variable values
- `variableName = value` - Modify values at runtime
- `:watch expr` - Watch expressions
- `:vars` - List all variables

### ✅ C++ Infrastructure (Exists but not connected)
- `VisualGasicDebugger` class with breakpoint storage
- `set_breakpoint()`, `should_break_at()` methods
- Profiling framework
- Time-travel debugging history recording

---

## Implementation Roadmap

### Phase 1: Line Number Tracking in Bytecode

**Files to modify:**
- `src/visual_gasic_compiler.cpp`
- `src/visual_gasic_bytecode.h`

**Tasks:**
- [ ] Add `OP_DEBUG_LINE` opcode to bytecode instruction set
- [ ] Emit `OP_DEBUG_LINE <line_number>` at the start of each source line during compilation
- [ ] Store source file path in bytecode header for mapping
- [ ] Create line number → bytecode offset mapping table

```cpp
// Example opcode addition in visual_gasic_bytecode.h
enum Opcode {
    // ... existing opcodes ...
    OP_DEBUG_LINE,      // Marks source line number
    OP_DEBUG_COLUMN,    // Optional: column for precise positioning
};
```

---

### Phase 2: Breakpoint Checking in VM Loop

**Files to modify:**
- `src/visual_gasic_instance.cpp` (bytecode executor)
- `src/visual_gasic_debugger.cpp`

**Tasks:**
- [ ] Add `current_line` and `current_file` tracking to VM state
- [ ] Check `should_break_at()` when processing `OP_DEBUG_LINE`
- [ ] Implement VM pause/resume mechanism
- [ ] Add stepping mode flags (`step_into`, `step_over`, `step_out`)

```cpp
// In visual_gasic_instance.cpp execution loop
case OP_DEBUG_LINE: {
    current_line = read_int();
    if (debugger && debugger->should_break_at(current_file, current_line)) {
        debugger->pause_execution(this);
        return;  // Yield execution
    }
    if (debugger && debugger->is_stepping()) {
        debugger->handle_step(this, current_line);
    }
    break;
}
```

---

### Phase 3: Pause/Resume Mechanism

**Files to modify:**
- `src/visual_gasic_instance.cpp`
- `src/visual_gasic_debugger.cpp`

**Tasks:**
- [ ] Add `is_paused` flag to VisualGasicInstance
- [ ] Implement `pause_execution()` that saves VM state
- [ ] Implement `resume_execution()` that restores and continues
- [ ] Add `_process()` yield when paused (don't block engine)
- [ ] Send pause notification to editor via EngineDebugger

```cpp
void VisualGasicDebugger::pause_execution(VisualGasicInstance* instance) {
    paused_instance = instance;
    instance->is_paused = true;
    
    // Notify editor
    Array msg;
    msg.push_back(instance->get_script_path());
    msg.push_back(instance->current_line);
    EngineDebugger::get_singleton()->send_message("visualgasic:paused", msg);
}
```

---

### Phase 4: Implement ScriptLanguageExtension Debug Methods

**Files to modify:**
- `src/visual_gasic_language.cpp`

**Tasks:**
- [ ] Implement `_debug_get_stack_level_count()` - return actual call depth
- [ ] Implement `_debug_get_stack_level_line()` - return line at each level
- [ ] Implement `_debug_get_stack_level_function()` - return Sub/Function name
- [ ] Implement `_debug_get_stack_level_source()` - return .vg file path
- [ ] Implement `_debug_get_stack_level_locals()` - return local variables
- [ ] Implement `_debug_get_stack_level_members()` - return member variables
- [ ] Implement `_debug_get_stack_level_globals()` - return module-level vars

```cpp
// Current (broken):
int32_t VisualGasicLanguage::_debug_get_stack_level_count() const {
    return 0;  // Always returns 0!
}

// Fixed:
int32_t VisualGasicLanguage::_debug_get_stack_level_count() const {
    if (!paused_instance) return 0;
    return paused_instance->call_stack.size();
}
```

---

### Phase 5: Step Into / Step Over / Step Out

**Files to modify:**
- `src/visual_gasic_debugger.cpp`
- `src/visual_gasic_debugger.h`

**Tasks:**
- [ ] Implement `step_into()` - break on next line (any depth)
- [ ] Implement `step_over()` - break on next line (same or shallower depth)
- [ ] Implement `step_out()` - break when returning to caller
- [ ] Track call depth for step over/out logic
- [ ] Bind methods in `_bind_methods()`

```cpp
void VisualGasicDebugger::step_into() {
    stepping_mode = STEP_INTO;
    break_on_next_line = true;
    resume_execution();
}

void VisualGasicDebugger::step_over() {
    stepping_mode = STEP_OVER;
    step_depth = current_call_depth;
    break_on_next_line = true;
    resume_execution();
}

void VisualGasicDebugger::step_out() {
    stepping_mode = STEP_OUT;
    step_depth = current_call_depth - 1;
    resume_execution();
}
```

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
