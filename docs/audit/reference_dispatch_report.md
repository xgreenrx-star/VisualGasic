# Reference dispatch audit report

Generated: 2026-09-08 by `scripts/audit_reference_dispatch.py`

## Summary

| Metric | Count |
|--------|------:|
| Language Reference commands (Part II) | 445 |
| GODOT_FUNCTIONS_REFERENCE entries | 64 |
| command_help entries | 405 |
| OK / dispatch found | 740 |
| Known gaps (allowlisted) | 17 |
| **Missing dispatch** | **0** |
| Doc source mismatch | 40 |

## Doc source mismatches

- **AudioServer** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **ConnectSignal** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **Deg2Rad** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **DisconnectSignal** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **DisplayServer** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **Engine** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **FindChild** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetActionStrength** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetChildren** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetCurrentScene** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetEngineVersion** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetGlobalPosition** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetKey** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetLastMouseVelocity** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetModulate** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetMousePosition** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetPosition** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetRoot** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetRotation** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetScale** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **GetVelocity** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **HasNode** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **IsEditorHint** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **IsMouseButtonPressed** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **IsOnCeiling** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **IsVisible** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **LoadScene** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **MoveAndCollide** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **MoveToward** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **OS** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **Rad2Deg** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **ReloadCurrentScene** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **SetGlobalPosition** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **SetModulate** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **SetPosition** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **SetRotation** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **SetScale** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **SetVelocity** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **SetVisible** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help
- **Time** — in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help

## Known gaps (allowlisted)

- **ConnectSignal** — Deprecated name; runtime uses Connect()
- **DataFile** — Parse-time DATA statement — not a runtime call_builtin
- **DataFile** — Parse-time DATA statement — not a runtime call_builtin
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
