#ifndef VISUAL_GASIC_BYTECODE_H
#define VISUAL_GASIC_BYTECODE_H

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <vector>
#include <deque>

using namespace godot;

namespace VisualGasic {
struct SubDefinition;
}

enum OpCode {
    OP_CONSTANT,      // [OP] [CONST_LO] [CONST_HI] - Load constant (16-bit LE index)
    OP_CONSTANT_LONG, // [OP] [CONST_LO] [CONST_HI] - Alias of OP_CONSTANT (kept for compat)
    OP_POP,      // [OP] - Pop stack
    
    // Variables
    OP_GET_GLOBAL, // [OP] [NAME_LO] [NAME_HI]
    OP_SET_GLOBAL, // [OP] [NAME_LO] [NAME_HI]
    OP_GET_LOCAL,  // [OP] [SLOT_IDX] (For future scoped locals)
    OP_SET_LOCAL,  // [OP] [SLOT_IDX]

    // Math / Logic
    OP_ADD, 
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_NEGATE,
    OP_CONCAT, // &
    OP_MOD,         // Mod operator
    OP_INT_DIVIDE,  // \ integer division
    OP_POWER,       // ^ or ** exponentiation
    OP_LIKE,        // Like pattern matching
    OP_SHL,         // << left bit-shift
    OP_SHR,         // >> right bit-shift

    // Extended numeric ops
    OP_ADD_I64,
    OP_ADD_I64_CONST,
    OP_SUB_I64,
    OP_SUB_I64_CONST,
    OP_MUL_I64,
    OP_MUL_I64_CONST,
    OP_ADD_F64,
    OP_SUB_F64,
    OP_MUL_F64,
    OP_DIV_F64,
    OP_ACCUM_I64_MULADD_CONST,
    OP_ADD_LOCAL_I64_STACK,
    OP_SUB_LOCAL_I64_STACK,
    OP_ADD_LOCAL_I64_CONST,
    OP_SUB_LOCAL_I64_CONST,
    OP_INC_LOCAL_I64,
    OP_ARITH_SUM,
    OP_BRANCH_SUM,
    OP_SUM_ARRAY_I64,
    OP_SUM_DICT_I64,
    OP_SUM_VGDICT_ALL_I64,       // [OP] [SLOT_IDX] - sum all int64 values in VGFastStringDict pool slot
    OP_ARRAY_FILL_I64_SEQ,
    OP_ALLOC_FILL_I64,
    OP_ALLOC_FILL_I64_OFFSET,
    OP_ALLOC_FILL_REPEAT_I64,
    OP_STRING_REPEAT,
    OP_STRING_REPEAT_OUTER,
    OP_ABS,
    OP_SGN,
    OP_SIN,        // [OP] - Pop double, push sin(v)
    OP_COS,        // [OP] - Pop double, push cos(v)
    OP_SQRT,       // [OP] - Pop double, push sqrt(v)
    OP_TAN,        // [OP] - Pop double, push tan(v)
    OP_ATAN2,      // [OP] - Pop y then x (x pushed first), push atan2(y,x)
    OP_FLOOR_F,    // [OP] - Pop double, push floor(v)
    OP_CEIL_F,     // [OP] - Pop double, push ceil(v)
    OP_EXP,        // [OP] - Pop double, push exp(v)
    OP_LOG,        // [OP] - Pop double, push log(v)

    // String/collection helpers
    OP_LEN,
    
    // Comparison
    OP_EQUAL,
    OP_NOT_EQUAL,
    OP_GREATER,
    OP_LESS,
    OP_GREATER_EQUAL,
    OP_LESS_EQUAL,
    OP_EQUAL_I64,
    OP_NOT_EQUAL_I64,
    OP_LESS_EQUAL_I64,
    
    // Logical
    OP_NOT,
    OP_AND,
    OP_OR,
    OP_XOR,

