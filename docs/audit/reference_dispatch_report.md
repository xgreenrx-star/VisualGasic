# Reference dispatch audit report

Generated: 2026-09-08 by `scripts/audit_reference_dispatch.py`

## Summary

| Metric | Count |
|--------|------:|
| Language Reference commands (Part II) | 445 |
| GODOT_FUNCTIONS_REFERENCE entries | 64 |
| command_help entries | 446 |
| OK / dispatch found | 773 |
| Known gaps (allowlisted) | 19 |
| **Missing dispatch** | **0** |
| Doc source mismatch | 0 |

## Known gaps (allowlisted)

- **ConnectSignal** — Deprecated name; runtime uses Connect()
- **ConnectSignal** — Deprecated name; runtime uses Connect()
- **DataFile** — Parse-time DATA statement — not a runtime call_builtin
- **DataFile** — Parse-time DATA statement — not a runtime call_builtin
- **DisconnectSignal** — Deprecated name; runtime uses Disconnect()
- **DisconnectSignal** — Deprecated name; runtime uses Disconnect()
- **emit_signal** — Use emit_signal() on owner or RaiseEvent for VB events
- **EmitSignal** — Use emit_signal() on owner or RaiseEvent for VB events
- **Interface** — Interface...End Interface not parsed (Implements works)
- **Interface** — Interface...End Interface not parsed (Implements works)
- **LoadData** — Runtime statement (STMT_LOAD_DATA) — not a global call_builtin
- **LoadData** — Runtime statement (STMT_LOAD_DATA) — not a global call_builtin
- **shutdown** — PyBridgeFacade.shutdown() instance method — not a global builtin
- **Speaker.Bus** — Speaker.Bus is compile-time alias for Speaker namespace
- **Speaker.Bus** — Speaker.Bus is compile-time alias for Speaker namespace
- **Sprite Data** — Sprite Data asset docs — IDE/context rail feature; not a global builtin
- **Sprite Data** — Sprite Data asset docs — IDE/context rail feature; not a global builtin
- **Using** — Using...End Using not parsed or executed
- **Using** — Using...End Using not parsed or executed

## How to run

```bash
python3 scripts/audit_reference_dispatch.py
python3 scripts/audit_reference_dispatch.py --write-report
```
