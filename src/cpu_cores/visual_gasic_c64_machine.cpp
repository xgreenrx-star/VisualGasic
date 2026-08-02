#include "visual_gasic_c64_machine.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>

// The reentrant 6510 core (header-only, internal linkage — confined to this TU).
#include "fake6502_ctx.h"

using namespace godot;

// Standard C64 palette (Pepto/Colodore-style), matching c64_constants.vg's
// GetC64Color() so native output is pixel-identical to the pure-VG renderer.
static const uint8_t C64_PALETTE[16][3] = {
	{ 0, 0, 0 }, { 255, 255, 255 }, { 136, 0, 0 }, { 170, 255, 238 },
	{ 204, 68, 204 }, { 0, 204, 85 }, { 0, 0, 170 }, { 238, 238, 119 },
	{ 221, 136, 85 }, { 102, 68, 0 }, { 255, 119, 119 }, { 51, 51, 51 },
	{ 119, 119, 119 }, { 170, 255, 102 }, { 0, 136, 255 }, { 187, 187, 187 }
};

// ---------------------------------------------------------------------------
// Static bus trampolines — recover `this` from ctx->userdata.
// ---------------------------------------------------------------------------
uint8_t VGC64Machine::_bus_read(Fake6502 *ctx, uint16_t addr) {
	return static_cast<VGC64Machine *>(ctx->userdata)->bus_read(addr);
}

void VGC64Machine::_bus_write(Fake6502 *ctx, uint16_t addr, uint8_t val) {
	static_cast<VGC64Machine *>(ctx->userdata)->bus_write(addr, val);
}

// ---------------------------------------------------------------------------
// Construction / destruction
// ---------------------------------------------------------------------------
VGC64Machine::VGC64Machine() {
	_cpu = memnew(Fake6502);
	memset(_cpu, 0, sizeof(Fake6502));
	memset(_ram, 0, sizeof(_ram));
	memset(_color_ram, 0, sizeof(_color_ram));
	memset(_basic_rom, 0, sizeof(_basic_rom));
	memset(_kernal_rom, 0, sizeof(_kernal_rom));
	memset(_char_rom, 0, sizeof(_char_rom));
	for (int i = 0; i < 8; i++) _key_col[i] = 0xFF;

	_cpu->read_cb = &VGC64Machine::_bus_read;
	_cpu->write_cb = &VGC64Machine::_bus_write;
	_cpu->userdata = this;

	_fb_bytes.resize(SCREEN_W * SCREEN_H * 4);
	uint8_t *p = _fb_bytes.ptrw();
	for (int i = 0; i < SCREEN_W * SCREEN_H; i++) {
		p[i * 4 + 0] = 0; p[i * 4 + 1] = 0; p[i * 4 + 2] = 0; p[i * 4 + 3] = 255;
	}
	_fb_image = Image::create_from_data(SCREEN_W, SCREEN_H, false, Image::FORMAT_RGBA8, _fb_bytes);
}

VGC64Machine::~VGC64Machine() {
	if (_cpu) {
		memdelete(_cpu);
		_cpu = nullptr;
	}
}

// ---------------------------------------------------------------------------
// ROM loading
// ---------------------------------------------------------------------------
bool VGC64Machine::load_rom_file(const String &path, uint8_t *dst, int max_len, int &out_len) {
	if (!FileAccess::file_exists(path)) {
		UtilityFunctions::print("[VGC64Machine] ROM not found: ", path);
		out_len = 0;
		return false;
	}
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
	if (f.is_null()) {
		UtilityFunctions::print("[VGC64Machine] Could not open ROM: ", path);
		out_len = 0;
		return false;
	}
	PackedByteArray data = f->get_buffer(f->get_length());
	int n = data.size();
	if (n > max_len) n = max_len;
	memcpy(dst, data.ptr(), n);
	out_len = n;
	return n > 0;
}

