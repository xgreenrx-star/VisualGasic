#include "visual_gasic_cpu_6502.h"

#include <godot_cpp/core/memory.hpp>

#include <cstring>

// The reentrant core is a header-only C implementation with internal linkage;
// including it here confines its static functions to this single translation unit.
#include "fake6502_ctx.h"

using namespace godot;

uint8_t VGCpu6502::_bus_read(Fake6502 *ctx, uint16_t addr) {
	VGCpu6502 *self = static_cast<VGCpu6502 *>(ctx->userdata);
	if (self->_io_hook_active && addr >= self->_io_lo && addr <= self->_io_hi && self->_read_hook.is_valid()) {
		Variant r = self->_read_hook.call((int)addr);
		return (uint8_t)((int)r & 0xFF);
	}
	return self->_ram[addr];
}

void VGCpu6502::_bus_write(Fake6502 *ctx, uint16_t addr, uint8_t val) {
	VGCpu6502 *self = static_cast<VGCpu6502 *>(ctx->userdata);
	if (self->_io_hook_active && addr >= self->_io_lo && addr <= self->_io_hi && self->_write_hook.is_valid()) {
		self->_write_hook.call((int)addr, (int)val);
		return;
	}
	self->_ram[addr] = val;
}

VGCpu6502::VGCpu6502() {
	_cpu = memnew(Fake6502);
	memset(_cpu, 0, sizeof(Fake6502));
	memset(_ram, 0, sizeof(_ram));
	_cpu->read_cb = &VGCpu6502::_bus_read;
	_cpu->write_cb = &VGCpu6502::_bus_write;
	_cpu->userdata = this;
}

VGCpu6502::~VGCpu6502() {
	if (_cpu) {
		memdelete(_cpu);
		_cpu = nullptr;
	}
}

// --- Execution control ---
void VGCpu6502::reset() {
	fake6502_reset(_cpu);
}

int VGCpu6502::step() {
	return (int)fake6502_step(_cpu);
}

int VGCpu6502::run_cycles(int cycles) {
	if (cycles < 0) cycles = 0;
	return (int)fake6502_exec(_cpu, (uint32_t)cycles);
}

int VGCpu6502::trigger_irq() {
	bool masked = (_cpu->status & FK_FLAG_INTERRUPT) != 0;
	fake6502_irq(_cpu);
	return masked ? 0 : 7;
}

int VGCpu6502::trigger_nmi() {
	fake6502_nmi(_cpu);
	return 7;
}

// --- Registers ---
int VGCpu6502::get_pc() const { return (int)_cpu->pc; }
void VGCpu6502::set_pc(int v) { _cpu->pc = (uint16_t)(v & 0xFFFF); }
int VGCpu6502::get_a() const { return (int)_cpu->a; }
void VGCpu6502::set_a(int v) { _cpu->a = (uint8_t)(v & 0xFF); }
int VGCpu6502::get_x() const { return (int)_cpu->x; }
void VGCpu6502::set_x(int v) { _cpu->x = (uint8_t)(v & 0xFF); }
int VGCpu6502::get_y() const { return (int)_cpu->y; }
void VGCpu6502::set_y(int v) { _cpu->y = (uint8_t)(v & 0xFF); }
int VGCpu6502::get_sp() const { return (int)_cpu->sp; }
void VGCpu6502::set_sp(int v) { _cpu->sp = (uint8_t)(v & 0xFF); }
int VGCpu6502::get_status() const { return (int)_cpu->status; }
void VGCpu6502::set_status(int v) { _cpu->status = (uint8_t)(v & 0xFF); }
int64_t VGCpu6502::get_instruction_count() const { return (int64_t)_cpu->instructions; }
int VGCpu6502::get_last_cycles() const { return (int)_cpu->clockticks6502; }

// --- Memory bus ---
int VGCpu6502::read_byte(int addr) const {
	return (int)_bus_read(_cpu, (uint16_t)(addr & 0xFFFF));
}

void VGCpu6502::write_byte(int addr, int val) {
	_bus_write(_cpu, (uint16_t)(addr & 0xFFFF), (uint8_t)(val & 0xFF));
}

int VGCpu6502::peek_ram(int addr) const {
	return (int)_ram[addr & 0xFFFF];
}

void VGCpu6502::poke_ram(int addr, int val) {
	_ram[addr & 0xFFFF] = (uint8_t)(val & 0xFF);
}

void VGCpu6502::load_bytes(int offset, const PackedByteArray &bytes) {
	int n = bytes.size();
	for (int i = 0; i < n; i++) {
		int a = offset + i;
		if (a < 0 || a > 0xFFFF) continue;
		_ram[a] = bytes[i];
	}
}

PackedByteArray VGCpu6502::get_memory() const {
	PackedByteArray out;
	out.resize(65536);
	memcpy(out.ptrw(), _ram, 65536);
	return out;
}

PackedByteArray VGCpu6502::get_memory_range(int offset, int length) const {
	PackedByteArray out;
	if (length <= 0 || offset < 0 || offset > 0xFFFF) return out;
	if (offset + length > 65536) length = 65536 - offset;
	out.resize(length);
	memcpy(out.ptrw(), _ram + offset, length);
	return out;
}

