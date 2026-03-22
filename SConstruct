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
        env.Append(CCFLAGS=["/Zi", "/Od"])
        env.Append(LINKFLAGS=["/DEBUG"])
    else:
        env.Append(CCFLAGS=["-g", "-O0"])
else:
    # Ship release binaries with symbols so perf reports can resolve VisualGasic frames
    if _is_msvc:
        env.Append(CCFLAGS=["/O2", "/DNDEBUG", "/Zi"])
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
if env["platform"] == "windows":
    env.Append(LIBS=["ws2_32", "ole32", "oleaut32", "uuid"])

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
