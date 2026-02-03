# Visual Gasic Debugging Implementation TODO

## Current Status

**Visual Gasic scripts (.vg) now have PARTIAL debugging support!**

| Feature | GDScript | Visual Gasic | Status |
|---------|----------|--------------|--------|
| Breakpoints pause execution | ✅ | ⚠️ | Infrastructure ready, pause loop pending |
| Step Into | ✅ | ⚠️ | Flag implemented, pause loop pending |
| Step Over | ✅ | ❌ | Not implemented |
| Step Out | ✅ | ❌ | Not implemented |
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

### Phase 3: Pause/Resume Mechanism 🔄 NEXT

**Files to modify:**
- `src/visual_gasic_instance.cpp`
- `src/visual_gasic_debugger.cpp`

**Tasks:**
- [ ] Add pause loop that waits for debugger commands
- [ ] Implement `resume_execution()` 
- [ ] Handle Godot editor Continue/Step buttons
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
