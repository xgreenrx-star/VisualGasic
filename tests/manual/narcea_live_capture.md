# Manual QA — Narcea Live Debug Capture

1. Project Settings → **Vg → Narcea** → enable **live_debug_capture**.
2. Open **AI Pair** → enable **Live debug capture (this run)** → accept consent → confirm orange banner.
3. Run sample (e.g. `samples/apps/vg_hex_editor`) with F5.
4. Set breakpoint in `.vg` → break → confirm **Immediate** chip shows frame count ≥ 1.
5. **Explain screen** in AI Pair → response references stack/UI metadata; vision models get PNG when supported.
6. **Clear capture** → frame count 0; game still running.
7. Stop game → capture OFF, buffer empty, `user://vg_narcea_live_session/` removed if created.
8. MCP (optional): `narcea_live_list_snapshots` on `127.0.0.1:8766`.
