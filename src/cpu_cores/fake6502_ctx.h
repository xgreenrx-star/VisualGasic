/* fake6502_ctx.h — reentrant, context-struct 6502/6510 CPU core for VisualGasic.
 *
 * DERIVED FROM: fake6502.h v1.3 (MyLittle6502 fork by David MHS Webster /
 *   github.com/gek169, originally by Mike Chambers). Upstream is FULLY PUBLIC
 *   DOMAIN / CC0 — see vendor/fake6502/fake6502.h and vendor/fake6502/README.md
 *   for the pristine snapshot and provenance.
 *
 * WHY THIS FILE EXISTS (VG changes, Aug 2026 — /memories/repo/vgcpucore_6502_plan.md):
 *   Upstream keeps all CPU state in file-scope globals, so only one 6502 can run
 *   per process ("there is no instancing it" — upstream FAQ). VisualGasic exposes
 *   6502 cores as an engine primitive (VGCpu6502) that any project may instantiate
 *   more than once, so this fork moves ALL state into a heap-allocatable Fake6502
 *   context struct and routes memory access through per-context read/write
 *   callbacks instead of the global read6502/write6502 externs.
 *
 * WHAT CHANGED vs. upstream:
 *   - All registers + working vars live in `struct Fake6502`; every function takes
 *     `Fake6502 *c` and touches `c->field` instead of a global.
 *   - `read6502(addr)`  -> `c->read_cb(c, addr)`
 *     `write6502(a,v)`  -> `c->write_cb(c, a, v)`   (per-instance memory bus)
 *   - Instruction handler `and()` renamed `and_6502()` (`and` is a reserved
 *     keyword in C++; this header is compiled inside the C++ GDExtension).
 *   - Fixed-width <stdint.h> types throughout; unused `getvalue16()` (dead in the
 *     base NMOS core) omitted to keep -Wunused-function quiet.
 *   - Undocumented/illegal opcodes are ALWAYS compiled in (real C64 software and
 *     demos depend on them).
 *
 * WHAT DID NOT CHANGE: opcode decode, addressing modes, flag semantics, cycle
 *   timing, illegal-opcode behavior, and BCD (decimal-mode ADC/SBC) are all
 *   transcribed faithfully from upstream. Upstream validated this logic against a
 *   real C64 KERNAL ("kernalemu") — Commodore BASIC V2 boots and runs.
 *
 * USAGE:
 *   Fake6502 cpu;
 *   memset(&cpu, 0, sizeof(cpu));      // registers/counters start at 0
 *   cpu.read_cb  = my_read;            // uint8_t(Fake6502*, uint16_t)
 *   cpu.write_cb = my_write;           // void   (Fake6502*, uint16_t, uint8_t)
 *   cpu.userdata = my_bus;             // opaque; recover inside the callbacks
 *   fake6502_reset(&cpu);              // once before execution
 *   fake6502_exec(&cpu, 20000);        // run ~20000 cycles
 */
#ifndef VG_FAKE6502_CTX_H
#define VG_FAKE6502_CTX_H

#include <stdint.h>

/* ---- status register flag bits ---- */
enum {
	FK_FLAG_CARRY     = 0x01,
	FK_FLAG_ZERO      = 0x02,
	FK_FLAG_INTERRUPT = 0x04,
	FK_FLAG_DECIMAL   = 0x08,
	FK_FLAG_BREAK     = 0x10,
	FK_FLAG_CONSTANT  = 0x20,
	FK_FLAG_OVERFLOW  = 0x40,
	FK_FLAG_SIGN      = 0x80
};

#define FK_BASE_STACK 0x100

typedef struct Fake6502 Fake6502;

struct Fake6502 {
	/* 6502/6510 CPU registers */
	uint16_t pc;
	uint8_t  sp, a, x, y, status;
	/* helper / working variables (kept per-instance for reentrancy) */
	uint32_t instructions;
	uint32_t clockticks6502;
	uint32_t clockgoal6502;
	uint16_t oldpc, ea, reladdr, value, result;
	uint8_t  opcode, oldstatus;
	uint8_t  penaltyop, penaltyaddr;
	/* optional post-instruction hook (e.g. VIC-II raster timing) */
	uint8_t  callexternal;
	void   (*loopexternal)(Fake6502 *c);
	/* REQUIRED per-instance memory bus */
	uint8_t (*read_cb)(Fake6502 *c, uint16_t address);
	void    (*write_cb)(Fake6502 *c, uint16_t address, uint8_t value);
	/* opaque user pointer for the bus adapter to recover its own object */
	void    *userdata;
};

/* ---- internal helper macros (all #undef'd at end of header) ---- */
#define FK_saveaccum(c, n) (c)->a = (uint8_t)((n) & 0x00FF)

#define FK_setcarry(c)       (c)->status |= FK_FLAG_CARRY
#define FK_clearcarry(c)     (c)->status &= (~FK_FLAG_CARRY)
#define FK_setzero(c)        (c)->status |= FK_FLAG_ZERO
#define FK_clearzero(c)      (c)->status &= (~FK_FLAG_ZERO)
#define FK_setinterrupt(c)   (c)->status |= FK_FLAG_INTERRUPT
#define FK_clearinterrupt(c) (c)->status &= (~FK_FLAG_INTERRUPT)
#define FK_setdecimal(c)     (c)->status |= FK_FLAG_DECIMAL
#define FK_cleardecimal(c)   (c)->status &= (~FK_FLAG_DECIMAL)
#define FK_setoverflow(c)    (c)->status |= FK_FLAG_OVERFLOW
#define FK_clearoverflow(c)  (c)->status &= (~FK_FLAG_OVERFLOW)
#define FK_setsign(c)        (c)->status |= FK_FLAG_SIGN
#define FK_clearsign(c)      (c)->status &= (~FK_FLAG_SIGN)