    // Flow Control
    OP_JUMP,           // [OP] [OFFSET_16]
    OP_JUMP_IF_FALSE,  // [OP] [OFFSET_16]
    OP_JUMP_IF_TRUE,   // [OP] [OFFSET_16]
    OP_LOOP,           // [OP] [OFFSET_16] (Jump back)
    
    // Functions
    OP_CALL,           // [OP] [METHOD_NAME_IDX] [ARG_COUNT]
    OP_CALL_BUILTIN,   // [OP] [FUNC_ID] [ARG_COUNT]
    OP_RETURN,         // [OP]
    OP_RETURN_VALUE,   // [OP]

    // Advanced
    OP_PRINT,          // [OP] - Print TOS
    OP_DEBUG_PRINT,    // [OP] - Debug.Print TOS → Immediate Window via debugger protocol
    OP_NEW_ARRAY,      // [OP] [SIZE]
    OP_NEW_ARRAY_I64,  // [OP] [SIZE]
    OP_NEW_DICT,       // [OP]
    OP_GET_ARRAY,      // [OP] [ARG_COUNT] (Base + Args on stack)
    OP_SET_ARRAY,      // [OP] [ARG_COUNT] (Value + Base + Args on stack)
    OP_GET_ARRAY_UNCHECKED,
    OP_SET_ARRAY_UNCHECKED,
    OP_GET_ARRAY_FAST,           // [OP] [ARG_COUNT] (Array-only fast path)
    OP_SET_ARRAY_FAST,
    OP_GET_ARRAY_FAST_UNCHECKED,
    OP_SET_ARRAY_FAST_UNCHECKED,
    OP_GET_DICT_FAST,            // [OP] [ARG_COUNT] (Dictionary fast path)
    OP_SET_DICT_FAST,
    OP_GET_DICT_TRUSTED,         // [OP] [ARG_COUNT] (Dictionary without runtime type checks)
    OP_SET_DICT_TRUSTED,
    OP_SET_DICT_LOCAL,           // [OP] [SLOT_IDX] [ARG_COUNT] - Modify dict local in-place (key+value on stack)
    OP_SET_DICT_GLOBAL,          // [OP] [NAME_IDX] [ARG_COUNT] - Modify dict global in-place
    OP_DICT_HAS_KEY,             // [OP] - Specialized has_key check (dict, key on stack)
    OP_DICT_SIZE,                // [OP] - Get dictionary size (dict on stack)
    OP_DICT_CLEAR_INPLACE,       // [OP] - Clear dictionary in place (dict on stack, pushes dict back)
    OP_DICT_KEYS,                // [OP] - Get dictionary keys array (dict on stack)
    OP_DICT_VALUES,              // [OP] - Get dictionary values array (dict on stack)
    OP_DICT_ERASE,               // [OP] - Erase key from dict (dict, key on stack, pushes dict back)
    OP_NEW_VGDICT,               // [OP] [SLOT_IDX] - Create a VGFastStringDict in local slot (sole-owner fast path)
    OP_GET_VGDICT_LOCAL,         // [OP] [SLOT_IDX] - Get from VGFastStringDict local (key on stack, pushes value)
    OP_SET_VGDICT_LOCAL,         // [OP] [SLOT_IDX] - Set in VGFastStringDict local (key+value on stack)
    OP_ARRAY_FILL_I64_OFFSET,
    OP_GET_MEMBER,     // [OP] [NAME_IDX]
    OP_SET_MEMBER,     // [OP] [NAME_IDX]
    OP_INTEROP_SET_NAME_LEN,

    // Whenever system
    OP_REGISTER_WHENEVER,   // [OP] [DATA_IDX] - Register a Whenever section (data is a Dictionary constant)
    OP_SUSPEND_WHENEVER,    // [OP] [NAME_IDX] - Suspend a Whenever section by name
    OP_RESUME_WHENEVER,     // [OP] [NAME_IDX] - Resume a Whenever section by name