bool VGC64Machine::load_roms(const String &basic_path, const String &kernal_path, const String &char_path) {
	int bl = 0, kl = 0, cl = 0;
	_has_basic = load_rom_file(basic_path, _basic_rom, sizeof(_basic_rom), bl);
	_has_kernal = load_rom_file(kernal_path, _kernal_rom, sizeof(_kernal_rom), kl);
	_has_char = load_rom_file(char_path, _char_rom, sizeof(_char_rom), cl);
	return _has_basic && _has_kernal && _has_char;
}

// ---------------------------------------------------------------------------
// Reset
// ---------------------------------------------------------------------------
void VGC64Machine::reset() {
	_port00 = 0x2F;
	_port01 = 0x37;
	update_banking();
	_ram[0] = _port00;
	_ram[1] = _port01;

	_cia1_ta = CIA1_TA_LATCH;
	_irq_line = false;
	_raster_line = 0;
	_cycle_in_line = 0;
	_raster_irq = 0;
	for (int i = 0; i < 8; i++) _key_col[i] = 0xFF;

	fake6502_reset(_cpu); // pulls reset vector from KERNAL ($FFFC/$FFFD)
}

void VGC64Machine::update_banking() {
	_loram = (_port01 & 0x01) != 0;
	_hiram = (_port01 & 0x02) != 0;
	_charen = (_port01 & 0x04) != 0;
}

// ---------------------------------------------------------------------------
// Memory bus (C64 PLA banking, no-cartridge / GAME=EXROM=1 case)
// ---------------------------------------------------------------------------
uint8_t VGC64Machine::bus_read(uint16_t addr) {
	if (addr == 0x0000) return _port00;
	if (addr == 0x0001) return _port01;

	if (addr < 0xA000) return _ram[addr];

	if (addr < 0xC000) { // $A000-$BFFF: BASIC ROM iff LORAM & HIRAM
		if (_loram && _hiram && _has_basic) return _basic_rom[addr - 0xA000];
		return _ram[addr];
	}

	if (addr < 0xD000) return _ram[addr]; // $C000-$CFFF

	if (addr < 0xE000) { // $D000-$DFFF: I/O, CHAR ROM, or RAM
		bool io_visible = _charen && (_loram || _hiram);
		bool char_visible = !_charen && (_loram || _hiram);
		if (io_visible) {
			if (addr < 0xD400) return _ram[addr];              // VIC-II regs (stored in RAM)
			if (addr < 0xD800) return _ram[addr];              // SID (stored in RAM)
			if (addr < 0xDC00) return _color_ram[(addr - 0xD800) & 0x3FF] | 0xF0;
			if (addr < 0xDD00) return read_cia1(addr & 0x0F);
			if (addr < 0xDE00) return read_cia2(addr & 0x0F);
			return _ram[addr];
		} else if (char_visible && _has_char) {
			return _char_rom[addr - 0xD000];
		}
		return _ram[addr];
	}

	// $E000-$FFFF: KERNAL ROM iff HIRAM
	if (_hiram && _has_kernal) return _kernal_rom[addr - 0xE000];
	return _ram[addr];
}

void VGC64Machine::bus_write(uint16_t addr, uint8_t val) {
	if (addr == 0x0000) {
		_port00 = val;
		update_banking();
		_ram[0] = val;
		return;
	}
	if (addr == 0x0001) {
		_port01 = val;
		update_banking();
		_ram[1] = val;
		return;
	}

	if (addr < 0xD000) { _ram[addr] = val; return; }

	if (addr < 0xE000) { // $D000-$DFFF
		bool io_visible = _charen && (_loram || _hiram);
		if (io_visible) {
			if (addr < 0xD400) { _ram[addr] = val; return; }   // VIC-II regs
			if (addr < 0xD800) { _ram[addr] = val; return; }   // SID
			if (addr < 0xDC00) { _color_ram[(addr - 0xD800) & 0x3FF] = val & 0x0F; return; }
			if (addr < 0xDD00) { write_cia1(addr & 0x0F, val); return; }
			if (addr < 0xDE00) { write_cia2(addr & 0x0F, val); return; }
			_ram[addr] = val;
			return;
		}
		_ram[addr] = val; // RAM under CHAR ROM
		return;
	}

	_ram[addr] = val; // RAM under KERNAL
}