#define FK_zerocalc(c, n)  { if ((n) & 0x00FF) FK_clearzero(c); else FK_setzero(c); }
#define FK_signcalc(c, n)  { if ((n) & 0x0080) FK_setsign(c);  else FK_clearsign(c); }
#define FK_carrycalc(c, n) { if ((n) & 0xFF00) FK_setcarry(c); else FK_clearcarry(c); }
/* n = result, m = accumulator, o = memory */
#define FK_overflowcalc(c, n, m, o) { if (((n) ^ (uint16_t)(m)) & ((n) ^ (o)) & 0x0080) FK_setoverflow(c); else FK_clearoverflow(c); }

/* ---- stack + memory helpers ---- */
static void fk_push16(Fake6502 *c, uint16_t pushval) {
	c->write_cb(c, FK_BASE_STACK + c->sp, (pushval >> 8) & 0xFF);
	c->write_cb(c, FK_BASE_STACK + ((c->sp - 1) & 0xFF), pushval & 0xFF);
	c->sp -= 2;
}

static void fk_push8(Fake6502 *c, uint8_t pushval) {
	c->write_cb(c, FK_BASE_STACK + c->sp--, pushval);
}

static uint16_t fk_pull16(Fake6502 *c) {
	uint16_t temp16;
	temp16 = c->read_cb(c, FK_BASE_STACK + ((c->sp + 1) & 0xFF)) | ((uint16_t)c->read_cb(c, FK_BASE_STACK + ((c->sp + 2) & 0xFF)) << 8);
	c->sp += 2;
	return temp16;
}

static uint8_t fk_pull8(Fake6502 *c) {
	return c->read_cb(c, FK_BASE_STACK + ++c->sp);
}

static uint16_t fk_mem_read16(Fake6502 *c, uint16_t addr) {
	return ((uint16_t)c->read_cb(c, addr) | ((uint16_t)c->read_cb(c, addr + 1) << 8));
}

/* ---- forward declarations (tables reference these before they're defined) ---- */
static void imp(Fake6502 *c);
static void acc(Fake6502 *c);
static void imm(Fake6502 *c);
static void zp(Fake6502 *c);
static void zpx(Fake6502 *c);
static void zpy(Fake6502 *c);
static void rel(Fake6502 *c);
static void abso(Fake6502 *c);
static void absx(Fake6502 *c);
static void absy(Fake6502 *c);
static void ind(Fake6502 *c);
static void indx(Fake6502 *c);
static void indy(Fake6502 *c);

static uint16_t getvalue(Fake6502 *c);
static void putvalue(Fake6502 *c, uint16_t saveval);

static void adc(Fake6502 *c);
static void and_6502(Fake6502 *c);
static void asl(Fake6502 *c);
static void bcc(Fake6502 *c);
static void bcs(Fake6502 *c);
static void beq(Fake6502 *c);
static void bit(Fake6502 *c);
static void bmi(Fake6502 *c);
static void bne(Fake6502 *c);
static void bpl(Fake6502 *c);
static void brk_6502(Fake6502 *c);
static void bvc(Fake6502 *c);
static void bvs(Fake6502 *c);
static void clc(Fake6502 *c);
static void cld(Fake6502 *c);
static void cli(Fake6502 *c);
static void clv(Fake6502 *c);
static void cmp(Fake6502 *c);
static void cpx(Fake6502 *c);
static void cpy(Fake6502 *c);
static void dec(Fake6502 *c);
static void dex(Fake6502 *c);
static void dey(Fake6502 *c);
static void eor(Fake6502 *c);
static void inc(Fake6502 *c);
static void inx(Fake6502 *c);
static void iny(Fake6502 *c);
static void jmp(Fake6502 *c);
static void jsr(Fake6502 *c);
static void lda(Fake6502 *c);
static void ldx(Fake6502 *c);
static void ldy(Fake6502 *c);
static void lsr(Fake6502 *c);
static void nop(Fake6502 *c);
static void ora(Fake6502 *c);
static void pha(Fake6502 *c);
static void php(Fake6502 *c);
static void pla(Fake6502 *c);
static void plp(Fake6502 *c);
static void rol(Fake6502 *c);
static void ror(Fake6502 *c);
static void rti(Fake6502 *c);
static void rts(Fake6502 *c);
static void sbc(Fake6502 *c);
static void sec(Fake6502 *c);
static void sed(Fake6502 *c);
static void sei(Fake6502 *c);
static void sta(Fake6502 *c);
static void stx(Fake6502 *c);
static void sty(Fake6502 *c);
static void tax(Fake6502 *c);
static void tay(Fake6502 *c);
static void tsx(Fake6502 *c);
static void txa(Fake6502 *c);
static void txs(Fake6502 *c);
static void tya(Fake6502 *c);
/* undocumented / illegal opcodes (always compiled — C64 software needs them) */
static void lax(Fake6502 *c);
static void sax(Fake6502 *c);
static void dcp(Fake6502 *c);
static void isb(Fake6502 *c);
static void slo(Fake6502 *c);
static void rla(Fake6502 *c);
static void sre(Fake6502 *c);
static void rra(Fake6502 *c);