    // Data/Restore system
    OP_RESTORE_DATA,        // [OP] - Reset DATA pointer (value on stack: -1 for start, or label name)
    OP_READ_DATA,           // [OP] - Read next value from DATA segments, push to stack
    OP_LOAD_DATA,           // [OP] - Load data from file (path on stack)
    OP_DATA_FROM_STRING,    // [OP] - Parse string on stack as comma-separated values, append to data tape
    OP_CLEAR_DATA,          // [OP] - Clear data tape, reset pointer, free runtime nodes
    OP_COERCE_TYPE,         // [OP] [TYPE_IDX] - Coerce top of stack to named type

    // Error Handling
    OP_ON_ERROR_RESUME_NEXT, // [OP] - Enable On Error Resume Next
    OP_ON_ERROR_GOTO,        // [OP] [LABEL_IDX] - Set On Error Goto label
    OP_ON_ERROR_GOTO_0,      // [OP] - Disable error handling (On Error Goto 0)

    // Literals
    OP_NIL,
    OP_TRUE,
    OP_FALSE,
    
    // Debug Support
    OP_DEBUG_LINE,     // [OP] [LINE_LO] [LINE_HI] - Track current source line for debugging
    OP_STOP,           // [OP] - VB6 Stop statement: trigger debugger break

    // Type-checking
    OP_IS_CLASS,       // [OP] - Pop class-name string + object, push bool (obj.is_class(name))

    // Object method calls
    OP_METHOD_CALL,    // [OP] [METHOD_NAME_IDX] [ARG_COUNT] - Pop base object + args, call method, push result

    // For Each iteration helpers
    OP_ITER_ARRAY,     // [OP] [SLOT_IDX] [IDX_SLOT] - Push arr[idx], used in For Each loop body
    OP_DICT_KEYS_CALL, // [OP] - Pop dict, push its keys() array

    // With...End With support
    OP_PUSH_WITH,      // [OP] - Pop TOS, push onto With context stack
    OP_POP_WITH,       // [OP] - Pop the With context stack
    OP_GET_WITH,       // [OP] - Push current With context onto value stack

    // Try/Catch/Finally exception handling
    OP_SETUP_TRY,      // [OP] [OFFSET_16] - Set up exception handler (offset to catch block)
    OP_POP_TRY,        // [OP] - Remove current exception handler
    OP_THROW,          // [OP] - Throw exception (error_code + message on stack)

    // Stack manipulation
    OP_DUP,            // [OP] - Duplicate top-of-stack

    // ReDim Preserve — resize array in-place
    OP_ARRAY_RESIZE,   // [OP] - Pop new_size, pop array, resize array, push result

    // New object instantiation
    OP_NEW_OBJECT,     // [OP] [CLASS_NAME_IDX] [ARG_COUNT] - Pop args, instantiate class, push result

    // File I/O (v2.10.0)
    OP_OPEN_FILE,      // [OP] [MODE] - Pop file_num, pop path → open file (mode: 0=Input,1=Output,2=Append,3=Binary,4=Random)
    OP_CLOSE_FILE,     // [OP] - Pop file_num → close file (0 = close all)
    OP_PRINT_FILE,     // [OP] [ARG_COUNT] - Pop args + file_num → Print #n, ...
    OP_WRITE_FILE,     // [OP] [ARG_COUNT] - Pop args + file_num → Write #n, ...
    OP_INPUT_FILE,     // [OP] [VAR_COUNT] - Pop var_names + file_num → Input #n, var1, var2
    OP_LINE_INPUT,     // [OP] - Pop var_name + file_num → Line Input #n, var

    // GoSub/Return (v2.10.0)
    OP_GOSUB,          // [OP] [OFFSET_16] - Push return address, jump to label
    OP_RETURN_GOSUB,   // [OP] - Pop return address from gosub stack, jump back

