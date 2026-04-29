#!/usr/bin/env python
import os
import sys

env = SConscript("godot-cpp/SConstruct")

# Allow passing debug_build via command-line args to enable -g -O0
from SCons.Script import ARGUMENTS
if ARGUMENTS.get("debug_build", "0") == "1":
    env["debug_build"] = True

# Optional AddressSanitizer build flag: pass `asan=1` on scons command line
if ARGUMENTS.get("asan", "0") == "1":
    env.Append(CCFLAGS=["-fsanitize=address", "-fno-omit-frame-pointer", "-g", "-O1"])
    env.Append(LINKFLAGS=["-fsanitize=address"])

# For the reference:
# - godot-cpp/test/src and godot-cpp/test/header are the includes
# - src is our local source

env.Append(CPPPATH=["src"])
sources = Glob("src/*.cpp")

# Exclude files that should not be compiled
exclude_files = [
    # All LSP binding issues resolved — LspPosition replaced with int params (v3.2)
]
sources = [s for s in sources if str(s) not in exclude_files]

# Detect MSVC vs GCC/Clang toolchain
_cc = str(env.subst("$CC")).lower()
_is_msvc = env.get("is_msvc", False) or _cc.endswith("cl") or _cc.endswith("cl.exe")

# Build variant flags: simple debug vs release heuristics driven by env['target']
if "debug" in env.get("target", "").lower() or env.get("debug_build", False):
    if _is_msvc:
        env.Append(CCFLAGS=["/Z7", "/Od"])
        env.Append(LINKFLAGS=["/DEBUG"])
    else:
        env.Append(CCFLAGS=["-g", "-O0"])
else:
    # Ship release binaries with symbols so perf reports can resolve VisualGasic frames
    if _is_msvc:
        env.Append(CCFLAGS=["/O2", "/DNDEBUG", "/Z7"])
        env.Append(LINKFLAGS=["/DEBUG"])
    else:
        env.Append(CCFLAGS=["-O3", "-DNDEBUG", "-g"])
        env.Append(LINKFLAGS=["-g"])

# Ensure debug symbols are preserved for template_debug builds (force link debug flags)
if "template_debug" in env.get("target", "").lower() or env.get("debug_build", False):
    if _is_msvc:
        env.Append(LINKFLAGS=["/DEBUG"])
    else:
        env.Append(LINKFLAGS=["-g"])
    # -rdynamic is Linux-only for backtrace symbol export
    if env["platform"] != "windows":
        env.Append(LINKFLAGS=["-rdynamic"])
    # Prevent automatic stripping of the produced shared library in debug builds.
    # Some toolchains or builders may run strip as a separate step; ensure STRIP is empty.
    env['STRIP'] = ''

# Force no automatic stripping for all builds in this repository to help debugging.
env['STRIP'] = ''

# --- libffi linking (required by VGNativeLibrary FFI support) ---
# Define VG_HAS_LIBFFI when libffi is available so FFI code compiles conditionally.
if env["platform"] in ["linux", "macos"]:
    try:
        env.ParseConfig('pkg-config --cflags --libs libffi')
        env.Append(CPPDEFINES=["VG_HAS_LIBFFI"])
    except Exception:
        # Fallback if pkg-config is not available
        env.Append(LIBS=["ffi"])
        env.Append(CPPDEFINES=["VG_HAS_LIBFFI"])
elif env["platform"] == "windows":
    # On Windows the FFI calls fall back to LoadLibrary/GetProcAddress;
    # link libffi only when a pre-built static lib is available.
    import os as _os
    if _os.path.exists('thirdparty/libffi/lib/ffi.lib'):
        env.Append(CPPPATH=['thirdparty/libffi/include'])
        env.Append(LIBPATH=['thirdparty/libffi/lib'])
        env.Append(LIBS=['ffi'])
        env.Append(CPPDEFINES=["VG_HAS_LIBFFI"])