// ---------------------------------------------------------------------------
// CIA1 (keyboard + Timer-A system IRQ)
// ---------------------------------------------------------------------------
uint8_t VGC64Machine::read_cia1(int off) {
	switch (off & 0x0F) {
		case 0x00: // PRA
			return 0xFF;
		case 0x01: { // PRB — keyboard rows for selected column
			uint8_t colMask = _ram[0xDC00] & 0xFF;
			if (colMask == 0xFF) return 0xFF;
			int idx = -1;
			switch (colMask) {
				case 0xFE: idx = 0; break; case 0xFD: idx = 1; break;
				case 0xFB: idx = 2; break; case 0xF7: idx = 3; break;
				case 0xEF: idx = 4; break; case 0xDF: idx = 5; break;
				case 0xBF: idx = 6; break; case 0x7F: idx = 7; break;
				default: return 0xFF;
			}
			return _key_col[idx];
		}
		case 0x02: return _ram[0xDC02];
		case 0x03: return _ram[0xDC03];
		case 0x0D: { // ICR — read clears
			uint8_t flags = _ram[0xDC0D];
			_ram[0xDC0D] = 0;
			return flags;
		}
		default: return 0;
	}
}

void VGC64Machine::write_cia1(int off, uint8_t val) {
	switch (off & 0x0F) {
		case 0x00: _ram[0xDC00] = val; break;
		case 0x02: _ram[0xDC02] = val; break;
		case 0x03: _ram[0xDC03] = val; break;
		default: break; // timer latch/control writes: system timer is modeled by cia_tick
	}
}

uint8_t VGC64Machine::read_cia2(int off) {
	switch (off & 0x0F) {
		case 0x00: return _ram[0xDD00];
		case 0x01: return _ram[0xDD01];
		default: return 0xFF;
	}
}

void VGC64Machine::write_cia2(int off, uint8_t val) {
	switch (off & 0x0F) {
		case 0x00: _ram[0xDD00] = val; break; // VIC bank select (bits 0-1, inverted)
		case 0x01: _ram[0xDD01] = val; break;
		case 0x02: _ram[0xDD02] = val; break;
		case 0x03: _ram[0xDD03] = val; break;
		default: break;
	}
}

void VGC64Machine::cia_tick(int cycles) {
	_cia1_ta -= cycles;
	if (_cia1_ta <= 0) {
		_cia1_ta += CIA1_TA_LATCH;
		_ram[0xDC0D] |= 0x81; // ICR: Timer-A underflow (bit0) + IRQ occurred (bit7)
		_irq_line = true;
	}
}

// ---------------------------------------------------------------------------
// VIC-II
// ---------------------------------------------------------------------------
uint8_t VGC64Machine::vic_fetch(uint16_t addr) {
	// VIC-II sees CHAR ROM at $1000-$1FFF in the default bank 0.
	if (addr >= 0x1000 && addr < 0x2000 && _has_char) {
		return _char_rom[addr - 0x1000];
	}
	return _ram[addr & 0xFFFF];
}

inline void VGC64Machine::put_pixel(int x, int y, int colIdx) {
	if (x < 0 || x >= SCREEN_W || y < 0 || y >= SCREEN_H) return;
	uint8_t *p = _fb_bytes.ptrw();
	int o = (y * SCREEN_W + x) * 4;
	const uint8_t *c = C64_PALETTE[colIdx & 0x0F];
	p[o + 0] = c[0]; p[o + 1] = c[1]; p[o + 2] = c[2]; p[o + 3] = 255;
}