/* ---- dispatch tables (read-only; shared across all instances) ---- */
static void (*addrtable[256])(Fake6502 *) = {
/*        |  0  |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  |  9  |  A  |  B  |  C  |  D  |  E  |  F  |     */
/* 0 */     imp, indx,  imp, indx,   zp,   zp,   zp,   zp,  imp,  imm,  acc,  imm, abso, abso, abso, abso, /* 0 */
/* 1 */     rel, indy,  imp, indy,  zpx,  zpx,  zpx,  zpx,  imp, absy,  imp, absy, absx, absx, absx, absx, /* 1 */
/* 2 */    abso, indx,  imp, indx,   zp,   zp,   zp,   zp,  imp,  imm,  acc,  imm, abso, abso, abso, abso, /* 2 */
/* 3 */     rel, indy,  imp, indy,  zpx,  zpx,  zpx,  zpx,  imp, absy,  imp, absy, absx, absx, absx, absx, /* 3 */
/* 4 */     imp, indx,  imp, indx,   zp,   zp,   zp,   zp,  imp,  imm,  acc,  imm, abso, abso, abso, abso, /* 4 */
/* 5 */     rel, indy,  imp, indy,  zpx,  zpx,  zpx,  zpx,  imp, absy,  imp, absy, absx, absx, absx, absx, /* 5 */
/* 6 */     imp, indx,  imp, indx,   zp,   zp,   zp,   zp,  imp,  imm,  acc,  imm,  ind, abso, abso, abso, /* 6 */
/* 7 */     rel, indy,  imp, indy,  zpx,  zpx,  zpx,  zpx,  imp, absy,  imp, absy, absx, absx, absx, absx, /* 7 */
/* 8 */     imm, indx,  imm, indx,   zp,   zp,   zp,   zp,  imp,  imm,  imp,  imm, abso, abso, abso, abso, /* 8 */
/* 9 */     rel, indy,  imp, indy,  zpx,  zpx,  zpy,  zpy,  imp, absy,  imp, absy, absx, absx, absy, absy, /* 9 */
/* A */     imm, indx,  imm, indx,   zp,   zp,   zp,   zp,  imp,  imm,  imp,  imm, abso, abso, abso, abso, /* A */
/* B */     rel, indy,  imp, indy,  zpx,  zpx,  zpy,  zpy,  imp, absy,  imp, absy, absx, absx, absy, absy, /* B */
/* C */     imm, indx,  imm, indx,   zp,   zp,   zp,   zp,  imp,  imm,  imp,  imm, abso, abso, abso, abso, /* C */
/* D */     rel, indy,  imp, indy,  zpx,  zpx,  zpx,  zpx,  imp, absy,  imp, absy, absx, absx, absx, absx, /* D */
/* E */     imm, indx,  imm, indx,   zp,   zp,   zp,   zp,  imp,  imm,  imp,  imm, abso, abso, abso, abso, /* E */
/* F */     rel, indy,  imp, indy,  zpx,  zpx,  zpx,  zpx,  imp, absy,  imp, absy, absx, absx, absx, absx  /* F */
};

static void (*optable[256])(Fake6502 *) = {
/*        |    0     |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  |  9  |  A  |  B  |  C  |  D  |  E  |  F  |      */
/* 0 */   brk_6502,  ora,  nop,  slo,  nop,  ora,  asl,  slo,  php,  ora,  asl,  nop,  nop,  ora,  asl,  slo, /* 0 */
/* 1 */        bpl,  ora,  nop,  slo,  nop,  ora,  asl,  slo,  clc,  ora,  nop,  slo,  nop,  ora,  asl,  slo, /* 1 */
/* 2 */        jsr, and_6502, nop, rla,  bit, and_6502, rol, rla,  plp, and_6502, rol, nop,  bit, and_6502, rol, rla, /* 2 */
/* 3 */        bmi, and_6502, nop, rla,  nop, and_6502, rol, rla,  sec, and_6502, nop, rla,  nop, and_6502, rol, rla, /* 3 */
/* 4 */        rti,  eor,  nop,  sre,  nop,  eor,  lsr,  sre,  pha,  eor,  lsr,  nop,  jmp,  eor,  lsr,  sre, /* 4 */
/* 5 */        bvc,  eor,  nop,  sre,  nop,  eor,  lsr,  sre,  cli,  eor,  nop,  sre,  nop,  eor,  lsr,  sre, /* 5 */
/* 6 */        rts,  adc,  nop,  rra,  nop,  adc,  ror,  rra,  pla,  adc,  ror,  nop,  jmp,  adc,  ror,  rra, /* 6 */
/* 7 */        bvs,  adc,  nop,  rra,  nop,  adc,  ror,  rra,  sei,  adc,  nop,  rra,  nop,  adc,  ror,  rra, /* 7 */
/* 8 */        nop,  sta,  nop,  sax,  sty,  sta,  stx,  sax,  dey,  nop,  txa,  nop,  sty,  sta,  stx,  sax, /* 8 */
/* 9 */        bcc,  sta,  nop,  nop,  sty,  sta,  stx,  sax,  tya,  sta,  txs,  nop,  nop,  sta,  nop,  nop, /* 9 */
/* A */        ldy,  lda,  ldx,  lax,  ldy,  lda,  ldx,  lax,  tay,  lda,  tax,  nop,  ldy,  lda,  ldx,  lax, /* A */
/* B */        bcs,  lda,  nop,  lax,  ldy,  lda,  ldx,  lax,  clv,  lda,  tsx,  lax,  ldy,  lda,  ldx,  lax, /* B */
/* C */        cpy,  cmp,  nop,  dcp,  cpy,  cmp,  dec,  dcp,  iny,  cmp,  dex,  nop,  cpy,  cmp,  dec,  dcp, /* C */
/* D */        bne,  cmp,  nop,  dcp,  nop,  cmp,  dec,  dcp,  cld,  cmp,  nop,  dcp,  nop,  cmp,  dec,  dcp, /* D */
/* E */        cpx,  sbc,  nop,  isb,  cpx,  sbc,  inc,  isb,  inx,  sbc,  nop,  sbc,  cpx,  sbc,  inc,  isb, /* E */
/* F */        beq,  sbc,  nop,  isb,  nop,  sbc,  inc,  isb,  sed,  sbc,  nop,  isb,  nop,  sbc,  inc,  isb  /* F */
};