    // Threading (v2.11.0)
    OP_LOCK,           // [OP] - Acquire per-instance mutex
    OP_UNLOCK,         // [OP] - Release per-instance mutex
    OP_PARALLEL_FOR_BEGIN, // [OP] [VAR_SLOT] [BODY_LEN_HI] [BODY_LEN_LO] - Start parallel for (start/end/step on stack)
    OP_PARALLEL_FOR_END,   // [OP] - Marker: end of parallel for body (workers stop here)
    OP_TASK_RUN_BEGIN, // [OP] [NAME_CONST] [BG_FLAG] [BODY_LEN_HI] [BODY_LEN_LO] - Submit body to WorkerThreadPool
    OP_TASK_RUN_END,   // [OP] - Marker: end of task run body
    OP_TASK_WAIT,      // [OP] [WAIT_ALL_FLAG] - Wait for active tasks (1=all, 0=any)
    OP_AWAIT,          // [OP] - Pop expression result, push back (future: async dispatch)

    // Event system (v3.5.0)
    OP_RAISE_EVENT,    // [OP] [NAME_IDX] [ARG_COUNT] - emit_signal on owner

    // Callable creation (v5.0.1)
    OP_ADDRESS_OF,     // [OP] - Pop method name string, push Callable(owner, name)

    // MemoryBuffer (v5.0 — M5: Buffer Type)
    // Fast direct-access byte buffer stored in a local variable slot.
    // The buffer is a PackedByteArray held in the locals[] Variant slot.
    // These opcodes access the raw data without Variant refcount/overhead.
    OP_BUF_ALLOC,       // [OP] [SLOT_IDX]       — Allocate: pop size (int64), create PackedByteArray, store in locals[slot]
    OP_BUF_FREE,        // [OP] [SLOT_IDX]       — Free: set locals[slot] to Variant()
    OP_BUF_READ8,       // [OP] [SLOT_IDX]       — Read byte: pop offset (int64), push buf[offset] as int64
    OP_BUF_WRITE8,      // [OP] [SLOT_IDX]       — Write byte: pop value (int64), pop offset (int64), buf[offset] = (uint8_t)value
    OP_BUF_READ16,      // [OP] [SLOT_IDX]       — Read 16-bit LE word
    OP_BUF_WRITE16,     // [OP] [SLOT_IDX]       — Write 16-bit LE word
    OP_BUF_READ32,      // [OP] [SLOT_IDX]       — Read 32-bit LE dword
    OP_BUF_WRITE32,     // [OP] [SLOT_IDX]       — Write 32-bit LE dword
    OP_BUF_SIZE,        // [OP] [SLOT_IDX]       — Push buf.size()
    OP_BUF_RESIZE,      // [OP] [SLOT_IDX]       — Pop new_size, buf.resize(new_size)

    // Global VGMemoryBuffer fast path (v6.2 — emulator perf: fuse OP_GET_GLOBAL +
    // OP_GET_ARRAY / OP_SET_ARRAY into a single opcode for Public/global
    // "Dim x As New MemoryBuffer(...)" variables, which stay a real VGMemoryBuffer
    // Object (see OP_BUF_* above for the separate local-slot PackedByteArray path).
    // Saves one opcode dispatch + one Variant push/pop + the array-type cascade
    // per access, on the single hottest path in the C64/GBA emulators
    // (Mem_Read/Mem_Write called on every emulated CPU cycle).
    OP_GET_GLOBAL_BUF8, // [OP] [NAME_CONST_LO] [NAME_CONST_HI] — pop offset, push global-VGMemoryBuffer.PeekByte(offset)
    OP_SET_GLOBAL_BUF8, // [OP] [NAME_CONST_LO] [NAME_CONST_HI] — pop value, pop offset, global-VGMemoryBuffer.PokeByte(offset, value)