void VGC64Machine::vic_tick(int cycles) {
	for (int n = 0; n < cycles; n++) {
		_cycle_in_line++;
		if (_cycle_in_line >= CYCLES_PER_LINE) {
			_cycle_in_line = 0;
			_raster_line++;
			if (_raster_line >= LINES_PER_FRAME) {
				_raster_line = 0;
				render_border();
			}

			_ram[0xD012] = _raster_line & 0xFF;
			uint8_t d011 = _ram[0xD011];
			if (_raster_line >= 256) _ram[0xD011] = (d011 & 0x7F) | 0x80;
			else _ram[0xD011] = d011 & 0x7F;

			if (_raster_line == _raster_irq) {
				_ram[0xD019] |= 0x01;
			}

			if (_raster_line >= 16 && _raster_line < 251) {
				render_scanline(_raster_line - 16);
			}
		}
	}
}

void VGC64Machine::render_border() {
	int borderCol = vic_reg(0x20) & 0x0F;
	for (int y = 0; y < BORDER_Y; y++)
		for (int x = 0; x < SCREEN_W; x++) put_pixel(x, y, borderCol);
	for (int y = SCREEN_H - BORDER_Y; y < SCREEN_H; y++)
		for (int x = 0; x < SCREEN_W; x++) put_pixel(x, y, borderCol);
	for (int y = BORDER_Y; y < SCREEN_H - BORDER_Y; y++) {
		for (int x = 0; x < BORDER_X; x++) put_pixel(x, y, borderCol);
		for (int x = SCREEN_W - BORDER_X; x < SCREEN_W; x++) put_pixel(x, y, borderCol);
	}
}

void VGC64Machine::paint_narrow_gap(int screenY, int xOff) {
	if (xOff <= 0) return;
	int rowY = screenY + BORDER_Y;
	if (rowY < 0 || rowY >= SCREEN_H) return;
	int borderCol = vic_reg(0x20) & 0x0F;
	for (int i = 0; i < xOff; i++) {
		put_pixel(BORDER_X + i, rowY, borderCol);
		put_pixel(SCREEN_W - BORDER_X - 1 - i, rowY, borderCol);
	}
}

void VGC64Machine::render_scanline(int screenY) {
	if (screenY < 0 || screenY >= VISIBLE_H) return;

	uint8_t ctrl1 = vic_reg(0x11);
	uint8_t ctrl2 = vic_reg(0x16);
	uint8_t memPtr = vic_reg(0x18);

	bool BMM = (ctrl1 & 0x20) != 0;
	bool MCM = (ctrl2 & 0x10) != 0;
	bool CSEL = (ctrl2 & 0x08) != 0;

	int yScroll = ctrl1 & 0x07;
	int charRow = (screenY + yScroll) / 8;
	int pixelRow = (screenY + yScroll) % 8;

	int vm10 = (memPtr & 0xF0) >> 4;
	int scrBase = vm10 << 10;
	int cbBits = (memPtr & 0x0E) >> 1;
	int charBase = cbBits << 11;

	int numCols = CSEL ? 40 : 38;
	int xOff = CSEL ? 0 : 8;

	if (BMM) {
		render_bitmap(screenY, charRow, pixelRow, scrBase, charBase, xOff);
	} else if (MCM) {
		render_mc_char(screenY, charRow, pixelRow, scrBase, numCols, xOff);
	} else {
		render_char(screenY, charRow, pixelRow, scrBase, charBase, numCols, xOff);
	}
}

void VGC64Machine::render_char(int screenY, int charRow, int pixelRow, int scrBase, int charBase, int numCols, int xOff) {
	int bgCol = vic_reg(0x21) & 0x0F;
	paint_narrow_gap(screenY, xOff);
	int sy = screenY + BORDER_Y;

	for (int col = 0; col < numCols; col++) {
		int scrAddr = (scrBase + charRow * 40 + col) & 0xFFFF;
		int ch = _ram[scrAddr];
		int chAddr = charBase + ch * 8 + pixelRow;
		uint8_t data = vic_fetch((uint16_t)chAddr);

		int index = charRow * 40 + col;
		if (index >= 0 && index < 0x400) _cur_fg = _color_ram[index] & 0x0F;

		for (int px = 0; px < 8; px++) {
			int sx = xOff + col * 8 + px + BORDER_X;
			int colIdx = (data & (0x80 >> px)) ? _cur_fg : bgCol;
			put_pixel(sx, sy, colIdx);
		}
	}
}

