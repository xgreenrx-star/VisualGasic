#ifndef VISUAL_GASIC_C64_MACHINE_H
#define VISUAL_GASIC_C64_MACHINE_H

// VGC64Machine — a fully NATIVE Commodore 64 machine exposed as a VisualGasic
// engine primitive. Unlike VGCpu6502 (a bare 6502 core whose memory bus can be
// routed back into VG script), this class keeps the ENTIRE hot path in C++:
//   - reentrant 6510 CPU (src/cpu_cores/fake6502_ctx.h)
//   - C64 memory map + PLA bank switching (RAM / BASIC / KERNAL / CHAR / I/O)
//   - VIC-II raster renderer (standard + multicolor char modes, bitmap mode)
//   - CIA1 Timer-A ~60 Hz system IRQ + keyboard matrix
// so a VG project gets real-hardware execution speed with zero per-access
// Callable round-trips.
//
// This exists specifically because the "Turbo Mode" approach in
// demos/C64_Emulator (native VGCpu6502 whose bus is hooked back to VG's
// Mem_Read/Mem_Write) still round-trips every single memory access through a
// VG Callable, which dominates cost and gives almost no speedup. Moving the
// bus + VIC + CIA into C++ removes that bottleneck entirely.
//
// MARKETING NOTE: the pure-VG C64 core (demos/C64_Emulator/c64_cpu.vg) remains
// the "written in 100% VG" showcase. VGC64Machine is a clearly-labeled,
// opt-in NATIVE engine capability ("VG ships a native C64 core — build a
// full-speed emulator instantly"), never a silent swap-in under the 100%-VG
// banner.
//
// Usage in VisualGasic:
//   Dim m As New VGC64Machine
//   m.LoadROMs "res://roms/basic.bin", "res://roms/kernal.bin", "res://roms/char.bin"
//   m.Reset
//   ' (optionally poke a fast-boot stub via m.WriteByte / m.SetPC)
//   Sub _Process(delta)
//       m.RunFrame                       ' one full PAL frame, natively
//       BlitImage DisplayImage, m.GetFramebuffer(), 0, 0, 384, 272, 0, 0
//       UpdateTexture DisplayTex, DisplayImage
//   End Sub

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <cstdint>

using namespace godot;

struct Fake6502;

class VGC64Machine : public RefCounted {
	GDCLASS(VGC64Machine, RefCounted);

public:
	// PAL geometry (matches demos/C64_Emulator/c64_constants.vg).
	static const int SCREEN_W = 384;
	static const int SCREEN_H = 272;
	static const int BORDER_X = 32;
	static const int BORDER_Y = 36;
	static const int VISIBLE_H = 200;
	static const int CYCLES_PER_FRAME_PAL = 19705;
	static const int CYCLES_PER_LINE = 63;
	static const int LINES_PER_FRAME = 312;
	static const int CIA1_TA_LATCH = 16421; // PAL ~60 Hz system IRQ

private:
	Fake6502 *_cpu = nullptr;

	uint8_t _ram[65536];        // main RAM (also backs I/O registers at $D000+)
	uint8_t _color_ram[1024];   // 4-bit color RAM (low nibble)
	uint8_t _basic_rom[8192];
	uint8_t _kernal_rom[8192];
	uint8_t _char_rom[4096];
	bool _has_basic = false;
	bool _has_kernal = false;
	bool _has_char = false;

	// Cartridge ROM (.crt, "Normal cartridge" hardware type 0 only -- no
	// bank-switching mappers yet). ROML = $8000-$9FFF (8K/16K carts), ROMH =
	// $A000-$BFFF (16K carts only). _cart_exrom/_cart_game mirror the real
	// EXROM/GAME cartridge-port lines: true = line high/inactive (no cart
	// effect, the power-on default), false = line asserted low by the
	// cartridge.
	uint8_t _cart_lo_rom[8192];
	uint8_t _cart_hi_rom[8192];
	bool _has_cart_lo = false;
	bool _has_cart_hi = false;
	bool _cart_exrom = true;
	bool _cart_game = true;