    // Optimization Hints (v6.0 — M6: Hint Attributes)
    // These are markers that the compiler uses internally; they do not
    // execute anything at runtime. They tell the optimizer to recognize
    // a loop pattern even if the structure doesn't match exactly.
    OP_HINT_ACCUMULATOR,  // [OP] [SLOT_IDX]     — Mark locals[slot] as a loop accumulator (int64 sum pattern)
    OP_HINT_LOOP_COUNTER,  // [OP] [SLOT_IDX]    — Mark locals[slot] as a loop counter (0→N-1 with Step 1)
    OP_HINT_PURE_CALL,    // [OP] [FUNC_IDX]     — Mark function call as pure (no side effects, foldable)

    // Select Case Jump Table (v6.2 - Emulator Performance Optimization)
    // Dense integer Select Case compiles to O(1) dispatch instead of O(n) if-else chain.
    // Format: [OP] [MIN_CONST_LO] [MIN_CONST_HI] [MAX_CONST_LO] [MAX_CONST_HI]
    //          [DEFAULT_OFFSET_LO] [DEFAULT_OFFSET_HI] [NUM_CASES_LO] [NUM_CASES_HI]
    //          followed by NUM_CASES x int16_t offsets (packed little-endian).
    // At runtime: val = pop_int(); if (val < min || val > max) ip += default_offset;
    //              else ip += offsets[val - min];
    OP_JUMP_TABLE,         // [OP] [MIN_C] [MAX_C] [DEF_OFF] [COUNT] [table...]

    // ByRef write-back (v6.2 — hot-path compiler support for ByRef params)
    // Pushes the post-call value of a ByRef parameter captured by the most
    // recent call_internal() (from _last_byref_captures) onto the stack, so the
    // compiler can store it back into the caller's variable via the normal
    // OP_SET_LOCAL / OP_SET_GLOBAL store opcodes. This lets Subs that make
    // statement- or expression-level ByRef calls compile to bytecode instead of
    // falling back to the (10-50x slower) AST tree-walk interpreter.
    // Format: [OP] [PARAM_NAME_CONST_LO] [PARAM_NAME_CONST_HI] [IS_GLOBAL] [DEST_LO] [DEST_HI]
    // DEST is the local slot index (IS_GLOBAL==0) or a constant-pool index for
    // the destination's global name (IS_GLOBAL==1) — the SAME destination the
    // compiler emits an OP_SET_LOCAL/OP_SET_GLOBAL for immediately after this.
    // If the param name IS found in _last_byref_captures, pushes the captured
    // value. If NOT found — e.g. the call the compiler resolved for write-back
    // purposes wasn't actually what ran at runtime, such as a builtin of the
    // same name winning over a coincidentally-matching user Sub/Function —
    // pushes the destination's CURRENT value instead, so the following store is
    // a true no-op rather than corrupting the variable with Nil.
    OP_BYREF_LOAD,

