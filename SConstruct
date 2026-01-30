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

# Exclude problematic files that need additional work
exclude_files = [
    "src/visual_gasic_lsp.cpp",  # Custom Position type needs Godot binding work
    # JIT, performance, and REPL modules are now fixed and included
]
# Also exclude old backup files
exclude_files += [
    "src/visual_gasic_jit_old.cpp",
    "src/visual_gasic_repl_old.cpp", 
    "src/visual_gasic_performance_old.cpp",
]
sources = [s for s in sources if str(s) not in exclude_files]

# Build variant flags: simple debug vs release heuristics driven by env['target']
if "debug" in env.get("target", "").lower() or env.get("debug_build", False):
    env.Append(CCFLAGS=["-g", "-O0"])
else:
    # Ship release binaries with symbols so perf reports can resolve VisualGasic frames
    env.Append(CCFLAGS=["-O3", "-DNDEBUG", "-g"])
    env.Append(LINKFLAGS=["-g"])

# Ensure debug symbols are preserved for template_debug builds (force link debug flags)
if "template_debug" in env.get("target", "").lower() or env.get("debug_build", False):
    env.Append(LINKFLAGS=["-g"])
    env.Append(LINKFLAGS=["-rdynamic"])  # ensure symbols exported for backtraces
    # Prevent automatic stripping of the produced shared library in debug builds.
    # Some toolchains or builders may run strip as a separate step; ensure STRIP is empty.
    env['STRIP'] = ''

# Force no automatic stripping for all builds in this repository to help debugging.
env['STRIP'] = ''

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