static const uint32_t ticktable[256] = {
/*        |  0  |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  |  9  |  A  |  B  |  C  |  D  |  E  |  F  |     */
/* 0 */      7,    6,    2,    8,    3,    3,    5,    5,    3,    2,    2,    2,    4,    4,    6,    6,  /* 0 */
/* 1 */      2,    5,    2,    8,    4,    4,    6,    6,    2,    4,    2,    7,    4,    4,    7,    7,  /* 1 */
/* 2 */      6,    6,    2,    8,    3,    3,    5,    5,    4,    2,    2,    2,    4,    4,    6,    6,  /* 2 */
/* 3 */      2,    5,    2,    8,    4,    4,    6,    6,    2,    4,    2,    7,    4,    4,    7,    7,  /* 3 */
/* 4 */      6,    6,    2,    8,    3,    3,    5,    5,    3,    2,    2,    2,    3,    4,    6,    6,  /* 4 */
/* 5 */      2,    5,    2,    8,    4,    4,    6,    6,    2,    4,    2,    7,    4,    4,    7,    7,  /* 5 */
/* 6 */      6,    6,    2,    8,    3,    3,    5,    5,    4,    2,    2,    2,    5,    4,    6,    6,  /* 6 */
/* 7 */      2,    5,    2,    8,    4,    4,    6,    6,    2,    4,    2,    7,    4,    4,    7,    7,  /* 7 */
/* 8 */      2,    6,    2,    6,    3,    3,    3,    3,    2,    2,    2,    2,    4,    4,    4,    4,  /* 8 */
/* 9 */      2,    6,    2,    6,    4,    4,    4,    4,    2,    5,    2,    5,    5,    5,    5,    5,  /* 9 */
/* A */      2,    6,    2,    6,    3,    3,    3,    3,    2,    2,    2,    2,    4,    4,    4,    4,  /* A */
/* B */      2,    5,    2,    5,    4,    4,    4,    4,    2,    4,    2,    4,    4,    4,    4,    4,  /* B */
/* C */      2,    6,    2,    8,    3,    3,    5,    5,    2,    2,    2,    2,    4,    4,    6,    6,  /* C */
/* D */      2,    5,    2,    8,    4,    4,    6,    6,    2,    4,    2,    7,    4,    4,    7,    7,  /* D */
/* E */      2,    6,    2,    8,    3,    3,    5,    5,    2,    2,    2,    2,    4,    4,    6,    6,  /* E */
/* F */      2,    5,    2,    8,    4,    4,    6,    6,    2,    4,    2,    7,    4,    4,    7,    7   /* F */
};

/* ---- addressing mode functions (compute effective address into c->ea) ---- */
static void imp(Fake6502 *c) { (void)c; }
static void acc(Fake6502 *c) { (void)c; }

static void imm(Fake6502 *c) {
	c->ea = c->pc++;
}

static void zp(Fake6502 *c) { /* zero-page */
	c->ea = (uint16_t)c->read_cb(c, (uint16_t)c->pc++);
}

static void zpx(Fake6502 *c) { /* zero-page,X */
	c->ea = ((uint16_t)c->read_cb(c, (uint16_t)c->pc++) + (uint16_t)c->x) & 0xFF; /* zero-page wraparound */
}

static void zpy(Fake6502 *c) { /* zero-page,Y */
	c->ea = ((uint16_t)c->read_cb(c, (uint16_t)c->pc++) + (uint16_t)c->y) & 0xFF; /* zero-page wraparound */
}

static void rel(Fake6502 *c) { /* relative for branch ops (8-bit signed) */
	c->reladdr = (uint16_t)c->read_cb(c, c->pc++);
	if (c->reladdr & 0x80) c->reladdr |= 0xFF00;
}

static void abso(Fake6502 *c) { /* absolute */
	c->ea = (uint16_t)c->read_cb(c, c->pc) | ((uint16_t)c->read_cb(c, c->pc + 1) << 8);
	c->pc += 2;
}