    // CanvasItem draw builtins — dedicated opcodes bypass OP_CALL dispatch (perf)
    OP_DRAW_RECT,      // [OP] [ARG_COUNT] - Pop args, draw_rect on owner CanvasItem
    OP_DRAW_LINE,      // [OP] [ARG_COUNT] - Pop args, draw_line on owner CanvasItem
    // Typed fast paths: stack = x,y (f64); operands = w f32 LE, h f32 LE, color const16, filled u8
    OP_DRAW_RECT_F64,  // DrawRect x, y, const_w, const_h, const_color, const_filled
    // Typed fast path: stack = x1,y1,x2,y2 (f64); operands = width f32 LE, color const16
    OP_DRAW_LINE_F64,  // DrawLine x1, y1, x2, y2, const_color, const_width
    // Grid-index fast paths: stack = i64 index; push x,y (f64) after draw for checksum locals
    OP_DRAW_RECT_GRID_IDX,         // cols i32, cell i32, w f32, h f32, color const16, filled u8
    OP_DRAW_LINE_GRID_IDX,         // cols i32, cell i32, x2_off f32, y2_off f32, width f32, color const16
    OP_DRAW_CIRCLE_GRID_IDX,       // cols i32, cell i32, ox f32, oy f32, radius f32, color const16
    OP_DRAW_TEXTURE_RECT_GRID_IDX, // tex global const16, cols i32, cell i32, w f32, h f32, tile u8
    // Typed fast paths: stack = x,y (f64); constant tail in operand stream
    OP_DRAW_CIRCLE_F64,            // radius f32, color const16
    OP_DRAW_TEXTURE_RECT_F64,      // tex global const16, w f32, h f32, tile u8
    // Whole-loop native paths: stack = iteration_count i64; updates cs local slot in-place
    OP_DRAW_RECT_GRID_LOOP,         // cs_slot u8, cols i32, cell i32, w f32, h f32, color const16, filled u8, cs_add i32
    OP_DRAW_LINE_GRID_LOOP,         // cs_slot u8, cols i32, cell i32, x2_off f32, y2_off f32, width f32, color const16, cs_add i32
    OP_DRAW_CIRCLE_GRID_LOOP,       // cs_slot u8, cols i32, cell i32, ox f32, oy f32, radius f32, color const16, cs_add i32
    OP_DRAW_TEXTURE_RECT_GRID_LOOP, // cs_slot u8, tex global const16, cols i32, cell i32, w f32, h f32, tile u8, cs_add i32
    OP_DRAW_POLYLINE_GRID_LOOP,     // cs_slot u8, cols i32, cell i32, width f32, color const16, cs_add i32
    OP_DRAW_RECT_OFFSET_LOOP,       // cs_slot u8, offset_arr const16, y_mul i32, y_mod i32, cell i32, w f32, h f32, color const16, filled u8, cs_add i32
    OP_VECTOR_UNIFORM_RECT_GRID_LOOP, // cs_slot u8, cols i32, cell i32, w f32, h f32, color const16, filled u8, cs_add i32

    // Block-scoped Let variables (v6.0)
    OP_PUSH_SCOPE,       // [OP] [COUNT u8] — allocate COUNT block-local slots (Variant nil)
    OP_POP_SCOPE,        // [OP] — release innermost block-local slots
    OP_GET_BLOCK_LOCAL,  // [OP] [FRAME u8] [OFFSET u8] — read block local (0 = innermost)
    OP_SET_BLOCK_LOCAL,  // [OP] [FRAME u8] [OFFSET u8] — write block local

    OP_COUNT_          // Sentinel — must be last (used by computed-goto table)
};

struct BytecodeChunk {
    Vector<uint8_t> code;
    Vector<Variant> constants;
    Vector<int> lines; // Line number per byte (RLE compressed ideally, but flat for now)
    Vector<String> local_names;
    Vector<uint8_t> local_types;
    int local_count = 0;

    // ── Fast-call convention (v6.0): when a Sub/Function has ONLY scalar-typed
    // ByVal parameters (no ByRef, no ParamArray, no dict/array/object params),
    // its parameters and return variable are given dedicated LOCAL SLOTS instead
    // of being stored in the string-keyed variables[] Dictionary. The compiler
    // assigns param slots 0..param_count-1 and (for Functions) the return value
    // slot return_slot, seeded directly from the call arguments — eliminating the
    // ~7 per-call Dictionary insert/lookup/erase operations that dominate call
    // overhead. Scalar-only keeps value semantics (no aliasing / sole-owner
    // escape-analysis interaction). fast_params=false => legacy globals path.
    bool fast_params = false;
    int  param_count = 0;   // number of leading local slots that are parameters
    int  return_slot = -1;  // local slot holding the Function return value (-1 = Sub / none)

