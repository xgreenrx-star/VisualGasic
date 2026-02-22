# VisualGasic v2.9.0 Release Notes

## System-Level Features — "From Game Engine to App Platform"

**Release Date**: 2025-07-14

This release adds **8 new C++ GDExtension classes** that bring system-level programming capabilities to VisualGasic, closing the gap between Godot's game-focused architecture and the real-world needs of VB6 application developers.

---

## 🆕 New Features

### Tier 1: Critical (Must-Have for Real Apps)

#### 1. VGProcess — Shell & Process Management
- `Shell()` built-in function returns PID (classic VB6 behavior)
- `New Process` with `Start()`, `Terminate()`, `WaitForExit()`
- Stdin/stdout/stderr piping with `WriteStdin()`, `ReadStdout()`, `ReadStderr()`
- Static `RunAndCapture()` and `RunWithStatus()` for one-liner execution
- Full VB6 PascalCase method aliases

#### 2. VGDatabase — SQLite Database Access
- Dynamic `libsqlite3.so` loading via dlopen (no compile-time dependency)
- `Open()`, `Close()`, `Execute()`, `Query()` with full result sets
- Parameterized queries: `ExecuteParams()`, `QueryParams()` (SQL injection safe)
- Transaction support: `BeginTransaction()`, `Commit()`, `Rollback()`
- Schema introspection: `TableExists()`, `GetTables()`
- `IsSQLiteAvailable()` built-in function

#### 3. VGSocket — WinSock-Style TCP/UDP Sockets
- POSIX socket wrapper with VB6 WinSock control API
- TCP: `Connect()`, `Listen()`, `Accept()`, `Send()`, `Receive()`
- UDP: `Bind()`, `SendTo()`
- Protocol enum: `TCP` / `UDP`

#### 4. VGSettings — VB6 Registry-Style Settings API
- `SaveSetting()` / `GetSetting()` / `DeleteSetting()` / `GetAllSettings()` built-in functions
- INI-file backend at `~/.config/visualgasic/settings.ini`
- Identical API to VB6's `SaveSetting(appname, section, key, value)`

### Tier 2: Important (Professional Features)

#### 5. VGFileWatcher — FileSystemWatcher
- inotify-based file/directory monitoring
- Configurable `Path`, `Filter`, `IncludeSubdirectories`
- `PollChanges()` returns array of `{action, path}` events
- `EnableRaisingEvents` property to start/stop watching

#### 6. VGCommonDialog — File/Color/Font Dialogs
- `ShowOpen()`, `ShowSave()`, `ShowColor()`, `ShowFolder()`
- Full VB6 CommonDialog property set: `FileName`, `Filter`, `InitDir`, `DialogTitle`, `MultiSelect`
- Font properties: `FontName`, `FontSize`, `FontBold`
- Uses zenity on Linux for native dialog display

#### 7. VGSysTray — System Tray Notifications
- `Icon`, `Tooltip`, `Visible` properties
- `ShowBalloon()` for toast notifications (via notify-send on Linux)
- Menu support: `AddMenuItem()`, `RemoveMenuItem()`, `ClearMenu()`

### Tier 3: VB6 Compatibility

#### 8. VGComInterop — COM Object Emulation
- `CreateObject()` built-in function (classic VB6 late binding)
- **Scripting.Dictionary**: Full implementation with `Add`, `Item`, `Exists`, `Remove`, `Keys`, `Items`, `CompareMode`
- **Scripting.FileSystemObject**: `FileExists`, `FolderExists`, `CopyFile`, `DeleteFile`, `MoveFile`, `ReadAll`, `WriteAll`, `CreateFolder`, and more
- **WScript.Shell**: `Run`, `ExpandEnvironmentStrings`, `CurrentDirectory`, `Environment`

---

## 🔧 Technical Improvements

### VB6 PascalCase Method Aliases
All 8 new classes register both `snake_case` (GDScript convention) and `PascalCase` (VB6 convention) method names. VB6 code calls `dict.Item("key")` or `proc.Start("cmd")` naturally.

### Bytecode VM Class Aliases
The bytecode VM (primary execution path) now maps VB6-friendly class names to internal GDExtension classes:
- `Process` → `VGProcess`
- `Database` → `VGDatabase`
- `WinSock` → `VGSocket`
- `FileSystemWatcher` → `VGFileWatcher`
- `CommonDialog` → `VGCommonDialog`
- `SysTray` → `VGSysTray`
- `Settings` → `VGSettings`
- `FileSystemObject` → `VGFileSystemObject`
- `ScriptingDictionary` → `VGScriptingDict`
- `WScriptShell` → `VGWScriptShell`
- `ComInterop` → `VGComInterop`

### Parser Enhancement
`Dim x As New ClassName` syntax now supported (creates object at declaration time).

### Static Object Crash Fix
Fixed signal 11 crash caused by static `Dictionary` member initialization before GDExtension API. Now uses lazy pointer initialization pattern.

### Dual Dispatch Path
All new built-in functions registered in both `call_builtin_expr` (AST tree-walker) and `call_builtin_expr_evaluated` (bytecode VM) to ensure they work regardless of execution path.

---

## 📊 Test Results

| Test Suite | Result |
|---|---|
| System Features (new) | **20/20 PASS** |
| Integration Tests | **20/20 PASS** |
| Builtin Unit Tests | **2/3 PASS** (03_array pre-existing) |

### System Features Test Coverage
- ✅ `Environ()` / `Environ$()`
- ✅ `SaveSetting()` / `GetSetting()` / `DeleteSetting()`
- ✅ `New Process`, `Shell()`, `RunAndCapture()`
- ✅ `IsSQLiteAvailable()`, `New Database`, in-memory SQLite queries
- ✅ `New WinSock`, UDP `Bind(0)`
- ✅ `New FileSystemWatcher`, `New CommonDialog`
- ✅ `CreateObject("Scripting.Dictionary")` with `Add`, `Item`, `Exists`, `Remove`

---

## 📦 New Files (16 source files)

```
src/visual_gasic_process.h          src/visual_gasic_process.cpp
src/visual_gasic_database.h         src/visual_gasic_database.cpp
src/visual_gasic_socket.h           src/visual_gasic_socket.cpp
src/visual_gasic_fswatcher.h        src/visual_gasic_fswatcher.cpp
src/visual_gasic_common_dialog.h    src/visual_gasic_common_dialog.cpp
src/visual_gasic_systray.h          src/visual_gasic_systray.cpp
src/visual_gasic_settings.h         src/visual_gasic_settings.cpp
src/visual_gasic_com_interop.h      src/visual_gasic_com_interop.cpp
```

## 📦 Modified Files
- `src/register_types.cpp` — 12 new class registrations
- `src/visual_gasic_builtins.cpp` — 8 new built-in functions (both dispatch paths)
- `src/visual_gasic_instance.cpp` — VB6 class aliases in AST interpreter
- `src/visual_gasic_instance_bytecode_vm.cpp` — VB6 class aliases in bytecode VM
- `src/visual_gasic_parser.cpp` — `Dim As New` syntax support

---

## ⬆️ Upgrade Notes

- **No breaking changes** — all existing VB6 scripts continue to work
- SQLite requires `libsqlite3.so.0` on the system (standard on most Linux distros)
- File dialogs require `zenity` for Linux (fallback to empty string if unavailable)
- System tray notifications require `notify-send` (standard with libnotify)

## 🏗️ Build

```bash
scons platform=linux target=template_debug -j4
```