static void absx(Fake6502 *c) { /* absolute,X */
	uint16_t startpage;
	c->ea = ((uint16_t)c->read_cb(c, c->pc) | ((uint16_t)c->read_cb(c, c->pc + 1) << 8));
	startpage = c->ea & 0xFF00;
	c->ea += (uint16_t)c->x;
	if (startpage != (c->ea & 0xFF00)) c->penaltyaddr = 1; /* page-cross penalty */
	c->pc += 2;
}

static void absy(Fake6502 *c) { /* absolute,Y */
	uint16_t startpage;
	c->ea = ((uint16_t)c->read_cb(c, c->pc) | ((uint16_t)c->read_cb(c, c->pc + 1) << 8));
	startpage = c->ea & 0xFF00;
	c->ea += (uint16_t)c->y;
	if (startpage != (c->ea & 0xFF00)) c->penaltyaddr = 1; /* page-cross penalty */
	c->pc += 2;
}

static void ind(Fake6502 *c) { /* indirect */
	uint16_t eahelp, eahelp2;
	eahelp = (uint16_t)c->read_cb(c, c->pc) | (uint16_t)((uint16_t)c->read_cb(c, c->pc + 1) << 8);
	eahelp2 = (eahelp & 0xFF00) | ((eahelp + 1) & 0x00FF); /* 6502 page-boundary wraparound bug */
	c->ea = (uint16_t)c->read_cb(c, eahelp) | ((uint16_t)c->read_cb(c, eahelp2) << 8);
	c->pc += 2;
}

static void indx(Fake6502 *c) { /* (indirect,X) */
	uint16_t eahelp;
	eahelp = (uint16_t)(((uint16_t)c->read_cb(c, c->pc++) + (uint16_t)c->x) & 0xFF); /* zp wraparound */
	c->ea = (uint16_t)c->read_cb(c, eahelp & 0x00FF) | ((uint16_t)c->read_cb(c, (eahelp + 1) & 0x00FF) << 8);
}

static void indy(Fake6502 *c) { /* (indirect),Y */
	uint16_t eahelp, eahelp2, startpage;
	eahelp = (uint16_t)c->read_cb(c, c->pc++);
	eahelp2 = (eahelp & 0xFF00) | ((eahelp + 1) & 0x00FF); /* zp wraparound */
	c->ea = (uint16_t)c->read_cb(c, eahelp) | ((uint16_t)c->read_cb(c, eahelp2) << 8);
	startpage = c->ea & 0xFF00;
	c->ea += (uint16_t)c->y;
	if (startpage != (c->ea & 0xFF00)) c->penaltyaddr = 1; /* page-cross penalty */
}

static uint16_t getvalue(Fake6502 *c) {
	if (addrtable[c->opcode] == acc) return (uint16_t)c->a;
	else return (uint16_t)c->read_cb(c, c->ea);
}

static void putvalue(Fake6502 *c, uint16_t saveval) {
	if (addrtable[c->opcode] == acc) c->a = (uint8_t)(saveval & 0x00FF);
	else c->write_cb(c, c->ea, (saveval & 0x00FF));
}

/* ---- instruction handlers ---- */
static void adc(Fake6502 *c) {
	c->penaltyop = 1;
	if (c->status & FK_FLAG_DECIMAL) {
		uint16_t AL, A, result_dec;
		A = c->a;
		c->value = getvalue(c);
		result_dec = (uint16_t)A + c->value + (uint16_t)(c->status & FK_FLAG_CARRY); /* dec */
		AL = (A & 0x0F) + (c->value & 0x0F) + (uint16_t)(c->status & FK_FLAG_CARRY);
		if (AL >= 0xA) AL = ((AL + 0x06) & 0x0F) + 0x10;
		A = (A & 0xF0) + (c->value & 0xF0) + AL;
		if (A & 0x80) FK_setsign(c); else FK_clearsign(c);
		if (A >= 0xA0) A += 0x60;
		c->result = A;
		if (A & 0xff80) FK_setoverflow(c); else FK_clearoverflow(c);
		if (A >= 0x100) FK_setcarry(c); else FK_clearcarry(c);
		FK_zerocalc(c, result_dec); /* NMOS does zerocalc on the binary result */
	} else {
		c->value = getvalue(c);
		c->result = (uint16_t)c->a + c->value + (uint16_t)(c->status & FK_FLAG_CARRY);
		FK_carrycalc(c, c->result);
		FK_zerocalc(c, c->result);
		FK_overflowcalc(c, c->result, c->a, c->value);
		FK_signcalc(c, c->result);
	}
	FK_saveaccum(c, c->result);
}

static void and_6502(Fake6502 *c) {
	c->penaltyop = 1;
	c->value = getvalue(c);
	c->result = (uint16_t)c->a & c->value;
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	FK_saveaccum(c, c->result);
}

static void asl(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = c->value << 1;
	FK_carrycalc(c, c->result);
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	putvalue(c, c->result);
}

static void bcc(Fake6502 *c) {
	if ((c->status & FK_FLAG_CARRY) == 0) {
		c->oldpc = c->pc;
		c->pc += c->reladdr;
		if ((c->oldpc & 0xFF00) != (c->pc & 0xFF00)) c->clockticks6502 += 2;
		else c->clockticks6502++;
	}
}

static void bcs(Fake6502 *c) {
	if ((c->status & FK_FLAG_CARRY) == FK_FLAG_CARRY) {
		c->oldpc = c->pc;
		c->pc += c->reladdr;
		if ((c->oldpc & 0xFF00) != (c->pc & 0xFF00)) c->clockticks6502 += 2;
		else c->clockticks6502++;
	}
}

