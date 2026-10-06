# Reference dispatch audit report

Generated: 2026-10-05 by `scripts/audit_reference_dispatch.py`

## Summary

| Metric | Count |
|--------|------:|
| Language Reference commands (Part II) | 461 |
| GODOT_FUNCTIONS_REFERENCE entries | 64 |
| command_help entries | 474 |
| OK / dispatch found | 799 |
| Known gaps (allowlisted) | 19 |
| **Missing dispatch** | **16** |
| Doc source mismatch | 0 |

## Missing dispatch (action required)

- **Autoload** — documented but no dispatch site in src/
  - language_reference:4047
- **CIRCLE (QuickBASIC)** — documented but no dispatch site in src/
  - language_reference:6364
- **GET (QB)** — documented but no dispatch site in src/
  - command_help:2124
- **GET (QuickBASIC graphics)** — documented but no dispatch site in src/
  - language_reference:7310
- **LINE (QuickBASIC graphics)** — documented but no dispatch site in src/
  - language_reference:8944
- **PAINT (QuickBASIC)** — documented but no dispatch site in src/
  - language_reference:10137
- **PLAY (QB)** — documented but no dispatch site in src/
  - command_help:2139
- **PLAY (QuickBASIC)** — documented but no dispatch site in src/
  - language_reference:10149
- **Point (QB)** — documented but no dispatch site in src/
  - command_help:2144
- **Point (QuickBASIC)** — documented but no dispatch site in src/
  - language_reference:10192
- **PUT (QB)** — documented but no dispatch site in src/
  - command_help:2129
- **PUT (QuickBASIC graphics)** — documented but no dispatch site in src/
  - language_reference:10321
- **SCREEN (QuickBASIC)** — documented but no dispatch site in src/
  - language_reference:11440
- **ScreenBox** — documented but no dispatch site in src/
  - command_help:2049
- **ScreenMode** — documented but no dispatch site in src/
  - command_help:2059
- **Vector Data** — documented but no dispatch site in src/
  - command_help:568

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
