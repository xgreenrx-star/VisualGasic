# VisualGasic System Integration Reference

Complete reference for system-level integration features.  
VisualGasic includes C#-class integration: native FFI, ODBC databases, cryptography,
XML, ZIP, async threading, and package management.  
System-level programming includes: system info, OS signals, file permissions,
raw memory, IPC, real threading, and an Android JNI bridge.

---

## Table of Contents

1. [Native Library / FFI](#1-native-library--ffi)
2. [ODBC Database](#2-odbc-database)
3. [Cryptography (VGCrypto)](#3-cryptography-vgcrypto)
4. [XML Processing (VGXml)](#4-xml-processing-vgxml)
5. [ZIP Archives (VGZip)](#5-zip-archives-vgzip)
6. [Async Tasks (VGTask / VGTaskRunner)](#6-async-tasks-vgtask--vgtaskrunner)
7. [Package Manager](#7-package-manager)
8. [Cross-Platform System Calls](#8-cross-platform-system-calls)
9. [Real COM Interop (Windows)](#9-real-com-interop-windows)
10. [VGSystem (System Info)](#10-vgsystem-system-info)
11. [VGSignalHandler (OS Signals)](#11-vgsignalhandler-os-signals)
12. [VGFilePermissions (Permissions & Links)](#12-vgfilepermissions-permissions--links)
13. [VGMemoryBuffer (Raw Memory)](#13-vgmemorybuffer-raw-memory)
14. [VGIPC (Inter-Process Communication)](#14-vgipc-inter-process-communication)
15. [VGAndroidBridge (Android Platform)](#15-vgandroidbridge-android-platform)
16. [Real Threading](#16-real-threading)
17. [Python Bridge (PyBridgeFacade)](#17-python-bridge-pybridgefacade)

---

## 1. Native Library / FFI

Load any `.so`, `.dll`, or `.dylib` and call its C functions directly from
Basic — the equivalent of VB6's `Declare Function` but cross-platform and
powered by **libffi**.

### Classes

| Class | Description |
|-------|-------------|
| `NativeLibrary` | Loads a shared library, calls functions |
| `NativeStruct` | Describes C struct layouts, allocates instances |

### Quick Start

```vb
Dim lib As Object
Set lib = New NativeLibrary

' Load the C math library
lib.Load "libm.so.6"               ' Linux
' lib.Load "libm.dylib"            ' macOS
' lib.Load "msvcrt.dll"            ' Windows

' Call sqrt(144)  →  12.0
Dim result As Variant
result = lib.CallFunction("sqrt", "double", Array("double"), Array(144.0))
Print "sqrt(144) = " & CStr(result)

' Full signature call:  double sqrt(double)
Dim argTypes As Array
argTypes = Array("double")
result = lib.CallFunction("sqrt", "double", argTypes, Array(25.0))
Print "sqrt(25) = " & CStr(result)

lib.Unload
```

### Working with C Structs

```vb
Dim s As Object
Set s = New NativeStruct

' Define:  struct Point { int x; int y; }
s.AddField "x", "int"
s.AddField "y", "int"

Print "Size: " & CStr(s.Size) & " bytes"   ' 8

' Allocate and use
Dim h As Integer
h = s.Create()
s.SetField h, "x", 100
s.SetField h, "y", 200
Print "x=" & CStr(s.GetField(h, "x"))      ' 100
s.Destroy h
```

### Supported FFI Types

`void`, `int`, `uint`, `long`, `ulong`, `float`, `double`, `pointer`, `string`,
`int8`, `uint8`, `int16`, `uint16`, `int32`, `uint32`, `int64`, `uint64`

### NativeLibrary Methods

| Method | Description |
|--------|-------------|
| `Load(path)` | Load a shared library. Returns `True` on success |
| `Unload()` | Unload the library |
| `QuickCall(name, ...)` | Convenience alias for simple calls; prefer `CallFunction(...)` when the return type matters |
| `CallFunction(name, returnType, argTypes, args)` | Full-signature call |
| `CallSimple(name, args)` | Array-based call |
| `CreateCallback(callable, returnType, argTypes)` | Create a C callback pointing to a VG Callable |
| `.IsLoaded` | Property — whether a library is loaded |
| `.Path` | Property — loaded library path |
| `.LastError` | Property — last error message |

---

## 2. ODBC Database

Connect to **any** database that has an ODBC driver — PostgreSQL, MySQL,
SQL Server, Oracle, SQLite, and more. Dynamically loads the ODBC library at
runtime so no compile-time dependency is required.

### Quick Start

```vb
Dim db As Object
Set db = New VGOdbc

db.ConnectionString = "Driver={PostgreSQL};Server=localhost;Database=myapp;Uid=admin;Pwd=secret;"
db.Open

' Run a query → returns Array of Dictionary
Dim rows As Variant
rows = db.Query("SELECT name, email FROM users ORDER BY name")

Dim i As Integer
For i = 0 To rows.size() - 1
    Print rows[i]["name"] & " — " & rows[i]["email"]
Next i

' Parameterized query (safe from SQL injection)
rows = db.QueryParams("SELECT * FROM users WHERE age > ?", Array(18))

' INSERT / UPDATE / DELETE
db.Execute "INSERT INTO logs (msg) VALUES ('Hello')"
db.ExecuteParams "UPDATE users SET name = ? WHERE id = ?", Array("Alice", 42)

' Transactions
db.BeginTransaction
db.Execute "UPDATE accounts SET balance = balance - 100 WHERE id = 1"
db.Execute "UPDATE accounts SET balance = balance + 100 WHERE id = 2"
db.CommitTransaction          ' or db.RollbackTransaction

db.Close
```

### Connection String Examples

```
PostgreSQL:  Driver={PostgreSQL};Server=localhost;Database=mydb;Uid=user;Pwd=pass;
MySQL:       Driver={MySQL};Server=localhost;Database=mydb;User=root;Password=pass;
SQL Server:  Driver={ODBC Driver 17 for SQL Server};Server=localhost;Database=mydb;
SQLite:      Driver={SQLite3};Database=/path/to/db.sqlite;
```

### VGOdbc Methods

| Method | Description |
|--------|-------------|
| `Open()` / `OpenWithString(cs)` | Connect using current or specified connection string |
| `Close()` | Disconnect |
| `Execute(sql)` | Run INSERT/UPDATE/DELETE |
| `ExecuteParams(sql, params)` | Parameterized execute |
| `Query(sql)` | Run SELECT → `Array` of `Dictionary` |
| `QueryParams(sql, params)` | Parameterized query |
| `BeginTransaction()` | Start a transaction |
| `CommitTransaction()` | Commit |
| `RollbackTransaction()` | Rollback |
| `ListTables()` | List table names |
| `TableExists(name)` | Check if a table exists |
| `ListDrivers()` | List installed ODBC drivers |
| `.IsOpen` | Property — connection state |
| `.ConnectionString` | Property — get/set connection string |
| `.LastError` | Property — last error message |

---

## 3. Cryptography (VGCrypto)

Static utility class for hashing, encoding, encryption, and random generation.
Uses Godot's built-in crypto engine — no external dependencies.

### Hashing

```vb
Print VGCrypto.MD5("hello")        ' "5d41402abc4b2a76b9719d911017c592"
Print VGCrypto.SHA1("hello")       ' 40-char hex
Print VGCrypto.SHA256("hello")     ' 64-char hex

' Hash binary data
Dim hash As String
hash = VGCrypto.MD5Bytes(somePackedByteArray)
```

### Encoding

```vb
' Base64
Dim b64 As String
b64 = VGCrypto.base64_encode("secret".to_utf8_buffer())
Dim raw As Variant
raw = VGCrypto.base64_decode(b64)

' Hex
Dim hex As String
hex = VGCrypto.hex_encode(data)
raw = VGCrypto.hex_decode(hex)
```

### AES-256 Encryption

```vb
Dim key As String
key = "MySecretKey12345MySecretKey12345"   ' 32 bytes

Dim encrypted As Variant
encrypted = VGCrypto.encrypt_aes("top secret".to_utf8_buffer(), key.to_utf8_buffer())

Dim decrypted As Variant
decrypted = VGCrypto.decrypt_aes(encrypted, key.to_utf8_buffer())
Print decrypted.get_string_from_utf8()     ' "top secret"
```

### Random & UUID

```vb
Dim bytes As Variant
bytes = VGCrypto.random_bytes(32)

Dim id As String
id = VGCrypto.generate_uuid()      ' "550e8400-e29b-41d4-a716-446655440000"
```

### HMAC

```vb
Dim sig As String
sig = VGCrypto.hmac_sha256(payload.to_utf8_buffer(), key.to_utf8_buffer())
```

### Full API

| Method | Description |
|--------|-------------|
| `MD5(text)` / `SHA1(text)` / `SHA256(text)` | Hash a string → hex |
| `MD5Bytes(data)` / `SHA1Bytes(data)` / `SHA256Bytes(data)` | Hash bytes → hex |
| `base64_encode(data)` / `base64_decode(b64)` | Base64 encode/decode |
| `hex_encode(data)` / `hex_decode(hex)` | Hex encode/decode |
| `encrypt_aes(data, key)` / `decrypt_aes(data, key)` | AES-256-CBC |
| `random_bytes(count)` | Random byte array |
| `generate_uuid()` | RFC 4122 v4 UUID string |
| `hmac_sha256(data, key)` | HMAC-SHA256 hex signature |

---

## 4. XML Processing (VGXml)

Read, write, parse, and query XML documents. Uses Godot's XMLParser internally.

### Load and Parse

```vb
Dim xml As Object
Set xml = New VGXml

' From string
xml.LoadString "<catalog><book>Title</book></catalog>"

' From file
xml.LoadFile "res://data/config.xml"

' Parse into a Dictionary tree
Dim tree As Variant
tree = xml.Parse()
Print tree["tag"]                  ' "catalog"
Print tree["children"][0]["text"]  ' "Title"
```

### XPath-Style Queries

```vb
' Find all matching nodes
Dim books As Variant
books = xml.SelectNodes("catalog/book")

' Find first match
Dim first As Variant
first = xml.SelectSingleNode("catalog/book")
```

### Save

```vb
xml.SaveFile "user://output.xml"

' Or get as string
Dim s As String
s = xml.ToString()
```

### VGXml Methods

| Method | Description |
|--------|-------------|
| `LoadFile(path)` | Load XML from file |
| `LoadString(xml)` | Load XML from string |
| `SaveFile(path)` | Save to file |
| `ToString()` | Get XML as string |
| `Parse()` | Parse to Dictionary tree |
| `SelectNodes(path)` | XPath query → Array of nodes |
| `SelectSingleNode(path)` | XPath query → first match |
| `.XmlContent` | Property — raw XML string |
| `.LastError` | Property — last error message |

---

## 5. ZIP Archives (VGZip)

Create, read, and extract ZIP archives. Uses Godot's ZIPReader/ZIPPacker.

### Create a ZIP

```vb
Dim zip As Object
Set zip = New VGZip

zip.OpenWrite "user://backup.zip"
zip.AddText "readme.txt", "Hello World!"
zip.AddText "data/config.txt", "key=value"
zip.AddFile "image.png", imageBytes       ' PackedByteArray
zip.Close
```

### Read a ZIP

```vb
Dim zip As Object
Set zip = New VGZip

zip.OpenRead "user://backup.zip"

Print "Files: " & CStr(zip.FileCount)

Dim files As Variant
files = zip.ListFiles()

Dim txt As String
txt = zip.read_text("readme.txt")
Print txt                                  ' "Hello World!"

If zip.file_exists("data/config.txt") Then
    Print zip.read_text("data/config.txt")
End If

zip.Close
```

### Extract

```vb
zip.OpenRead "user://backup.zip"
zip.extract_to "user://restored/"          ' Extract all files
zip.extract_file "readme.txt", "user://readme_copy.txt"  ' Single file
zip.Close
```

### VGZip Methods

| Method | Description |
|--------|-------------|
| `OpenRead(path)` | Open for reading |
| `OpenWrite(path)` | Open/create for writing |
| `Close()` | Close the archive |
| `ListFiles()` | List all file names → Array |
| `read_file(name)` | Read file → PackedByteArray |
| `read_text(name)` | Read file → String |
| `file_exists(name)` | Check if file exists |
| `extract_to(dir)` | Extract all files to directory |
| `extract_file(name, dest)` | Extract single file |
| `AddText(name, text)` | Add a text file |
| `AddFile(name, data)` | Add a binary file |
| `add_directory_recursive(dir)` | Add entire directory tree |
| `.FileCount` | Property — number of files |
| `.IsOpen` | Property — whether archive is open |
| `.ArchivePath` | Property — file path |
| `.LastError` | Property — last error |

---

## 6. Async Tasks (VGTask / VGTaskRunner)

Run work on background threads without freezing the game.

### Single Task

```vb
Dim task As Object
Set task = New VGTask

' Run in background
task.RunAsync Callable(Me, "HeavyWork")

' Wait for result (blocks)
Dim result As Variant
result = task.WaitForResult()
Print "Done: " & CStr(result)

' Check status without blocking
Print task.Status        ' "pending", "running", "completed", "failed", "cancelled"
Print task.IsComplete    ' True / False
```

### Delayed Task

```vb
Dim task As Object
Set task = New VGTask
task.RunDelayed Callable(Me, "DoSomething"), 2.0    ' 2-second delay
```

### Cancellation

```vb
task.RunAsync Callable(Me, "LongProcess")
' ... later ...
task.Cancel
Print task.IsCancelled   ' True
```

### Parallel Task Runner

```vb
Dim runner As Object
Set runner = New VGTaskRunner

runner.AddTask Callable(Me, "Worker1")
runner.AddTask Callable(Me, "Worker2")
runner.AddTask Callable(Me, "Worker3")

Print "Tasks: " & CStr(runner.TaskCount)

runner.RunAll               ' Run all in parallel, wait for completion

Dim results As Variant
results = runner.get_all_results()

Dim i As Integer
For i = 0 To results.size() - 1
    Print "Task " & CStr(i) & ": " & CStr(results[i])
Next i
```

### VGTask Methods

| Method | Description |
|--------|-------------|
| `RunAsync(callable)` | Run in background thread |
| `RunAsyncWithArgs(callable, args)` | Run with arguments |
| `RunDelayed(callable, seconds)` | Run after delay |
| `Cancel()` | Cancel the task |
| `WaitForResult()` | Block until result ready |
| `.IsComplete` | Property |
| `.IsRunning` | Property |
| `.IsFailed` | Property |
| `.IsCancelled` | Property |
| `.Status` | Property — status string |
| `.Result` | Property — task result |
| `.ErrorMessage` | Property |

### VGTaskRunner Methods

| Method | Description |
|--------|-------------|
| `AddTask(callable)` | Add a task |
| `RunAll()` | Run all, wait for completion |
| `RunAllLimited(maxConcurrent)` | Run with thread limit |
| `get_all_results()` | Get all results → Array |
| `.TaskCount` | Property — number of tasks |
| `.CompletedCount` | Property |
| `.Progress` | Property — 0.0 to 1.0 |

---

## 7. Package Manager

Manage project dependencies with semantic versioning, registries, and
manifest files (`vgpkg.json`).

### Initialize

```vb
Dim pkg As Object
Set pkg = New VisualGasicPackage

pkg.Initialize "res://"
```

### Install Packages

```vb
' Install a single package
Dim result As Variant
result = pkg.InstallPackage("vg-math", "^1.0.0")
Print result["message"]

' Install multiple
result = pkg.install_packages(Array("vg-ui@2.0.0", "vg-net@1.5.0"))

' Update
result = pkg.update_package("vg-math")
result = pkg.update_all_packages()

' Uninstall
pkg.UninstallPackage "vg-math"
```

### Project Dependencies

```vb
' Initialize project manifest
pkg.initialize_project "res://"

' Add/remove dependencies
pkg.add_dependency "vg-utils", "^2.0.0"
pkg.remove_dependency "vg-utils"

' List current dependencies
Dim deps As Variant
deps = pkg.get_project_dependencies()
```

### Registries

```vb
' Add a package registry
pkg.AddRegistry "official", "https://packages.visualgasic.org"
pkg.AddRegistry "private", "https://my-server.com/vg-packages", "auth-token-123"
pkg.set_default_registry "official"

' Search
Dim results As Variant
results = pkg.search_packages("math")
```

### Create & Publish

```vb
' Create package template
pkg.create_package_template "my-lib", "library"

' Validate manifest
Dim valid As Boolean
valid = pkg.validate_package_manifest("res://vgpkg.json")

' Build & publish
pkg.build_package "res://"
pkg.publish_package "res://", "official"
```

### Version Constraint Syntax

| Pattern | Meaning |
|---------|---------|
| `^1.2.0` | Compatible with 1.x.x (≥1.2.0, <2.0.0) |
| `~1.2.0` | Patch updates only (≥1.2.0, <1.3.0) |
| `>=2.0.0` | At least 2.0.0 |
| `1.5.0` | Exact version |

---

## 8. Cross-Platform System Calls

All system classes now work on **Linux**, **macOS**, and **Windows**:

| Class | Linux/macOS | Windows |
|-------|------------|---------|
| `VGProcess` | fork/exec/pipe | CreateProcess/CreatePipe |
| `VGSocket` | POSIX sockets | WinSock2 |
| `VGFileWatcher` | inotify / kqueue | FindFirstChangeNotification |
| `VGSysTray` | (stub — desktop-specific) | Shell_NotifyIcon + HWND_MESSAGE |

These classes are available in current VisualGasic releases.
The Windows and macOS backends are complete, so the same VG code
runs on all three platforms without changes.

```vb
' Process — same code, all platforms
Dim proc As Object
Set proc = New Process
Dim output As String
output = proc.RunAndCapture("echo", "Hello World")
Print output

' Socket — same code, all platforms
Dim sock As Object
Set sock = New WinSock
sock.Protocol = 0   ' TCP
sock.Connect "example.com", 80
sock.SendData "GET / HTTP/1.0" & vbCrLf & vbCrLf
Print sock.GetData()
sock.Close
```

---

## 9. Real COM Interop (Windows)

On Windows, `CreateObject()` now falls through to the real COM subsystem
via `CoCreateInstance` / `IDispatch` when the requested ProgID isn't one of
the built-in emulated objects. This means you can automate **Excel**,
**Word**, **Outlook**, or any installed COM server.

```vb
' Built-in objects work everywhere (cross-platform)
Dim dict As Object
Set dict = CreateObject("Scripting.Dictionary")
dict.Add "key", "value"

' Real COM automation (Windows only)
Dim xl As Object
Set xl = CreateObject("Excel.Application")
xl.Visible = True
xl.Workbooks.Add
xl.Cells(1, 1).Value = "Hello from VisualGasic!"
```

---

## Demo Files

| Demo | Location | What it shows |
|------|----------|---------------|
| **FFI** | `demos/Utilities/FFI/demo_ffi.vg` | Load libm, call sqrt/cos, C structs |
| **FFI — C++ Lib** | `demos/Utilities/FFI/demo_ffi_cpp_lib.vg` | Build & call Vec2 C++ class via C ABI |
| **Crypto** | `demos/Utilities/Crypto/demo_crypto.vg` | MD5, SHA, AES, Base64, UUID, HMAC |
| **XML** | `demos/Utilities/XML/demo_xml.vg` | Parse, XPath, save/load |
| **ZIP** | `demos/Utilities/ZIP/demo_zip.vg` | Create, read, extract archives |
| **ODBC** | `demos/Data_and_Files/ODBC/demo_odbc.vg` | Database connect, query, transactions |
| **Async Tasks** | `demos/Threading/demo_async_tasks.vg` | VGTask, VGTaskRunner, cancellation |
| **Packages** | `demos/Utilities/PackageManager/demo_packages.vg` | Install, registries, dependencies |
| **Python Bridge** | `demos/Utilities/PythonBridge/demo_python_bridge.vg` | Import Python stdlib, call functions |
| **Smoke Test** | `demo/test_v3_features.vg` | Automated test of all system classes |

Run the smoke test:
```bash
cd demo
../Godot_v4.6.1-stable_linux.x86_64 --headless -s run_v3_features.gd
```

---

## 10. VGSystem (System Info)

Cross-platform system information queries.

### Quick Start

```vb
Dim sys As Object = New VGSystem
Print "Host: " & sys.Hostname
Print "CPU: " & sys.CpuName & " (" & CStr(sys.CpuCount) & " cores)"
Print "RAM: " & CStr(sys.TotalMemory / 1073741824) & " GB"
Print "OS: " & sys.OsFull
Print "Uptime: " & CStr(CInt(sys.Uptime / 3600)) & " hours"
Print "Locale: " & sys.GetLocale()
```

### API Reference

| Method | Returns | Description |
|--------|---------|-------------|
| `Hostname` | String | Machine hostname |
| `Username` | String | Current user |
| `ProcessId` | int | PID |
| `CpuCount` | int | Logical cores |
| `CpuName` | String | CPU model |
| `Architecture` | String | x86_64, aarch64, etc. |
| `TotalMemory` / `FreeMemory` / `UsedMemory` | int64 | RAM in bytes |
| `MemoryUsagePercent` | double | RAM % |
| `FreeDiskSpace(path)` / `TotalDiskSpace(path)` | int64 | Disk in bytes |
| `DiskUsagePercent(path)` | double | Disk % |
| `OsName` / `OsVersion` / `OsFull` | String | OS details |
| `Endianness` | String | "little" / "big" |
| `Uptime` | double | Seconds since boot |
| `GetEnv(name)` / `SetEnv(name, val)` / `HasEnv(name)` | String/void/bool | Environment variables |
| `GetAllEnv()` | Dictionary | All env vars |
| `GetLocale()` / `GetLanguage()` / `GetTimezone()` | String | Locale info |
| `GetTimezoneOffset()` | int | UTC offset (seconds) |
| `GetSystemInfo()` | Dictionary | Everything in one call |

### Platform Notes

- **Linux**: Uses `sysinfo()`, `statvfs()`, `uname()`, `/proc/cpuinfo`
- **macOS**: Uses `sysctl()`, `statvfs()`, `uname()`
- **Windows**: Uses `GlobalMemoryStatusEx()`, `GetDiskFreeSpaceExW()`, `GetComputerNameW()`

---

## 11. VGSignalHandler (OS Signals)

Handle OS signals and atexit cleanup. Thread-safe via `call_deferred`.

```vb
Dim sh As Object = New VGSignalHandler
sh.OnInterrupt(Lambda() => Print("Caught Ctrl+C!"))
sh.OnTerminate(Lambda() => Print("Shutting down"))
sh.OnExit(Lambda() => Print("Cleanup..."))
```

| Method | Description |
|--------|-------------|
| `OnInterrupt(handler)` | SIGINT (Ctrl+C) |
| `OnTerminate(handler)` | SIGTERM |
| `OnHangup(handler)` | SIGHUP |
| `OnUser1(handler)` / `OnUser2(handler)` | SIGUSR1/2 |
| `OnExit(handler)` | atexit cleanup |
| `SetHandler(name, handler)` | Generic by signal name |
| `RemoveHandler(name)` | Remove handler |
| `HasHandler(name)` | Check registration |
| `GetRegisteredSignals()` | List all names |
| `RaiseSignal(name)` | Send to self |
| `LastSignal` | Last received signal |
| `IsInstalled` | Any handlers active |

### Platform Notes

- **Linux/macOS**: Uses `std::signal()`, `std::atexit()`
- **Windows**: Uses `SetConsoleCtrlHandler()` for CTRL_C_EVENT, CTRL_CLOSE_EVENT, CTRL_LOGOFF_EVENT, CTRL_SHUTDOWN_EVENT

---

## 12. VGFilePermissions (Permissions & Links)

UNIX permissions, ownership, symlinks, file locking, VB6-style attributes.

```vb
Dim fp As Object = New VGFilePermissions
fp.Chmod "/tmp/script.sh", &o755
Print fp.GetPermissionsString("/tmp/script.sh")   ' "rwxr-xr-x"
fp.CreateSymlink "/tmp/link", "/tmp/script.sh"

' File locking
If fp.TryLockFile("/tmp/data.lock") Then
    ' ... critical section ...
    fp.UnlockFile "/tmp/data.lock"
End If

' VB6-style attributes
Dim attr As Integer = fp.GetAttr("C:\data.txt")
If attr And 1 Then Print "Read-only"
```

| Method | Returns | Description |
|--------|---------|-------------|
| `Chmod(path, mode)` | bool | Set UNIX permissions |
| `GetPermissions(path)` | int | Permission bits |
| `GetPermissionsString(path)` | String | "rwxr-xr-x" |
| `IsReadable/IsWritable/IsExecutable(path)` | bool | Access checks |
| `Chown(path, owner, group)` | bool | Change ownership |
| `GetOwner(path)` / `GetGroup(path)` | String | Owner/group name |
| `CreateSymlink(link, target)` | bool | Symbolic link |
| `CreateHardlink(link, target)` | bool | Hard link |
| `IsSymlink(path)` / `ReadSymlink(path)` | bool/String | Symlink queries |
| `LockFile(path)` / `TryLockFile(path)` | bool | Exclusive lock |
| `UnlockFile(path)` / `IsLocked(path)` | bool | Unlock / check |
| `GetAttr(path)` / `SetAttr(path, flags)` | int/bool | VB6 attributes (1=ReadOnly, 2=Hidden, 4=System, 16=Dir, 32=Archive) |
| `GetFileInfo(path)` | Dictionary | Full stat |
| `FileLen(path)` | int64 | Size in bytes |
| `FileType(path)` | String | "file", "directory", "symlink" |

### Platform Notes

- **Linux/macOS**: `chmod()`, `chown()`, `flock()`, `symlink()`, `lstat()`
- **Windows**: `CreateSymbolicLinkW()`, `LockFileEx()`, `GetFileAttributesW()`, `SetFileAttributesW()`

---

## 13. VGMemoryBuffer (Raw Memory)

Raw byte buffer with Peek/Poke — the VB6 equivalent of `CopyMemory`.

```vb
Dim buf As Object = New VGMemoryBuffer
buf.Allocate 1024

' Write C-style struct
buf.PokeInt32 0, 42
buf.PokeFloat 4, 3.14
buf.PokeFloat 8, 2.71

' Read back
Print "ID=" & CStr(buf.PeekInt32(0))
Print "X=" & CStr(buf.PeekFloat(4))

' FFI interop
Dim ptr As Long = buf.GetPointer()

Print buf.HexDump(0, 16)
buf.Free
```

| Method | Description |
|--------|-------------|
| `Allocate(size)` / `Resize(size)` / `Free()` | Lifecycle |
| `IsAllocated` / `Size` | Status |
| `Fill(byte)` / `FillRange(off, len, byte)` / `Clear()` | Initialize |
| `PeekByte/Int16/UInt16/Int32/Int64(off)` | Read integers |
| `PeekFloat/Double(off)` | Read floats |
| `PeekString(off, len)` | Read UTF-8 |
| `PokeByte/Int16/UInt16/Int32/Int64(off, val)` | Write integers |
| `PokeFloat/Double(off, val)` | Write floats |
| `PokeString(off, val)` | Write UTF-8 |
| `CopyTo(dest, srcOff, dstOff, len)` | Copy to buffer |
| `CopyFrom(src, srcOff, dstOff, len)` | Copy from buffer |
| `ToByteArray()` / `FromByteArray(arr)` | PackedByteArray conversion |
| `FindByte(val, start)` / `FindPattern(bytes, start)` | Search |
| `HexDump(off, len)` | Debug hex dump |
| `GetPointer()` | Raw int64 for FFI |

---

## 14. VGIPC (Inter-Process Communication)

Named pipes, UNIX domain sockets, and POSIX shared memory.

### Named Pipes

```vb
Dim ipc As Object = New VGIPC
ipc.CreateNamedPipe "/tmp/myapp.pipe"
ipc.OpenPipe "/tmp/myapp.pipe", "write"
ipc.WritePipe "Hello from VG!"
ipc.ClosePipe
```

| Method | Description |
|--------|-------------|
| `CreateNamedPipe(path)` | mkfifo / CreateNamedPipe |
| `OpenPipe(path, mode)` | Open for "read" or "write" |
| `ReadPipe(max)` / `ReadPipeBytes(max)` | Read string / bytes |
| `WritePipe(data)` / `WritePipeBytes(data)` | Write string / bytes |
| `ClosePipe()` / `DeleteNamedPipe(path)` | Close / remove |

### UNIX Domain Sockets

```vb
' Server
Dim srv As Object = New VGIPC
srv.CreateDomainSocket "/tmp/myapp.sock"
srv.AcceptConnection
Dim msg As String = srv.ReadSocket(1024)
srv.WriteSocket "ACK: " & msg
srv.CloseSocket

' Client
Dim cli As Object = New VGIPC
cli.ConnectDomainSocket "/tmp/myapp.sock"
cli.WriteSocket "Hello"
Print cli.ReadSocket(1024)
cli.CloseSocket
```

| Method | Description |
|--------|-------------|
| `CreateDomainSocket(path)` | Create, bind, listen |
| `ConnectDomainSocket(path)` | Connect as client |
| `AcceptConnection()` | Accept incoming |
| `ReadSocket(max)` / `ReadSocketBytes(max)` | Read |
| `WriteSocket(data)` / `WriteSocketBytes(data)` | Write |
| `CloseSocket()` | Close + unlink |

### Shared Memory

```vb
' Writer process
Dim w As Object = New VGIPC
w.CreateSharedMemory "myapp_data", 4096
w.WriteSharedMemory 0, "shared state"
w.CloseSharedMemory

' Reader process
Dim r As Object = New VGIPC
r.OpenSharedMemory "myapp_data", 4096
Print r.ReadSharedMemory(0, 12)  ' "shared state"
r.CloseSharedMemory
```

| Method | Description |
|--------|-------------|
| `CreateSharedMemory(name, size)` | shm_open + mmap |
| `OpenSharedMemory(name, size)` | Attach existing |
| `WriteSharedMemory(off, data)` / `WriteSharedMemoryBytes(off, data)` | Write |
| `ReadSharedMemory(off, len)` / `ReadSharedMemoryBytes(off, len)` | Read |
| `CloseSharedMemory()` | Unmap + unlink |

### Platform Notes

- **Linux**: `mkfifo()`, `AF_UNIX`, `shm_open()`/`mmap()` (links `-lrt`)
- **macOS**: Same POSIX APIs (no `-lrt` needed)
- **Windows**: `CreateNamedPipeW()`, `CreateFileMappingW()`/`MapViewOfFile()` (no domain sockets)

---

## 15. VGAndroidBridge (Android Platform)

JNI bridge for Android APIs. Returns safe defaults on non-Android platforms.

```vb
Dim android As Object = New VGAndroidBridge

If android.IsAndroid() Then
    Print "Device: " & android.DeviceManufacturer & " " & android.DeviceModel
    Print "SDK " & CStr(android.SdkVersion)
    android.ShowToast "Hello from VG!", 1
    android.Vibrate 200
    
    Dim batt As Dictionary = android.GetBatteryInfo()
    Print "Battery: " & CStr(batt("level")) & "%"
End If
```

| Method | Returns | Description |
|--------|---------|-------------|
| `SdkVersion` | int | Android SDK level |
| `DeviceModel` / `DeviceManufacturer` | String | Device info |
| `AndroidVersion` | String | Version string |
| `PackageName` / `AppVersion` / `DeviceId` | String | App identity |
| `HasPermission(perm)` | bool | Check permission |
| `RequestPermission(perm)` / `RequestPermissions(perms)` | void | Request |
| `GetGrantedPermissions()` | Array | Granted list |
| `OpenUrl(url)` / `ShareText(text, title)` / `SendEmail(to, subj, body)` | void | Intents |
| `OpenAppSettings()` | void | App settings |
| `ShowToast(msg, dur)` / `Vibrate(ms)` | void | UI feedback |
| `ExternalStoragePath` / `CacheDir` / `FilesDir` | String | Storage paths |
| `GetBatteryInfo()` | Dictionary | level, status, charging |
| `IsAndroid()` | bool | Platform check |
| `KeepScreenOn(enabled)` | void | Prevent sleep |

---

## 16. Real Threading

The multitask runtime now uses real OS threads instead of serial execution stubs.

| Feature | Before | After |
|---------|--------------|---------------|
| `Task.Run` | Serial (inline) | `std::thread` with scope clone |
| `Parallel For` | Serial loop | Partitioned across `hardware_concurrency()` cores |
| `Parallel Section` | Serial sequence | Atomic work-stealing (`std::atomic<int>`) |

### Safety Model

- Each thread gets an independent copy of the variable scope via `Dictionary.duplicate(true)`
- `std::atomic<bool>` propagates errors from worker threads
- `Parallel For` falls back to serial for ≤4 iterations to avoid thread overhead
- Foreground tasks are joined; background tasks are detached

```vb
' Real parallel execution across all CPU cores
Parallel For i = 0 To 999
    ProcessItem(i)
Next

' Real background thread
Task.Run BackgroundSave
    SerializeGameState()
    CompressAndWrite()
End Task
```

---

## 17. Python Bridge (PyBridgeFacade)

Call Python 3 modules and functions directly from VisualGasic, using
an out‑of‑process worker (Tier A). No compile‑time flag is needed.

**Prerequisite:** Python 3 must be installed and on PATH.

### Quick Start

```vb
Dim bridge As Object
Set bridge = New PyBridgeFacade

If Not bridge.InitializeBridge() Then
    Print "Error: " & bridge.GetStatus()
    Exit Sub
End If

' Import a Python stdlib module
Dim mathMod As Variant
mathMod = bridge.PyImport("math")

' Call functions
Dim result As Variant
result = bridge.PyCall(mathMod, "sqrt", Array(144.0))
Print "sqrt(144) = " & CStr(result)       ' 12.0

result = bridge.PyCall(mathMod, "sin", Array(3.14159265 / 2))
Print "sin(pi/2) = " & CStr(result)       ' 1.0

bridge.shutdown()
```

### Serialisation with json

```vb
Dim jsonMod As Variant
jsonMod = bridge.PyImport("json")

Dim data As Array
data = Array("hello", 42, True)

Dim jsonStr As Variant
jsonStr = bridge.PyCall(jsonMod, "dumps", Array(data))
Print jsonStr                              ' ["hello", 42, true]

Dim parsed As Variant
parsed = bridge.PyCall(jsonMod, "loads", Array(jsonStr))
```

### Error Handling

```vb
Dim badMod As Variant
badMod = bridge.PyImport("nonexistent_module_xyz")
If IsEmpty(badMod) Then
    Print "Import failed (expected)"
End If

Dim badResult As Variant
badResult = bridge.PyCall(mathMod, "nonexistent_func", Array(42))
If IsEmpty(badResult) Then
    Print "Call failed (expected)"
End If
```

### Bulk Data / PyProcessBuffer

```vb
Dim bufStr As String
bufStr = "Hello from VisualGasic!"

Dim buffer As Variant
buffer = bufStr.to_utf8_buffer()
Dim bufResult As Variant
bufResult = bridge.PyProcessBuffer(jsonMod, "dumps", buffer)
```

### PyBridgeFacade Methods

| Method | Description |
|--------|-------------|
| `InitializeBridge()` | Launch worker, verify connectivity |
| `IsAvailable()` | Static — check if Python 3 is on PATH |
| `GetStatus()` | Current bridge status string |
| `PyImport(module)` | Import a Python module → opaque handle |
| `PyCall(handle, method, args)` | Call function on imported module |
| `PyCallAsync(module, method, args)` | Async call (runs synchronously in v6) |
| `PyProcessBuffer(handle, method, buffer)` | Bulk data processing |
| `shutdown()` | Graceful worker termination |

### Architecture

- **Tier A (v6 baseline):** Launches `python_worker.py` as a child process.
  Protocol: length‑prefixed JSON frames over stdin/stdout.
- **Tier B (planned Phase 6):** Embedded CPython — requires `python=1` build flag.

### Demo

```
demos/Utilities/PythonBridge/demo_python_bridge.vg
```

```bash
godot --headless --path demo -s test_suites/run_vg.gd -- demo_python_bridge.vg
```