static void beq(Fake6502 *c) {
	if ((c->status & FK_FLAG_ZERO) == FK_FLAG_ZERO) {
		c->oldpc = c->pc;
		c->pc += c->reladdr;
		if ((c->oldpc & 0xFF00) != (c->pc & 0xFF00)) c->clockticks6502 += 2;
		else c->clockticks6502++;
	}
}

static void bit(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = (uint16_t)c->a & c->value;
	FK_zerocalc(c, c->result);
	c->status = (c->status & 0x3F) | (uint8_t)(c->value & 0xC0);
}

static void bmi(Fake6502 *c) {
	if ((c->status & FK_FLAG_SIGN) == FK_FLAG_SIGN) {
		c->oldpc = c->pc;
		c->pc += c->reladdr;
		if ((c->oldpc & 0xFF00) != (c->pc & 0xFF00)) c->clockticks6502 += 2;
		else c->clockticks6502++;
	}
}

static void bne(Fake6502 *c) {
	if ((c->status & FK_FLAG_ZERO) == 0) {
		c->oldpc = c->pc;
		c->pc += c->reladdr;
		if ((c->oldpc & 0xFF00) != (c->pc & 0xFF00)) c->clockticks6502 += 2;
		else c->clockticks6502++;
	}
}

static void bpl(Fake6502 *c) {
	if ((c->status & FK_FLAG_SIGN) == 0) {
		c->oldpc = c->pc;
		c->pc += c->reladdr;
		if ((c->oldpc & 0xFF00) != (c->pc & 0xFF00)) c->clockticks6502 += 2;
		else c->clockticks6502++;
	}
}

static void brk_6502(Fake6502 *c) {
	c->pc++;
	fk_push16(c, c->pc);
	fk_push8(c, c->status | FK_FLAG_BREAK);
	FK_setinterrupt(c);
	c->pc = (uint16_t)c->read_cb(c, 0xFFFE) | ((uint16_t)c->read_cb(c, 0xFFFF) << 8);
}

static void bvc(Fake6502 *c) {
	if ((c->status & FK_FLAG_OVERFLOW) == 0) {
		c->oldpc = c->pc;
		c->pc += c->reladdr;
		if ((c->oldpc & 0xFF00) != (c->pc & 0xFF00)) c->clockticks6502 += 2;
		else c->clockticks6502++;
	}
}

static void bvs(Fake6502 *c) {
	if ((c->status & FK_FLAG_OVERFLOW) == FK_FLAG_OVERFLOW) {
		c->oldpc = c->pc;
		c->pc += c->reladdr;
		if ((c->oldpc & 0xFF00) != (c->pc & 0xFF00)) c->clockticks6502 += 2;
		else c->clockticks6502++;
	}
}

static void clc(Fake6502 *c) { FK_clearcarry(c); }
static void cld(Fake6502 *c) { FK_cleardecimal(c); }
static void cli(Fake6502 *c) { FK_clearinterrupt(c); }
static void clv(Fake6502 *c) { FK_clearoverflow(c); }

static void cmp(Fake6502 *c) {
	c->penaltyop = 1;
	c->value = getvalue(c);
	c->result = (uint16_t)c->a - c->value;
	if (c->a >= (uint8_t)(c->value & 0x00FF)) FK_setcarry(c); else FK_clearcarry(c);
	if (c->a == (uint8_t)(c->value & 0x00FF)) FK_setzero(c); else FK_clearzero(c);
	FK_signcalc(c, c->result);
}

static void cpx(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = (uint16_t)c->x - c->value;
	if (c->x >= (uint8_t)(c->value & 0x00FF)) FK_setcarry(c); else FK_clearcarry(c);
	if (c->x == (uint8_t)(c->value & 0x00FF)) FK_setzero(c); else FK_clearzero(c);
	FK_signcalc(c, c->result);
}

static void cpy(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = (uint16_t)c->y - c->value;
	if (c->y >= (uint8_t)(c->value & 0x00FF)) FK_setcarry(c); else FK_clearcarry(c);
	if (c->y == (uint8_t)(c->value & 0x00FF)) FK_setzero(c); else FK_clearzero(c);
	FK_signcalc(c, c->result);
}

static void dec(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = c->value - 1;
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	putvalue(c, c->result);
}

static void dex(Fake6502 *c) { c->x--; FK_zerocalc(c, c->x); FK_signcalc(c, c->x); }
static void dey(Fake6502 *c) { c->y--; FK_zerocalc(c, c->y); FK_signcalc(c, c->y); }

static void eor(Fake6502 *c) {
	c->penaltyop = 1;
	c->value = getvalue(c);
	c->result = (uint16_t)c->a ^ c->value;
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	FK_saveaccum(c, c->result);
}

static void inc(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = c->value + 1;
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	putvalue(c, c->result);
}

static void inx(Fake6502 *c) { c->x++; FK_zerocalc(c, c->x); FK_signcalc(c, c->x); }
static void iny(Fake6502 *c) { c->y++; FK_zerocalc(c, c->y); FK_signcalc(c, c->y); }

static void jmp(Fake6502 *c) { c->pc = c->ea; }

static void jsr(Fake6502 *c) {
	fk_push16(c, c->pc - 1);
	c->pc = c->ea;
}