void VGC64Machine::render_mc_char(int screenY, int charRow, int pixelRow, int scrBase, int numCols, int xOff) {
	int mc1 = vic_reg(0x22) & 0x0F;
	int mc2 = vic_reg(0x23) & 0x0F;
	int bgCol = vic_reg(0x21) & 0x0F;
	paint_narrow_gap(screenY, xOff);
	int sy = screenY + BORDER_Y;

	for (int col = 0; col < numCols; col++) {
		int scrAddr = (scrBase + charRow * 40 + col) & 0xFFFF;
		int ch = _ram[scrAddr];
		int chBase = (ch & 0x08) ? 0x0000 : 0x0800;
		int chAddr = chBase + (ch & 0x07) * 8 + pixelRow;
		uint8_t data = _ram[chAddr & 0xFFFF];

		int index = charRow * 40 + col;
		if (index >= 0 && index < 0x400) _cur_fg = _color_ram[index] & 0x0F;

		for (int px = 0; px < 4; px++) {
			int pair = (data & 0xC0) >> 6;
			data = (uint8_t)((data << 2) & 0xFF);
			int pc;
			switch (pair) {
				case 0: pc = bgCol; break;
				case 1: pc = mc1; break;
				case 2: pc = mc2; break;
				default: pc = _cur_fg; break;
			}
			for (int dx = 0; dx < 2; dx++) {
				int sx = xOff + col * 8 + px * 2 + dx + BORDER_X;
				put_pixel(sx, sy, pc);
			}
		}
	}
}

void VGC64Machine::render_bitmap(int screenY, int charRow, int pixelRow, int scrBase, int charBase, int xOff) {
	paint_narrow_gap(screenY, xOff);
	int sy = screenY + BORDER_Y;

	for (int col = 0; col < 40; col++) {
		int bitmapRow = charRow * 8 + pixelRow;
		int bitmapAddr = charBase + bitmapRow * 40 + col;
		uint8_t data = _ram[bitmapAddr & 0xFFFF];

		int scrAddr = (scrBase + charRow * 40 + col) & 0xFFFF;
		int colorInfo = _ram[scrAddr];
		int fgCol = (colorInfo >> 4) & 0x0F;
		int bgCol = colorInfo & 0x0F;

		for (int px = 0; px < 8; px++) {
			int sx = xOff + col * 8 + px + BORDER_X;
			int colIdx = (data & (0x80 >> px)) ? fgCol : bgCol;
			put_pixel(sx, sy, colIdx);
		}
	}
}

// ---------------------------------------------------------------------------
// Execution
// ---------------------------------------------------------------------------
uint32_t VGC64Machine::run_frame() {
	return run_cycles(CYCLES_PER_FRAME_PAL);
}

uint32_t VGC64Machine::run_cycles(int cycles) {
	uint32_t ran = 0;
	int guard = 0;
	int guard_max = cycles * 8 + 100000;
	while ((int)ran < cycles) {
		if (_irq_line && (_cpu->status & FK_FLAG_INTERRUPT) == 0) {
			fake6502_irq(_cpu);
			_irq_line = false;
		}
		uint32_t c = fake6502_step(_cpu);
		if (c == 0) c = 1;
		ran += c;
		vic_tick((int)c);
		cia_tick((int)c);
		if (++guard > guard_max) break; // safety net against a runaway loop
	}
	// Publish the framebuffer once per call.
	_fb_image->set_data(SCREEN_W, SCREEN_H, false, Image::FORMAT_RGBA8, _fb_bytes);
	return ran;
}

