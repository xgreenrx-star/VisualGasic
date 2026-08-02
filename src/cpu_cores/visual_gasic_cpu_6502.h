#ifndef VISUAL_GASIC_CPU_6502_H
#define VISUAL_GASIC_CPU_6502_H

// VGCpu6502 — native MOS 6502 / 6510 CPU core exposed as a VisualGasic engine
// primitive for building emulators (C64, NES-style machines, homebrew retro
// hardware, ...). Wraps the reentrant fake6502 core (src/cpu_cores/fake6502_ctx.h,
// derived from the public-domain MyLittle6502) behind a Godot RefCounted object
// so any VG project can instantiate one — or several — independent CPUs.
//
// This is a general-purpose ENGINE capability, deliberately separate from the
// "C64 emulator written in 100% VG" showcase: existing VG-authored cores keep
// their pure-VG bragging rights; this class is an opt-in native accelerator that
// projects reach for when they want real-hardware execution speed.
//
// Usage in VisualGasic:
//   Dim cpu As New VGCpu6502
//   cpu.LoadBytes 0, program_bytes          ' load code/data into RAM
//   cpu.SetResetVector &H0600               ' where execution begins
//   cpu.Reset
//   Dim ran As Integer
//   ran = cpu.RunCycles(20000)              ' execute ~20000 cycles
//   Print cpu.GetPC(), cpu.PeekRAM(&H20)
//
//   ' Memory-mapped I/O (VIC / SID / CIA style device registers). VG script has
//   ' no syntax to construct a raw Callable, so pass the target object plus the
//   ' method NAMES (same pattern as the VG builtin Connect(source, signal, method));
//   ' the engine builds the Callables internally:
//   cpu.SetIOHook &HD000, &HDFFF, Me, "io_read", "io_write"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/callable.hpp>

#include <cstdint>

using namespace godot;

// Full definition lives in fake6502_ctx.h, which is included only by the .cpp so
// the header-only core's static functions don't leak into other translation units.
struct Fake6502;

class VGCpu6502 : public RefCounted {
	GDCLASS(VGCpu6502, RefCounted);

	Fake6502 *_cpu = nullptr;
	uint8_t _ram[65536];

	// Optional memory-mapped I/O window. When active and an accessed address is
	// within [_io_lo, _io_hi], reads/writes are routed through the Callables
	// instead of flat RAM. This is how emulators wire device registers to VG
	// handler functions while normal RAM/ROM fetches stay native-fast.
	bool _io_hook_active = false;
	uint32_t _io_lo = 0x10000; // > 0xFFFF => disabled
	uint32_t _io_hi = 0;
	Callable _read_hook;
	Callable _write_hook;

	// The memory bus the core calls into. static so they match the plain C
	// function-pointer type in Fake6502; they recover `this` from ctx->userdata.
	static uint8_t _bus_read(Fake6502 *ctx, uint16_t addr);
	static void _bus_write(Fake6502 *ctx, uint16_t addr, uint8_t val);

protected:
	static void _bind_methods();

public:
	VGCpu6502();
	~VGCpu6502();

	// --- Execution control ---
	void reset();
	int step();                 // execute one instruction; returns cycles used
	int run_cycles(int cycles); // run up to N cycles; returns cycles executed
	// IRQ is level-gated by the interrupt-disable flag (matches real 6502/fake6502
	// semantics): returns 7 (cycles consumed) if the interrupt was serviced, or 0 if
	// it was masked (I flag set) and silently ignored -- callers that need an
	// edge/latch-until-serviced IRQ line (like a CIA timer) should keep re-calling
	// this once per Step() while the line is asserted and only clear their pending
	// flag when it returns non-zero. NMI always services immediately.
	int trigger_irq();
	int trigger_nmi();

	// --- Registers (debugger / Immediate window / Toolbox) ---
	int get_pc() const;      void set_pc(int v);
	int get_a() const;       void set_a(int v);
	int get_x() const;       void set_x(int v);
	int get_y() const;       void set_y(int v);
	int get_sp() const;      void set_sp(int v);
	int get_status() const;  void set_status(int v);
	int64_t get_instruction_count() const;
	int get_last_cycles() const;

	// --- Memory bus ---
	int read_byte(int addr) const;      // bus read  (honors the I/O hook)
	void write_byte(int addr, int val); // bus write (honors the I/O hook)
	int peek_ram(int addr) const;       // raw RAM read  (bypasses the I/O hook)
	void poke_ram(int addr, int val);   // raw RAM write (bypasses the I/O hook)
	void load_bytes(int offset, const PackedByteArray &bytes);
	PackedByteArray get_memory() const;
	PackedByteArray get_memory_range(int offset, int length) const;
	void clear_memory();
	void set_reset_vector(int addr);

	// --- Memory-mapped I/O hooks ---
	// VG-callable form: target object + method names (VG script cannot construct
	// a raw Callable itself). Builds Callable(target, method) internally.
	void set_io_hook_named(Object *target, const String &read_method, const String &write_method, int lo, int hi);
	void set_io_hook(int lo, int hi, const Callable &read_cb, const Callable &write_cb);
	void clear_io_hook();
};

#endif // VISUAL_GASIC_CPU_6502_H