static void lda(Fake6502 *c) {
	c->penaltyop = 1;
	c->value = getvalue(c);
	c->a = (uint8_t)(c->value & 0x00FF);
	FK_zerocalc(c, c->a);
	FK_signcalc(c, c->a);
}

static void ldx(Fake6502 *c) {
	c->penaltyop = 1;
	c->value = getvalue(c);
	c->x = (uint8_t)(c->value & 0x00FF);
	FK_zerocalc(c, c->x);
	FK_signcalc(c, c->x);
}

static void ldy(Fake6502 *c) {
	c->penaltyop = 1;
	c->value = getvalue(c);
	c->y = (uint8_t)(c->value & 0x00FF);
	FK_zerocalc(c, c->y);
	FK_signcalc(c, c->y);
}

static void lsr(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = c->value >> 1;
	if (c->value & 1) FK_setcarry(c); else FK_clearcarry(c);
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	putvalue(c, c->result);
}

static void nop(Fake6502 *c) {
	switch (c->opcode) {
		case 0x1C:
		case 0x3C:
		case 0x5C:
		case 0x7C:
		case 0xDC:
		case 0xFC:
			c->penaltyop = 1;
			break;
	}
}

static void ora(Fake6502 *c) {
	c->penaltyop = 1;
	c->value = getvalue(c);
	c->result = (uint16_t)c->a | c->value;
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	FK_saveaccum(c, c->result);
}

static void pha(Fake6502 *c) { fk_push8(c, c->a); }
static void php(Fake6502 *c) { fk_push8(c, c->status | FK_FLAG_BREAK); }

static void pla(Fake6502 *c) {
	c->a = fk_pull8(c);
	FK_zerocalc(c, c->a);
	FK_signcalc(c, c->a);
}

static void plp(Fake6502 *c) {
	c->status = fk_pull8(c) | FK_FLAG_CONSTANT;
}

static void rol(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = (c->value << 1) | (c->status & FK_FLAG_CARRY);
	FK_carrycalc(c, c->result);
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	putvalue(c, c->result);
}

static void ror(Fake6502 *c) {
	c->value = getvalue(c);
	c->result = (c->value >> 1) | ((c->status & FK_FLAG_CARRY) << 7);
	if (c->value & 1) FK_setcarry(c); else FK_clearcarry(c);
	FK_zerocalc(c, c->result);
	FK_signcalc(c, c->result);
	putvalue(c, c->result);
}

static void rti(Fake6502 *c) {
	c->status = fk_pull8(c);
	c->value = fk_pull16(c);
	c->pc = c->value;
}

static void rts(Fake6502 *c) {
	c->value = fk_pull16(c);
	c->pc = c->value + 1;
}

static void sbc(Fake6502 *c) {
	c->penaltyop = 1;
	if (c->status & FK_FLAG_DECIMAL) {
		uint16_t result_dec, A, AL, B, C;
		A = c->a;
		C = (uint16_t)(c->status & FK_FLAG_CARRY);
		c->value = getvalue(c); B = c->value; c->value = c->value ^ 0x00FF;
		result_dec = (uint16_t)c->a + c->value + (uint16_t)(c->status & FK_FLAG_CARRY); /* dec */
		/* Both CMOS and NMOS */
		FK_carrycalc(c, result_dec);
		FK_overflowcalc(c, result_dec, c->a, c->value);
		/* NMOS only */
		FK_signcalc(c, result_dec);
		FK_zerocalc(c, result_dec);
		/* Sequence 3 is NMOS only */
		AL = (A & 0x0F) - (B & 0x0F) + C - 1;
		if (AL & 0x8000) AL = ((AL - 0x06) & 0x0F) - 0x10;
		A = (A & 0xF0) - (B & 0xF0) + AL;
		if (A & 0x8000) A = A - 0x60;
		c->result = A;
	} else {
		c->value = getvalue(c) ^ 0x00FF;
		c->result = (uint16_t)c->a + c->value + (uint16_t)(c->status & FK_FLAG_CARRY);
		FK_carrycalc(c, c->result);
		FK_zerocalc(c, c->result);
		FK_overflowcalc(c, c->result, c->a, c->value);
		FK_signcalc(c, c->result);
	}
	FK_saveaccum(c, c->result);
}

static void sec(Fake6502 *c) { FK_setcarry(c); }
static void sed(Fake6502 *c) { FK_setdecimal(c); }
static void sei(Fake6502 *c) { FK_setinterrupt(c); }

static void sta(Fake6502 *c) { putvalue(c, c->a); }
static void stx(Fake6502 *c) { putvalue(c, c->x); }
static void sty(Fake6502 *c) { putvalue(c, c->y); }

static void tax(Fake6502 *c) { c->x = c->a; FK_zerocalc(c, c->x); FK_signcalc(c, c->x); }
static void tay(Fake6502 *c) { c->y = c->a; FK_zerocalc(c, c->y); FK_signcalc(c, c->y); }
static void tsx(Fake6502 *c) { c->x = c->sp; FK_zerocalc(c, c->x); FK_signcalc(c, c->x); }
static void txa(Fake6502 *c) { c->a = c->x; FK_zerocalc(c, c->a); FK_signcalc(c, c->a); }
static void txs(Fake6502 *c) { c->sp = c->x; }
static void tya(Fake6502 *c) { c->a = c->y; FK_zerocalc(c, c->a); FK_signcalc(c, c->a); }