// ---------------------------------------------------------------------------
// Bus / register access for VG
// ---------------------------------------------------------------------------
int VGC64Machine::read_byte(int addr) { return bus_read((uint16_t)(addr & 0xFFFF)); }
void VGC64Machine::write_byte(int addr, int val) { bus_write((uint16_t)(addr & 0xFFFF), (uint8_t)(val & 0xFF)); }
int VGC64Machine::peek_ram(int addr) const { return _ram[addr & 0xFFFF]; }
void VGC64Machine::poke_ram(int addr, int val) { _ram[addr & 0xFFFF] = (uint8_t)(val & 0xFF); }

int VGC64Machine::get_pc() const { return _cpu->pc; }
void VGC64Machine::set_pc(int v) { _cpu->pc = (uint16_t)(v & 0xFFFF); }
int VGC64Machine::get_a() const { return _cpu->a; }
int VGC64Machine::get_x() const { return _cpu->x; }
int VGC64Machine::get_y() const { return _cpu->y; }
int VGC64Machine::get_sp() const { return _cpu->sp; }
int VGC64Machine::get_status() const { return _cpu->status; }
int64_t VGC64Machine::get_instruction_count() const { return (int64_t)_cpu->instructions; }

void VGC64Machine::set_key_col(int idx, int val) {
	if (idx >= 0 && idx < 8) _key_col[idx] = (uint8_t)(val & 0xFF);
}

void VGC64Machine::assert_irq() { _irq_line = true; }

Ref<Image> VGC64Machine::get_framebuffer() {
	_fb_image->set_data(SCREEN_W, SCREEN_H, false, Image::FORMAT_RGBA8, _fb_bytes);
	return _fb_image;
}

// ---------------------------------------------------------------------------
// Godot bindings (VG-facing PascalCase API)
// ---------------------------------------------------------------------------
void VGC64Machine::_bind_methods() {
	ClassDB::bind_method(D_METHOD("LoadROMs", "basic_path", "kernal_path", "char_path"), &VGC64Machine::load_roms);
	ClassDB::bind_method(D_METHOD("Reset"), &VGC64Machine::reset);
	ClassDB::bind_method(D_METHOD("RunFrame"), &VGC64Machine::run_frame);
	ClassDB::bind_method(D_METHOD("RunCycles", "cycles"), &VGC64Machine::run_cycles);

	ClassDB::bind_method(D_METHOD("ReadByte", "addr"), &VGC64Machine::read_byte);
	ClassDB::bind_method(D_METHOD("WriteByte", "addr", "value"), &VGC64Machine::write_byte);
	ClassDB::bind_method(D_METHOD("PeekRAM", "addr"), &VGC64Machine::peek_ram);
	ClassDB::bind_method(D_METHOD("PokeRAM", "addr", "value"), &VGC64Machine::poke_ram);

	ClassDB::bind_method(D_METHOD("GetPC"), &VGC64Machine::get_pc);
	ClassDB::bind_method(D_METHOD("SetPC", "value"), &VGC64Machine::set_pc);
	ClassDB::bind_method(D_METHOD("GetA"), &VGC64Machine::get_a);
	ClassDB::bind_method(D_METHOD("GetX"), &VGC64Machine::get_x);
	ClassDB::bind_method(D_METHOD("GetY"), &VGC64Machine::get_y);
	ClassDB::bind_method(D_METHOD("GetSP"), &VGC64Machine::get_sp);
	ClassDB::bind_method(D_METHOD("GetStatus"), &VGC64Machine::get_status);
	ClassDB::bind_method(D_METHOD("GetInstructionCount"), &VGC64Machine::get_instruction_count);

	ClassDB::bind_method(D_METHOD("SetKeyCol", "idx", "value"), &VGC64Machine::set_key_col);
	ClassDB::bind_method(D_METHOD("AssertIRQ"), &VGC64Machine::assert_irq);
	ClassDB::bind_method(D_METHOD("GetFramebuffer"), &VGC64Machine::get_framebuffer);
}
