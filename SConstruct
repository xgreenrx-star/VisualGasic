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
    "src/visual_gasic_lsp.cpp",  # LSP needs binding rework for LspPosition type (v3.0)
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
    # -rdynamic is Linux-only for backtrace symbol export
    if env["platform"] != "windows":
        env.Append(LINKFLAGS=["-rdynamic"])
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
