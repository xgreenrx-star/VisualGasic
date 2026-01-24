# Phase 1 Implementation Plan: Core Editor Features

## Priority Order

### 1. Visual Form Designer ⭐ **MAJOR FEATURE**
**Goal:** VB6-style drag-and-drop form editing experience

**Components:**
- `form_designer.gd` - Main EditorPlugin for form editing
- `form_canvas.gd` - Visual editing surface with grid
- `control_handle.gd` - Selection/resize handles for controls
- `property_grid.gd` - VB6-style property inspector

**Features:**
- Drag controls from toolbox onto form
- Visual selection with resize handles
- Snap-to-grid and alignment guides
- Multi-select and bulk property editing
- Z-order management (bring to front/send to back)
- Copy/paste controls
- Undo/redo support
- Generate .bas code from visual layout

**Implementation Steps:**
1. Create form_designer plugin that hooks into Godot editor
2. Implement canvas with grid overlay
3. Add drag-drop from existing toolbox
4. Create selection handles with 8-point resize
5. Integrate with property inspector
6. Add keyboard shortcuts (Ctrl+C/V, Delete, Arrow keys)
7. Implement code generation to sync visual → .bas file

---

### 2. Project Wizards
**Goal:** Quick-start templates like VB6 wizards

**Components:**
- `wizard_dialog.gd` - Main wizard dialog system
- `templates/` - Project templates directory

**Wizard Types:**
1. **Standard EXE** - Single form application
2. **Database Application** - Form with database connection boilerplate
3. **Game Project** - Basic game loop with input handling
4. **ActiveX DLL** - For creating reusable components
5. **Custom Control** - For building custom UI controls

**Features:**
- Multi-step wizard UI
- Template variable substitution
- Auto-generate folder structure
- Create initial .bas files with boilerplate
- Add to recent projects

---

### 3. Menu Editor Fixes (Quick Win)
**File:** `demo/addons/visual_gasic/menu_editor.gd` lines 163-164

**Implementation:**
- Add up/down button functionality
- Implement menu item reordering
- Update tree display after move
- Preserve menu hierarchy during moves

---

## Success Criteria
- [ ] Can create new form visually by dragging controls
- [ ] Can resize/move controls with mouse
- [ ] Properties update in real-time
- [ ] Generated .bas file matches visual layout
- [ ] Wizards create runnable project templates
- [ ] Menu editor up/down buttons work

---

## Timeline Estimate
- Form Designer: 3-4 days (complex, many components)
- Project Wizards: 1-2 days (mostly UI and templates)
- Menu Editor Fix: 1-2 hours (simple logic)

**Total Phase 1: ~1 week**

---

## Technical Notes

### Form Designer Architecture
```
EditorPlugin (form_designer.gd)
├── FormCanvas (main editing surface)
│   ├── Grid overlay
│   ├── Selected control handles
│   └── Drop target detection
├── ControlHandle (resize/move)
│   ├── 8 resize points
│   └── Drag handling
└── PropertyGrid (VB6-style inspector)
    ├── Categorized properties
    └── Real-time updates
```

### Integration Points
- Hook into existing `VisualGasicToolbox` for control palette
- Use `VisualGasicScript` resource for code generation
- Extend `simple_inspector.gd` for VB6-style properties
- Integrate with `vb6_importer.gd` for reverse engineering

---

## Future Phases (Reference)

### Phase 2: Performance (1-2 weeks)
- Implement bytecode compiler using visual_gasic_bytecode.h
- Add bytecode caching (visual_gasic_bytecode_cache.h)
- Optimize variable lookups (Dictionary → HashMap)
- Split visual_gasic_instance.cpp into modules

### Phase 3: Debugging (2-3 weeks)
- Breakpoint support in editor
- Step-through debugging (F10/F11)
- Variable watch window
- Call stack viewer
- Immediate window for runtime evaluation

### Phase 4: Polish (1 week)
- Fix remaining HACKs
- Add more VB6 controls (MSFlexGrid, RichTextBox)
- CI/CD for multi-platform builds
- Documentation and examples