void VGCpu6502::clear_memory() {
	memset(_ram, 0, sizeof(_ram));
}

void VGCpu6502::set_reset_vector(int addr) {
	_ram[0xFFFC] = (uint8_t)(addr & 0xFF);
	_ram[0xFFFD] = (uint8_t)((addr >> 8) & 0xFF);
}

// --- Memory-mapped I/O hooks ---
void VGCpu6502::set_io_hook(int lo, int hi, const Callable &read_cb, const Callable &write_cb) {
	_io_lo = (uint32_t)(lo & 0xFFFF);
	_io_hi = (uint32_t)(hi & 0xFFFF);
	_read_hook = read_cb;
	_write_hook = write_cb;
	_io_hook_active = true;
}

// VG script cannot construct a raw Callable, so this is the entry point actually
// exposed to VG (bound as "SetIOHook"): pass the target object + method name
// strings, exactly like the VG builtin Connect(source, signal, method) does.
void VGCpu6502::set_io_hook_named(Object *target, const String &read_method, const String &write_method, int lo, int hi) {
	set_io_hook(lo, hi, Callable(target, read_method), Callable(target, write_method));
}

void VGCpu6502::clear_io_hook() {
	_io_hook_active = false;
	_io_lo = 0x10000;
	_io_hi = 0;
	_read_hook = Callable();
	_write_hook = Callable();
}

void VGCpu6502::_bind_methods() {
	// Execution control
	ClassDB::bind_method(D_METHOD("Reset"), &VGCpu6502::reset);
	ClassDB::bind_method(D_METHOD("Step"), &VGCpu6502::step);
	ClassDB::bind_method(D_METHOD("RunCycles", "cycles"), &VGCpu6502::run_cycles);
	ClassDB::bind_method(D_METHOD("TriggerIRQ"), &VGCpu6502::trigger_irq);
	ClassDB::bind_method(D_METHOD("TriggerNMI"), &VGCpu6502::trigger_nmi);

	// Registers
	ClassDB::bind_method(D_METHOD("GetPC"), &VGCpu6502::get_pc);
	ClassDB::bind_method(D_METHOD("SetPC", "value"), &VGCpu6502::set_pc);
	ClassDB::bind_method(D_METHOD("GetA"), &VGCpu6502::get_a);
	ClassDB::bind_method(D_METHOD("SetA", "value"), &VGCpu6502::set_a);
	ClassDB::bind_method(D_METHOD("GetX"), &VGCpu6502::get_x);
	ClassDB::bind_method(D_METHOD("SetX", "value"), &VGCpu6502::set_x);
	ClassDB::bind_method(D_METHOD("GetY"), &VGCpu6502::get_y);
	ClassDB::bind_method(D_METHOD("SetY", "value"), &VGCpu6502::set_y);
	ClassDB::bind_method(D_METHOD("GetSP"), &VGCpu6502::get_sp);
	ClassDB::bind_method(D_METHOD("SetSP", "value"), &VGCpu6502::set_sp);
	ClassDB::bind_method(D_METHOD("GetStatus"), &VGCpu6502::get_status);
	ClassDB::bind_method(D_METHOD("SetStatus", "value"), &VGCpu6502::set_status);
	ClassDB::bind_method(D_METHOD("GetInstructionCount"), &VGCpu6502::get_instruction_count);
	ClassDB::bind_method(D_METHOD("GetLastCycles"), &VGCpu6502::get_last_cycles);

	// Memory bus
	ClassDB::bind_method(D_METHOD("ReadByte", "addr"), &VGCpu6502::read_byte);
	ClassDB::bind_method(D_METHOD("WriteByte", "addr", "value"), &VGCpu6502::write_byte);
	ClassDB::bind_method(D_METHOD("PeekRAM", "addr"), &VGCpu6502::peek_ram);
	ClassDB::bind_method(D_METHOD("PokeRAM", "addr", "value"), &VGCpu6502::poke_ram);
	ClassDB::bind_method(D_METHOD("LoadBytes", "offset", "bytes"), &VGCpu6502::load_bytes);
	ClassDB::bind_method(D_METHOD("GetMemory"), &VGCpu6502::get_memory);
	ClassDB::bind_method(D_METHOD("GetMemoryRange", "offset", "length"), &VGCpu6502::get_memory_range);
	ClassDB::bind_method(D_METHOD("ClearMemory"), &VGCpu6502::clear_memory);
	ClassDB::bind_method(D_METHOD("SetResetVector", "addr"), &VGCpu6502::set_reset_vector);

	// Memory-mapped I/O hooks
	ClassDB::bind_method(D_METHOD("SetIOHook", "target", "read_method", "write_method", "lo", "hi"), &VGCpu6502::set_io_hook_named);
	ClassDB::bind_method(D_METHOD("ClearIOHook"), &VGCpu6502::clear_io_hook);

	// Inspector/debugger-visible register properties.
	ADD_PROPERTY(PropertyInfo(Variant::INT, "pc"), "SetPC", "GetPC");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "a"), "SetA", "GetA");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "x"), "SetX", "GetX");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "y"), "SetY", "GetY");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "sp"), "SetSP", "GetSP");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "status"), "SetStatus", "GetStatus");
}