# --- POSIX libraries required by v3.1 system-level classes ---
# librt: shm_open/shm_unlink (VGIPC shared memory)
# libpthread: threading in VGTask, Parallel For
if env["platform"] == "linux":
    env.Append(LIBS=["rt", "pthread"])

# --- Windows system libraries ---
# ws2_32: Winsock2 (sockets, networking)
# ole32 + oleaut32: COM interop (VGComObject)
# uuid: COM interface IIDs (IID_IDispatch, etc.)
# user32: CreateWindowEx, DestroyWindow, LoadIcon, RegisterClass (VGSysTray)
# shell32: Shell_NotifyIcon, ShellExecute (VGSysTray, VGSystem)
# advapi32: Registry APIs, GetUserName (VGSystem, VGRegistry)
if env["platform"] == "windows":
    env.Append(LIBS=["ws2_32", "ole32", "oleaut32", "uuid", "user32", "shell32", "advapi32"])

# --- Android build support ---
if env["platform"] == "android":
    env.Append(CPPDEFINES=["ANDROID_ENABLED"])
    env.Append(LIBS=["log"])  # __android_log_print
    # Android NDK sysroot provides POSIX subset — no librt needed

# Optional: allow using ccache by setting the environment variable USE_CCACHE=1
import os
if os.environ.get("USE_CCACHE", "0") == "1":
    # Prepend ccache to the compiler tool if available
    try:
        env.Prepend(CC="ccache "+env.get("CC", "gcc"))
    except Exception:
        pass

# Optional: treat warnings as errors via environment ARGUMENT (warn_as_error=1)
from SCons.Script import ARGUMENTS
if ARGUMENTS.get("warn_as_error", "0") == "1":
    env.Append(CCFLAGS=["-Wall", "-Werror"])


if env["platform"] == "macos":
    library = env.SharedLibrary(
        "demo/bin/libvisualgasic.{}.{}.framework/libvisualgasic.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "demo/bin/visualgasic{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)

# Post-build: mirror the .so into addons/visual_gasic/bin/ (canonical location
# used by symlinked game projects and the install scripts).
import shutil as _shutil, glob as _glob
def _mirror_to_addons(target, source, env):
    """Copy built libraries from demo/bin/ → addons/visual_gasic/bin/.

    `addons/visual_gasic/bin` is committed as a symlink → `../../bin`. On fresh
    CI clones the symlink target may not exist (root `bin/` is gitignored), so
    we resolve through the symlink and create the real destination directory
    before copying. This makes the post-action idempotent across local dev,
    fresh clones, and re-runs.
    """
    import os
    dst = "addons/visual_gasic/bin"
    # Resolve symlinks so we materialize the real target dir if missing.
    real_dst = os.path.realpath(dst)
    try:
        os.makedirs(real_dst, exist_ok=True)
    except OSError:
        # As a fallback, if `dst` itself is a dangling symlink, replace it
        # with a real directory so the copy below can proceed.
        if os.path.islink(dst) and not os.path.exists(dst):
            os.unlink(dst)
            os.makedirs(dst, exist_ok=True)
        else:
            raise
    for t in target:
        src_path = str(t)
        if os.path.isfile(src_path):
            try:
                _shutil.copy2(src_path, os.path.join(dst, os.path.basename(src_path)))
            except (OSError, IOError) as exc:
                # Non-fatal: mirroring is a convenience. Warn but don't break the build.
                print("warning: _mirror_to_addons could not copy {}: {}".format(src_path, exc))
env.AddPostAction(library, _mirror_to_addons)

# Additional helper target: parser harness (link against same objects)
# NOTE: Tool builds disabled - missing headers and incomplete implementations
# To enable, create the missing tools/standalone_tokenizer.h and tools/parser_harness.cpp

# import os as tools_os
# try:
#     if tools_os.path.exists('tools/parser_harness.cpp'):
#         prog = env.Program(target="tools/parser_harness", source=(['tools/parser_harness.cpp'] + sources))
#         Default(prog)
# except Exception:
#     pass
# 
# ... rest of tools disabled ...
