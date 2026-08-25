# Facebook post — compute + draw performance (Aug 2026)

Facebook does not render markdown tables. Copy the **PLAIN TEXT** block below directly into your post.

---

## COPY FROM HERE (plain text for Facebook)

Visual Gasic isn't just readable — it's fast.

We beat GDScript on every published compute and draw benchmark — including FunctionCall. Shipping as **v5.4.0-beta1** this weekend (road to **VG6** stable in 2027).

Same VB6-style language. Same Godot 4.6. Code you can audit — without paying a GDScript tax.

━━━━━━━━━━━━━━━━━━━━
COMPUTE (12 tests)
Lower microseconds = faster. Same work, verified by checksums.
━━━━━━━━━━━━━━━━━━━━

✅ Arithmetic — GD 8,864 µs → VG 52 µs (170× faster)
✅ ArraySum — GD 7,096 µs → VG 235 µs (30× faster)
✅ StringConcat — GD 8,262 µs → VG 184 µs (45× faster)
✅ Branching — GD 11,450 µs → VG 150 µs (76× faster)
✅ FunctionCall — GD 8,923 µs → VG 165 µs (54× faster)
✅ ArrayDict — GD 19,426 µs → VG 4,558 µs (4.3× faster)
✅ DictFastGet — GD 49,235 µs → VG 3,026 µs (16× faster)
✅ DictFastSet — GD 34,536 µs → VG 3,621 µs (9.5× faster)
✅ Interop — GD 13,097 µs → VG 282 µs (46× faster)
✅ Allocations — GD 11,042 µs → VG 304 µs (36× faster)
✅ AllocationsFast — GD 15,563 µs → VG 2,282 µs (6.8× faster)
✅ FileIO — GD 1,654 µs → VG 993 µs (1.7× faster)

12/12 compute: Visual Gasic wins.

FunctionCall was the last gap — pure Sub/Function call overhead. The compiler now inlines trivial helpers and fuses nested call loops instead of dispatching through the VM 50,000 times.

━━━━━━━━━━━━━━━━━━━━
CANVAS DRAW (9 workloads)
Time inside _draw per frame.
━━━━━━━━━━━━━━━━━━━━

✅ FilledRects ×2500 — GD 967 µs → VG 123 µs (7.9× faster)
✅ OutlineRects ×2500 — GD 2,876 µs → VG 479 µs (6× faster)
✅ Lines ×2000 — GD 733 µs → VG 280 µs (2.6× faster)
✅ Circles ×1500 — GD 3,429 µs → VG 1,832 µs (1.9× faster)
✅ Sprites ×2000 — GD 1,289 µs → VG 365 µs (3.5× faster)
✅ Polylines ×800 — GD 2,089 µs → VG 1,123 µs (1.9× faster)
✅ Mixed ×2500 — GD 6,991 µs → VG 3,327 µs (2.1× faster)
✅ VectorCanvas batch ×2500 — GD 1,841 µs → VG 271 µs (6.8× faster)
✅ Moving rects (avg/frame) — GD 148 µs → VG 37 µs (4× faster)

9/9 draw: Visual Gasic wins.

Draw used to lag behind. Grid-loop fusion compiles hot _Draw tile loops to native C++ — no per-primitive VM tax.

Coming this weekend: draw fusion, call inlining, published benchmark docs, and a CI gate so we don't silently regress.

Open source · Godot GDExtension
https://github.com/xgreenrx-star/VisualGasic

## STOP COPYING HERE

---

## Shorter version (if character limit bites)

Visual Gasic — fast AND readable. We beat GDScript on all 12 compute microbenchmarks (up to 170× on arithmetic) and all 9 canvas draw tests (up to 7.9× on filled rects). FunctionCall — our old weak spot — is now 54× faster. Shipping this weekend.

Compute: Arithmetic 170×, Branching 76×, FunctionCall 54×, StringConcat 45×, Interop 46×, + 7 more.

Draw: FilledRects 7.9×, VectorCanvas 6.8×, Moving rects 4×, Mixed 2.1×, + 5 more.

VB6-style BASIC for Godot 4.6. Open source.
https://github.com/xgreenrx-star/VisualGasic