/* ---- undocumented / illegal opcodes ---- */
static void lax(Fake6502 *c) { lda(c); ldx(c); }

static void sax(Fake6502 *c) {
	sta(c); stx(c);
	putvalue(c, c->a & c->x);
	if (c->penaltyop && c->penaltyaddr) c->clockticks6502--;
}

static void dcp(Fake6502 *c) {
	dec(c); cmp(c);
	if (c->penaltyop && c->penaltyaddr) c->clockticks6502--;
}

static void isb(Fake6502 *c) {
	inc(c); sbc(c);
	if (c->penaltyop && c->penaltyaddr) c->clockticks6502--;
}

static void slo(Fake6502 *c) {
	asl(c); ora(c);
	if (c->penaltyop && c->penaltyaddr) c->clockticks6502--;
}

static void rla(Fake6502 *c) {
	rol(c); and_6502(c);
	if (c->penaltyop && c->penaltyaddr) c->clockticks6502--;
}

static void sre(Fake6502 *c) {
	lsr(c); eor(c);
	if (c->penaltyop && c->penaltyaddr) c->clockticks6502--;
}

static void rra(Fake6502 *c) {
	ror(c); adc(c);
	if (c->penaltyop && c->penaltyaddr) c->clockticks6502--;
}

/* ---- public API (reentrant; pass the same Fake6502* every call) ---- */
static void fake6502_reset(Fake6502 *c) {
	/* Faithful to upstream: reads a few dummy addresses, then loads the reset
	   vector. Callers must zero the struct and set read_cb/write_cb first. */
	c->read_cb(c, 0x00ff);
	c->read_cb(c, 0x00ff);
	c->read_cb(c, 0x00ff);
	c->read_cb(c, 0x0100);
	c->read_cb(c, 0x01ff);
	c->read_cb(c, 0x01fe);
	c->pc = fk_mem_read16(c, 0xfffc);
	c->sp = 0xfd;
	c->status |= FK_FLAG_CONSTANT | FK_FLAG_INTERRUPT;
}

static void fake6502_nmi(Fake6502 *c) {
	fk_push16(c, c->pc);
	fk_push8(c, c->status & ~FK_FLAG_BREAK);
	c->status |= FK_FLAG_INTERRUPT;
	c->pc = (uint16_t)c->read_cb(c, 0xFFFA) | ((uint16_t)c->read_cb(c, 0xFFFB) << 8);
}

static void fake6502_irq(Fake6502 *c) {
	if ((c->status & FK_FLAG_INTERRUPT) == 0) {
		fk_push16(c, c->pc);
		fk_push8(c, c->status & ~FK_FLAG_BREAK);
		c->status |= FK_FLAG_INTERRUPT;
		c->pc = (uint16_t)c->read_cb(c, 0xFFFE) | ((uint16_t)c->read_cb(c, 0xFFFF) << 8);
	}
}

static uint32_t fake6502_exec(Fake6502 *c, uint32_t tickcount) {
	/* clockticks6502 is reset every call to avoid the 32-bit overflow hang that
	   the original had when a single instruction pushed the running total high. */
	c->clockgoal6502 = tickcount;
	c->clockticks6502 = 0;
	while (c->clockticks6502 < c->clockgoal6502) {
		c->opcode = c->read_cb(c, c->pc++);
		c->status |= FK_FLAG_CONSTANT;
		c->penaltyop = 0;
		c->penaltyaddr = 0;
		(*addrtable[c->opcode])(c);
		(*optable[c->opcode])(c);
		c->clockticks6502 += ticktable[c->opcode];
		if (c->penaltyop && c->penaltyaddr) { c->clockticks6502++; }
		c->instructions++;
		if (c->callexternal) (*c->loopexternal)(c);
	}
	return c->clockticks6502;
}

static uint32_t fake6502_step(Fake6502 *c) {
	c->opcode = c->read_cb(c, c->pc++);
	c->status |= FK_FLAG_CONSTANT;
	c->penaltyop = 0;
	c->penaltyaddr = 0;
	c->clockticks6502 = 0;
	(*addrtable[c->opcode])(c);
	(*optable[c->opcode])(c);
	c->clockticks6502 += ticktable[c->opcode];
	if (c->penaltyop && c->penaltyaddr) c->clockticks6502++;
	c->instructions++;
	if (c->callexternal) (*c->loopexternal)(c);
	return c->clockticks6502;
}

static void fake6502_hookexternal(Fake6502 *c, void (*funcptr)(Fake6502 *)) {
	if (funcptr != nullptr) {
		c->loopexternal = funcptr;
		c->callexternal = 1;
	} else {
		c->callexternal = 0;
	}
}

/* keep internal helper macros out of the including translation unit */
#undef FK_saveaccum
#undef FK_setcarry
#undef FK_clearcarry
#undef FK_setzero
#undef FK_clearzero
#undef FK_setinterrupt
#undef FK_clearinterrupt
#undef FK_setdecimal
#undef FK_cleardecimal
#undef FK_setoverflow
#undef FK_clearoverflow
#undef FK_setsign
#undef FK_clearsign
#undef FK_zerocalc
#undef FK_signcalc
#undef FK_carrycalc
#undef FK_overflowcalc

#endif /* VG_FAKE6502_CTX_H */