	// Processor port ($00 DDR / $01 data) + decoded PLA banking lines.
	uint8_t _port00 = 0x2F;
	uint8_t _port01 = 0x37;
	bool _loram = true;
	bool _hiram = true;
	bool _charen = true;

	// CIA1 keyboard matrix (8 columns, active-low) + Timer-A system IRQ.
	uint8_t _key_col[8];
	int32_t _cia1_ta = CIA1_TA_LATCH;
	bool _irq_line = false;

	// VIC-II raster state.
	int _raster_line = 0;
	int _cycle_in_line = 0;
	int _raster_irq = 0;
	int _cur_fg = 14; // persisted foreground when color-RAM index goes out of range

	// Framebuffer (RGBA8) + reusable Godot Image.
	PackedByteArray _fb_bytes;
	Ref<Image> _fb_image;

	// --- memory bus (banking-aware) ---
	static uint8_t _bus_read(Fake6502 *ctx, uint16_t addr);
	static void _bus_write(Fake6502 *ctx, uint16_t addr, uint8_t val);
	uint8_t bus_read(uint16_t addr);
	void bus_write(uint16_t addr, uint8_t val);
	void update_banking();

	// --- CIA ---
	uint8_t read_cia1(int off);
	void write_cia1(int off, uint8_t val);
	uint8_t read_cia2(int off);
	void write_cia2(int off, uint8_t val);
	void cia_tick(int cycles);

	// --- VIC-II ---
	inline uint8_t vic_reg(int r) const { return _ram[0xD000 + r]; }
	uint8_t vic_fetch(uint16_t addr); // VIC sees CHAR ROM at $1000-$1FFF (bank 0)
	void vic_tick(int cycles);
	void render_border();
	void render_scanline(int screenY);
	void render_char(int screenY, int charRow, int pixelRow, int scrBase, int charBase, int numCols, int xOff);
	void render_mc_char(int screenY, int charRow, int pixelRow, int scrBase, int numCols, int xOff);
	void render_bitmap(int screenY, int charRow, int pixelRow, int scrBase, int charBase, int xOff);
	void paint_narrow_gap(int screenY, int xOff);
	inline void put_pixel(int x, int y, int colIdx);

	static bool load_rom_file(const String &path, uint8_t *dst, int max_len, int &out_len);

protected:
	static void _bind_methods();

public:
	VGC64Machine();
	~VGC64Machine();

	bool load_roms(const String &basic_path, const String &kernal_path, const String &char_path);
	// Loads a .crt cartridge image (Normal/type-0 8K or 16K only -- prints and
	// rejects anything else, including bank-switched mappers like EasyFlash or
	// Action Replay, which are not implemented yet). Persists across reset()
	// (matches real hardware: a cartridge stays inserted through a RESET).
	bool load_cartridge(const String &path);
	void unload_cartridge();
	bool has_cartridge() const { return _has_cart_lo || _has_cart_hi; }
	void reset();
	uint32_t run_frame();      // execute one PAL frame; returns cycles run
	uint32_t run_cycles(int cycles);

	// Bus access (banking-aware) for boot-stub setup / debugging.
	int read_byte(int addr);
	void write_byte(int addr, int val);
	int peek_ram(int addr) const;      // raw RAM (bypasses banking)
	void poke_ram(int addr, int val);

	// CPU register access (debugger / Immediate window).
	int get_pc() const; void set_pc(int v);
	int get_a() const;  int get_x() const; int get_y() const;
	int get_sp() const; int get_status() const;
	int64_t get_instruction_count() const;

	void set_key_col(int idx, int val);
	void assert_irq();                 // manually raise the IRQ line

	Ref<Image> get_framebuffer();
};

#endif // VISUAL_GASIC_C64_MACHINE_H