    // ── Per-call perf (v6.0): precomputed scalar-coercion codes for the
    // fast-call binder.  call_internal previously ran param.type_hint.to_lower()
    // + string compares for EVERY parameter (and return_type.to_lower() once) on
    // EVERY call to coerce args to the declared type — the residual ~4% to_lower
    // after fast_params engaged.  The type hints are immutable, so the compiler
    // maps them to a small enum once, MIRRORING the binder's coercion EXACTLY:
    // 0=none, 1=int64, 2=double, 3=string, 4=bool.  Only populated when
    // fast_params is true; fast_return_coerce stays -1 for Subs / unpopulated.
    Vector<int8_t> fast_param_coerce;   // one entry per parameter slot
    int8_t fast_return_coerce = -1;     // Function return init (-1 = none/unset)

    // ── Per-call perf (v6.0): cached set of global names this chunk writes via
    // OP_SET_GLOBAL. The AST-fallback rollback in execute_bytecode() needs a
    // pre-call snapshot of exactly these globals, and the LIST is deterministic
    // per chunk — so compute it ONCE (full-chunk walk) instead of re-scanning
    // the entire bytecode on every single call. Populated lazily on the first
    // full-chunk (non-parallel, p_ip_end<=0) execution, which is main-thread
    // only in practice (parallel-for bodies run as p_ip_end>0 sub-ranges and
    // skip the scan entirely). See execute_bytecode().
    Vector<String> globals_written;
    bool globals_scan_done = false;

    void write(uint8_t byte, int line) {
        code.push_back(byte);
        lines.push_back(line); // Simplify mapping 1:1 for now
    }
    
    int add_constant(const Variant& value) {
        // Deduplicate: reuse existing constant if an identical value exists.
        // All constant pool indices are 16-bit (max 65 535 entries).
        for (int i = 0; i < (int)constants.size(); i++) {
            if (constants[i].get_type() == value.get_type() && constants[i] == value) {
                return i;
            }
        }
        constants.push_back(value);
        return constants.size() - 1;
    }
};

struct VMInlineCallFrame {
    BytecodeChunk *chunk = nullptr;
    VisualGasic::SubDefinition *func = nullptr;
    int return_ip = 0;
    int locals_frame = 0;
    bool fast_call = false;
    int fast_param_count = 0;
    int fast_return_slot = -1;
};

struct VMState {
    int ip; // Instruction Pointer
    std::vector<Variant> stack;

    // v6.0 (Part AB): per-thread pool of reusable local-variable frames.
    // execute_bytecode used to heap-allocate a fresh godot Vector<Variant> for
    // its `locals` on EVERY call (CowData<Variant> resize + Memory::alloc_static
    // + _unref/~CowData teardown — the last per-call heap alloc on the hot path).
    // Instead each nesting level reuses one Vector kept here: locals_depth marks
    // the current frame (bumped on entry, dropped on return via an RAII guard),
    // and locals_pool[depth] is resized/overwritten in place — after warmup no
    // allocation occurs.  A std::deque is used (not std::vector) because it gives
    // STABLE element addresses: growing it for a deeper nested frame never
    // invalidates references to shallower frames, so `debug_bc_locals = &locals`
    // stays valid across nested calls.  Living in VMState (already threaded via
    // Part X's p_vm) means the hot path pays no extra thread_local __tls_get_addr
    // to reach it, and each OS thread's tl_vm owns an isolated pool.
    std::deque<Vector<Variant>> locals_pool;
    int locals_depth = 0;

    // Block-scoped Let variables: stack of {base_slot, slot_count} into locals[].
    struct BlockScopeFrame {
        int base_slot = 0;
        int slot_count = 0;
    };
    std::vector<BlockScopeFrame> block_scope_frames;

    // In-VM fast calls: module-level fast_params Subs switch frames inside one
    // execute_bytecode() run instead of recursing through call_internal().
    std::vector<VMInlineCallFrame> inline_call_stack;

    // Call Frame info usually needed here for recursion
    // For now we can assume flat execution or use C++ recursion for calls
};

#endif
